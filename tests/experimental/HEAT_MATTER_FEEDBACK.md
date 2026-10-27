# Heat/Matter feedback: reference-map prototype

Base: `cedaa2bb60fbff797abce699c52e77f1c508cd3a`, branch `feature/cycle-auto-run`.

**Recommendation: continue targeted research (B). The minimum 3× full-day milestone is not demonstrated.** The bounded full-day comparison did not complete; do not infer its accuracy or speedup from shorter runs.

This is an isolated experiment. Production `Simulation`, `TimeManager`, GameState, modifiers, generator definitions, gameplay RNG and save code are unchanged. The previous experimental operator remains the benchmark default; select this operator explicitly with `--integrator=map`.

## Diagnosis

The old operator evaluates one existing `Simulation.update(h)` against two half updates. Neither generally approximates repeated `Simulation.update(0.1)` well enough for environmental feedback:

- Production precedes Matter decay, which adds Heat, then Heat leak. Rates and modifiers observe the resources at their particular positions in this ordered map.
- Heat can switch from its explicit branch to the existing implicit solver when a larger timestep requests enough loss. Its explicit post-tick equilibrium and pre-leak peak differ from a large-step equilibrium, even with the same formulas.
- Matter decay is an explicit capped flow. Increasing the timestep changes the amount held, the subsequent thermic-mass Heat modifier, Heat production, leak and all their statistics.
- A long call records a lump-production peak before environmental loss. A matching final balance is insufficient to validate those peaks or accumulated overflow.
- The existing distributed error budget scales cumulative-field allowance by `h / offline_duration`. At the minimum trial size the old operator can already disagree too much, then repeats the same unsuccessful experiment after ten exact ticks. Snapshot capture is a smaller cost than repeated trials, signatures and numerical work.

In the reproduced 600-second diagnostic runs, both Heat and stored-Matter cases rejected 599 attempts and executed all 6000 reference ticks. Heat's worst estimator field was lifetime overflow in 597 attempts and Heat in two. Stored Matter's worst fields were overflow in 312 attempts, Heat in 285 and decay in two. All were numerical rejections, not threshold crossings or unsupported mechanics. Detailed profiling runs are separate from primary throughput samples.

The power-law loss curves, thresholds, sensitivity, resistance and thermic-mass formulas are reused through actual reference-map probes; this experiment contains no second copy of those formulas.

## Selected approach

For the complete numerical state `y` (resources and independently recorded cumulative flows), define `d(y) = F_0.1(y) - y`. For an interval of `n` reference ticks:

1. Measure `d0 = d(y)` using one actual 0.1-second simulation call.
2. Predict resource amounts `yp = y + n*d0`; restore counters before this speculative probe.
3. Measure `d1 = d(yp)` using another actual 0.1-second call.
4. Estimate `ynew = y + n*d0 + (n-1)/2 * (d1-d0)`.

The correction matches the `n(n-1)/2 * J(d)*d` term of repeated discrete-map composition. Ordinary Heun integration with coefficient `n/2` instead targets a different continuous-time system. This second-order reference-map approximation is **not exact**, nor a general stability or accuracy proof.

The existing outer controller compares one coarse interval to two grid-aligned half intervals, retains the fine result only when every numerical field passes its distributed budget, and otherwise rolls back. Relative tolerances remain 0.1%, 0.01% and 0.001%; absolute tolerance is 1e-8 in each field's units. No tolerance was relaxed to achieve a speedup.

Production, consumption, losses, weighted Heat overflow and Matter decay counters are integrated separately using the same measured increments and weights. They are not reconstructed just from final stockpiles. Because the updates are affine combinations of conservative reference flows, balance identities carry through up to floating-point error. Negative/nonfinite predicted resources, negative corrected resources, or decreasing cumulative flows reject the trial rather than clipping away the accounting discrepancy.

Peaks receive special handling: retain historical/reference-probe peaks and estimate the last reference microstep's pre-loss peak by shifting the endpoint probe to the corrected endpoint and backing out its last net increment. Do not treat a whole macro interval's production as one instantaneous peak. Peak accuracy is still an approximation and is tested against the oracle's recorded peaks; an unobserved internal extremum is a remaining risk.

A bounded retry cooldown doubles the exact fallback window after repeated minimum-size failures, from ten to at most 1000 reference ticks. Accepted adaptive work resets the cooldown. The audit boundary can shorten a window. Every fallback tick still executes the original simulator; the cooldown skips failed *attempts*, never gameplay updates. The original operator defaults to no cooldown; `--retry_max=1000` enables the control separately.

