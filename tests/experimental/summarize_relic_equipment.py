"""Summarize retained samples; never discard outliers or modify measurements."""
import json
import pathlib
import statistics


def summarize(path):
    data = json.loads(path.read_text())
    rows = []
    for observation in data['observations']:
        row = {'label': observation['label'], 'ticks': observation['ticks'], 'methods': {}}
        for kind in ('exact', 'previous', 'extended', 'adaptive'):
            values = [r['wall_usec'] / 1000 for r in data['runs']
                      if r['label'] == row['label'] and r['ticks'] == row['ticks']
                      and r['kind'] == kind and not r['warmup']]
            if values:
                row['methods'][kind] = {'median_ms': statistics.median(values),
                                        'min_ms': min(values), 'max_ms': max(values),
                                        'samples': len(values)}
        methods = row['methods']
        row['native_speedup'] = methods['exact']['median_ms'] / methods['extended']['median_ms']
        row['previous_runtime_change_percent'] = (methods['extended']['median_ms'] /
                                                   methods['previous']['median_ms'] - 1) * 100
        row['kernel_coverage_percent'] = observation['counters']['kernel_ticks'] / row['ticks'] * 100
        row['builds'] = observation['counters']['builds']
        rows.append(row)
    return rows


def main():
    root = pathlib.Path(__file__).resolve().parent
    result = {}
    for label, filename in [('main', 'relic_equipment_benchmark_results.json'),
                            ('initial_failed_reference_assertion', 'relic_equipment_benchmark_initial_results.json'),
                            ('confirmation', 'relic_equipment_benchmark_confirmation_results.json')]:
        path = root / filename
        if path.exists():
            result[label] = summarize(path)
    (root / 'relic_equipment_benchmark_summary.json').write_text(json.dumps(result, indent=2) + '\n')


if __name__ == '__main__':
    main()
