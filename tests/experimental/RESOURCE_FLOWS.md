# Conservative resource-flow experiment

## Scope and repository

Inspected branch `feature/cycle-auto-run`, HEAD `e64ad636b57c30f31e6b68bbd981293068ff41fb`; recent predecessors were `6fadba6` (waiting bounds), `3d5c5f7` (horizon policies), `dd98e0a` (reference-map feedback), and `cedaa2b` (initial adaptive study). No branch was created or switched. Initial checkout had an untracked temporary Ogg file; it is preserved. No production source, definition, formula, setting, save field or production offline caller changes.

**Result:** actual Arcane Compressor expansion (Nexum input, Matter output) now adapts. This is a real consumer/converter using its existing definition and implementation, not a synthetic constant-rate rule. It is a deliberately narrow funded fixture, not evidence of faster realistic mixed catch-up. Natural mixed gameplay remains exact. See measured tables below.

## Inspected authoritative tick order

`simulation/simulation.gd:update`, with the existing TimeManager 0.1-second offline grid:

1. Remember starting Heat; set offline interval-statistics tracking and reconcile realm log bookkeeping.
2. Apply eligible automatic upgrades in registry order (offline index caches candidates, not eligibility). Effects may unlock generators/modes/IO, attach modifiers/sensitivities or change thresholds.
3. Calculate the Eternal Furnace Heat multiplier once.
4. Iterate generators in registration order: Atomic Friction, Molecular Agitation, Lava Mites, Infernal Condensation (`thermal_furnace`), Matter Furnace, Arcane Compressor, Infernal Forge, Relic Crucible.
5. For each unlocked generator update throttling **before** operation checks. Cycles use their separate activation/completion path. Continuous generators start if allowed; offline duration is capped by each available input/rate. Consume inputs in IO order, then calculate and produce outputs in IO order using the now-mutated state. A partial interval can stop operation. Later generators see earlier transactions.
6. Matter decay: evaluate the power-law sink at post-generator Matter, clamp to stock, remove Matter, record lost Matter and decay totals, add the same quantity to Heat and record Heat production.
7. Heat leak: inspect post-decay Heat and tick-start Heat. Use explicit loss in the mild regime; stiff/crossing cases call the existing implicit substep Heat-balance integrator. Record actual loss and CF-weighted overflow totals.
8. Generator autobuyers, in their existing order. Then upgrade autobuyers, in existing tree/registry order. Success starts cooldown; failure remains ready. Each purchase can affect the next buyer and the next tick.
9. Offline-entry logging cleanup; periodic active-play economy snapshots do not run offline.

Activation purchases transact activation costs and crafting ingredients, set critical snapshots, and may change levels. Cycle processing consumes/produces during available elapsed time; completion rolls event RNG, applies completion outputs, may wipe Heat on CF output, awards shards/relics, applies level consequences, and clears progress/operating flags. Offline auto-run can restart within the same tick and consume its remaining duration. Knowing a nominal finish time alone is insufficient to skip these transactions.

## Resource-flow dependency map

