"""Summarize paired deterministic repeats; never select the fastest sample."""
import json
import statistics
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def main():
    data = json.loads((ROOT / "observer_benchmark_results.json").read_text())
    groups = defaultdict(lambda: defaultdict(dict))
    for row in data["runs"]:
        if not row["warmup"] and row["wall_usec"] > 0:
            groups[(row["label"], row["workload"], int(row["ticks"]))][int(row["repeat"])][row["kind"]] = row
    summary = []
    for (label, workload, ticks), repeats in groups.items():
        kinds = defaultdict(list)
        for methods in repeats.values():
            for kind, row in methods.items():
                kinds[kind].append(row)
        result = {"label": label, "workload": workload, "ticks": ticks, "methods": {}}
        for kind, runs in kinds.items():
            speeds = [ticks * 1_000_000 / row["wall_usec"] for row in runs]
            result["methods"][kind] = {"ticks_per_second_median": statistics.median(speeds), "ticks_per_second_min": min(speeds), "ticks_per_second_max": max(speeds), "runs": len(runs)}
        for numerator, denominator, field in [("native", "optimized", "speedup"), ("previous", "optimized", "versus_previous"), ("instrumented", "optimized", "instrumentation_cost_ratio"), ("historical", "optimized", "versus_historical")]:
            pairs = [r[numerator]["wall_usec"] / r[denominator]["wall_usec"] for r in repeats.values() if numerator in r and denominator in r]
            if pairs:
                result[field] = {"median": statistics.median(pairs), "min": min(pairs), "max": max(pairs)}
        result["speedup_from_median_times"] = statistics.median(r["wall_usec"] for r in kinds["native"]) / statistics.median(r["wall_usec"] for r in kinds["optimized"])
        result["versus_previous_from_median_times"] = statistics.median(r["wall_usec"] for r in kinds["previous"]) / statistics.median(r["wall_usec"] for r in kinds["optimized"])
        if "instrumented" in kinds:
            result["instrumentation_from_median_times"] = statistics.median(r["wall_usec"] for r in kinds["instrumented"]) / statistics.median(r["wall_usec"] for r in kinds["optimized"])
        measured = kinds.get("instrumented", kinds["optimized"])[0]
        counters = measured["counters"]
        result["coverage_percent"] = 100 * counters["kernel_ticks"] / ticks
        result["previous_coverage_percent"] = 100 * kinds["previous"][0]["counters"]["kernel_ticks"] / ticks
        result["counters"] = counters
        result["observer_metrics"] = measured["observer_metrics"].copy()
        result["observer_time_ranges"] = {}
        if result["observer_metrics"]:
            for key in ["observer_check_usec", "callback_usec", "eligibility_usec", "packet_build_usec"]:
                values = [r["observer_metrics"][key] for r in kinds["instrumented"]]
                result["observer_metrics"][key] = statistics.median(values)
                result["observer_time_ranges"][key] = {"median": statistics.median(values), "min": min(values), "max": max(values)}
        summary.append(result)
    output = {"environment": {key: data[key] for key in ["engine", "cpu", "repetitions", "logging", "platform", "processor_count", "debug_build", "baseline_commit", "native_step"]}, "comparisons": len(data["runs"]), "all_exact_parity": all(r["exact_parity"] for r in data["runs"]), "failures": data["failures"], "scenarios": summary}
    (ROOT / "observer_summary.json").write_text(json.dumps(output, indent=2) + "\n")
    lines = ["| State / observers / ticks | Native ticks/s (median; range) | Kernel ticks/s (median; range) | Median-time speedup | Paired speedup (median; range) | vs previous median times | Coverage before → after | Instrumentation cost |", "|---|---:|---:|---:|---:|---:|---:|---:|"]
    for row in summary:
        def rate(kind):
            r = row["methods"][kind]
            return f'{r["ticks_per_second_median"]:,.0f}; {r["ticks_per_second_min"]:,.0f}–{r["ticks_per_second_max"]:,.0f}'
        ratio = row["speedup"]
        instrumentation = row.get("instrumentation_cost_ratio", {}).get("median")
        overhead = (f'{(instrumentation - 1) * 100:+.1f}%; {(row["instrumentation_cost_ratio"]["min"] - 1) * 100:+.1f}–{(row["instrumentation_cost_ratio"]["max"] - 1) * 100:+.1f}%' if instrumentation else "—")
        lines.append(f'| {row["label"]} / {row["workload"]} / {row["ticks"]:,} | {rate("native")} | {rate("optimized")} | {row["speedup_from_median_times"]:.3f}× | {ratio["median"]:.3f}×; {ratio["min"]:.3f}–{ratio["max"]:.3f} | {row["versus_previous_from_median_times"]:.3f}× | {row["previous_coverage_percent"]:.3f}% → {row["coverage_percent"]:.3f}% | {overhead} |')
    lines.extend(["", "| State / observers / ticks | Observer checks / signals | Check µs | Calls / callback µs | Builds / rebuilds | Cycle / automation / automatic-upgrade invalidations | Fallback ticks by reason |", "|---|---:|---:|---:|---:|---:|---|"])
    for row in summary:
        m = row["observer_metrics"]
        if not m:
            continue
        lines.append(f'| {row["label"]} / {row["workload"]} / {row["ticks"]:,} | {int(m["observer_checks"])} / {int(m["observer_signal_checks"])} | {m["observer_check_usec"]} | {int(m["observer_invocations"])} / {m["callback_usec"]} | {int(m["packet_builds"])} / {int(m["packet_rebuilds"])} | {int(m["cycle_invalidations"])} / {int(m["automation_invalidations"])} / {int(m["automatic_upgrade_invalidations"])} | {json.dumps(m["fallback_ticks_by_reason"])} |')
    (ROOT / "observer_summary.md").write_text("\n".join(lines) + "\n")
    print(json.dumps({"comparisons": output["comparisons"], "exact": output["all_exact_parity"], "scenarios": len(summary), "failures": output["failures"]}))


if __name__ == "__main__":
    main()
