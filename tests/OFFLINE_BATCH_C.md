# Offline simulation Batch C

Starting HEAD: `e4da47423f30a71a1440dd2ac93a1477ae83fb05`, branch `feature/cycle-auto-run`. Local and remote HEAD matched before editing. The four pre-existing untracked asset files were preserved. No development branch was created/switched.

## Retained changes

- **12 ms soft wall-clock work budget:** TimeManager checks elapsed work after each original numerical step and yields when the budget is exhausted. Nonpositive `offline_work_budget_ms` selects the original 100-step schedule for comparisons. Initial/final progress and the final redraw remain; intermediate progress is clamped to its total. Zero/negative durations still return immediately. Diagnostic counters record actual steps, yields, maximum uninterrupted block and time awaiting frames. This improves cooperative scheduling, not simulation arithmetic or every workload's throughput. A single slow tick, callback or OS descheduling can exceed the budget.
- **Offline enabled-automation index:** each manager builds its enabled IDs in its original registry order. Disabled entries require no per-tick dispatch. Enable/disable, load, reset, normal updates and catch-up entry invalidate the index. Technology unlock, generator unlock, resources, upgrades, modes, relics and realm effects are **not** cached: the original enabled/unlocked/affordability/waiting/cooldown logic remains live for every retained entry. In particular, enabling a locked entry does not cache its ineligibility. Normal simulation still scans its original registry.

No numerical step, resource formula, generator order, cooldown subtraction, purchase priority, probability, RNG routing, cycle behavior or save schema changed. No interval integration is skipped. A programmatic caller directly editing public automation dictionaries during a catch-up must call `invalidate_offline_index()`; application code uses `set_enabled()`. Direct edits between catch-ups are refreshed by `Simulation.prepare_offline()`.

## Method and limits

Godot **4.6.1 stable Linux**, same shared host and engine for reference/candidate. The target Windows/Godot 4.7.2 loading screen was not rendered. Disposable imported project copies contain the starting commit's mechanic files; only benchmark fixtures were copied into the reference. No concurrent simulation benchmarks. Every subprocess had a timeout; the duration matrix also had a bounded execution budget. Engine startup, fixture creation, snapshots and hashing are outside the internal timer. Profiling was separate from timing.

Primary matrix: two serial samples per version and cell, alternating before/after order. Tables show **median [minimum–maximum] seconds**, with all outliers retained. Two samples are descriptive, not a statistical speed guarantee. The primary matrix took 745 seconds including process startup and contribution runs. Its budget stopped an optional expanded repetition matrix across the remaining fixtures; those fixtures already had exact exploratory comparisons and focused regression coverage. A separate eight-hour inactive pair has one sample per version and is correctness evidence only. The 8/12/16 ms exploratory experiment has three samples per cell; its versions differ only in scheduling. Exploratory and final hashes have different schemas and must only be compared within their own experiment.

The final binary snapshot includes resources; all persisted progression, prestige rewards, inventory/equipment and RNG state; runtime generator flags, cycle progress/critical snapshots, discrete fractions; automatic upgrades; all automation cooldown/waiting fields (including internal waiting-cost metadata); discoveries; dormancy; lifetime/run/offline statistics; progression events in order and four next gameplay RNG words. Only the independently randomized cosmetic lava palette is excluded from the persisted snapshot. Manager clocks have a separate binary hash. Direct and manager paths retain their existing different endpoint arithmetic and are compared with their own reference path, not with each other.

## Baseline profiling

Instrumented share of the five top-level measured phases at 600 simulated seconds (percent; nested counters are not added twice):

| Scenario | Generators | Automatic upgrades | Generator automation | Upgrade automation | Environment |
|---|---:|---:|---:|---:|---:|
| critical_cycles | 45.3 | 7.2 | 29.1 | 15.0 | 3.3 |
| environment | 80.3 | 9.3 | 4.7 | 2.4 | 3.3 |
| feedback | 68.6 | 6.1 | 15.1 | 7.9 | 2.3 |
| fresh | 29.5 | 41.0 | 12.0 | 5.8 | 11.7 |
| idle | 47.6 | 31.9 | 9.9 | 4.9 | 5.7 |
| midgame | 81.2 | 9.7 | 4.0 | 2.0 | 3.0 |
| starved | 57.5 | 25.0 | 8.0 | 4.7 | 4.8 |
| stress | 62.6 | 6.9 | 18.4 | 10.0 | 2.1 |