Threshold crossings and near-threshold changing endpoints continue to reject and return to the authoritative grid. No derivative-only prediction of a safe crossing time was added: coupled feedback makes such a prediction unreliable without further bounds. Predictor/corrector probes, threshold rejection and bounded retries are the only selected mechanisms; there is no event queue, equilibrium jump or analytic loss formula.

## Scope and fixtures

- `heat` / `feedback_heat`: existing Atomic Friction, starting above the Heat threshold.
- `matter` / `feedback_held`: existing Heat source, stored Matter decay and its held-Matter modifier.
- `feedback_matter`: synthetic input-free continuous Matter source, Heat producer paused; decay still produces Heat and can leak.
- `feedback_combined`: the synthetic source plus existing Heat production and both environmental flows.
- `feedback_threshold`: both stocks begin 0.01 below their environmental thresholds.
- `feedback_equilibrium`: existing Heat source prewarmed with 10,000 authoritative ticks; setup is outside timed measurement.
- `feedback_high`: high starting Heat and Matter, exercising nonlinear/stiff reference behavior.
- `feedback_dynamic`: additional test modifier using the existing resource-dependent inverse-square-root formula, plus thermic mass.
- `feedback_starved` / `feedback_recovery`: existing input-consuming generators, with Heat production stopped/resumed; exact fallback.
- `feedback_stored`: existing Atomic Friction level 10, Heat 3× threshold and stored Matter 2× threshold. No synthetic generator. Both environmental losses and the Matter-held Heat effect evolve.
- `feedback_representative`: the same combined fixture plus a synthetic input-free Matter source producing 0.25/s. This tests simultaneous replenishment/decay; it is **not a real player save or an existing recipe**.

Existing Matter-producing generators consume resources and/or produce discrete output. They stay on exact fallback, as do active automation, cycles, critical crafting and complex consumers. This batch does not expand their adaptive eligibility. The numerical helper is generalized over resource/statistics keys; fixture IDs do not appear in its implementation.

## Measurement and correctness

All throughput runs are serial, headless, on the same Linux host and Godot 4.6.1. They are not Windows/Godot 4.7.2 measurements. Shared-host variability is substantial; report paired ratios and median/range, never a single favorable sample as a stable guarantee.

Timing excludes fixture setup and final JSON serialization. Reference time subtracts per-audit comparison overhead; adaptive wall time includes audit capture, all rejected work, signatures and checkpoints. Per-attempt trace capture is enabled only for diagnostic runs. Built-in aggregate timing counters remain in both experimental operators. Their scopes overlap: rejected time includes restoration/signatures, trial time includes numerical work, and map-operator time includes its probes and extrapolation. Do not sum overlapping counters.

Maximum deviation means maximum **sampled** at every accepted macro endpoint plus fixed 60-second checkpoints, not a proven bound at every reference tick. Full reference peak statistics, lifetime/run/offline production/consumption/loss, weighted overflow, decay, reward multipliers, interval clocks and dormancy are included. Per-field errors and final reference/candidate values are retained in `feedback_results.json`.

Strict fingerprints include generator flags/levels/modes, upgrades/application log order, inventory, automation state, discoveries and prestige state/projected rounded rewards. Gameplay RNG state is compared separately. Focused regressions observe crafting/downlevel/unlock signals and require binary-exact fallbacks. No statistical tolerance excuses a discrete/RNG mismatch.

## Results

### Serial throughput before the final entry guard

These measurements use the same numerical operator and controller before the final offline-entry/logging guard. Main feedback fixtures already begin with ten exact ticks, so their numerical work counts/trajectories are unchanged by that guard. The prewarmed equilibrium fixture gains an exact-entry requirement in the final code. Final-code measurements are reported separately; timing versions are not pooled.