| System / inspected implementation | Continuous or nonlinear behavior | Discrete boundaries and dependencies | Consequence for bounds and automation |
|---|---|---|---|
| `Generator.get_input_consumption_per_second`, `get_production_rate`; `consume_inputs`, `produce_outputs` | IO base rate × level (where configured) × mode × realm × applicable modifiers/sensitivities. Input rates and output rates are evaluated at different ordered states. | Operating/start/stop flags, pause, level/mode changes. Offline min(input/rate) caps available duration. | Bound every generator's **gross** input/output, preserve registration/IO ordering. Net endpoint positivity alone cannot prove availability. |
| Transfer mode (`is_resource_transfer`) | Output derives from first input base rate × level × input multiplier; production bonuses are bypassed. Input calculation also bypasses modifiers. | Mode unlock/selection; exhaustion. | Existing metadata supplies a useful static capability, even when unused production modifiers depend on changing Matter. |
| Matter / `thermic_mass` | Logarithmic held-Matter boost targeting Heat production, scaled by realm effect. Formula clamps to 1 at Matter ≤ 1. | Automatic first unlock at Matter ≥ 1 is discrete. Formula join itself is continuous. | Consuming Matter can reduce future Heat production; ignoring that consumer is not an independent Heat forecast. |
| Heat leak (`GameState.get_heat_leak_per_second_at`, `Simulation.apply_heat_leak`) | Nonnegative power law above threshold; zero below. Continuous value at threshold. Different numerical update regime at stiff-step criteria (including the 5% test). | No jump in physical leak rate at threshold, but numerical branch/clamp changes matter for reference-map parity. | Sink may be ignored for an upper Heat bound only if all its coupled production dependencies remain enclosed. New consumer proof requires leak inactive throughout. |
| Matter decay (`get_matter_decay_per_second`, `apply_matter_decay`) | Nonnegative power law above threshold, continuous at join; clamped explicit per-tick removal. | Crossing changes active branch, not an instantaneous physical event. | It is a Heat **source**, a Matter sink, and a reward/statistics source. Never drop it as merely a sink. |
| Ash contamination (`Modifier` inverse sqrt), cycle slowdown | Smooth suppression above configured Ash threshold. Sensitivity blends penalty, cycle speed is clamped nonnegative. | Automatic contamination unlock; threshold join is continuous. Lava Mites add separate discrete throttling hysteresis. | Ash-producing consumers can change all future output rates and cycle times. New proof rejects changing Ash dependencies and Lava Mites controller. |
| Lava Mites (`_update_lava_mite_throttle_state`) | Normal/throttled input-rate calculations; dormancy depends on TimeManager clock. | One-second normal-input reserve for recovery; toggled throttle state; suppression of selected Ash input modifiers. | Controller is hardcoded by generator ID and lacks a metadata contract. Explicit rejection records this gap; no positive generator-ID whitelist. |
| Essence influence / accumulation | Held Essence changes crystallization sensitivity, Mite Ash draw, and Essence output via existing modifiers. CF penalty is exponential; sensitivity changes its exponent. | Automatic unlocks and mode/upgrade purchases. Formula joins are continuous; changing resource-dependent rates are not inherently discrete. | New proof permits dynamic formulas only with known formula kinds and immutable resource dependencies. |
| Other dynamic modifiers / `ModifierSensitivity` | log, sqrt, inverse sqrt, inverse reservoir, exponent, thresholded power; generator-level dependencies; mode filters; realm factors. | Generator-level dependencies remain fixed only without purchases/completions. Unknown formula metadata is unsupported. | Reuse formula constants and actual calculation methods. No sampled current-rate extrapolation for a changing dependency. |
| Discrete generator outputs | Fractional `production_progress` accumulates then floors units. | Integer production, discovery signals, progress remainder. | Exact fallback; continuous interpolation must not invent integer production. Condensation's Matter and compression's Nexum are discrete. |
| Generator/upgrade unlocks and operating modes | Modifiers can affect input/output/cost/scaling/speed. | Registry-ordered automatic/manual upgrades; exclusivity; mode/output unlock; level changes. | Pending automatic upgrades need an immutable unmet requirement; purchase-dependent state always stays exact unless existing waiting proof excludes purchase. |
| Autobuyers (`GeneratorAutomationManager`, `UpgradeAutomationManager`) | Countdown accumulation on tick grid. | Initial/success cooldown expiry, failed readiness, affordability, tree and generator priority, resource requirements. | Reuse existing source-free upper-bound proof; growing purchase-resource bounds and arbitrary dynamic costs still reject. Positive upgrade timers remain exact. |
| Statistics, discovery, prestige, RNG | Produced/consumed/lost totals, transient highest stock, run/lifetime/offline overflow and Matter decay; CF-weighted overflow contributes to current-realm reward. | Discovery, integer projected prestige reward, crafting inventory, event signals and gameplay RNG draws. | Checkpoint includes continuous statistics; signatures cover levels, flags, automation, modes, discoveries, inventory and event history. Existing prestige exposure gate retained; no projected reward boundary guess. |

There is no generic dependency graph for controllers, environmental numerical branches, future reward floors or arbitrary future formula implementations. IO/modifier metadata covers a useful subset, not the whole simulation. Nonlinear continuous behavior is not labelled a discrete event merely to simplify this distinction.

## Rejection instrumentation and measured coverage losses