Fresh uses the unmodified initial GameState. Midgame disables automation in the existing multi-generator stress fixture. Starved removes all resources and pauses input-free producers; the regression also tests recovery with a producer active. Idle pauses all generators with no stored resources. Environment starts with high Heat/Matter/Ash and ordinary environmental defenses. Feedback uses the existing low-defense fixture. Stress enables both automation managers. Critical cycles use the existing affordable repeating craft/RNG fixture; its costs/reserves/effects are synthetic test data, not balance changes.

Repeated modifier/sensitivity/input/output evaluation still dominates productive workloads. Nonlinear Heat leakage depends on step-start Heat and net within-step flow; Matter decay also produces Heat. Ash affects both production and cycle progress, while dormancy changes with real offline time. These couplings prohibit treating resource-starved generators or apparently steady balances as inactive.

## Scheduling contribution only

600 simulated seconds, no automation-index change. Wall time and work-block columns are median [range]; the work column is the **maximum block from each run**, not average tick time. Yields/callbacks are medians; full counts and frame-wait measurements are in JSON.

| Scenario | Budget | Wall seconds | Max block ms | Yields | Progress callbacks |
|---|---:|---:|---:|---:|---:|
| idle | 100 steps | 0.571 [0.570–0.603] | 12.645 [12.051–14.864] | 61 | 62 |
| idle | 8 ms | 0.657 [0.591–0.754] | 9.914 [8.744–119.051] | 75 | 76 |
| idle | 12 ms | 0.582 [0.576–0.600] | 13.075 [13.031–13.496] | 47 | 48 |
| idle | 16 ms | 0.599 [0.581–0.701] | 17.158 [16.580–29.452] | 36 | 37 |
| stress | 100 steps | 1.917 [1.846–1.921] | 48.659 [46.761–54.091] | 61 | 62 |
| stress | 8 ms | 2.052 [2.036–2.160] | 10.710 [10.636–11.066] | 237 | 238 |
| stress | 12 ms | 2.015 [2.013–2.030] | 14.582 [14.300–15.343] | 160 | 161 |
| stress | 16 ms | 2.007 [1.977–2.077] | 20.503 [17.626–37.426] | 119 | 120 |
| critical_cycles | 100 steps | 1.178 [1.170–1.218] | 28.120 [25.162–38.569] | 61 | 62 |
| critical_cycles | 8 ms | 1.258 [1.213–1.295] | 10.179 [9.607–10.232] | 147 | 148 |
| critical_cycles | 12 ms | 1.283 [1.225–1.530] | 15.387 [12.814–24.248] | 101 | 102 |
| critical_cycles | 16 ms | 1.381 [1.308–6.846] | 59.309 [40.994–354.676] | 80 | 81 |

All schedule variants have identical binary state/clock hashes and actual step counts, including varying global reseeds and random calls in progress callbacks. At 12 ms, stress median maximum work fell from 48.659 to 14.582 ms, at the cost of wall time rising from 1.917 to 2.015 seconds. Critical cycles fell from 28.120 to 15.387 ms, while wall time rose from 1.178 to 1.283 seconds. Idle yields fell from 61 to 47, but wall time was essentially unchanged (0.571 to 0.582 seconds). Thus the retained budget is a responsiveness tradeoff, not a claimed universal throughput gain. The 8 ms case produced more callbacks/waits; 16 ms allowed larger blocks and encountered severe host stalls. Neither is the default. OS stalls also exceeded the 8/12 ms budgets; these are soft cooperative limits.

## Event-aware index contribution

60 alternating-order component pairs, 1,000 updates of both disabled managers per sample:

| Full scan µs | Enabled-index µs | Interpretation |
|---:|---:|---|
| 9696.500 [7765.000–20015.000] | 1731.000 [1366.000–6417.000] | Removes disabled dispatch and repeated upgrade-tree allocation; not an end-to-end multiplier. |