| Fixture | Seconds | Method | N | Reference s: median [range] | Experimental s: median [range] | Paired speedup: median [range] | Evaluations | Accepted / rejected | Exact ticks |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|
| feedback_stored | 14400 | map | 2 | 66.044 [47.647–84.441] | 21.033 [9.152–32.915] | 3.886 [2.565–5.206]× | 5776 | 811 / 54 | 600 |
| feedback_representative | 3600 | map | 2 | 16.649 [16.487–16.811] | 4.965 [3.793–6.137] | 3.543 [2.739–4.347]× | 2844 | 358 / 85 | 320 |
| feedback_stored | 3600 | map | 2 | 25.025 [13.329–36.721] | 5.831 [5.532–6.130] | 4.200 [2.410–5.990]× | 2666 | 363 / 50 | 320 |
| feedback_representative | 600 | map | 2 | 4.021 [3.530–4.513] | 5.371 [4.357–6.386] | 0.758 [0.707–0.810]× | 1542 | 201 / 50 | 160 |
| feedback_stored | 600 | map | 2 | 2.975 [2.471–3.479] | 4.631 [3.597–5.666] | 0.702 [0.436–0.967]× | 1376 | 189 / 34 | 160 |
| heat | 600 | map | 2 | 2.285 [2.261–2.308] | 8.615 [7.858–9.372] | 0.267 [0.246–0.288]× | 3418 | 432 / 89 | 600 |
| matter | 600 | map | 2 | 3.200 [2.561–3.838] | 6.231 [5.571–6.891] | 0.530 [0.372–0.689]× | 2434 | 322 / 99 | 160 |
| feedback_representative | 600 | original | 2 | 4.854 [2.427–7.281] | 16.494 [9.153–23.835] | 0.285 [0.265–0.305]× | 7797 | 0 / 599 | 6000 |
| feedback_stored | 600 | original | 2 | 3.596 [2.515–4.676] | 9.633 [7.393–11.874] | 0.367 [0.340–0.394]× | 7797 | 0 / 599 | 6000 |
| heat | 600 | original | 2 | 2.848 [2.370–3.326] | 10.382 [8.494–12.270] | 0.275 [0.271–0.279]× | 7797 | 0 / 599 | 6000 |
| matter | 600 | original | 2 | 1.895 [1.882–1.908] | 7.826 [6.951–8.701] | 0.245 [0.216–0.274]× | 7797 | 0 / 599 | 6000 |
| feedback_combined | 600 | map | 1 | 2.061 [2.061–2.061] | 7.025 [7.025–7.025] | 0.293 [0.293–0.293]× | 3072 | 354 / 104 | 600 |
| feedback_dynamic | 600 | map | 1 | 4.353 [4.353–4.353] | 9.491 [9.491–9.491] | 0.459 [0.459–0.459]× | 2486 | 257 / 71 | 600 |
| feedback_equilibrium | 600 | map | 1 | 1.415 [1.415–1.415] | 0.303 [0.303–0.303] | 4.669 [4.669–4.669]× | 142 | 24 / 0 | 0 |
| feedback_held | 600 | map | 1 | 1.704 [1.704–1.704] | 4.652 [4.652–4.652] | 0.366 [0.366–0.366]× | 2578 | 268 / 81 | 600 |
| feedback_high | 600 | map | 1 | 1.891 [1.891–1.891] | 6.213 [6.213–6.213] | 0.304 [0.304–0.304]× | 1730 | 199 / 38 | 320 |
| feedback_matter | 600 | map | 1 | 4.167 [4.167–4.167] | 10.435 [10.435–10.435] | 0.399 [0.399–0.399]× | 4128 | 513 / 10 | 1200 |
| feedback_recovery | 600 | map | 1 | 3.461 [3.461–3.461] | 2.902 [2.902–2.902] | 1.192 [1.192–1.192]× | 6000 | 0 / 0 | 6000 |
| feedback_starved | 600 | map | 1 | 1.963 [1.963–1.963] | 2.981 [2.981–2.981] | 0.659 [0.659–0.659]× | 6000 | 0 / 0 | 6000 |
| feedback_threshold | 600 | map | 1 | 1.719 [1.719–1.719] | 10.615 [10.615–10.615] | 0.162 [0.162–0.162]× | 3080 | 356 / 104 | 600 |

### Final-code throughput

| Fixture | Seconds | N | Reference s: median [range] | Experimental s: median [range] | Paired speedup: median [range] | Evaluations | Accepted / rejected | Exact ticks |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| feedback_stored | 3600 | 2 | 40.010 [21.084–58.935] | 8.016 [6.454–9.579] | 5.667 [2.201–9.132]× | 2666 | 363 / 50 | 320 |
| feedback_stored | 600 | 2 | 1.767 [1.692–1.843] | 7.787 [6.677–8.898] | 0.233 [0.190–0.276]× | 1376 | 189 / 34 | 160 |

### Error-target sweep, 600 seconds

Maxima across the short map observations at each target; independent resource/statistics maxima can occur in different fields and times. All near-zero comparisons use atol 1e-8. The complete per-field final and maximum sampled deviations remain in JSON.

| Target | Map observations | Max resource abs / relative | Max other numeric abs / relative | Worst normalized error | Accuracy failures | Discrete / RNG failures |
|---:|---:|---:|---:|---:|---:|---:|
| 0.1% | 9 | 0.2351 / 0.0001036 | 0.2352 / 3.326e-05 | 0.1036 | 0 | 0 |
| 0.01% | 19 | 0.001487 / 4.046e-06 | 0.009549 / 4.261e-06 | 0.04261 | 0 | 0 |
| 0.001% | 9 | 0.0001774 / 4.609e-07 | 0.0002164 / 4.318e-07 | 0.04609 | 0 | 0 |

