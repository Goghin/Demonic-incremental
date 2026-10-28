"""Serial core-gameplay investigation; exact/old/new comparisons and diagnostics."""
import argparse
import hashlib
import json
import pathlib
import statistics
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--scenarios', default='early,mid,forge_competing')
    parser.add_argument('--duration', type=float, default=120)
    parser.add_argument('--repeats', type=int, default=3)
    parser.add_argument('--survey', action='store_true')
    parser.add_argument('--ablations', action='store_true')
    parser.add_argument('--output', default='tests/experimental/core_results.json')
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parents[2]
    rows = []
    hashes = {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in (root / 'tests/experimental').glob('core_*.gd')}
    hashes['core_progression.json'] = hashlib.sha256((root / 'tests/experimental/core_progression.json').read_bytes()).hexdigest()
    for scenario in args.scenarios.split(','):
        ablations = ['none', 'cycles', 'automation', 'cycles_automation', 'consumers'] if args.ablations else ['none']
        for ablation in ablations:
            command = [args.godot, '--headless', '--path', str(root), '--script', 'tests/experimental/core_benchmark.gd', '--', f'--scenario={scenario}', f'--duration={args.duration}', f'--repeats={args.repeats}', f'--survey={str(args.survey).lower()}', f'--ablation={ablation}']
            result = subprocess.run(command, capture_output=True, text=True, timeout=600)
            log = result.stdout + result.stderr
            if result.returncode or any(t in log for t in ('ERROR', 'WARNING')):
                raise RuntimeError(log)
            data = [json.loads(line[10:]) for line in log.splitlines() if line.startswith('CORE_JSON ')]
            if len(data) != args.repeats or any(r['failures'] for r in data):
                raise RuntimeError(log)
            rows.extend(data)
            output = {'source_hashes': hashes, 'diagnostic_only': args.survey or args.ablations, 'runs': rows}
            (root / args.output).write_text(json.dumps(output, indent=2) + '\n')
            print(scenario, ablation, 'coverage', data[0]['runs']['new']['adaptive_coverage'], 'paired exact/new', statistics.median(r['runs']['new']['speedup'] for r in data), flush=True)


if __name__ == '__main__':
    main()
