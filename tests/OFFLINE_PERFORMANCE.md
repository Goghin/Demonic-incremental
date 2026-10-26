# Offline performance batch 1

Historical measurements below predate gameplay RNG isolation and Batch C. See `GAMEPLAY_RNG.md` and `OFFLINE_BATCH_C.md` for current RNG ownership and offline scheduling.

Starting commit: `1f49de685a792efb489ec756c6722d1c46f2043b` on `feature/cycle-auto-run`.

## Retained changes

1. **Partial-input startup:** when an offline startup input is nonempty, its consumption rate cannot affect the startup decision. Skip that calculation there; evaluate rates at the original operating-duration and consumption points. Empty inputs still evaluate their rate, including zero-rate cases. Normal startup retains its one-second reserve and its original rate evaluations. There is no rate-value cache, multiplication regrouping, or timestep change.
2. **Automatic-upgrade index:** maintain the registry-ordered list of pending automatic upgrades instead of walking all purchased/nonautomatic upgrades on every offline tick. Requirements, levels, and effects remain live. Refresh after automatic application, registry-size change, realm-run change, active-play evaluation, or `rebuild_upgrade_effects()`. Thus maxed entries can be removed without losing reset/load behavior. New resource amounts, relics, generator levels, modes, and realm effects do not require numeric-cache invalidation because no numeric results or eligibility decisions are cached.


Generator order, input/output mutation order, all cooldown subtraction/overshoot arithmetic, buyer priority, completion logic, and RNG calls remain unchanged. Generator/upgrade automation implementations and TimeManager stepping/progress/yield scheduling were ultimately left unchanged.

## Method

Godot **4.6.1 stable**, Linux headless, shared AMD EPYC 9V74 host. The project advertises Godot 4.7. Timings are not predictions for the target Windows machine. Processes ran serially, with no concurrent simulation benchmarks. Engine startup, fixture setup, final serialization and hashing are outside the internal compute timer. A deterministic in-memory logger replaces file I/O in the comparative harness; the existing corrected benchmark also runs separately with its original logging behavior.

Every case resets the global seed to `123456`. Direct runs retain the benchmark's fixed-count 0.1-second loop and endpoint dormancy evaluation. Manager runs await `TimeManager.simulate_offline()` including clocks, dormancy, progress signals and frame yields. They do not include save loading or the rendered game scene. Compare each path with its own starting-commit path: their existing floating-point endpoint handling is not changed or unified.

Snapshots cover resources, generator levels/operating flags/cycle progress/modes/throttle/critical snapshots/discrete production fractions; upgrade levels; lifetime/current-run/offline statistics and peaks; overflow and Matter-decay prestige counters; discoveries; inventory and generated relic rolls; automation cooldown/wait state; a complete in-memory progression log; and four subsequent global RNG outputs. SHA-256 of `var_to_bytes(snapshot)` additionally verifies double precision and Variant types, not just formatted JSON. Manager clocks have a separate binary hash. Internal waiting-cost cache metadata is excluded from the large snapshot; no automation-cost implementation change is retained.

The host showed large timing outliers, including a 155-second one-hour prototype run. All timings are retained when calculating stated medians. Final source-verified comparisons are paired single runs at each required duration/path. Exploratory one-hour and four-hour comparisons also used three samples per version; their large spread motivated the final isolated/source-verified run rather than a precision claim. These are descriptive measurements, not statistically established speed guarantees. Isolated component timings alternate raw/optimized order in one process to reduce drift; they are not additive whole-game speedups.

## Measurements

Final paired runs below verify the runtime-loaded source hashes, not just the checkout files. State hashes match exactly in every row. Single-run wall times vary substantially and must not be interpreted as a universal percentage improvement.

| Path | Offline duration | Starting commit | Candidate | Observation |
|---|---:|---:|---:|---|
| direct | 1h | 25.892s | 12.200s | 52.9% lower time in this pair |
| direct | 4h | 57.077s | 77.657s | 36.1% slower in this pair |
| manager | 1h | 17.523s | 13.807s | 21.2% lower time in this pair |
| manager | 4h | 78.965s | 51.739s | 34.5% lower time in this pair |