### Long-run resource and accumulated-statistics accuracy

Final-code stored Matter, 1 h, N=2. Relative values below are fractions, not percentages.

| Field | Reference final (median) | Max final absolute / relative error | Max sampled absolute / relative error |
|---|---:|---:|---:|
| resource/heat | 2260 | 1.053e-05 / 4.659e-09 | 0.0001848 / 8.175e-08 |
| resource/matter | 100.7 | 2.164e-05 / 2.149e-07 | 0.0001073 / 1.053e-06 |
| lifetime/heat/total_produced | 1.949e+05 | 0.0003856 / 1.979e-09 | 0.003412 / 7.165e-08 |
| lifetime/heat/total_lost | 1.956e+05 | 0.0003751 / 1.918e-09 | 0.003522 / 7.452e-08 |
| reward/overflow | 1.956e+05 | 0.0003751 / 1.918e-09 | 0.003522 / 7.452e-08 |
| lifetime/matter/total_produced | 0 | 0 / 0 | 0 / 0 |
| lifetime/matter/total_lost | 99.28 | 2.164e-05 / 2.18e-07 | 0.0001073 / 1.094e-06 |
| reward/decay | 99.28 | 2.164e-05 / 2.18e-07 | 0.0001073 / 1.094e-06 |
| lifetime/heat/highest_amount | 3009 | 0 / 0 | 0 / 0 |
| lifetime/matter/highest_amount | 200 | 0 / 0 | 0 / 0 |
| reward/multiplier | 1.834 | 1.438e-08 / 7.837e-09 | 7.357e-08 / 4.184e-08 |
Pre-entry-guard stored Matter, 4 h, N=2. Relative values below are fractions, not percentages.

| Field | Reference final (median) | Max final absolute / relative error | Max sampled absolute / relative error |
|---|---:|---:|---:|
| resource/heat | 2260 | 7.945e-07 / 3.516e-10 | 5.748e-05 / 2.543e-08 |
| resource/matter | 100.3 | 1.685e-06 / 1.681e-08 | 4.093e-05 / 4.03e-07 |
| lifetime/heat/total_produced | 7.783e+05 | 0.001802 / 2.315e-09 | 0.001894 / 2.803e-08 |
| lifetime/heat/total_lost | 7.79e+05 | 0.001802 / 2.312e-09 | 0.001926 / 2.862e-08 |
| reward/overflow | 7.79e+05 | 0.001802 / 2.312e-09 | 0.001926 / 2.862e-08 |
| lifetime/matter/total_produced | 0 | 0 / 0 | 0 / 0 |
| lifetime/matter/total_lost | 99.71 | 1.685e-06 / 1.69e-08 | 4.093e-05 / 4.158e-07 |
| reward/decay | 99.71 | 1.685e-06 / 1.69e-08 | 4.093e-05 / 4.158e-07 |
| lifetime/heat/highest_amount | 3009 | 0 / 0 | 0 / 0 |
| lifetime/matter/highest_amount | 200 | 0 / 0 | 0 / 0 |
| reward/multiplier | 1.907 | 1.046e-09 / 5.486e-10 | 2.821e-08 / 1.59e-08 |

### Rejection and fallback controls

| Control | Rejected | Evaluations | Exact ticks | Rejected wall scope s | Numerical s | Map operator s | Guard/signature s |
|---|---:|---:|---:|---:|---:|---:|---:|
| feedback-final-cooldown-only-feedback_representative.log | 15 | 6045 | 6000 | 0.300 | 4.862 | 0.000 | 0.185 |
| feedback-final-cooldown-only-heat.log | 15 | 6045 | 6000 | 0.128 | 4.867 | 0.000 | 0.104 |
| feedback-final-map-no-cooldown-feedback_representative.log | 60 | 1592 | 150 | 0.571 | 0.733 | 1.923 | 0.912 |
| feedback-final-map-no-cooldown-heat.log | 137 | 3660 | 550 | 1.448 | 1.641 | 3.941 | 2.597 |

The cooldown-only control remains 100% exact. Its occasional speedup above 1× versus the reference is host/timing variability, not accelerated integration. The deterministic finding is fewer failed trials (599 → 15 in these 600-second controls) and fewer total evaluations (7797 → 6045). Single control timings do not establish an independent throughput contribution.


## Failed and incomplete runs

