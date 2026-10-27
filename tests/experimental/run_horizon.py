"""Bound one streamed Godot experiment; retain output and partial results on timeout.

Usage: python run_horizon.py --godot GODOT --project PROJECT --output RUN.log
       --timeout 120 -- --scenario=feedback --duration=3600 --accuracy=balanced
"""
import argparse
import json
import subprocess
import time
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True)
    parser.add_argument("--project", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--timeout", type=float, default=120)
    parser.add_argument("arguments", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error("timeout must be positive")
    forwarded = args.arguments[1:] if args.arguments[:1] == ["--"] else args.arguments
    command = [args.godot, "--headless", "--path", args.project, "--script",
               "res://tests/experimental/horizon_benchmark.gd", "--", *forwarded]
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    try:
        import resource
        cpu_before = resource.getrusage(resource.RUSAGE_CHILDREN)
    except ImportError:
        resource = None
        cpu_before = None
    status = {"command": command, "timeout_seconds": args.timeout, "timed_out": False}
    with output.open("w", encoding="utf-8") as log:
        try:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT,
                                    timeout=args.timeout, check=False)
            status["exit_code"] = result.returncode
        except subprocess.TimeoutExpired:
            status["timed_out"] = True
    status["process_wall_seconds"] = time.monotonic() - started
    if resource is not None:
        cpu_after = resource.getrusage(resource.RUSAGE_CHILDREN)
        status["process_cpu_seconds"] = (cpu_after.ru_utime + cpu_after.ru_stime
                                         - cpu_before.ru_utime - cpu_before.ru_stime)
    text = output.read_text(encoding="utf-8", errors="replace")
    status["engine_errors"] = any(marker in text for marker in ("SCRIPT ERROR", "ERROR:", "WARNING:"))
    status["results"] = [json.loads(line.split(" ", 1)[1]) for line in text.splitlines()
                         if line.startswith("HORIZON_JSON ")]
    status["comparison_validated"] = False
    status["success"] = not status["timed_out"] and status.get("exit_code") == 0 and not status["engine_errors"]
    for result in status["results"]:
        if "accuracy_pass" in result:
            status["comparison_validated"] = all(result.get(key, False) for key in ("accuracy_pass", "discrete_parity", "rng_parity", "prestige_parity", "reference_complete"))
            status["success"] &= all(result.get(key, False) for key in
                                     ("accuracy_pass", "discrete_parity", "rng_parity", "prestige_parity", "reference_complete"))
    output.with_suffix(".status.json").write_text(json.dumps(status, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: value for key, value in status.items() if key not in ("command", "results")}))
    return 0 if status["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