**Four-hour direct compute did not improve in the final source-verified pair.** Earlier three-sample direct comparisons had medians 15.588 → 13.974 seconds at one hour and 62.781 → 61.488 seconds at four hours, with wide ranges. In addition, the normal-path control (which retains the original arithmetic) varied from 2.602 to 4.200 seconds. Its varied wall time despite matching state further limits timing attribution on this host. A robust end-to-end speedup percentage cannot be claimed. The retained code removes measured redundant work, but target-machine confirmation is necessary. No result is discarded from the reported exploratory medians.

### Individual contributions

| Retained operation | Raw median | Optimized median | Scope |
|---|---:|---:|---|
| automatic_upgrades | 40.253ms | 20.009ms | 2.01× for 1,000 automatic-upgrade evaluations; 80 alternating-order pairs |
| startup_gate | 20.093ms | 13.525ms | 1.49× for 200 passes over continuous-generator startup/duration gates; 40 alternating-order pairs, available-input fixture |

These isolated reductions are not whole-simulation speedups and are not additive. The startup fixture has nonempty inputs; resource-starved workloads benefit less. A probe regression confirms zero startup rate evaluations for nonempty offline inputs, the original evaluations for normal startup, and a required evaluation for empty inputs—including the zero-effective-draw case.

The final corrected benchmark profile assigns 64.4% of instrumented phase time to generator processing, 18.0% to generator automation, 9.1% to upgrade automation, and 6.5% to automatic upgrades. Repeated modifier/sensitivity evaluation still dominates input/output paths; no evaluated multiplier cache was retained.


## Candidates tested and rejected

- **Input-modifier and sensitivity object indexes:** candidate lists were ordered and kept live object references, with explicit invalidation and size checks. They matched the comparison snapshots, but additional lookup/count/branch overhead did not demonstrate a reliable gain for these short lists. The one-hour times were 19.715 / 13.418 / 20.250 seconds; a 600-second control also regressed. Removed entirely.
- **Automation technology IDs, strong local state references, tree candidate indexes, and tree-list reuse:** numerical/cooldown/purchase comparisons matched, but the end-to-end evidence was inconsistent: one-hour times were 14.390 / 12.455 / 155.422 seconds; the 600-second median was 3.569 versus 2.671 for its initial baseline control. Removed rather than retaining extra manager state or per-tick branching.
- **Automatic index retaining maxed entries:** only modest/inconsistent whole-loop gains. Refined to retain pending upgrades and refresh at the existing reset/rebuild boundaries. No eligibility polling was skipped.
- **Merged startup/duration gate:** exact snapshots, but more operating-duration calls for input-starved generators and no reliable isolated whole-loop benefit (one-hour times 28.027 / 18.595 / 21.643). Replaced by the smaller nonempty-input short circuit in `Generator.can_start_operating()`.
- **12 ms wall-clock progress budget:** an isolated 600-second manager test increased progress callbacks from 62 to 140–152, with identical state and clocks. It did not establish a consistent throughput benefit. More importantly, `SmokeEmitterRenderer._process()` consumes the global RNG and RealmView updates continue during loading. Changing frame-yield cadence could perturb cycle/crafting RNG in the actual scene. Removed; the original 100-tick progress/yield sequence remains, including its final update/frame.
- Evaluated numeric rate caches, cached static multiplier products, cooldown deadlines, and skipped waiting checks were **not implemented**. They need more invalidation machinery, can change floating-point operation order or purchase timing, and are not justified in this batch.

## Validation

- **45 regression cases passed, zero failures**, with no parser/runtime warnings or errors. Three cases added relative to the 42-case starting suite cover startup gate equivalence across modes/resources/levels/pause states and dynamic modifiers, skipped evaluation counts/zero-draw inputs, and automatic-upgrade order/pruning/reset/rebuild invalidation.
- The existing corrected one-hour benchmark completed with no warnings/errors; 0.5s and 1.0s comparisons correctly report **387.1566%** and **387.6153%** maximum metric deviations. Those larger steps are benchmark controls only; production remains at 0.1s.
- Both final component benchmarks completed cleanly.
- Source-verified binary snapshots match at 1h and 4h for direct compute and TimeManager; manager clocks match bit for bit. The full original frame-yield/progress sequence is retained.
- A 600s normal Simulation path control matches the reference binary snapshot.
- A 600s RNG-heavy fixture matches the reference binary snapshot, including Forge critical/downlevel events, CF, recipe consumption, generated relic rolls/inventory, and global RNG fingerprint. Both versions finish that fixture at **491 CF** and seven inventory entries.
- `git diff --check` passes.

