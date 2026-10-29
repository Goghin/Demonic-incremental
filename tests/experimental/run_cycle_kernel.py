"""Reproduce cycle fixtures, strict differential tests and serial benchmarks."""
import argparse
import pathlib
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--mode', choices=('fixtures', 'tests', 'benchmark', 'regression', 'scope', 'all'), default='all')
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parents[2]
    for mode, script in [('fixtures', 'tests/experimental/cycle_progression_builder.gd'),
                         ('tests', 'tests/experimental/run_cycle_kernel_tests.gd'),
                         ('benchmark', 'tests/experimental/cycle_kernel_benchmark.gd'),
                         ('regression', 'tests/run_regression_tests.gd'),
                         ('scope', 'tests/experimental/cycle_scope_audit.gd')]:
        if args.mode != mode and not (args.mode == 'all' and mode != 'fixtures'):
            continue
        result = subprocess.run([args.godot, '--headless', '--path', str(root), '--script', script],
                                capture_output=True, text=True, timeout=1200)
        output = result.stdout + result.stderr
        print(output, end='', flush=True)
        if result.returncode or 'ERROR' in output or 'WARNING' in output:
            raise RuntimeError('Godot validation failed: ' + mode)


if __name__ == '__main__':
    main()