The first runtime import attempted to use an incompletely copied asset tree. Those benchmark observations contained resource/parser errors and were rejected, not included in primary performance evidence. Reimporting the complete assets resolved the standalone errors. Full-project import still reports the starting branch's unrelated `game.gd` indentation error; a clean rendered game launch is not claimed or repaired here.

The first hour-long map screen failed the aggregate numerical comparison because checkpoint restoration restored the old dormancy value. Resource/flow errors were small, but the 3600-second dormancy discrepancy was about 0.19565 and rightly failed. Updating the accepted endpoint penalty corrected this; these failed observations are retained as exploratory results.

A diagnostic timer wrapper initially called an unavailable parent method after a function rename; its parser/runtime errors invalidate that run. The corrected explicit parent call passes standalone parser checking. An early full-suite command hit its 90-second timeout during expanded feedback coverage; a subsequent 240-second attempt also timed out after the original 64 cases. Neither is a passing full suite. The final regression uses shorter focused numerical fixtures (the separate 600-second benchmark sweep retains all three targets) and a 480-second command bound. A subsequent suite found the retry test's reference did not clip its final timestep like the benchmark. Matching the authoritative duration-clipping convention fixed the binary comparison; no gameplay code was changed.

Final validation logs and exact outcomes are recorded in `feedback_results.json`. RESULTS: 70 passed, 0 failed. `simulation/offline_simulation_benchmark.gd`: incomplete (timeout). `tests/offline_component_benchmark.gd`: passed. `tests/offline_performance_benchmark.gd`: passed. `tests/offline_batch_c_benchmark.gd`: passed.

## Full-day milestone and stopping decision

The replenished-Matter four-hour comparison hit its 180-second command bound. A final-code 24-hour stored-Matter comparison then hit its 420-second bound without a completed accuracy result. These are incomplete measurements, not numerical failures and not evidence of a 3× speedup. The original capture helper did not flush intermediate phase output on that timeout; no unknown partial timing is presented as measured.

A separate, instrumented 60-second diagnostic was then stopped with partial progress preserved. Its last recorded accepted time was about 45,734 seconds (12.7 hours), 14,668 reference-map evaluations, 2,140 accepted macro steps, 107 rejected trials and 1,200 exact fallback ticks. Its rejected trials were driven by lifetime Matter-decay error. It did not run the reference oracle to those times, so it establishes work/progress only, not long-run accuracy or a full-day speedup. The diagnostic source and progress records are preserved in the results JSON.

No full-day retry or wider matrix was pursued. Four-hour measurements are promising but variable; the 5.21× and 2.57× stored-Matter observations do not establish a reliable minimum 3× result, and cannot substitute for 24-hour validation.

The next bounded investigation should first persist/reference checkpoint traces and stream partial results so expensive oracle work survives a timeout. Then isolate the remaining coarse-operator, snapshot/signature and estimator costs, with a single full-day oracle comparison on a stable host. Only after that is event/consumer expansion justified. No tolerance relaxation or production enablement follows from this batch.

## Remaining limitations and next step

The acceptance estimate is heuristic and tested on these fixtures, not a global error certificate. Threshold-local error, nonlinear extrema, untested relic configurations, long saved contexts, scaled time, stabilization/recovery and consumer affordability remain risks or unsupported. This experiment owns a fresh scale-one interval; it is not a save-resume adapter. It does not remove the production catch-up cost for automated, crafting or input-allocation-heavy saves.

After the full-day numerical/performance gate is met, the next justified work is a representative real-save dependency/coverage study and dense-reference checks around thresholds/extrema, followed by one narrowly bounded consumer only if worthwhile. Do not enable this path in TimeManager without separate approval. No production rollout or general 10×/25×/50× claim follows from a restricted feedback success.

## Reproduce

```text
godot --headless --path . --script res://tests/run_regression_tests.gd
godot --headless --path . --script res://tests/experimental/adaptive_benchmark.gd -- --scenario=heat --duration=600 --trace=true
godot --headless --path . --script res://tests/experimental/adaptive_benchmark.gd -- --scenario=feedback_stored --duration=3600 --integrator=map --tolerance=0.0001 --absolute=1e-8 --maximum=60 --repeats=2
godot --headless --path . --script res://tests/experimental/adaptive_benchmark.gd -- --scenario=feedback_representative --duration=86400 --integrator=map --tolerance=0.0001 --absolute=1e-8 --maximum=60 --repeats=1
```

Other controls: `--retry_max=0` disables backoff; `--retry_max=1000` tests it with the old operator; `--force_exact=true` uses reference ticks. Keep long runs serial and bounded; validate short cases first. Do not compare a different tolerance, engine, fixture or timing scope as if it were the same experiment.
