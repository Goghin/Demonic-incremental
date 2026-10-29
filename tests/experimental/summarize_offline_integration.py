"""Summaries preserve every sample, including regressions and warmup metadata."""
import collections
import json
import pathlib
import statistics

ROOT = pathlib.Path(__file__).resolve().parent
METRICS = ['pipeline_usec', 'runtime_usec', 'restore_usec', 'prepare_usec',
           'elapsed_usec', 'frame_wait_usec', 'achievement_usec',
           'result_data_usec', 'finalization_usec', 'retained_memory_estimate_bytes']

def summarize(path):
    data = json.loads(path.read_text())
    groups = collections.defaultdict(list)
    for row in data['rows']:
        if not row['warmup'] and not row.get('instrumented', False):
            key = (row['fixture'], row['seconds'], row['scope'], row['scale'], row['budget_ms'])
            groups[key].append(row)
    result = []
    for key, rows in groups.items():
        item = dict(zip(['fixture', 'requested_seconds', 'scope', 'scale', 'budget_ms'], key))
        item['methods'] = {}
        for kernel, name in [(False, 'native'), (True, 'kernel')]:
            sample = [r for r in rows if r['kernel'] == kernel]
            method = {'samples': len(sample)}
            for metric in METRICS:
                values = [r[metric] for r in sample]
                method[metric] = {'median': statistics.median(values), 'min': min(values), 'max': max(values)}
            for metric in ['steps', 'effective_requested_seconds', 'offline_seconds', 'game_seconds', 'yields', 'progress_events']:
                method[metric] = [r[metric] for r in sample]
            method['counters'] = [r['counters'] for r in sample]
            item['methods'][name] = method
        n, k = item['methods']['native'], item['methods']['kernel']
        item['pipeline_speedup'] = n['pipeline_usec']['median'] / k['pipeline_usec']['median']
        item['coordinator_speedup'] = n['runtime_usec']['median'] / k['runtime_usec']['median']
        result.append(item)
    return {'engine': data.get('engine'), 'cpu': data.get('cpu'), 'failures': data.get('failures', []), 'groups': result}

def main():
    output = {}
    for label in ['bench', 'overhead_variants', 'confirm']:
        path = ROOT / ('offline_integration_' + label + '.json')
        if path.exists():
            output[label] = summarize(path)
    (ROOT / 'offline_integration_summary.json').write_text(json.dumps(output, indent=2) + '\n')

if __name__ == '__main__':
    main()