The final component control calls the full-scan path (which now also marks the offline index dirty). The first indexed update rebuild is included. All-active scenarios still pay the small index check and receive no disabled-entry benefit. End-to-end contribution measurements below include this overhead and host variability.

## Final before/after duration matrix

Combined = enabled index plus default 12 ms manager budget; direct timings exercise the index only. N=2 for each completed ordinary cell. No tolerances are used for state comparisons.

| Scenario | Duration | Path | Reference seconds | Combined seconds | Exact state / clocks |
|---|---:|---|---:|---:|---|
| idle | 0.166667 h | direct | 0.651 [0.606–0.697] | 0.821 [0.564–1.078] | identical (N=2/2) |
| idle | 0.166667 h | manager | 0.718 [0.635–0.801] | 0.795 [0.775–0.815] | identical (N=2/2) |
| midgame | 0.166667 h | direct | 1.401 [1.390–1.413] | 2.000 [1.554–2.445] | identical (N=2/2) |
| midgame | 0.166667 h | manager | 1.512 [1.470–1.555] | 1.433 [1.430–1.435] | identical (N=2/2) |
| idle | 1 h | direct | 3.930 [3.768–4.091] | 5.033 [4.766–5.301] | identical (N=2/2) |
| idle | 1 h | manager | 3.885 [3.674–4.097] | 3.463 [3.361–3.565] | identical (N=2/2) |
| midgame | 1 h | direct | 8.866 [8.806–8.926] | 12.448 [8.560–16.336] | identical (N=2/2) |
| midgame | 1 h | manager | 9.611 [9.075–10.147] | 9.481 [8.979–9.984] | identical (N=2/2) |
| idle | 4 h | direct | 14.493 [14.288–14.699] | 13.825 [12.972–14.678] | identical (N=2/2) |
| idle | 4 h | manager | 17.441 [14.586–20.295] | 15.214 [14.521–15.906] | identical (N=2/2) |
| midgame | 4 h | direct | 41.562 [39.581–43.543] | 47.053 [40.364–53.742] | identical (N=2/2) |
| midgame | 4 h | manager | 48.484 [48.429–48.538] | 44.299 [42.067–46.531] | identical (N=2/2) |
| idle | 8 h | manager | 44.782 [44.782–44.782] | 27.731 [27.731–27.731] | identical (N=1/1) |

### Contributions at 600 seconds (manager)

Same expanded snapshot and cosmetic RNG interference. N=2 per version; compare rows within the same fixture.

| Scenario | Reference | Index only | Scheduling only | Combined |
|---|---:|---:|---:|---:|
| fresh | 1.658 [1.086–2.230] | 0.841 [0.588–1.094] | 0.962 [0.910–1.015] | 0.626 [0.547–0.705] |
| stress | 2.691 [2.637–2.746] | 2.948 [2.648–3.248] | 2.574 [2.539–2.610] | 2.188 [2.127–2.250] |
| idle | 0.676 [0.672–0.679] | 0.767 [0.601–0.933] | 0.601 [0.599–0.602] | 0.602 [0.558–0.647] |

Raw observations, hashes, source fingerprints, exploratory repetitions, all scheduling counters and baseline profiles are in `offline_batch_c_results.json`. Host variation is substantial and some end-to-end cells regress. The measured disabled-dispatch reduction and shorter work blocks justify these narrow changes; a reliable general simulation speedup is **not** established.

## Event boundaries: investigation and rejected paths

