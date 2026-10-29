"""Serial reproducible resource research; parser/runtime warnings are failures."""
import argparse
import os
import pathlib
import subprocess
import threading


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--mode', choices=('fixtures', 'tests', 'benchmark', 'regression', 'scope', 'all'), default='all')
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parents[2]
    scripts = [('fixtures', 'tests/experimental/essence_nexum_progression_builder.gd'),
               ('tests', 'tests/experimental/run_essence_nexum_tests.gd'),
               ('benchmark', 'tests/experimental/essence_nexum_benchmark.gd'),
               ('regression', 'tests/run_regression_tests.gd'),
               ('scope', 'tests/experimental/essence_nexum_scope_audit.gd')]
    for mode, script in scripts:
        if args.mode != mode and not (args.mode == 'all' and mode != 'fixtures'):
            continue
        command = [args.godot, '--headless', '--path', str(root), '--script', script]
        lines = []
        log_kind = 'exploration' if mode == 'fixtures' and os.environ.get('RESOURCE_PROGRESS_EXPLORE') == '1' else mode
        if mode == 'benchmark' and os.environ.get('RESOURCE_BENCH_CONFIRM') == '1':
            log_kind = 'confirmation'
        with (root / 'tests' / 'experimental' / ('essence_nexum_' + log_kind + '.log')).open('w') as log_file:
            with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                  text=True) as process:
                timer = threading.Timer(1800, process.kill)
                timer.start()
                try:
                    for line in process.stdout:
                        lines.append(line)
                        log_file.write(line)
                        log_file.flush()
                        print(line, end='', flush=True)
                    code = process.wait()
                finally:
                    timer.cancel()
        log = ''.join(lines)
        if code or 'ERROR' in log or 'WARNING' in log:
            raise RuntimeError('Godot validation failed: ' + mode)



if __name__ == '__main__':
    main()
