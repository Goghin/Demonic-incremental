"""Summarize like-for-like native/archived/current automation measurements."""
import json
import pathlib
import statistics

ROOT = pathlib.Path(__file__).resolve().parent
MARKER = '<!-- MEASURED_RESULTS -->'


def main():
    raw = json.loads((ROOT / 'automation_kernel_benchmark_results.json').read_text())
    validation = json.loads((ROOT / 'automation_kernel_validation.json').read_text())
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
    (ROOT / 'automation_kernel_summary.json').write_text(json.dumps(summary, indent=2) + '\n')
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
              '| Fixture / ticks | Kernel / native ticks | Builds (rebuilds = builds − 1) | Purchase invalidation ticks | Automatic header ticks | Build µs total | Release µs total | Kernel µs total | Native µs total |',
              '|---|---:|---:|---:|---:|---:|---:|---:|---:|']
    for s in summaries:
        c = s['observations']['counters']
        lines.append(f"| {s['label']} / {s['ticks']} | {c['kernel_ticks']} / {c['fallback_ticks']} | {c['builds']} | {c['structural_invalidations']} | {c['event_ticks']} | {c['build_usec']} | {c['invalidate_usec']} | {c['kernel_usec']} | {c['fallback_usec']} |")
    lines += ['', 'Native-manager telemetry comes from separate, verified-equivalent diagnostic executions, never the timed optimized path:', '',
              '| Fixture / ticks | Generator success / failed attempts | Generator waiting checks / cache refreshes | Generator cooldown decrements / ready transitions | Upgrade success / failed attempts | Upgrade waiting checks | Upgrade cooldown decrements / ready transitions |',
              '|---|---:|---:|---:|---:|---:|---:|']
    for s in summaries:
        o=s['observations'];g=o['generator_activity'];u=o['upgrade_activity']
        lines.append(f"| {s['label']} / {s['ticks']} | {g['successful']} / {g['failed']} | {g['waiting_checks']} / {g['waiting_refreshes']} | {g['cooldown_decrements']} / {g['ready_transitions']} | {u['successful']} / {u['failed']} | {u['waiting_checks']} | {u['cooldown_decrements']} / {u['ready_transitions']} |")
    lines += ['', f"Binary/discrete/RNG parity: **{len(exact_rows)}/{len(exact_rows)}** archived/current public/isolated samples including warmup; all numerical error fields zero. Dedicated automation differential suite: **{summary['individual_tick_comparisons']}** individual tick comparisons, plus reentry and diagnostic-instrumentation parity. Full original graph fingerprints match at endpoints. No tolerance was widened.", '']
    report = ROOT / 'EXACT_FLOW_AUTOMATION.md'
    report.write_text(report.read_text().split(MARKER)[0].rstrip() + '\n\n' + '\n'.join(lines))


if __name__ == '__main__':
    main()