The existing runner already records primary fallback ticks by reason, rejected trial counts by numerical/boundary reason, offending numerical field, evaluations and microsecond totals. The new runner adds subsystem/generator/resource-specific proof reasons and proof call/time totals. Fallback tick counts × 0.1 give attributed simulated seconds (fractional last ticks need the usual duration cap). Numerical trial rejections do not consume simulated time. These disjoint primary buckets are sensitive to guard precedence.

`resource_flow_diagnostics.gd` is an **opt-in survey**, excluded from throughput results. It retains the unchanged baseline primary reason and separately samples overlapping blockers at every rejected guard call. Consumer IO, near-empty inputs, discrete outputs, dynamic modifier types, active cycles and environmental sources are distinguished. Coexisting blockers are not added together as lost coverage. `resource_flow_survey.json` preserves the raw survey.

In the 120-second mixed fixture the old runner rejects all 1,200 ticks for `prestige_currency_exposure`. At 120 rejected guard samples, secondary blockers include the active Forge cycle, Mite and furnace/compressor consumption, discrete Condensation Matter and compressor Nexum output, and Mite consumption whose inspected controller has no generic metadata contract. Input-starvation indicators occur for 116–119 of those samples for several consumers; dynamic Matter/Ash/Essence modifiers occur in 119 samples. Heat leak appears in 3 samples and Matter decay into Heat in 1. Thus eliminating the generic consumer rejection alone cannot recover this fixture: prestige, discrete outputs and cycles independently remain blockers. The final runner takes the cheap existing prestige gate first, avoiding unnecessary new proof work here.

The isolated fixtures distinguish lost coverage from rate coupling, exhaustion, environmental regime uncertainty, dynamic costs, automatic unlocks, initial automation transitions and possible purchases. Full primary reason counts, accepted/rejected trials, rejected fields and integration/proof/boundary overhead remain in the raw result files. Diagnostic wall times are not pooled into benchmark medians.

## Conservative bounding strategy and implementation

Select the smallest provable capability: invariant continuous rates, positive input reserves, no environmental activity anywhere in the box, and no intervening discrete changes. `resource_flow_bounds.gd` constructs a dependency set from active IO. For applicable input/output modifiers, known dynamic resource formulas require an unchanging dependency; dynamic generator-level formulas require the inherited no-event guard. Dynamic sensitivities receive the same treatment. Transfer outputs bypass the irrelevant production-modifier graph exactly as production code does. Unknown formulas fail closed. No definitions or modifiers are cleared for eligibility.

Using actual production/input getters, sum nonnegative finite gross rates `P[r]`, `C[r]`. For horizon `H`, resource `r` starts at `A[r]`:

- Lower bound: `L[r] = A[r] - H*C[r] - padding`.
- Upper bound: `U[r] = A[r] + H*P[r] + padding`.

No replenishment is credited to the lower bound, and no consumption is credited to the upper bound. With invariant nonnegative rates and inactive environmental effects, every ordered transaction in every reference tick lies inside this gross-flow box, by induction. Require strictly positive reserves for consumed resources and strict upper bounds below both environmental thresholds. Pad outward for floating-point summation using a reference-transaction-count roundoff bound (with a minimum safety margin); reject nonfinite amounts, rates or bounds and horizons whose roundoff bound is not usable. The horizon is **maximum step plus one reference tick**, including the endpoint reference-map probe. It is intentionally not reduced to a guessed exhaustion/affordability time. A full maximum-width box may reject a smaller safe interval; exact simulation is preferable to an unsupported event-time estimate.

Recompute proof on every guard. The inherited consumer rejection now has a default-deny hook; only the new subclass overrides it following a successful proof. Consumed resources join the inherited changing-resource set so automatic upgrades cannot be incorrectly declared invariant. Parent guards still require settled operating/throttle/discovery/logging state, no active/auto cycles, no discrete outputs, no exposed prestige and no possible purchases. Existing source-free automation bounds conservatively account for potential Matter-to-Heat conversion. Consumers still execute inside actual reference-map probes; they are never omitted from the simulation.

### Environmental bounds investigated, not implemented for consumers

