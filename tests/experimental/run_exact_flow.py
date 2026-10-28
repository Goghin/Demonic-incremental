"""Reproduce compact exact-kernel research; warnings and runtime errors fail."""
import argparse
import pathlib
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--mode', choices=('tests', 'profile', 'benchmark', 'all'), default='all')
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parents[2]
    scripts = []
    for mode, script in (('tests', 'run_exact_flow_tests.gd'),
                         ('profile', 'kernel_profile.gd'),
                         ('benchmark', 'exact_flow_benchmark.gd')):
        if args.mode in (mode, 'all'):
            scripts.append('tests/experimental/' + script)
    for script in scripts:
        result = subprocess.run([args.godot, '--headless', '--path', str(root),
                                 '--script', script], capture_output=True, text=True, timeout=600)
        log = result.stdout + result.stderr
        if result.returncode or 'ERROR' in log or 'WARNING' in log:
            raise RuntimeError(log)
        print(log, end='', flush=True)


if __name__ == '__main__':
    main()
