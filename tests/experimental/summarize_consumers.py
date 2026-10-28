"""Regenerate measured consumer tables from raw observations, without timing."""
import json
import pathlib
import statistics

ROOT = pathlib.Path(__file__).resolve().parent


def median(values):
    return statistics.median(list(values))


def main():
    raw = json.loads((ROOT / 'consumer_benchmark_results.json').read_text())
    validation = json.loads((ROOT / 'consumer_validation.json').read_text())
    assert not raw['failures'] and not validation['failures']
    assert len(raw['runs']) == 288, 'Full benchmark matrix required, not QUICK mode'
    groups = []
    for label, ticks in sorted({(r['label'], r['ticks']) for r in raw['runs']}):
        group = {'label': label, 'ticks': ticks, 'diagnostic': label.startswith(('mite_', 'multi_')), 'methods': {}}
        for kind in ('exact', 'previous', 'previous_isolated', 'isolated', 'extended', 'adaptive'):
            rows = [r for r in raw['runs'] if r['label'] == label and r['ticks'] == ticks and r['kind'] == kind and not r['warmup']]
            times = [r['wall_usec'] for r in rows]
            method = {'samples_usec': times, 'median_usec': median(times), 'min_usec': min(times), 'max_usec': max(times),
                      'usec_per_tick': median(times) / ticks,
                      'binary_parity': all(r['binary_parity'] for r in rows),
                      'discrete_parity': all(r['discrete_parity'] for r in rows),
                      'rng_parity': all(r['rng_parity'] for r in rows),
                      'max_normalized_numeric_error': max(r['numeric_error']['normalized'] for r in rows),
                      'kernel_coverage_percent': median(100 * r['kernel_ticks'] / ticks for r in rows),
                      'fallback_ticks': median(r['fallback_ticks'] for r in rows),
                      'packet_build_usec': median(r['packet_build_usec'] for r in rows),
                      'retained_packet_estimate_bytes': median(r['packet_retained_allocation_estimate_bytes'] for r in rows)}
            if kind in ('extended', 'previous'):
                method['build_usec'] = median(r['counters']['build_usec'] for r in rows)
                method['release_usec'] = median(r['counters']['invalidate_usec'] for r in rows)
                method['builds'] = median(r['counters']['builds'] for r in rows)
                method['automatic_event_ticks'] = median(r['counters']['event_ticks'] for r in rows)
            if kind != 'adaptive':
                assert method['binary_parity'] and method['discrete_parity'] and method['rng_parity']
                assert method['max_normalized_numeric_error'] == 0
            group['methods'][kind] = method
        for method in group['methods'].values():
            method['speedup_vs_exact'] = group['methods']['exact']['median_usec'] / method['median_usec']
            method['speedup_vs_previous_public'] = group['methods']['previous']['median_usec'] / method['median_usec']
        groups.append(group)
    tested = [r for r in raw['runs'] if r['kind'] in ('previous', 'previous_isolated', 'isolated', 'extended')]
    assert all(r['binary_parity'] for r in tested)
    summary = {'engine': raw['engine'], 'cpu': raw['cpu'], 'sample_method': 'Three samples after one excluded warmup, alternating order; min/max are observed ranges, not confidence intervals.',
               'kernel_and_previous_parity_samples_including_warmup': len(tested),
               'compared_tick_views': sum(c.get('compared_ticks', 0) for c in validation['cases']),
               'additional_tick_views': sum(c.get('reserve_edge_checks', 0) + c.get('repeated_transitions', 0) + (c['counters']['kernel_ticks'] + c['counters']['fallback_ticks'] if c.get('reentry') else 0) for c in validation['cases']),
               'benchmarks': groups, 'observations': raw['observations'], 'validation_failures': validation['failures']}
    (ROOT / 'consumer_summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    lines = ['## Final measurements', '',
             'Official %s, Linux x86_64, %s. All times below are milliseconds unless labeled otherwise. One warmup excluded, three measured repetitions. Raw samples and ranges are retained in consumer_summary.json.' % (raw['engine']['string'], raw['cpu']), '',
             '| Fixture / ticks | Native | Previous public | Extended public | Adaptive reference | Extended / native speedup | Extended coverage |',
             '|---|---:|---:|---:|---:|---:|---:|']
    for group in groups:
        m = group['methods']
        values = ['%.3f' % (m[k]['median_usec']/1000) for k in ('exact', 'previous', 'extended', 'adaptive')]
        lines.append('| %s / %s | %s | %.3f× | %.0f%% |' % (group['label'], group['ticks'], ' | '.join(values), m['extended']['speedup_vs_exact'], m['extended']['kernel_coverage_percent']))
    lines += ['', 'The original mid and Forge fixtures still have zero kernel coverage; their apparent relative speed changes are fallback-loop/scheduling measurements, not acceleration of those mechanics. Diagnostic scenarios (mite_*, multi_*) are controlled cases, not mature-game speedup evidence.', '',
              '| Fixture / ticks | Previous isolated | Extended isolated | Isolated speedup vs native | Public build µs | Public release µs | Packet bytes (retained estimate) |',
              '|---|---:|---:|---:|---:|---:|---:|']
    for group in groups:
        m = group['methods']; k = m['extended']; isolated = m['isolated']
        lines.append('| %s / %s | %.3f | %.3f | %.3f× | %.0f | %.0f | %.0f |' % (group['label'],group['ticks'], m['previous_isolated']['median_usec']/1000, isolated['median_usec']/1000, isolated['speedup_vs_exact'],k['build_usec'],k['release_usec'],isolated['retained_packet_estimate_bytes']))
    lines += ['', 'There is no additional bulk write-back or checkpoint cost. Every live balance/phase/statistics write is included in both isolated and public kernel time. Independent samples and different loop dispatch/control paths can invert isolated/public medians; their difference is not a setup measurement.', '',
              '| Fixture / ticks | Previous public range | Extended public range | Extended µs/tick | Public change vs previous |',
              '|---|---:|---:|---:|---:|']
    for group in groups:
        m=group['methods'];old=m['previous'];new=m['extended']
        lines.append('| %s / %s | %.3f–%.3f | %.3f–%.3f | %.2f | %+.2f%% runtime |' % (group['label'],group['ticks'],old['min_usec']/1000,old['max_usec']/1000,new['min_usec']/1000,new['max_usec']/1000,new['usec_per_tick'],100*(new['median_usec']/old['median_usec']-1)))
    early_short = next(g['methods'] for g in groups if g['label'] == 'early' and g['ticks'] == 2000)
    early_long = next(g['methods'] for g in groups if g['label'] == 'early' and g['ticks'] == 36000)
    changes = [100 * (m['extended']['median_usec'] / m['previous']['median_usec'] - 1) for m in (early_short, early_long)]
    overlap = all(max(m['extended']['min_usec'], m['previous']['min_usec']) <= min(m['extended']['max_usec'], m['previous']['max_usec']) for m in (early_short, early_long))
    early_note = 'Early public runtime changes versus the previous kernel are %+.2f%% at 2,000 ticks and %+.2f%% at 36,000 ticks; their observed ranges %s. Both remain faster than native. The longer median regression is retained explicitly. Extra input-record indirection and disabled diagnostic branches add interpreter work; scheduling/cache variance is also visible, and three samples cannot attribute the whole difference to either. The consumer-stage speedups survive construction and all required synchronization; these states still have no running TimeManager schedule.' % (changes[0], changes[1], 'overlap' if overlap else 'do not all overlap')
    lines += ['', early_note, '',
              '| Untimed diagnostic interval | Kernel / native ticks | Builds | Automatic event ticks | Throttle transitions | Partial-duration operations | Input exhaustion events | Empty duration checks |',
              '|---|---:|---:|---:|---:|---:|---:|---:|']
    for observation in raw['observations']:
        c=observation['counters'];f=observation['flows']
        lines.append('| %s / %s | %s / %s | %s | %s | %s | %s | %s | %s |' % (observation['label'],observation['ticks'],c['kernel_ticks'],c['fallback_ticks'],c['builds'],c['event_ticks'],f.get('controller_transitions','n/a'),f.get('partial_operations','n/a'),f.get('input_exhaustions','n/a'),f.get('empty_duration_checks','n/a')))
    lines += ['', 'Partial operations count positive input-limited durations below the native stop epsilon, across all executed continuous generators. Empty duration checks count reached multi-input duration checks returning zero; empty startup rejection is earlier and is not included. Input exhaustion events count each positive sequential consumption that writes an input balance to exactly zero, including exact-boundary depletion; already-empty startup is not a new exhaustion event. Exact-boundary and startup exhaustion have dedicated binary regression witnesses. A partial-duration operation can leave a floating-point residual; no epsilon clamp is introduced. Flow event telemetry covers kernel-executed work; internal events during native fallback are not attributed. Rebuild count is builds minus one; controller transitions require no rebuild. The separate automatic-upgrade regression continues to require native boundary exit/reconstruction.', '',
              'Independent blocker inventory at entry:']
    for observation in raw['observations']:
        if observation['label'] in ('mid', 'forge_competing'):
            lines += ['', '- %s: `%s`' % (observation['label'],json.dumps(observation['initial_blockers'],sort_keys=True))]
    lines += ['', '**Parity:** %s previous/extended public/isolated samples including warmup have complete byte equality, discrete/RNG equality and zero measured numerical error against constant-tick native control. The dedicated consumer suite compares %s individual tick views plus repeated/reentry views; the long reached test spans 10,000 ticks. Binary equality includes fractional phases, consumption/accounting, throttles and the fixed dormancy penalty. No tolerances were expanded.' % (len(tested),summary['compared_tick_views']), '',
              '**Next capability:** enabled generator/upgrade automation, with native ordering/cooldown/waiting-cache preservation and a post-purchase structural invalidation contract. It is the independent blocker in the original mid fixture. Active cycles remain an additional Forge blocker. TimeManager integration is separately necessary before claiming end-to-end dormancy behavior or offline-client speedups; rebuilding per tiny clock update could erase the measured benefit and must be measured.', '']
    path=ROOT/'EXACT_FLOW_CONSUMERS.md'
    path.write_text(path.read_text().split('## Final measurements')[0].rstrip()+'\n\n'+'\n'.join(lines))


if __name__ == '__main__':
    main()