For a proven invariant production envelope, ignoring environmental sinks gives `Matter ≤ M0 + Pmatter*H`. Matter decay is monotone in nonnegative stock above threshold with fixed realm/upgrade parameters; its per-tick loss is at most the actual decay formula evaluated at that gross upper stock, multiplied by the reference step and clamped to available stock. A conservative Matter lower envelope could subtract that bounded loss as well as all inputs. Total decay Heat cannot exceed initial Matter plus all Matter production; this supplies a coarse Heat upper envelope **only when generator Heat production itself is enclosed**. Changing Matter boosts to Heat require interval-evaluated modifiers and sensitivity composition, not the initial Heat rate.

The current Heat branch also depends on tick-start/post-generator Heat and net production, and switches to its implicit substep solver when stiff. A sink-only envelope does not enclose intermediate peaks, overflow statistics, solver branch behavior or reference-map error by itself. Implementing a general environmental/consumer bound was not justified by the available metadata and measured blockers. The safe initial class proves both effects remain zero. Existing producer-only environmental feedback support remains unchanged.

### Explicitly unsupported

Changing resource-dependent production/input/sensitivity formulas; unknown formulas; Lava Mites or inactive unlocked consumer transitions; active/auto cycles; discrete outputs; exhaustion within the conservative box; possible Heat-leak/Matter-decay exposure or crossing; possible automatic resource upgrades; potentially affordable autobuyers and dynamic costs; prestige exposure. Lack of proof means authoritative 0.1-second fallback. No production enablement is provided.

## Fixtures and validation

`resource_flow_fixtures.gd` uses existing definitions and formulas, seeded gameplay RNG `123456`, actual mode switching and upgrade-effect reconstruction. Transfer reserves/realm funding are controlled initial conditions, not claimed reachable ordinary-play snapshots. The cycle fixture inherits the established funded stress fixture, including its pre-existing free-activation setup; this is only an exact-fallback/RNG test, never the accepted proof case. The mixed fixture inherits the existing multi-generator automation/cycle setup.

- Transfer: Arcane Compressor expansion consumes Nexum and continuously creates Matter.
- Exhaustion: finite Nexum reserve; accepted early intervals, authoritative partial-operation/exhaustion ticks and subsequent exact fallback.
- Matter modifier: unpaused Atomic Friction; expansion changes Matter and its real Heat boost.
- Heat leak: active Heat producer with initial Heat above the actual threshold, plus transfer flow.
- Matter decay: initial Matter above threshold; actual removed Matter creates Heat.
- Threshold: initial Matter just below threshold and real expansion crosses it.
- Generator wait / upgrade wait: enabled real autobuyers with existing cooldowns/requirements. Generator wait remains conservatively blocked because the old source graph treats any Matter source as potential Heat conversion; upgrade wait has provable immutable blockers.
- Competing: actual purchase competition fixture, original priority and deductions.
- Mixed: multiple consumers, nonlinear dependencies, automation, discrete production and active Forge.
- Cycles: explicit exact fallback with event/crafting/RNG parity.
- Late both: prior optimized waiting control; dynamic cost: exact rejection control.

`resource_flow_tests.gd` adds 49 dense endpoint cases over zero, fractional and longer intervals (`0`, `0.01`, `0.15`, `1.05`, `9.9`, `20.05`, `120.05`), five read-only/invalidation proof checks, and six consecutive fresh experimental intervals alternating a real Matter-dependent producer. The full regression entry point calls this group; a standalone launcher is also provided. This narrowly scoped test registration is the only change outside `tests/experimental/`.

Candidates run before exact reference; the union of **every accepted endpoint** is requested from the 0.1-second reference, in addition to ordinary fixed audits. Tests compare the existing numeric metrics at unchanged absolute `1e-8`, relative `1e-4` requirements and require exact discrete signatures, purchase ticks/costs/order, RNG and projected reward. Signatures include inventory/crafting state, output progress, modes/unlocks, automation timers/wait caches and gameplay events. All available run/lifetime/offline production, consumption, losses, peaks and reward accumulators are compared. Production has no independent per-generator accumulated-flow counters; real input/output getters and aggregate accounting are exercised. No tolerances were widened. The inherited step-doubling estimator is a numerical error estimator, not a formal global accuracy certificate; dense reference comparisons remain mandatory.

## Serial benchmark results

