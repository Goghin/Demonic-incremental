"""Serial reproducible resource research; parser/runtime warnings are failures."""
import argparse
import os
import pathlib
import subprocess
import threading


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--mode', choices=('fixtures', 'tests', 'benchmark', 'regression', 'all'), default='all')
    args = parser.parse_args()
    root = pathlib.Path(__file__).resolve().parents[2]
    scripts = [('fixtures', 'tests/experimental/relic_crafting_progression_builder.gd'),
               ('tests', 'tests/experimental/run_relic_crafting_tests.gd'),
               ('benchmark', 'tests/experimental/relic_crafting_benchmark.gd'),
               ('regression', 'tests/run_regression_tests.gd')]
    for mode, script in scripts:
        if args.mode != mode and not (args.mode == 'all' and mode != 'fixtures'):
            continue
        command = [args.godot, '--headless', '--path', str(root), '--script', script]
        if mode != 'regression':
            command += ['--quit-after', '2']
        lines = []
        log_kind = mode + ("_confirmation" if mode == "benchmark" and os.environ.get("CRAFT_BENCH_CONFIRM") == "1" else "")
        log_mode = 'a' if mode == 'benchmark' and os.environ.get('CRAFT_BENCH_RESUME') == '1' else 'w'
        with (root / 'tests' / 'experimental' / ('relic_crafting_' + log_kind + '.log')).open(log_mode) as log_file:
            with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                  text=True) as process:
                timer = threading.Timer(7200, process.kill)
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
        if code or any(word in log.lower() for word in ('error', 'warning', 'fatal')):
            raise RuntimeError('Godot validation failed: ' + mode + '; exit=' + str(code))



if __name__ == '__main__':
    main()
