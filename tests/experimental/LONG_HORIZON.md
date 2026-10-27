# Long-horizon optimization and experimental accuracy modes

Base: `dd98e0a7f88d7a244dc2789957f6118f3d400d5c`, branch `feature/cycle-auto-run`.

**Practical answer: no. We cannot yet reliably reduce the realistic Windows catch-up from 36 minutes to six–eight minutes.** The realistic mixed fixture uses exact simulation throughout. The retained optimizations help restricted, source-free continuous feedback, especially a late Matter-decay regime; they do not extend adaptive eligibility to automation, consumers or active crafts. Production remains unchanged and adaptive simulation is not enabled.

## Diagnosis: two distinct long-run costs

The original four-hour feedback diagnostic did not deteriorate: its first hour cost 6.21 seconds, then 1.93, 2.37 and 3.35 seconds. Later hours each used 840 reference-map evaluations and zero rejected trials, with 100% adaptive coverage. Average accepted width was 25.71 seconds. Generator activity remained one Heat source; thresholds and modifiers are recorded per segment in the data.

The separate reference took 29.90 seconds for its first simulated hour and hit a 90-second bound before finishing four hours. Older benchmark timeouts covered startup, adaptive work and the expensive reference phase together, and their capture helper lost partial phase output. A past 420-second timeout therefore cannot be assigned solely to the adaptive phase.

However, a new bounded diagnostic of the **starting commit's numerical implementation**, isolated through snapshot scripts, exposed a real late collapse. At about 20 hours, Matter entered the absolute 0.1-unit environmental safety margin. Matter was approaching the threshold asymptotically, not crossing it. The blanket margin nevertheless rejected every changing interval. Hours 21 and 22 each used 36,240 evaluations: 36,000 exact ticks plus failed trials. The diagnostic hit its 120-second bound after 22 recorded hours. No complete 24-hour accuracy or timing result is claimed.

Thus both expensive oracle/harness work and a specific false event barrier matter. Increasing resource amounts, more active generators, or growing numerical instability were not established as the cause. Shared-host timings also vary substantially even with identical evaluation counts. Process CPU and wall times are recorded, but do not isolate CPU-frequency/cache effects or prove a particular host cause.

### Selected hourly segments from the starting implementation

| Hour end | Wall s | Evaluations | Rejected | Exact ticks | Adaptive coverage | Mean / median / max step s |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 15.302 | 4830 | 107 | 1200 | 96.667% | 6.946 / 2.400 / 52.800 |
| 2 | 3.815 | 840 | 0 | 0 | 100.000% | 25.714 / 26.400 / 52.800 |
| 4 | 2.734 | 840 | 0 | 0 | 100.000% | 25.714 / 26.400 / 52.800 |
| 19 | 1.350 | 840 | 0 | 0 | 100.000% | 25.714 / 26.400 / 52.800 |
| 20 | 4.421 | 17962 | 45 | 17302 | 51.939% | 24.283 / 26.400 / 52.800 |
| 21 | 8.978 | 36240 | 60 | 36000 | 0.000% | 0.000 / 0.000 / 0.000 |
| 22 | 12.269 | 36240 | 60 | 36000 | 0.000% | 0.000 / 0.000 / 0.000 |

Complete segment counters, resource levels and reasons are preserved in the results JSON. Current-run profiling additionally measures all captures/restores and live thresholds/modifiers.

## Retained changes

1. **Source-free Matter-decay margin proof.** True predicted crossings still reject. Near-margin work may proceed only above the threshold, with nonincreasing coarse/fine predictions, no active Matter producer, no consumers/controllers allowed by the original guard, and a reference-step loss below half the initial excess. The existing Matter decay is a positive power-law sink with exponent at least two; its loss/excess ratio decreases as the stock decreases. By induction, once a reference tick cannot cross, subsequent source-free reference ticks cannot cross either. The half-excess bound provides additional numerical clearance. This removes a false barrier without assuming constant rates or relaxing tolerances.
2. **Redundant probe capture removed.** After restoring a checkpoint and writing predicted resource amounts, all non-resource numeric fields are already known. Reuse those fields rather than flattening the entire state again: four numeric captures become three per coarse map. There is no cross-tick cache or modifier-rate cache; all actual rate calculations still use live state and the existing formulas.
3. **Statistics initialization once per resource.** Replace repeated idempotent `_ensure_resource` calls during the same statistics write. Operator states and sampled trajectories remain binary identical in focused tests.
4. **Segmented diagnostics and bounded streaming.** Optional hourly/minute aggregation records accepted widths, coverage, rejections, reference evaluations, capture/restore time, fallback time/reasons, resources, thresholds, effective modifiers, active generators and enabled automation. No per-tick logging is added.
5. **Oracle traces.** Atomically preserve binary numeric/discrete/RNG/reward observations, with engine/platform/architecture, production-source digest, fixture, harness and initial-state identity. Reuse is refused on mismatches. This is an observation cache, not resumable GameState serialization. An incomplete reference never counts as an accuracy pass.