All throughput rows use three serial repeats with fixed seeds and dense accepted-endpoint audits. Candidate order alternates; the exact reference runs last to audit the union of accepted endpoints. No benchmark ran alongside validation in the retained final batches. Timings include runner/audit overhead, so very short differences are noisy. Paired speedups are medians of per-repeat ratios, not ratios of column medians. The old runner retains the `e64ad63` algorithm: the new default-deny hook returns at the original consumer rejection; its extra changing-input code is unreachable in that baseline. New capability is enabled only by the separate subclass.

| Fixture / duration | Exact median s | e64 algorithm median s | New median s | Paired exact/new | Paired old/new | New coverage | Max normalized sampled error |
|---|---:|---:|---:|---:|---:|---:|---:|
| transfer / 120s | 0.069 | 0.072 | 0.033 | 2.02× | 2.13× | 99.167% | 2.12e-10 |
| exhaustion / 120s | 0.065 | 0.070 | 0.077 | 0.87× | 0.88× | 21.167% | 3.9e-11 |
| matter_modifier / 120s | 0.083 | 0.095 | 0.087 | 0.95× | 1.13× | 0.000% | 0 |
| heat_leak / 120s | 0.142 | 0.135 | 0.138 | 1.03× | 1.01× | 0.000% | 0 |
| matter_decay / 120s | 0.073 | 0.077 | 0.079 | 0.93× | 0.98× | 0.000% | 0 |
| threshold / 120s | 0.094 | 0.104 | 0.128 | 0.76× | 0.81× | 0.000% | 0 |
| generator_wait / 120s | 0.078 | 0.087 | 0.105 | 0.84× | 0.90× | 0.000% | 0 |
| upgrade_wait / 120s | 0.164 | 0.167 | 0.040 | 3.83× | 4.10× | 90.833% | 2.11e-10 |
| competing / 120s | 0.095 | 0.099 | 0.107 | 0.91× | 1.02× | 0.000% | 0 |
| mixed / 120s | 0.618 | 0.619 | 0.627 | 0.98× | 1.01× | 0.000% | 0 |
| cycles / 120s | 0.123 | 0.123 | 0.125 | 0.94× | 1.03× | 0.000% | 0 |
| late_both / 120s | 0.164 | 0.314 | 0.323 | 0.51× | 0.96× | 90.833% | 0.0535 |
| dynamic_cost / 120s | 0.088 | 0.094 | 0.094 | 0.94× | 0.98× | 0.000% | 0 |
| transfer / 3600s | 2.014 | 2.050 | 0.194 | 9.54× | 10.38× | 99.972% | 4.43e-07 |
| late_both / 3600s | 4.437 | 1.261 | 1.324 | 3.48× | 0.96× | 98.833% | 0.0137 |
| transfer / 14400s | 7.562 | 8.014 | 0.718 | 10.83× | 11.55× | 99.993% | 4.43e-07 |
| late_both / 14400s | 16.810 | 3.110 | 3.049 | 5.60× | 0.99× | 99.583% | 0.00504 |

Normalized deviation must be ≤ 1.0 at the unchanged tolerance. Every retained row has exact discrete, RNG and prestige parity and an empty failure list. For supported expansion the resources match exactly in these runs; tiny accumulated statistics/clock differences remain far below tolerance. The accepted class consumes and produces 5 units per second using the existing expansion IO; over four hours this exercises 72,000 Nexum input and 72,000 Matter output, with initial automatic-upgrade/discovery bookkeeping on exact ticks.

| New expansion run | Accepted / rejected trials | Evaluations | Fallback ticks | Proof ms | Autobuyer boundary ms |
|---|---:|---:|---:|---:|---:|
| 3600s (repeat 0) | 71 / 0 | 434 | 10 | 6.437 | 1.248 |
| 14400s (repeat 0) | 251 / 0 | 1514 | 10 | 27.638 | 4.147 |

Complete per-repeat timings, evaluations, checkpoint costs, boundary calls, accepted/rejected intervals, fallback reasons and maximum resource/statistics deviations are retained in `resource_flow_results.json`, `resource_flow_1h.json`, and `resource_flow_4h.json`, with source hashes. `resource_flow_validation.json` retains final clean test commands/output and explicitly unsuccessful full-editor validation.

