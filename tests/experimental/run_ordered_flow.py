"""Run ordered-flow validation and serial benchmarks; warnings are failures."""
import argparse
import pathlib
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--mode', choices=('tests', 'benchmark', 'all'), default='all')
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parents[2]
    scripts = []
    if args.mode in ('tests', 'all'):
        scripts.append('tests/experimental/run_ordered_flow_tests.gd')
    if args.mode in ('benchmark', 'all'):
        scripts.append('tests/experimental/ordered_flow_benchmark.gd')
    for script in scripts:
        result = subprocess.run([args.godot, '--headless', '--path', str(root),
                                 '--script', script], capture_output=True, text=True, timeout=600)
        log = result.stdout + result.stderr
        if result.returncode or 'ERROR' in log or 'WARNING' in log:
            raise RuntimeError(log)
        print(log, end='', flush=True)


if __name__ == '__main__':
    main()
