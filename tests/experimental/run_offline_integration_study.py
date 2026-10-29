"""Strict serial driver. Uses a separate user-data directory for real save/log IO."""
import argparse
import os
import pathlib
import subprocess
import tempfile
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--godot', required=True)
    parser.add_argument('--mode', choices=['smoke', 'tests', 'bench', 'overhead_variants', 'confirm', 'boundaries', 'zero', 'micro', 'profiles'], default='tests')
    args = parser.parse_args()
    if sys.platform != "linux":
        raise RuntimeError("Native user-data isolation has only been validated on Linux")
    env = os.environ.copy()
    env['TM_STUDY_MODE'] = args.mode
    env['GODOT_SILENCE_ROOT_WARNING'] = '1'
    with tempfile.TemporaryDirectory(prefix='offline-study-user-') as user:
        env['XDG_DATA_HOME'] = user
        env['TM_STUDY_USER_ROOT'] = user
        script = ('offline_integration_overhead.gd' if args.mode == 'micro' else
                  'offline_integration_profiles.gd' if args.mode == 'profiles' else
                  'offline_integration_study.gd')
        result = subprocess.run([args.godot, '--headless', '--path', str(ROOT), '--script',
                                 'tests/experimental/' + script],
                                cwd=ROOT, env=env, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, timeout=7200)
    log = result.stdout
    (ROOT / 'tests/experimental' / f'offline_integration_{"overhead" if args.mode == "micro" else args.mode}.log').write_text(log)
    print(log)
    if result.returncode or any(word in log.lower() for word in ('error', 'warning', 'fatal')):
        raise RuntimeError(f'Study failed: {args.mode}, exit={result.returncode}')

if __name__ == '__main__':
    main()
