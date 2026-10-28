"""Run automation experiments; parser warnings and runtime errors fail."""
import argparse
import pathlib
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--mode', choices=('fixtures', 'tests', 'benchmark', 'regression', 'all'), default='all')
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parents[2]
    for mode, script in [('fixtures', 'tests/experimental/automation_progression_builder.gd'),
                         ('tests', 'tests/experimental/run_automation_kernel_tests.gd'),
                         ('benchmark', 'tests/experimental/automation_kernel_benchmark.gd'),
                         ('regression', 'tests/run_regression_tests.gd')]:
        if args.mode != mode and not (args.mode == 'all' and mode != 'fixtures'):
            continue
        result = subprocess.run([args.godot, '--headless', '--path', str(root), '--script',
                                 script], capture_output=True,
                                text=True, timeout=600)
        text = result.stdout + result.stderr
        if result.returncode or 'ERROR' in text or 'WARNING' in text:
            raise RuntimeError(text)
        print(text, end='', flush=True)


if __name__ == '__main__':
    main()
