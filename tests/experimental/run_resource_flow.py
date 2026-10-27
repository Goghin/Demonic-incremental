"""Serial, timeout-bounded benchmark driver; raw results include every counter.
Usage: python tests/experimental/run_resource_flow.py --godot /path/to/godot
"""
import argparse
import hashlib
import json
import pathlib
import statistics
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--scenarios', default='transfer,exhaustion,matter_modifier,heat_leak,matter_decay,threshold,generator_wait,upgrade_wait,competing,mixed,cycles,late_both,dynamic_cost')
    parser.add_argument('--duration', type=float, default=120)
    parser.add_argument('--repeats', type=int, default=1)
    parser.add_argument('--output', default='tests/experimental/resource_flow_results.json')
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parents[2]
    rows = []
    hashes = {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest() for path in (root / 'tests/experimental').glob('*.gd')}
    for scenario in args.scenarios.split(','):
        command = [args.godot, '--headless', '--path', str(root), '--script', 'tests/experimental/resource_flow_benchmark.gd', '--', f'--scenario={scenario}', f'--duration={args.duration}', f'--repeats={args.repeats}']
        completed = subprocess.run(command, capture_output=True, text=True, timeout=600)
        log = completed.stdout + completed.stderr
        if completed.returncode or any(token in log for token in ('SCRIPT ERROR', 'ERROR:', 'WARNING:')):
            raise RuntimeError(log)
        results = [json.loads(line.removeprefix('FLOW_JSON ')) for line in log.splitlines() if line.startswith('FLOW_JSON ')]
        if len(results) != args.repeats or any(row['failures'] for row in results):
            raise RuntimeError(log)
        rows.extend(results)
        print(scenario, 'median exact/new', statistics.median(row['runs']['new']['speedup'] for row in results), 'old/new', statistics.median(row['runs']['old']['seconds'] / row['runs']['new']['seconds'] for row in results), flush=True)
        pathlib.Path(root / args.output).write_text(json.dumps({'source_hashes': hashes, 'runs': rows}, indent=2) + '\n')


if __name__ == '__main__':
    main()