The monotone proof is specific to the current environmental sink contract, not a generator-specific shortcut. It reads the existing decay getter at the saved amount and restores the raw amount without resource setters, peaks, signals or RNG. A Matter producer, unsafe loss fraction, predicted crossing, changed eligibility, or other unsupported system keeps exact fallback. Heat's near-margin cases remain conservative. Changes to the production decay contract would require reviewing this proof.

## Rejected optimization

Preserving a large proposed timestep across audit clipping looked attractive, but caused 34–37 rejected trials per later hour where the baseline had none. Later-hour evaluations became 858–888 versus 840, despite larger average accepted widths. One-hour adaptive time also worsened in the screen. Accuracy passed, but work did not improve; the proposal-selection change was removed. Its sources and results are retained in `horizon_results.json`.

## Experimental policies

All parameters are centralized in `accuracy_modes.gd`; no player settings or save fields are added.

| Policy | Numerical target | Maximum macro step | Other restrictions |
|---|---:|---:|---|
| Precise | Authoritative 0.1-second map | 0.1 s | Exact throughout |
| Balanced | rtol 0.01%, atol 1e-8 | 60 s | Conservative guards and distributed budget |
| Fast | rtol 0.1%, atol 1e-8 | 60 s | Same guards; not an approval of gameplay tolerance |

Balanced/Fast choose exact simulation for intervals up to 600 seconds, mitigating the measured short-run regression. The cutoff is an experimental duration policy, not a gameplay duration cap. Longer unmeasured intervals are not guaranteed to outperform Precise.

Both modes also choose exact simulation whenever prestige currency is present or an active output can create it. Existing automation, cycles, consumers, unsafe automatic upgrades, discovery transitions and time-dependent modifiers remain guarded. The reward API lacks dependency/boundary metadata; a conservative currency gate protects the current formula without duplicating it or adjusting rewards afterward. This sacrifices adaptive coverage, including some zero-reward states.

## Prestige protection

A fixture locates the next integer boundary using the production prestige calculator and bisection. An overflow change of roughly four units around 10 billion can change the integer reward—about 4e-10 relative, far below either adaptive tolerance. Continuous relative accuracy alone therefore cannot guarantee integer reward parity. The protected modes execute exact ticks from the start in this fixture; the reward transition is exercised and remains identical. No reward compensation is performed.

## Measurements and accuracy

Linux Godot 4.6.1 headless, not the target Windows/Godot 4.7.2 machine. Runs are serial and bounded. Fixture/startup time is excluded from engine simulation timings; the launcher records whole-process wall/CPU times separately. Reference compute excludes audit/cache reporting overhead. Adaptive wall includes retained snapshots and all runtime trial checks. Dense and fixed retained audits are identified per run; changing retention is tested to leave numerical state unchanged. Per-trial error, discrete and RNG checks remain enabled in throughput runs.

Cached-reference ratios reuse a measured oracle timing. They are not repeated contemporaneous paired speedup evidence and must not be presented as a reliable mixed-gameplay gain. The data retain every valid slow run and configuration failure.

### Non-diagnostic late-checkpoint throughput

| Policy | Adaptive s | Measured cached reference s | Ratio to cached reference | Evaluations | Accepted / rejected | Resource max abs / relative | Statistics max abs / relative |
|---|---:|---:|---:|---:|---:|---:|---:|
| timing-late-balanced-false.status.json | 12.7189 | 12.3601 | 0.97× | 36260 | 0 / 65 | 0 / 0 | 0 / 0 |
| timing-late-balanced-true.status.json | 2.0476 | 12.3601 | 6.04× | 878 | 115 / 30 | 0.0047835 / 2.1169e-06 | 0.0047833 / 4.4264e-07 |
| timing-late-fast-true.status.json | 1.7256 | 12.3601 | 7.16× | 860 | 113 / 29 | 0.045509 / 2.0139e-05 | 0.045509 / 6.8367e-07 |

All relative entries are fractions, not percentages. These are one-hour continuations from a late resource/statistics checkpoint, not whole-day comparisons. The non-diagnostic before/after Balanced times were 12.72 / 2.05 seconds (6.21× in that observation); a separate profiled pair was 9.66 / 1.87 seconds. Do not pool profiled and non-profiled timings. There is insufficient repeated non-profiled evidence to claim a reliable speedup factor.

### Static operator component experiment

