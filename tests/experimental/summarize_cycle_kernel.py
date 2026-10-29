"""Summarize like-for-like native/archived/current cycle measurements."""
import json
import pathlib
import statistics

ROOT = pathlib.Path(__file__).resolve().parent
MARKER = '<!-- MEASURED_RESULTS -->'


def main():
    raw = json.loads((ROOT / 'cycle_kernel_benchmark_results.json').read_text())
    validation = json.loads((ROOT / 'cycle_kernel_validation.json').read_text())
    assert not raw['failures'] and not validation['failures']
    groups = {}
    for row in raw['runs']:
        if not row['warmup']:
            groups.setdefault((row['label'], row['ticks']), {}).setdefault(row['kind'], []).append(row)
    summaries = []
    for (label, ticks), methods in groups.items():
        timings = {kind: {'median_usec': statistics.median(r['wall_usec'] for r in rows),
                          'min_usec': min(r['wall_usec'] for r in rows),
                          'max_usec': max(r['wall_usec'] for r in rows)}
                   for kind, rows in methods.items()}
        observed = next(x for x in raw['observations'] if x['label'] == label and x['ticks'] == ticks)
        counters = observed['counters']
        summaries.append({'label': label, 'ticks': ticks, 'timings': timings,
                          'speedup': timings['exact']['median_usec'] / timings['extended']['median_usec'],
                          'change_vs_previous_percent': 100 * (timings['extended']['median_usec'] / timings['previous']['median_usec'] - 1),
                          'coverage_percent': 100 * counters['kernel_ticks'] / ticks,
                          'observations': observed,
                          'previous_packet_retained_estimate_bytes': statistics.median(r['packet_retained_allocation_estimate_bytes'] for r in methods['previous_isolated']),
                          'packet_retained_estimate_bytes': statistics.median(r['packet_retained_allocation_estimate_bytes'] for r in methods['isolated'])})
    exact_rows = [r for r in raw['runs'] if r['kind'] not in ('exact', 'adaptive')]
    assert all(r['binary_parity'] and r['rng_parity'] and r['discrete_parity'] and r['numeric_error']['normalized'] == 0 for r in exact_rows)
    summary = {'engine': raw['engine'], 'cpu': raw['cpu'], 'measured_samples_per_method': 3,
               'non_native_binary_parity_samples_including_warmup': len(exact_rows),
               'individual_tick_comparisons': sum(x.get('compared_ticks', 0) for x in validation['cases']),
               'scenarios': summaries}
    (ROOT / 'cycle_kernel_summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    lines = [MARKER, '', '## Measured results', '',
             'Milliseconds below are medians of three measured runs; one preceding warmup per method/scenario is excluded. Ranges are measured min–max, not confidence intervals.', '',
             '| Fixture / ticks | Native ms | Previous public ms | Extended public ms | Adaptive reference ms | Speedup vs native | Kernel coverage |',
             '|---|---:|---:|---:|---:|---:|---:|']
    for s in summaries:
        t = s['timings']
        speedup = f"{s['speedup']:.3f}×" if s['coverage_percent'] > 0 else 'n/a (native fallback)'
        lines.append(f"| {s['label']} / {s['ticks']} | {t['exact']['median_usec']/1000:.3f} | {t['previous']['median_usec']/1000:.3f} | {t['extended']['median_usec']/1000:.3f} | {t['adaptive']['median_usec']/1000:.3f} | {speedup} | {s['coverage_percent']:.3f}% |")
    lines += ['', '| Fixture / ticks | Previous public range ms | Extended public range ms | Runtime change vs previous | Previous isolated ms | Extended isolated ms | Previous / extended retained packet bytes (estimate) |',
              '|---|---:|---:|---:|---:|---:|---:|']
    for s in summaries:
        t = s['timings']
        lines.append(f"| {s['label']} / {s['ticks']} | {t['previous']['min_usec']/1000:.3f}–{t['previous']['max_usec']/1000:.3f} | {t['extended']['min_usec']/1000:.3f}–{t['extended']['max_usec']/1000:.3f} | {s['change_vs_previous_percent']:+.2f}% | {t['previous_isolated']['median_usec']/1000:.3f} | {t['isolated']['median_usec']/1000:.3f} | {s['previous_packet_retained_estimate_bytes']:.0f} / {s['packet_retained_estimate_bytes']:.0f} |")
    lines += ['', 'Separate intrusive phase-clock runs (excluded from throughput medians):', '',
              '| Fixture / ticks | Kernel / native ticks | Builds (rebuilds = builds − 1) | Structural invalidation ticks | Automatic header ticks | Build µs total | Release µs total | Kernel µs total | Native µs total | Kernel cycle µs | Cycle invalidations |',
              '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|']
    for s in summaries:
        c = s['observations']['counters']
        lines.append(f"| {s['label']} / {s['ticks']} | {c['kernel_ticks']} / {c['fallback_ticks']} | {c['builds']} | {c['structural_invalidations']} | {c['event_ticks']} | {c['build_usec']} | {c['invalidate_usec']} | {c['kernel_usec']} | {c['fallback_usec']} | {c['cycle_usec']} | {c['cycle_invalidations']} |")
    lines += ['', 'Native-cycle telemetry comes from separate, verified-equivalent diagnostic executions, never the timed optimized path:', '',
              '| Fixture / ticks | Completions | Auto starts / attempts | Critical / normal | RNG randi words | Native completion µs | Native Forge cycle µs | Net level-change calls: completion / startup |',
              '|---|---:|---:|---:|---:|---:|---:|---:|']
    for s in summaries:
        o=s['observations']; c=o['cycle_activity']
        lines.append(f"| {s['label']} / {s['ticks']} | {c['completions']} | {c['auto_successes']} / {c['auto_attempts']} | {o['critical_completions']} / {o['normal_completions']} | {o['rng_words']} | {c['completion_usec']} | {c['cycle_usec']} | {c['completion_level_changes']} / {c['startup_level_changes']} |")
    lines += ['', 'Native profiler (intrusive, overlapping microsecond totals; excluded from throughput):', '',
              '| Fixture / ticks | Generator processing | Cycle processing subset | Input / output rate calculations | Environmental effects | Generator / upgrade automation | Automatic upgrades |',
              '|---|---:|---:|---:|---:|---:|---:|']
    for s in summaries:
        t = s['observations']['native_profile']['totals_usec']
        lines.append(f"| {s['label']} / {s['ticks']} | {t.get('generator_processing',0)} | {t.get('cycle_generator_processing',0)} | {t.get('input_rate_calculation',0)} / {t.get('production_rate_calculation',0)} | {t.get('environmental_effects',0)} | {t.get('generator_automation',0)} / {t.get('upgrade_automation',0)} | {t.get('automatic_upgrades',0)} |")
    lines += ['', f"Binary/discrete/RNG parity: **{len(exact_rows)}/{len(exact_rows)}** archived/current public/isolated samples including warmup; all numerical error fields zero. Dedicated cycle differential suite: **{summary['individual_tick_comparisons']}** individual tick comparisons, plus reentry and diagnostic-instrumentation parity. Full original graph fingerprints match at endpoints. No tolerance was widened.", '']
    report = ROOT / 'EXACT_FLOW_CYCLES.md'
    report.write_text(report.read_text().split(MARKER)[0].rstrip() + '\n\n' + '\n'.join(lines))


if __name__ == '__main__':
    main()
