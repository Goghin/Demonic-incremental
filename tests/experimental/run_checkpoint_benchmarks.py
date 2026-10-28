"""Serial, order-balanced reference/compact checkpoint measurements."""
import argparse
import hashlib
import json
import pathlib
import platform
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parents[2]
    directory = root / 'tests/experimental'
    collected = {kind: {'runs': [], 'profiles': []} for kind in ('reference', 'compact')}
    for block, order in enumerate((('reference', 'compact'), ('compact', 'reference'))):
        for kind in order:
            command = [args.godot, '--headless', '--path', str(root), '--script',
                       'tests/experimental/checkpoint_benchmark.gd', '--', '--kind=' + kind]
            completed = subprocess.run(command, capture_output=True, text=True, timeout=300)
            log = completed.stdout + completed.stderr
            if completed.returncode or 'ERROR' in log or 'WARNING' in log:
                raise RuntimeError(log)
            data = json.loads((directory / ('checkpoint_' + kind + '_measurements.json')).read_text())
            if data['failures']:
                raise RuntimeError(str(data['failures']))
            for key in ('runs', 'profiles'):
                collected[kind][key].extend(dict(row, block=block) for row in data[key])
            for key in ('engine', 'platform', 'cpu', 'debug_build'):
                collected[kind][key] = data[key]
            print('Completed block', block, kind, flush=True)
    source_names = ['checkpoint_benchmark.gd', 'compact_checkpoint.gd',
                    'runtime_state_descriptors.gd', 'transaction_checkpoint.gd']
    for kind, data in collected.items():
        data.update(kind=kind, failures=[], host=platform.platform(),
                    sample_policy='Two reverse-order serial blocks; seven warm samples plus one excluded cold/warmup per fixture per block.',
                    source_sha256={name: hashlib.sha256((directory / name).read_bytes()).hexdigest()
                                   for name in source_names})
        (directory / ('checkpoint_' + kind + '_measurements.json')).write_text(json.dumps(data, indent=2) + '\n')


if __name__ == '__main__':
    main()