The exact hashes and source fingerprints are in `offline_performance_results.json`. Timing observations, including regressions and outliers, are kept separate from the exactness evidence.


The test suite's old `GeneratorStatsEntry` fixture is now freed after its assertions. This removes the pre-existing shutdown RID/ObjectDB/resource leaks from the standalone suite. The cycle-auto-run regression also uses the existing fake logger, so it no longer appends fixture events to the gameplay log. All final benchmark/test entry points are checked for `SCRIPT ERROR`, `ERROR:` and `WARNING:` in addition to their exit status; any occurrence fails validation.

The pre-existing full-project import/font and `game.gd` indentation issues were not changed. The standalone suite and benchmark scripts run cleanly with the existing imported assets. A clean import and rendered loading-screen test under the target Godot version remain separate checks; no full-game launch claim is made here.

## Reproduce

Use disposable copies of the starting commit and candidate on the same engine/build/machine, copying the two benchmark scripts into the reference copy. Do not modify reference mechanic files. Run serially:

```text
godot --headless --path . --script res://tests/run_regression_tests.gd
godot --headless --path . --script res://simulation/offline_simulation_benchmark.gd
godot --headless --path . --script res://tests/offline_performance_benchmark.gd -- --duration=3600 --repeats=3
godot --headless --path . --script res://tests/offline_performance_benchmark.gd -- --duration=14400 --repeats=3
godot --headless --path . --script res://tests/offline_performance_benchmark.gd -- --duration=3600 --mode=manager
godot --headless --path . --script res://tests/offline_performance_benchmark.gd -- --duration=14400 --mode=manager
godot --headless --path . --script res://tests/offline_performance_benchmark.gd -- --duration=600 --mode=normal
godot --headless --path . --script res://tests/offline_performance_benchmark.gd -- --duration=600 --scenario=critical_cycles
godot --headless --path . --script res://tests/offline_component_benchmark.gd
```

The component benchmark requires the candidate implementation; it invokes the raw/optimized automatic-upgrade paths and a copy of the original partial-input startup predicate. Parse `PERFORMANCE_JSON` / `COMPONENT_JSON` lines, check all repetitions, and compare binary snapshot/clock hashes. `--profile=true` enables the existing phase counters; keep profiling separate from timing comparisons. `--scenario=feedback` changes realm/resource conditions; `--scenario=cycles` isolates an affordable cycle workload. The critical-cycle fixture deliberately changes costs, enables effects, and stocks crafting ingredients to exercise RNG and repeated random relic creation; it is a test fixture, not a balance proposal.

## Remaining bottlenecks and limits

Dynamic input/output modifiers, resource transfers/statistics, nonlinear feedback and per-tick automation waiting checks remain significant. Larger input/sensitivity lists in future saves could justify revisiting indexes, but this batch does not assume they help. There is no adaptive timestep, event queue, equilibrium detection, tail approximation, native-code port, or offline duration cap.

The pending automatic list assumes upgrade definitions are stable during a catch-up. A same-size replacement/edit of registry definitions must use the existing effect-rebuild hook, which invalidates the list. Normal progression, resource changes, realm reset/load, and in-place levels use the tested live references and refresh rules.

Progress continues to yield every 100 ticks. Its actual wall-clock responsiveness depends on tick cost, rendering and callbacks. The existing use of global RNG by frame-driven visual effects means full-scene crafting determinism can depend on rendering; headless simulation equivalence does not solve that pre-existing coupling. This batch preserves the existing yield sequence and leaves RNG ownership/isolation for a separate change. Shared-host noise and the different target engine make target-machine measurements important before promising a particular speedup.