Nine interleaved blocks of 100 identical 60-second coarse evaluations used a fixed restored state. Median [range] microseconds per block:

| Variant | Median [range] us | Final state |
|---|---:|---|
| Original | 335881 [193831–1229422] | Identical |
| Reuse known probe fields | 226175 [157069–496506] | Identical |
| Ensure statistics once | 183591 [176656–848031] | Identical |

These isolated medians suggest improvement, but ranges overlap broadly and they are not end-to-end speedup guarantees. One-hour cleanup screens also passed all numerical checks with unchanged evaluation counts. No 5× claim is based on these component timings.

### Scenario coverage and limitations

Ten-minute Precise/Balanced/Fast comparisons cover early progression, linear production, Heat equilibrium, Matter equilibrium, coupled feedback, Ash, Essence, consumers, automation, cycles, idle and mixed gameplay, plus a prestige boundary. All completed screen comparisons passed with exact numeric parity because the short-duration policy selected exact ticks. The cycle screen observed three critical completions, three normal completions, two downlevels and six relic crafts, identically across modes. Threshold-adjacent 660-second Balanced/Fast cases exercised adaptive Heat behavior and passed. A high-variant command used the wrong shared cache path; the identity guard rejected it, and it is classified as an invalid configuration, not an accuracy result.

The original four-hour diagnostic and the rejected-proposal comparison are preserved separately. The final margin fix is validated through the late-state continuation, focused tests and full regression suite. A final 12-/24-hour paired oracle comparison was not completed. No long-horizon Fast stability claim or final-code 24-hour speedup is made.

Resource and statistic comparisons include all resources, production/consumption/loss, peaks, lifetime/current-run/offline statistics, weighted overflow, decay, reward multipliers, dormancy and clocks. Strict fingerprints include ordering/state of upgrades, generators, inventory, automation and progression logs; RNG and integer rewards are checked separately. Maximum deviations are sampled at retained common audit times, not dense-time error bounds. Raw final numeric values and fingerprints remain in the data.

## Validation and remaining risks

**76 regression tests passed, zero failures, no parser warnings or runtime errors.** Added coverage verifies cleanup binary equivalence, short/zero/fractional intervals, configuration validation, diagnostic/retention invariance, exact mixed fallback, reward-boundary protection and the monotone sink proof. A development mixed fixture initially called a nonexistent purchase method; that invalid run was rejected and corrected before the full suite. No passing result relies solely on Godot's exit code: logs are checked for engine errors/warnings.

There is no production TimeManager integration, rendered Windows timing, general save/resume adapter, dense-time numerical guarantee or consumer/automation event solver. Arbitrary relic configurations and a future change to the decay/reward contracts require new validation. The existing unrelated full-scene import issue documented in the previous report was not repaired; no clean rendered-scene launch is claimed.

## Recommendation

Continue targeted research, not production rollout. Recommend **Precise plus one conservative adaptive policy** as the next evaluation target. Keep Fast as an internal experimental preset; its small late-checkpoint advantage and larger deviations do not justify a third player setting yet. In short and mixed cases it performs exactly the same simulation work as Balanced/Precise.

The realistic mixed fixture has enabled automation and active resource-consuming/cycle systems. Those guards do not become eligible merely because more offline time passes. It therefore has zero adaptive coverage and no basis for a reliable 5× improvement. The demonstrated late-Matter fix is useful, but cannot presently turn the user's 36-minute catch-up into six–eight minutes without further event/consumer architecture and target-machine validation.

Next work should quantify real-save eligibility, then address one consumer/automation boundary at a time with exact replay near affordability/exhaustion and strict reward protection. Do not expand numerical tolerances to conceal those architectural limits.

## Reproduce

```text
godot --headless --path . --script res://tests/run_regression_tests.gd
godot --headless --path . --script res://tests/experimental/horizon_components.gd
python tests/experimental/run_horizon.py --godot GODOT --project . --output RUN.log --timeout 120 -- --scenario=late_feedback --duration=3600 --accuracy=balanced --audit=fixed --cache=REFERENCE.cache
```

Other controls: `--accuracy=precise|balanced|fast`, `--diagnostics=true --segment=3600`, `--audit=dense|fixed`, `--margin_proof=false`, `--candidate=baseline|fields|ensure|combined`, `--short_exact=0`, `--action=reference|adaptive|paired`, `--refresh_reference=true`. Use a different cache for different fixtures/durations; mismatches fail closed. Cache files preserve observations after each reference hour, not executable resumable saves. Full comparisons that time out remain incomplete.

Recorded completed accuracy comparisons: **53**, including historical controls and removed candidates; all passed discrete/RNG/integer reward comparisons. See per-run source/configuration metadata rather than pooling versions.
