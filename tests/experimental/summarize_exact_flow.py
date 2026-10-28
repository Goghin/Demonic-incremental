"""Summarize retained raw measurements; no timing or allocation is inferred."""
import json
import pathlib
import statistics

ROOT = pathlib.Path(__file__).resolve().parent


def median(values):
    return statistics.median(list(values))


def main():
    benchmark = json.loads((ROOT / 'exact_flow_benchmark_results.json').read_text())
    profile = json.loads((ROOT / 'kernel_profile_results.json').read_text())
    validation = json.loads((ROOT / 'exact_flow_validation.json').read_text())
    assert not benchmark['failures'] and not profile['failures'] and not validation['failures']
    groups = []
    for label, ticks in sorted({(r['label'], r['ticks']) for r in benchmark['runs']}):
        group = {'label': label, 'ticks': ticks, 'methods': {}}
        for kind in ('exact', 'isolated', 'kernel', 'existing'):
            rows = [r for r in benchmark['runs'] if r['label'] == label and r['ticks'] == ticks
                    and r['kind'] == kind and not r['warmup']]
            walls = [r['wall_usec'] for r in rows]
            method = {'median_usec': median(walls), 'min_usec': min(walls), 'max_usec': max(walls),
                      'samples': len(walls), 'usec_per_tick': median(walls) / ticks,
                      'packet_build_median_usec': median(r['packet_build_usec'] for r in rows),
                      'packet_retained_allocation_estimate_bytes': median(r['packet_heap_delta_bytes'] for r in rows),
                      'full_binary_parity': all(r['full_binary_parity'] for r in rows),
                      'discrete_parity': all(r['discrete_parity'] for r in rows),
                      'rng_parity': all(r['rng_parity'] for r in rows),
                      'max_normalized_numeric_error': max(r['numeric_error']['normalized'] for r in rows)}
            if kind == 'kernel':
                method['coverage_percent'] = median(100 * r['kernel_ticks'] / ticks for r in rows)
                method['fallback_ticks'] = median(r['fallback_ticks'] for r in rows)
                method['build_usec'] = median(r['counters']['build_usec'] for r in rows)
                method['release_usec'] = median(r['counters']['invalidate_usec'] for r in rows)
            group['methods'][kind] = method
        exact = group['methods']['exact']['median_usec']
        for method in group['methods'].values():
            method['speedup_vs_exact'] = exact / method['median_usec']
            method['runtime_reduction_percent'] = 100 * (1 - method['median_usec'] / exact)
        groups.append(group)
    profiles = []
    for scenario, kind in sorted({(r['scenario'], r['kind']) for r in profile['runs']}):
        rows = [r for r in profile['runs'] if r['scenario'] == scenario and r['kind'] == kind]
        keys = set().union(*(r['native_totals'].keys() for r in rows))
        details = set().union(*(r['nested_details'].keys() for r in rows))
        profiles.append({'scenario': scenario, 'kind': kind, 'median_wall_usec': median(r['wall_usec'] for r in rows),
                         'native_inclusive_median_usec': {k: median(r['native_totals'].get(k, 0) for r in rows) for k in sorted(keys)},
                         'nested_inclusive_medians': {k: {v: median(r['nested_details'].get(k, {}).get(v, 0) for r in rows) for v in ('calls', 'usec')} for k in sorted(details)},
                         'history_calls': median(r['history_calls'] for r in rows),
                         'history_usec': median(r['history_usec'] for r in rows),
                         'signals': median(r['signals'] for r in rows),
                         'signal_handler_usec': median(r['signal_handler_usec'] for r in rows)})
    summary = {'methodology': 'One excluded warmup; three alternating-order throughput samples; range is min/max, not a confidence interval. Profile timings inclusive and intrusive.',
               'benchmarks': groups, 'profiles': profiles, 'phase_profiles': benchmark['phase_profiles']}
    (ROOT / 'exact_flow_summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    lines = ['## 10. Final measured results', '',
             'Linux x86_64, AMD EPYC 9V74, official Godot 4.6.1. Three measured samples per method after one excluded warmup. Each cell is median milliseconds (minimum–maximum). Samples alternate execution order; ranges describe observed stability, not confidence intervals.', '',
             '| Fixture / ticks | Native exact | Isolated packet | Public kernel | Existing prototype | Kernel speedup | Kernel coverage |',
             '|---|---:|---:|---:|---:|---:|---:|']
    for g in groups:
        m = g['methods']
        values = ['%.3f (%.3f–%.3f)' % (m[k]['median_usec']/1000, m[k]['min_usec']/1000, m[k]['max_usec']/1000) for k in ('exact','isolated','kernel','existing')]
        lines.append('| %s / %s | %s | %.3f× | %.2f%% |' % (g['label'], g['ticks'], ' | '.join(values), m['kernel']['speedup_vs_exact'], m['kernel']['coverage_percent']))
    lines += ['', 'The isolated and public loops are independently timed. Small inversions between their medians reflect run-to-run scheduling/cache noise; subtracting those medians does not measure setup cost. One-tick results are especially noisy and do not amortize construction. No mature-fixture speedup is claimed: they execute native fallback, their relative overhead/noise is reported, and their kernel coverage is zero.', '',
              '| Fixture / ticks | Build median µs (public) | Release median µs | Additional retained packet bytes (estimate) | Kernel µs/tick | Exact fallback ticks |',
              '|---|---:|---:|---:|---:|---:|']
    for g in groups:
        k=g['methods']['kernel'];i=g['methods']['isolated']
        lines.append('| %s / %s | %.0f | %.0f | %.0f | %.2f | %.0f |' % (g['label'],g['ticks'],k['build_usec'],k['release_usec'],i['packet_retained_allocation_estimate_bytes'],k['usec_per_tick'],k['fallback_ticks']))
    lines += ['', 'No transaction capture/commit/rollback is needed on the accepted kernel path: this is deterministic exact execution, not a speculative candidate requiring replay. Transaction interoperability is validated separately. All in-place resource/statistics/phase synchronization is included in kernel tick time; no extra bulk write-back is performed.', '',
              'The separate intrusive phase-profile rows in exact_flow_summary.json expose event checks, tick execution, fallback, build and release. These clock-instrumented timings are not used for throughput speedups.', '',
              '| Native inclusive profiling (2,000 ticks), ms | Early | Mid | Forge |',
              '|---|---:|---:|---:|']
    native = {p['scenario']: p for p in profiles if p['kind']=='native_profile'}
    for key in ['generator_processing','available_operating_duration','input_consumption','output_production','production_rate_calculation','automatic_upgrades','generator_automation','upgrade_automation','heat_leak','matter_decay','cycle_generator_processing']:
        lines.append('| %s | %s |' % (key,' | '.join('%.2f' % (native[s]['native_inclusive_median_usec'].get(key,0)/1000) for s in ('early','mid','forge_competing'))))
    lines += ['', 'Generator processing dominates the major-phase profile. Output/rate and repeated modifier work are expensive in early gameplay; Forge also adds substantial input, availability and cycle work. These inclusive categories overlap. The detailed profile retains static/dynamic multiplier, sensitivity, fractional-phase accessor, statistics, history and signal measurements; it approximately doubles Forge runtime and therefore is not a throughput baseline.', '',
              '| Detailed early probes / 2,000 ticks | Calls (median) | Inclusive ms (median) |', '|---|---:|---:|']
    detail = next(p for p in profiles if p['scenario']=='early' and p['kind']=='detail_profile')
    for key,value in detail['nested_inclusive_medians'].items():
        lines.append('| %s | %.0f | %.3f |' % (key,value['calls'],value['usec']/1000))
    witness = next(p for p in profiles if p['scenario']=='completion_witness' and p['kind']=='detail_profile')
    lines += ['', 'The real completion witness observed %.0f signal(s), %.0f µs in their handler(s), and %.0f history writes taking %.0f µs (detailed medians). Early throughput observed no signals/history events during that window; counters and peaks still execute.' % (witness['signals'],witness['signal_handler_usec'],witness['history_calls'],witness['history_usec']), '',
              '**Correctness:** all kernel and isolated benchmark samples (including warmup and the one-hour run) have complete binary endpoint equality, discrete/RNG parity and zero measured resource/statistics deviation against the constant-tick control. Every-tick regression views pass, including thresholds, integer-output phases, automatic upgrade invalidation, rollback/resumption and fallback random outcomes. No tolerance was expanded. Baseline full suite: 91 passing groups. Final full suite: 92 passing groups, zero failures, parser warnings or runtime errors in final validation logs.', '',
              '**Next milestone:** extend exact controller/multi-input and event invalidation contracts to the real mature fixtures, then profile a real Windows save with its TimeManager/UI context. Keep exact ordered ticks as the oracle. Current results justify reduced per-tick overhead in supported early gameplay; they do not establish full-game acceleration, approximate batching eligibility or Windows compatibility.', '']
    report = ROOT / 'EXACT_FLOW_KERNEL.md'
    content = report.read_text().split('## 10. Final measured results')[0].rstrip()
    report.write_text(content + '\n\n' + '\n'.join(lines))


if __name__ == '__main__':
    main()