| Opportunity | Decision / obstacle |
|---|---|
| Disabled automation | Retained: preference events invalidate a registry-ordered index. No eligibility or numerical cache. |
| Locked generators | Already skipped by the authoritative loop. No new cache is justified. |
| Paused/inactive generators | Keep existing checks: throttle/operating flags may change, and cycles can auto-activate. An additional per-generator gate/index adds invalidation without measured justification. |
| Resource waiting | Do not skip: producers earlier in the same tick, decay-to-Heat, upgrades and transfers can cross affordability before the buyer executes. |
| Cooldown deadlines | Existing `remaining_cooldown` is advisory boundary data. Retain repeated subtraction/overshoot arithmetic. Replacing repeated 0.1 subtractions with a bulk subtraction changes double bits and can change the purchase tick near zero. For example, 50 IEEE-double subtractions of 0.1 from 5.0 leave 1.0269562977782698e-15, whereas one bulk subtraction produces zero. No deadline jump was implemented. |
| Cycle completion | `remaining_duration / current_speed` is only a current bound. Ash, sensitivity, dormancy, inputs, levels and events can change it; normal resource production continues between completions. No cycle interval skip was implemented. |
| Entirely unproductive intervals | Clock/dormancy/countdown progression and floating additions still change state even with zero production. No whole-step skip was proven, so the original loop remains. |
| New event queue / numeric caches | Not implemented: no evidence that their complexity would outperform the narrow gate while preserving exact ordering. |

8/16 ms scheduling alternatives remain selectable for experiments, with 12 ms as the default. No approximations, adaptive timesteps, fast-forwarding, new duration limits, native extensions or changes to production arithmetic were introduced. Unfavorable timing samples were not discarded or repaired with numerical tolerances.

## Regression validation and next phase

The complete final runner passed **57 cases, zero failures**, without parser warnings or runtime errors: 52 existing plus five Batch-C cases. They exercise full-scan/index parity every tick through cooldown boundaries and purchases; enabled/disabled and live technology changes; reset/rebuild; inactive and resource-starved generators with nonzero dormancy and producer feedback; warm-index save/load; repeated critical/downlevel/crafting actions; exact state/RNG and clocks under 8/12/16 ms scheduling with cosmetic interference; loaded active crafts; direct edits between catch-ups; and negative/zero/very short durations at time scales 0, 1 and 2.5. Save tests compare equally reloaded states; they do not assert repairs to unrelated uninterrupted-vs-resumed timing differences.

The original corrected one-hour benchmark, all three component measurements, the performance benchmark entry point and the Batch-C benchmark all completed without warnings/errors. Final source hashes were checked against the starting commit and the final candidate. No subprocess timed out. Existing larger-step controls are benchmark-only; 0.1-second gameplay stays authoritative. All validation commands reject parser warnings, runtime errors and nonzero status. Pre-existing full-project font/import and `game.gd` indentation errors remain outside the standalone dependency graph; no full-game/editor import or rendered Windows loading-screen success is claimed.

Next: validate the 12 ms default in the real Windows loading screen, then profile resource-dependent modifier evaluation on representative player saves. A larger event-driven architecture is **not justified yet**. Before any numerical interval skip, specify explicit dependency notifications and an exact representation of cooldown/cycle rounding semantics. The current work demonstrates structural dispatch skipping and independent frame scheduling, not a route to skipping continuous integration safely.

## Reproduce

Use the same engine with disposable copies of the starting commit and candidate, copying the current benchmark scripts into the reference. Do not overwrite reference mechanic files. Run serially:

```text
godot --headless --path . --script res://tests/run_regression_tests.gd
godot --headless --path . --script res://simulation/offline_simulation_benchmark.gd
godot --headless --path . --script res://tests/offline_component_benchmark.gd
godot --headless --path . --script res://tests/offline_batch_c_benchmark.gd -- --scenario=midgame --duration=3600 --mode=direct --repeats=3
godot --headless --path . --script res://tests/offline_batch_c_benchmark.gd -- --scenario=stress --duration=600 --mode=manager --budget=0 --noise=true --repeats=3
godot --headless --path . --script res://tests/offline_batch_c_benchmark.gd -- --scenario=stress --duration=600 --mode=manager --budget=12 --noise=true --repeats=3
```

Use durations 600, 3600 and 14400; fixtures `fresh`, `midgame`, `starved`, `stress`, `cycles`, `critical_cycles`, `feedback`, `environment`, `idle`. `--profile=true` is a separate instrumented run. Internal budgets are configurable through `TimeManager.offline_work_budget_ms`; there is no new player-facing setting or save field.
