"""Run consumer experiments; parser warnings and runtime errors fail."""
import argparse
import pathlib
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--mode', choices=('fixtures', 'tests', 'benchmark', 'all'), default='all')
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parents[2]
    for mode, script in [('fixtures', 'consumer_progression_builder.gd'),
                         ('tests', 'run_consumer_tests.gd'),
                         ('benchmark', 'consumer_benchmark.gd')]:
        if args.mode != mode and not (args.mode == 'all' and mode != 'fixtures'):
            continue
        result = subprocess.run([args.godot, '--headless', '--path', str(root), '--script',
                                 'tests/experimental/' + script], capture_output=True,
                                text=True, timeout=600)
        text = result.stdout + result.stderr
        if result.returncode or 'ERROR' in text or 'WARNING' in text:
            raise RuntimeError(text)
        print(text, end='', flush=True)


if __name__ == '__main__':
    main()
