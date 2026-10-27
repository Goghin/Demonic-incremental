"""Run bounded serial autobuyer experiments; retain failures and partial output."""
import argparse
import json
import subprocess
import time
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--project', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--timeout', type=float, default=90)
    parser.add_argument('arguments', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error('timeout must be positive')
    forwarded = args.arguments[1:] if args.arguments[:1] == ['--'] else args.arguments
    command = [args.godot, '--headless', '--path', args.project, '--script',
               'res://tests/experimental/autobuyer_benchmark.gd', '--', *forwarded]
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    status = {'command': command, 'timeout_seconds': args.timeout, 'timed_out': False}
    started = time.monotonic()
    with output.open('w', encoding='utf-8') as log:
        try:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                                    timeout=args.timeout, check=False)
            status['exit_code'] = result.returncode
        except subprocess.TimeoutExpired:
            status['timed_out'] = True
    status['process_wall_seconds'] = time.monotonic() - started
    text = output.read_text(encoding='utf-8', errors='replace')
    status['engine_errors'] = any(word in text for word in ('ERROR:', 'SCRIPT ERROR', 'WARNING:'))
    status['results'] = [json.loads(line.split(' ', 1)[1]) for line in text.splitlines()
                         if line.startswith('AUTOBUYER_JSON ')]
    status['success'] = (not status['timed_out'] and status.get('exit_code') == 0
                         and not status['engine_errors'] and bool(status['results'])
                         and all(row.get('failure_count', 1) == 0 for row in status['results']))
    output.with_suffix('.status.json').write_text(json.dumps(status, indent=2) + '\n')
    print(json.dumps({key: value for key, value in status.items() if key not in ('command', 'results')}))
    return 0 if status['success'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