The exhaustion fixture recovers only about 21% coverage: the maximum-width reserve proof deliberately switches to exact well before depletion. Threshold and generator-wait cases can be materially slower than the previous runner on these short intervals because repeated proofs add overhead without acceptance. The old waiting control has no new flow-proof calls; its one-hour paired timing is about 4.6% slower in this final batch and the four-hour timing about 1% slower. These small samples establish neither a sustained improvement nor a significant slowdown. Keep the negative data rather than claiming universal performance gains. The mixed fixture has zero coverage and no reliable gain; no longer realistic test or 24-hour extrapolation was attempted.

## Regression, compatibility and unsuccessful runs

**87 regression groups passed, 0 failed**, including the new resource-flow group. The focused standalone suite also passed. Final passing regression, focused and benchmark logs contain no parser/runtime warnings or errors. Testing used **Linux Godot 4.6.1**, not Windows Godot 4.7.2. No Windows/editor-play validation is claimed.

The one-CPU editor import/check still reports `game.gd:771` (“Expected statement, found Indent”), and an optimized-translation `bucket_table_size == 0` import error. These are outside scope and were not fixed. Editor exit code 0 was not treated as success. An import-generated tracked CSV-import rewrite was restored; unrelated initial untracked content was preserved.

Discarded development attempts: the first unrestricted import crashed and lacked imported assets; an available import cache then enabled standalone validation. A conditional typed-array assignment caused a harness runtime failure; it was corrected. A cycle fixture initially reused a logger without the tick-clock capability and was corrected. Proof unit tests initially sampled before the real Matter automatic unlock had settled; they were fixed to settle on reference ticks. Repeated-interval testing now uses fresh supported TimeManager contexts while retaining the actual simulation state. Preliminary timings overlapping regression work were stopped and replaced by the final serial batches. None of these runs contribute to the final medians. Initial reports/measurements were inspected again against current source.

## Bottlenecks and next step

This class proves production and consumption coexist safely in a real continuous converter. It does not yet accept a separate Heat producer coupled to its Matter-producing consumer: that interaction changes Thermic Mass, so it is covered by an exact-fallback fixture. Likewise, realistic Condensation/compression introduce discrete outputs, and Mites introduce controller state. The conservative existing purchase proof also over-approximates potential Matter-to-Heat conversion, blocking some otherwise harmless generator waits.

The next useful experimental target is the actual two-generator expansion + Atomic Friction fixture: enclose Matter’s monotone held-amount Heat modifier over a proven Matter box, including sensitivity composition, while keeping environmental regimes, purchases and automatic effects exact. This is a small explicit formula capability, not a symbolic solver or a constant-rate guess. It should first demonstrate endpoint/error and event parity at resource/upgrade boundaries. Before widening to realistic cycles/Mites, expose read-only dependency/capability descriptors for hardcoded controllers and reference numerical regimes; IO metadata alone cannot certify them. Keep production offline simulation unchanged until broader reachable-save coverage and numerical enclosures justify enabling any path.

## Reproduce

```text
godot --headless --path . --script tests/run_regression_tests.gd
godot --headless --path . --script tests/experimental/run_resource_flow_tests.gd
python tests/experimental/run_resource_flow.py --godot GODOT --repeats 3
python tests/experimental/run_resource_flow.py --godot GODOT --scenarios transfer,late_both --duration 3600 --repeats 3 --output tests/experimental/resource_flow_1h.json
python tests/experimental/run_resource_flow.py --godot GODOT --scenarios transfer,late_both --duration 14400 --repeats 3 --output tests/experimental/resource_flow_4h.json
godot --headless --path . --script tests/experimental/resource_flow_benchmark.gd -- --scenario=mixed --duration=120 --survey=true
```

The driver bounds each subprocess at 600 seconds and rejects warning/error output, nonzero exit codes, missing results or validation failures. Short-duration exact policy is disabled only inside this explicit experiment. Production settings and save fields are unchanged.

## Core-gameplay investigation follow-up

See [CORE_GAMEPLAY.md](CORE_GAMEPLAY.md) for the recovered progression witness, replay-verified early/mid/Forge fixtures, simultaneous blockers, diagnostic ablations and real completion-boundary tests. It demonstrates why the restricted Nexum result does not generalize. No new core eligibility exception is enabled; the report provides the measured architectural alternative and a concrete transactional-state/clock/phase proposal.
