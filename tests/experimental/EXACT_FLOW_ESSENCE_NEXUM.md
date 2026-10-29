# Exact ordered kernel: Essence and Nexum

Base `0a008c0c3d69c0011e2fe9656ffaf31febd9546f`, branch `feature/cycle-auto-run`. Experimental synchronous core only; no production integration, approximation, speculative checkpointing or balance changes.

## Audited production mechanics

Authority: `game_state.gd` registration/setters/accounting; `Resources/resource_state.gd`; `Game/save_manager.gd`; `simulation/simulation.gd` update, consume_inputs, produce_outputs, environmental and cycle methods; `Generators/generator.gd` input/production/mode APIs; AtomicFriction, LavaMiteColony, ThermalCompressor and cycle factories; UpgradeRegistry; Modifier/ModifierSensitivity; both automation managers; relic generation and inventory code. Existing kernel/consumer/automation/cycle reports and regression assertions were inspected before editing. HEAD was the requested commit; unrelated untracked assets/UIDs were preserved.

All six native resources use the same registered ResourceState storage, initialized to zero. Save/load iterates registered resource IDs, with the existing historical CF spelling migration; Essence/Nexum have no special persistence representation. Native setters discover positive stock and update lifetime/run peaks. Production/consumption recording updates lifetime/run and optional simulation statistics, with interval accounting disabled by offline updates. There is no Essence/Nexum capacity clamp or passive decay. Environmental processing affects Matter and Heat only.

| Resource | Native producers | Native consumers | Feedback and boundaries |
|---|---|---|---|
| Essence | Atomic Friction intensified mode: 0.0001/sec/level, continuous; unlocked Mite output: 0.0005/sec/level, discrete | Compressor compression: 100/sec/level; purchase of intensified mode (100), Ash adaptation (25), retention (25 base), stabilization (250 base) | Automatic Influence/Accumulation require held Essence >=1 at next tick header; Ash scaling above100; accumulation and sensitivities described below |
| Nexum | Compressor compression: 1/sec/level, discrete | Compressor expansion: raw1 × mode input5 × level per second | No native Nexum-dependent modifier, threshold, capacity, decay or thermal bonus. Positive stock contributes discovery/statistics; spending returns native Matter output |

Compression's ordered inputs are Matter5000 then Essence100 per second per level. It is **ordinary production**, not a transfer mode. Its Nexum output receives ordinary production modifiers, including any applicable global penalties. Its amount is floored only through the native fractional output accumulator; no conversion is rounded at input spending. Compression may therefore spend resources before a whole Nexum is emitted, and input shortage limits operating duration.

Expansion is explicitly a **resource transfer**: its input is Nexum1 with input multiplier5. Input modifiers are bypassed. Its output rate is `(first input raw amount × level scale) × input multiplier`, irrespective of the output's nominal amount, production multiplier, realm bonuses, production modifiers or sensitivities. Its factory Matter output is continuous. Thus native expansion yields **one Matter per Nexum consumed**, not5,000; the experiment preserves the actual source, not a presumed inverse. No production-modifier cache is populated by transfer evaluation. Multiple inputs/outputs in a transfer diagnostic follow the same native first-input output rule; no conservation generalization is invented.

Relic Crucible's extraction description mentions “essence”, but its native outputs are inventory Relic Shards, not ResourceIds.ESSENCE. Recycle/combine/random relic crafting are inventory paths. The “Essence-Touched” relic affix alters Crystallization sensitivity; it is not another resource producer. Equipped relic effects and all inventory crafting remain independently refused. Production Forge has no Essence/Nexum IO; native resource-only cycle support now accepts registered Essence/Nexum inputs/rewards, tested by explicitly synthetic IO additions, without claiming new production Forge recipes.

## Ordered dependency map

Native registration: Atomic Friction → Molecular Agitation → Lava Mites → Infernal Condensation → Matter Furnace → Thermal Compressor → Infernal Forge → Relic Crucible. All ordered structures and original references are retained.

Tick order: start-Heat snapshot/bookkeeping → native automatic upgrades → each unlocked generator's native controller → cycle native path OR continuous startup/availability/ordered consumption/ordered output → Matter decay/Heat conversion → Heat leak → generator autobuyers → upgrade autobuyers → offline bookkeeping.

Availability evaluates each input against pre-consumption stock. Consumption then reevaluates rates sequentially after earlier writes. Outputs evaluate after all input consumption and sequentially after earlier outputs. Partial duration, startup positive-stock checks, epsilon shutdown and integer-floor/remainder association are unchanged. The single-input path reuses a rate only where no resource mutation intervenes.

| Dependency | Evaluation lifetime / action |
|---|---|
| Base IO, mode multiplier, level scale, static modifiers and static sensitivity | Constant within exclusive packet; rebuild at public call/purchase/configuration boundary |
| Essence production by Atomic Friction | Earlier same-tick write, visible to Mite controller/input rates and later output modifiers |
| Mite Heat/Ash draw | Native controller and native input APIs; Influence adds `1 + .01*sqrt(Essence)` to INPUT_DRAW with target empty (both inputs); throttling suppresses applicable Ash escalation, not Essence feedback |
| Essence Influence → Crystallization sensitivity | Native dynamic inverse sqrt `1/(1+.01*sqrt(Essence))`; native special power penalty evaluation retained |
| Essence Accumulation | Native inverse sqrt penalty above configured/fallback threshold0, coefficient .09, targeting Essence output; output reads current held Essence, including earlier outputs |
| Retention/Stabilization | Native .92/.95 sensitivity factors per purchased level; purchases invalidate after automation; next tick uses rebuilt tapes |
| Mite Ash adaptation | Native power-threshold formula above Ash100, strength .25/exponent .5; post-input Ash affects output in same operation |
| Compression spending Essence | Later same-tick Forge modifier evaluation observes reduced stock; earlier generator production changes next tick; no balance cache |
| Expansion adding Matter | Later Forge sees Matter; native environmental decay subsequently converts Matter into Heat, affecting automation affordability |
| Nexum-driven feedback | None in current production definitions; diagnostic dynamic resource effects validate generality without claiming native Nexum feedback |
| Automatic upgrades at Essence1 | Existing live header check releases packet, executes full native tick, rebuilds before next tick |
| Forge resource changes/completion | Native cycle at registration position; live balance-dependent tapes remain live; own level change invalidates after tick |
| Relics, external clock/UI/disk callbacks, unreviewed active cycles | Explicit fallback; not admitted by adding resource support |

Formula calculations are delegated to the original Modifier/ModifierSensitivity methods. A static modifier with a dynamic sensitivity stays in the dynamic suffix. Multiplication ordering is not algebraically regrouped, and no dynamic Essence/Nexum value is evaluated once per interval.

## Implemented resource representation

The existing ordered InputOperation and Output tapes retain original Generator/GeneratorIO/ResourceState references. The output whitelist is replaced by a registered-resource check, after the existing native ResourceState script/finite-balance audit. Unknown output resources still reject. Native modifier/sensitivity script guards stay; only the specific Essence exclusion is removed. No new resource simulation engine or shadow resource dictionary exists.

For transfer inputs, a constant Rate stores `raw × mode input multiplier`, followed by the existing final level multiplication. Transfer outputs store `(first raw input × level) × input multiplier` and bypass ordinary modifier/cache construction. This is data driven from `is_resource_transfer` and IO order, with no Compressor ID in the flow loop. Ordinary production retains its original fast path and Heat/Matter native realm specialization. Cycles retain the reviewed native adapter; only registered resource input/output restrictions are generalized. Inventory/event/RNG/custom-script guards remain intact.

Instrumentation chooses a MeasuredRate subclass at construction only in separate diagnostic executions. Normal Rate has no additional per-evaluation counter or measurement branch. Tape evaluation and dynamic suffix counts omit native Mite/cycle evaluations and transfer constant rates; native profiler rate call counts supply complementary evidence. These are not claimed as a complete hardware-operation count.

## Identity and invalidation

Packets never own copied balances/phases/configuration and never replace shared objects. No new object is allocated in the normal per-tick resource loop. Normal resource changes, exhaustion, recovery, thresholds and dynamic feedback do not reconstruct packets. Public run boundaries release all packet references; caller mode/pause/IO/modifier/level edits are observed by the next build.

Native generator/upgrade purchases retain cooldown/waiting/priority/callback semantics and invalidate through the existing owned purchase-log witness after environmental processing. Automatic upgrades remain native header boundaries. Forge net level changes invalidate after the native cycle call/tick. Native completion-only resource writes need no rebuild. No full-state fingerprint or structural signature is performed in optimized ticks. Fingerprints and numerical comparisons exist only in validation, outside throughput timing.

Old tests asserting Essence unlocks or transfer flags must always fall back now assert positive execution, without changing byte-equality checks. Independent fallback/resumption tests use the existing unsupported prestige boundary. Cycle rejection still tests unregistered resource outputs. All previously registered regression groups remain present.

## Fixture provenance

Existing early, consumer, mid and original Forge saves are unchanged. `essence_nexum_progression_builder.gd` starts from the prior **earned** `automation_progression.json: settled` save and pays native permanent Essence/Compressor technology costs, retaining its enabled buyers. It refreshes realm effects after those purchases exactly as the native prestige panel does. Its ledger records native purchases and legal pause/mode actions. No resource/upgrade/level grants or removal of an existing unsupported mechanic is used to advertise coverage. Pausing Matter Furnace is an explicit player policy to conserve Matter; condenser/Mites/buyers remain active.

A bounded400,000-tick exploration earned Essence extraction, Ash adaptation and retention but did not earn the25,000-Matter Compressor unlock. Its action/save manifest is retained in `essence_nexum_exploration.json`, including the optional unmet goals. This is not proof of global unreachability. The reproducible shorter160,000-tick builder requires Essence and records optional unmet Compression/Nexum/Expansion goals separately. New earned fixtures are Essence/feedback, not mature-game Nexum claims.

Other fixtures are explicitly diagnostics: granted technologies/upgrades/stocks, synthetic sequential resource consumer/modifiers and resource-only Forge IO probes. Compression, Expansion, mixed feedback, mode changes and stress throughput are diagnostic performance evidence only. No earned Nexum or relic-equipped speedup is claimed.

## Validation contract

Dedicated tests compare detailed binary resource/runtime/configuration/phase/automation/cache/statistics/event/RNG views against native Simulation.update(0.1,true) **after every tick**, and against the archived0a008c0 kernel (which uses exact fallback on new resources). Initial packet construction is checked read-only with the original identity-aware whole-graph fingerprint; endpoints also require full-graph equality. Boundary probes compare the full graph after every tick, including depletion/recovery, mode switches, native purchase, modifier edits, Ash threshold, explicit unsupported fallback and resumption. No numerical tolerances are introduced.

Witnesses cover real Essence integer outputs and feedback upgrade activation, exact first-tick exhaustion, fractional Nexum output, sequential Essence draw affecting subsequent Nexum consumption, ignored transfer modifiers/cache bypass, native Essence upgrade purchase, Forge completion with simultaneous resources, and native resource-only cycle consumption/rewards. Existing Forge critical/RNG and transaction rollback groups remain registered.

## Benchmark methodology

Archive packet/kernel/cycle contract from0a008c0; only archive preload paths change. The same engine, host, deterministic fixtures and method cadence compare native, archived/current public and isolated, and the existing adaptive reference. Four repetitions alternate method order; warmup excluded, medians and min–max over three measured samples. Public timings include builds, releases, invalidation/rebuilds, native calls/accounting/automation and fallback. Exact endpoint fingerprints and numerical/discrete/RNG checks run outside timing; all non-adaptive methods must be byte equal.

Mode-change throughput uses identical legal changes between20-tick public calls, with no hidden exact replay; this synchronization scenario reports the four public/native/reference methods only. Other isolated rows omit initial/reconstruction build times explicitly. Separate diagnostic runs enable intrusive clocks/counters, native cycle probe and native profiler. They verify endpoint parity but are excluded from throughput medians. Native subphase times overlap and cannot be summed. Static allocation deltas are retained-packet estimates, not exact heap/peak/RSS or total allocation traffic. There is no checkpoint cost.

Reproduce serially from the repository root:

```sh
python tests/experimental/run_essence_nexum.py --godot /path/to/godot --mode fixtures
python tests/experimental/run_essence_nexum.py --godot /path/to/godot --mode tests
python tests/experimental/run_essence_nexum.py --godot /path/to/godot --mode benchmark
python tests/experimental/run_essence_nexum.py --godot /path/to/godot --mode regression
python tests/experimental/summarize_essence_nexum.py
```

The wrapper rejects nonzero exit, parser warnings and runtime errors. The optional negative exploration manifest records an unmet gameplay goal, not a validation error; reproduce it with RESOURCE_PROGRESS_EXPLORE=1 in fixture mode. Environment/raw samples/logs are stored alongside this report. Linux Godot4.6.1 validation does not establish Windows Godot4.7.2 compatibility.

## Remaining scope

Relic inventory/equipment and Crucible crafting, unreviewed active cycles, custom callbacks/scripts and external TimeManager/runner/UI/filesystem effects remain unsupported. General resource transfer is now admitted only under the existing isolated synchronous native contracts. There is no multi-tick batching or production integration. Additional resource types using registered native ResourceState and the same IO/modifier semantics need no whitelist edit; novel environmental/controller/event semantics still require explicit audit.

Performance assessment and next-step recommendation follow the measured tables below; no full-game acceleration claim follows from the diagnostic rows.

## Verified results and performance assessment

The original baseline passes95 groups; the final full regression passes **96 groups, zero failures** and retains every prior registered group. All retained and new validation logs contain no parser warnings or runtime errors. The full-suite execution writes the dedicated validation manifest: **11,800 named per-tick comparisons**, also compared against archived0a008c0; **65 full-graph reentry ticks** and **10 full-graph cycle-resource ticks** supplement these. Actual initial Essence and Nexum discovery transitions are asserted. Discrete phases, all numerical state, RNG, events and complete endpoint graphs match exactly; no tolerance was introduced.

Matched main benchmarks pass **344/344** non-reference archived/current public/isolated byte comparisons. The separate confirmation adds **72/72**, for **416/416** checks including warmups. Adaptive remains a separately measured reference. All exact numerical error fields are zero, with binary equality also covering production phases.

The same-run long public-core speedups versus native are early36,000 **1.814×**, consumer10,000 **1.480×**, original mid10,000 **1.403×**, original Forge10,000 **1.372×**. The two earned Essence10,000 fixtures measure **1.521× /1.452×**, with **100%** kernel ticks, enabled native buyers and20,000 partial operations each. They are actual resource-starved feedback gameplay, not an artificially funded steady state. Native resources, statistics and automation still execute every tick. Original mid coverage is99.98%; early/consumer/Forge coverage100% at these lengths.

New diagnostics measure **1.228×** compression, **1.308×** expansion, **1.988×** mixed resources and **1.411×** frequent mode changes versus native. Most new diagnostic intervals have one automatic-header native tick, giving99.95% at2,000 or99.99% at10,000. These figures are not mature-game Nexum performance claims. The original high-Ash compression diagnostic emits **zero** whole Nexum before exhaustion; the low-Ash diagnostic emits a real whole Nexum from zero phase, while the near-integer phase probe separately validates its boundary. Both retain native decay and feedback. Large Matter funding alone was not a valid solution: native decay can remove the entire stock in one tick. Neither output counts nor the earned-fixture goal were relaxed to force success.

Main-run regressions versus archived0a008c0 are explicitly retained: consumer2,000 **+14.89%**, consumer10,000 **+7.48%**, mid2,000 **+2.45%** runtime. Consumer2,000 extended samples span303–611ms, while its isolated medians are essentially equal (321.839 vs321.976ms). Construction adds less than1ms in ordinary one-build intervals. Source comparison confirms that Packet.step, startup/availability helpers and public Kernel.run method bodies are byte-identical to the base; Rate.evaluate has no new hot-path branch. Ordinary packet retained estimates are equal, including20,496bytes for consumer. The changes are construction/validation/transfer tapes and opt-in diagnostics, not additional ordinary-tick calculations.

A serial confirmation with one warmup and **five measured repeats** keeps the same engine/fixtures/method order. Its consumer medians change **−1.83%** at2,000 and **+1.13%** at10,000 versus the previous kernel; native speedups are1.630× and1.575×. Its ranges still contain large outliers (long extended1.359–2.393s). Thus the original large slowdown is not stable evidence of a generalization cost. A small consumer-long overhead remains possible; no claim of universal improvement over0a008c0 or statistical significance is made. All original samples remain in the report/raw files, alongside confirmation.

Packet retained allocation estimates range roughly**15–39KiB** for the new single-packet diagnostics/earned states, excluding existing shared state and code. Earned-feedback10,000 needs one build: measured public construction831µs and release74µs, already included in its wall time. Mixed10,000 has16 builds/14 structural invalidations, with12,208µs public build time. Frequent mode changes cause117 builds across100 public calls,16 purchase invalidations and one header boundary:73,777µs public construction plus4,149µs release. Resource updates alone cause no rebuild. These costs are measured; they are not checkpoint timings or exact total heap allocation.

Separate intrusive native profiles place most cost in ordered generator processing. In earned-feedback, generator processing is4.800s and upgrade automation1.671s, versus environmental processing0.335s; production/input rate calculation subsets are1.229/0.484s. These instrumented totals overlap and have timer overhead; they do not decompose the public wall-clock medians. The controller's repeated native input/modifier checks, native accounting and waiting upgrade scans remain significant. Packet reconstruction is not the ordinary long-interval bottleneck. There is no justification here for speculative batching or another resource engine.

Canonical save-loaded scope diagnostics (`transfer`, `mixed`, `essence`, `late_both`) now execute9/10 ticks through the kernel, with one legitimate native automatic header and exact endpoints. These are diagnostics, not earned performance fixtures. The inventory/crafting save remains0/10: relic inventory and its active unreviewed Relic Crucible are independent blockers. Relic equipment/crafting and external TimeManager integration remain outside the supported contract; no Windows compatibility is inferred from this Linux run.

## Recommended next milestone

Audit **read-only relic inventory/equipment and native modifier dependencies**, retaining native fallback for Crucible crafting until a separate reviewed completion/inventory contract exists. This is the next concrete independent blocker exposed by the scope survey. Keep the exact ordered core and native automation/cycle paths; no new clock adapter is required just to run these resource flows synchronously.

Separately improve the earned progression policy before advertising Nexum-stage acceleration: the recorded policy spends its available permanent currency on technologies and stalls around9,265 Matter below the25,000 unlock. A native continuation with more earned prestige currency and an audited density/production allocation is a concrete fixture-construction experiment, not an implemented capability or a proof that the current goal is unreachable. Measure native waiting-upgrade scans and repeated dynamic input evaluation before proposing further throughput changes.

## Changed-file manifest

All38 files are experimental infrastructure or regression registration; no production file changes.

```text
tests/experimental/EXACT_FLOW_CYCLES.md
tests/experimental/EXACT_FLOW_ESSENCE_NEXUM.md
tests/experimental/automation_kernel_tests.gd
tests/experimental/baselines/exact_flow_0a008c0_cycles.gd
tests/experimental/baselines/exact_flow_0a008c0_kernel.gd
tests/experimental/baselines/exact_flow_0a008c0_packet.gd
tests/experimental/consumer_tests.gd
tests/experimental/cycle_kernel_tests.gd
tests/experimental/essence_nexum_baseline_regression.log
tests/experimental/essence_nexum_benchmark.gd
tests/experimental/essence_nexum_benchmark.log
tests/experimental/essence_nexum_benchmark_results.json
tests/experimental/essence_nexum_confirmation.log
tests/experimental/essence_nexum_confirmation_results.json
tests/experimental/essence_nexum_confirmation_summary.json
tests/experimental/essence_nexum_environment.json
tests/experimental/essence_nexum_exploration.json
tests/experimental/essence_nexum_exploration.log
tests/experimental/essence_nexum_fixtures.gd
tests/experimental/essence_nexum_fixtures.log
tests/experimental/essence_nexum_progression.json
tests/experimental/essence_nexum_progression_builder.gd
tests/experimental/essence_nexum_regression.log
tests/experimental/essence_nexum_scope.log
tests/experimental/essence_nexum_scope_audit.gd
tests/experimental/essence_nexum_scope_audit.json
tests/experimental/essence_nexum_summary.json
tests/experimental/essence_nexum_tests.gd
tests/experimental/essence_nexum_tests.log
tests/experimental/essence_nexum_validation.json
tests/experimental/exact_flow_cycles.gd
tests/experimental/exact_flow_kernel.gd
tests/experimental/exact_flow_packet.gd
tests/experimental/exact_flow_tests.gd
tests/experimental/run_essence_nexum.py
tests/experimental/run_essence_nexum_tests.gd
tests/experimental/summarize_essence_nexum.py
tests/run_regression_tests.gd
```

<!-- MEASURED_RESULTS -->

## Measured results

Milliseconds below are medians of three measured runs; one preceding warmup per method/scenario is excluded. Ranges are measured min–max, not confidence intervals.

| Fixture / ticks | Native ms | Previous public ms | Extended public ms | Adaptive reference ms | Speedup vs native | Kernel coverage |
|---|---:|---:|---:|---:|---:|---:|
| early / 2000 | 339.046 | 173.147 | 166.728 | 353.594 | 2.034× | 100.000% |
| early / 36000 | 6643.209 | 3740.425 | 3662.237 | 7083.646 | 1.814× | 100.000% |
| consumer_50000 / 2000 | 471.531 | 296.471 | 340.610 | 501.269 | 1.384× | 100.000% |
| consumer_50000 / 10000 | 2338.332 | 1469.826 | 1579.777 | 2501.431 | 1.480× | 100.000% |
| mid / 2000 | 370.102 | 262.497 | 268.940 | 407.582 | 1.376× | 99.900% |
| mid / 10000 | 2171.242 | 1551.457 | 1547.664 | 2247.470 | 1.403× | 99.980% |
| forge_competing / 2000 | 1057.149 | 800.688 | 793.898 | 1134.285 | 1.332× | 100.000% |
| forge_competing / 10000 | 6596.813 | 4830.001 | 4806.875 | 7097.223 | 1.372× | 100.000% |
| essence_only / 2000 | 421.405 | 339.106 | 209.280 | 342.871 | 2.014× | 99.950% |
| essence_feedback / 10000 | 3503.851 | 3520.522 | 2177.487 | 3713.927 | 1.609× | 99.990% |
| compression / 2000 | 202.772 | 201.940 | 165.143 | 244.028 | 1.228× | 99.950% |
| compression_low_ash / 2000 | 255.512 | 228.803 | 163.255 | 230.639 | 1.565× | 99.950% |
| compression_phase / 2000 | 212.472 | 212.129 | 158.481 | 229.879 | 1.341× | 99.950% |
| expansion / 2000 | 246.645 | 244.072 | 188.631 | 276.769 | 1.308× | 99.950% |
| mixed_resources / 10000 | 3934.980 | 3811.091 | 1979.367 | 3801.274 | 1.988× | 99.990% |
| forge_resources / 2000 | 660.886 | 665.980 | 377.492 | 703.606 | 1.751× | 99.950% |
| sequential_feedback / 2000 | 353.414 | 341.252 | 221.213 | 371.548 | 1.598× | 99.950% |
| feedback_stress / 2000 | 701.866 | 692.343 | 396.196 | 739.352 | 1.772× | 99.950% |
| compression_partial / 2000 | 215.070 | 218.013 | 165.665 | 246.245 | 1.298× | 100.000% |
| mode_changes / 2000 | 731.235 | 929.341 | 518.269 | 13.121 | 1.411× | 99.950% |
| earned_essence / 10000 | 4732.263 | 4669.397 | 3111.584 | 4713.235 | 1.521× | 100.000% |
| earned_feedback / 10000 | 4693.653 | 5188.684 | 3232.048 | 4923.000 | 1.452× | 100.000% |

| Fixture / ticks | Previous public range ms | Extended public range ms | Runtime change vs previous | Previous isolated ms | Extended isolated ms | Previous / extended retained packet bytes (estimate) |
|---|---:|---:|---:|---:|---:|---:|
| early / 2000 | 161.648–178.060 | 161.384–174.993 | -3.71% | 179.582 | 194.585 | 23604 / 23604 |
| early / 36000 | 3603.410–3867.643 | 3585.317–3693.988 | -2.09% | 3561.579 | 3637.100 | 23604 / 23604 |
| consumer_50000 / 2000 | 295.498–316.593 | 303.344–610.597 | +14.89% | 321.976 | 321.839 | 20496 / 20496 |
| consumer_50000 / 10000 | 1458.182–1563.918 | 1489.477–1745.445 | +7.48% | 1453.518 | 1480.590 | 20496 / 20496 |
| mid / 2000 | 258.788–265.945 | 268.482–274.795 | +2.45% | 257.244 | 261.537 | 23676 / 23676 |
| mid / 10000 | 1517.489–1553.959 | 1543.154–1567.533 | -0.24% | 1534.196 | 1553.420 | 23676 / 23676 |
| forge_competing / 2000 | 789.620–1188.500 | 785.435–1327.040 | -0.85% | 790.878 | 788.741 | 35508 / 35508 |
| forge_competing / 10000 | 4796.534–4877.625 | 3851.600–5528.677 | -0.48% | 5081.136 | 6078.343 | 35508 / 35508 |
| essence_only / 2000 | 311.127–476.008 | 209.094–276.383 | -38.28% | 329.477 | 226.157 | 0 / 15084 |
| essence_feedback / 10000 | 3502.673–3621.808 | 2133.609–2232.028 | -38.15% | 3579.300 | 2133.385 | 0 / 30996 |
| compression / 2000 | 188.769–243.988 | 158.297–217.135 | -18.22% | 213.786 | 153.393 | 0 / 19444 |
| compression_low_ash / 2000 | 204.767–311.282 | 161.268–169.816 | -28.65% | 267.657 | 178.538 | 0 / 19444 |
| compression_phase / 2000 | 204.174–213.003 | 158.364–165.424 | -25.29% | 209.046 | 163.366 | 0 / 19444 |
| expansion / 2000 | 240.607–260.417 | 178.732–189.673 | -22.72% | 245.149 | 201.089 | 0 / 17252 |
| mixed_resources / 10000 | 3510.744–4947.807 | 1930.507–2046.464 | -48.06% | 3599.300 | 1990.105 | 0 / 37628 |
| forge_resources / 2000 | 653.891–671.771 | 375.367–399.519 | -43.32% | 660.061 | 366.184 | 0 / 39080 |
| sequential_feedback / 2000 | 336.856–368.046 | 218.989–227.023 | -35.18% | 343.566 | 225.355 | 0 / 25424 |
| feedback_stress / 2000 | 683.202–725.518 | 394.935–397.916 | -42.77% | 701.862 | 396.169 | 0 / 37628 |
| compression_partial / 2000 | 214.063–218.036 | 164.449–174.315 | -24.01% | 219.043 | 156.075 | 0 / 19444 |
| mode_changes / 2000 | 733.898–1051.058 | 510.062–794.781 | -44.23% | n/a | n/a | n/a |
| earned_essence / 10000 | 4602.813–6282.136 | 3071.630–3205.355 | -33.36% | 4659.781 | 3165.607 | 0 / 29512 |
| earned_feedback / 10000 | 4827.444–5980.570 | 3200.418–3279.697 | -37.71% | 4725.771 | 3261.819 | 0 / 29512 |

Construction/release clocks already present in measured public runs (medians of three, included in public wall time):

| Fixture / ticks | Public build µs | Public release µs |
|---|---:|---:|
| early / 2000 | 603 | 53 |
| early / 36000 | 546 | 60 |
| consumer_50000 / 2000 | 863 | 59 |
| consumer_50000 / 10000 | 560 | 56 |
| mid / 2000 | 1781 | 114 |
| mid / 10000 | 1622 | 126 |
| forge_competing / 2000 | 770 | 246 |
| forge_competing / 10000 | 1670 | 155 |
| essence_only / 2000 | 892 | 89 |
| essence_feedback / 10000 | 1094 | 73 |
| compression / 2000 | 665 | 64 |
| compression_low_ash / 2000 | 1206 | 71 |
| compression_phase / 2000 | 939 | 67 |
| expansion / 2000 | 1107 | 63 |
| mixed_resources / 10000 | 12208 | 633 |
| forge_resources / 2000 | 1169 | 79 |
| sequential_feedback / 2000 | 871 | 73 |
| feedback_stress / 2000 | 1124 | 147 |
| compression_partial / 2000 | 416 | 57 |
| mode_changes / 2000 | 73777 | 4149 |
| earned_essence / 10000 | 794 | 111 |
| earned_feedback / 10000 | 831 | 74 |

Separate intrusive phase-clock runs (excluded from throughput medians):

| Fixture / ticks | Kernel / native ticks | Builds (rebuilds = builds − 1) | Structural invalidation ticks | Automatic header ticks | Build µs total | Release µs total | Kernel µs total | Native µs total | Kernel cycle µs | Cycle invalidations |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| early / 2000 | 2000 / 0 | 1 | 0 | 0 | 645 | 81 | 162117 | 0 | 0 | 0 |
| early / 36000 | 36000 / 0 | 1 | 0 | 0 | 1222 | 88 | 3460171 | 0 | 0 | 0 |
| consumer_50000 / 2000 | 2000 / 0 | 1 | 0 | 0 | 540 | 108 | 291386 | 0 | 0 | 0 |
| consumer_50000 / 10000 | 10000 / 0 | 1 | 0 | 0 | 572 | 140 | 1458501 | 0 | 0 | 0 |
| mid / 2000 | 1998 / 2 | 3 | 0 | 2 | 1748 | 254 | 252532 | 564 | 0 | 0 |
| mid / 10000 | 9998 / 2 | 3 | 0 | 2 | 2321 | 392 | 1525259 | 615 | 0 | 0 |
| forge_competing / 2000 | 2000 / 0 | 1 | 0 | 0 | 1331 | 238 | 814851 | 0 | 131097 | 0 |
| forge_competing / 10000 | 10000 / 0 | 1 | 0 | 0 | 828 | 4355 | 5578200 | 0 | 1069658 | 0 |
| essence_only / 2000 | 1999 / 1 | 2 | 0 | 1 | 945 | 113 | 209902 | 532 | 0 | 0 |
| essence_feedback / 10000 | 9999 / 1 | 2 | 0 | 1 | 1734 | 149 | 2202634 | 522 | 0 | 0 |
| compression / 2000 | 1999 / 1 | 2 | 0 | 1 | 919 | 129 | 163135 | 1014 | 0 | 0 |
| compression_low_ash / 2000 | 1999 / 1 | 2 | 0 | 1 | 1115 | 124 | 158334 | 384 | 0 | 0 |
| compression_phase / 2000 | 1999 / 1 | 2 | 0 | 1 | 1229 | 122 | 148106 | 1952 | 0 | 0 |
| expansion / 2000 | 1999 / 1 | 2 | 0 | 1 | 1424 | 119 | 187315 | 573 | 0 | 0 |
| mixed_resources / 10000 | 9999 / 1 | 16 | 14 | 1 | 10155 | 995 | 2010464 | 681 | 0 | 0 |
| forge_resources / 2000 | 1999 / 1 | 2 | 0 | 1 | 1497 | 175 | 383642 | 810 | 107 | 0 |
| sequential_feedback / 2000 | 1999 / 1 | 2 | 0 | 1 | 1152 | 150 | 223659 | 526 | 0 | 0 |
| feedback_stress / 2000 | 1999 / 1 | 2 | 0 | 1 | 1443 | 171 | 408516 | 771 | 0 | 0 |
| compression_partial / 2000 | 2000 / 0 | 1 | 0 | 0 | 1427 | 134 | 165851 | 0 | 0 | 0 |
| mode_changes / 2000 | 1999 / 1 | 117 | 16 | 1 | 79860 | 6886 | 443900 | 2269 | 0 | 0 |
| earned_essence / 10000 | 10000 / 0 | 1 | 0 | 0 | 965 | 106 | 3144950 | 0 | 0 | 0 |
| earned_feedback / 10000 | 10000 / 0 | 1 | 0 | 0 | 1164 | 107 | 3247516 | 0 | 0 | 0 |

Native-cycle telemetry comes from separate, verified-equivalent diagnostic executions, never the timed optimized path:

| Fixture / ticks | Completions | Auto starts / attempts | Critical / normal | RNG randi words | Native completion µs | Native Forge cycle µs | Net level-change calls: completion / startup |
|---|---:|---:|---:|---:|---:|---:|---:|
| early / 2000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |
| early / 36000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |
| consumer_50000 / 2000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |
| consumer_50000 / 10000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |
| mid / 2000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |
| mid / 10000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |
| forge_competing / 2000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 175891 | 0 / 0 |
| forge_competing / 10000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 1285513 | 0 / 0 |
| essence_only / 2000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |
| essence_feedback / 10000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |
| compression / 2000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |
| compression_low_ash / 2000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |
| compression_phase / 2000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |
| expansion / 2000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |
| mixed_resources / 10000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |
| forge_resources / 2000 | 1 | 0 / 0 | 0 / 1 | 0 | 49 | 5328 | 0 / 0 |
| sequential_feedback / 2000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |
| feedback_stress / 2000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |
| compression_partial / 2000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |
| mode_changes / 2000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |
| earned_essence / 10000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |
| earned_feedback / 10000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |

Native profiler (intrusive, overlapping microsecond totals; excluded from throughput):

| Fixture / ticks | Generator processing | Cycle processing subset | Input / output rate calculations | Environmental effects | Generator / upgrade automation | Automatic upgrades |
|---|---:|---:|---:|---:|---:|---:|
| early / 2000 | 292422 | 3967 | 4771 / 94933 | 14451 | 3968 / 3255 | 51247 |
| early / 36000 | 6184660 | 78434 | 110411 / 2016820 | 851319 | 81115 / 67018 | 1154654 |
| consumer_50000 / 2000 | 419340 | 3986 | 30469 / 132717 | 40456 | 4817 / 3896 | 35570 |
| consumer_50000 / 10000 | 2172288 | 17821 | 167829 / 669393 | 198437 | 21271 / 16612 | 178470 |
| mid / 2000 | 335022 | 3620 | 24783 / 58523 | 13677 | 28864 / 3730 | 36108 |
| mid / 10000 | 1915155 | 19729 | 155931 / 314269 | 194689 | 154407 / 19998 | 178148 |
| forge_competing / 2000 | 1035917 | 132880 | 113756 / 245659 | 43621 | 34364 / 3858 | 32566 |
| forge_competing / 10000 | 18951753 | 3162615 | 1086744 / 5127141 | 714166 | 1446173 / 63063 | 1643815 |
| essence_only / 2000 | 239656 | 3884 | 0 / 69548 | 70006 | 4151 / 3415 | 26049 |
| essence_feedback / 10000 | 4488621 | 25278 | 368299 / 1675378 | 398902 | 31333 / 28540 | 409476 |
| compression / 2000 | 214140 | 7511 | 40 / 58 | 45939 | 5260 / 3081 | 33504 |
| compression_low_ash / 2000 | 157236 | 3560 | 41 / 42 | 40962 | 3285 / 2899 | 26358 |
| compression_phase / 2000 | 146743 | 3668 | 35 / 50 | 39181 | 3111 / 2643 | 24734 |
| expansion / 2000 | 151281 | 3079 | 34 / 37 | 73762 | 3359 / 3175 | 25216 |
| mixed_resources / 10000 | 3312819 | 19536 | 306623 / 1136666 | 84419 | 159310 / 18409 | 128677 |
| forge_resources / 2000 | 701811 | 6577 | 67148 / 247765 | 17122 | 5849 / 3465 | 21242 |
| sequential_feedback / 2000 | 272525 | 3757 | 231 / 72754 | 73075 | 5100 / 3082 | 24692 |
| feedback_stress / 2000 | 691180 | 3559 | 63405 / 228067 | 24932 | 4003 / 3448 | 26110 |
| compression_partial / 2000 | 122863 | 3367 | 5 / 21 | 70825 | 4074 / 3507 | 32196 |
| mode_changes / 2000 | 680978 | 3702 | 63194 / 229223 | 24566 | 29531 / 4263 | 26351 |
| earned_essence / 10000 | 3550105 | 22148 | 411916 / 920867 | 207206 | 167659 / 871345 | 117053 |
| earned_feedback / 10000 | 4799703 | 28770 | 483638 / 1228744 | 335246 | 206185 / 1671062 | 186700 |

Resource-operation diagnostics (separate untimed executions):

| Fixture / ticks | Native input / output flow evaluations | Kernel tape evaluations | Kernel dynamic modifier evaluations | Partial operations / exact exhaustion witnesses |
|---|---:|---:|---:|---:|
| early / 2000 | 2000 / 10000 | 12000 | 14000 | 2000 / 2000 |
| early / 36000 | 36000 / 180000 | 216000 | 252000 | 36000 / 32880 |
| consumer_50000 / 2000 | 4000 / 6000 | 6000 | 10000 | 0 / 0 |
| consumer_50000 / 10000 | 20000 / 30000 | 30000 | 50000 | 0 / 0 |
| mid / 2000 | 4958 / 9668 | 11658 | 13604 | 3363 / 3255 |
| mid / 10000 | 28958 / 49668 | 59658 | 69604 | 19363 / 19255 |
| forge_competing / 2000 | 12000 / 16000 | 18000 | 26000 | 0 / 0 |
| forge_competing / 10000 | 60000 / 80000 | 90000 | 130000 | 53 / 50 |
| essence_only / 2000 | 0 / 2000 | 1999 | 3904 | 0 / 0 |
| essence_feedback / 10000 | 30000 / 60000 | 69993 | 99989 | 4182 / 4025 |
| compression / 2000 | 14 / 7 | 2023 | 6 | 1 / 1 |
| compression_low_ash / 2000 | 14 / 7 | 2023 | 6 | 1 / 1 |
| compression_phase / 2000 | 14 / 7 | 2023 | 6 | 1 / 1 |
| expansion / 2000 | 20 / 20 | 0 | 0 | 0 / 1 |
| mixed_resources / 10000 | 34796 / 62398 | 89580 | 102387 | 11651 / 10796 |
| forge_resources / 2000 | 7380 / 12690 | 18740 | 24675 | 2668 / 2654 |
| sequential_feedback / 2000 | 56 / 2056 | 4133 | 6105 | 4 / 1 |
| feedback_stress / 2000 | 7914 / 12957 | 19816 | 20946 | 2103 / 2102 |
| compression_partial / 2000 | 2 / 1 | 2004 | 1 | 1 / 1 |
| mode_changes / 2000 | 7024 / 12522 | 16996 | 20491 | 1669 / 1606 |
| earned_essence / 10000 | 30000 / 60000 | 70000 | 90000 | 20000 / 18390 |
| earned_feedback / 10000 | 30000 / 60000 | 70000 | 90000 | 20000 / 20000 |

Binary/discrete/RNG parity: **344/344** archived/current public/isolated samples including warmup; all numerical error fields zero. Dedicated resource differential suite: **11800** individual tick comparisons, plus reentry and diagnostic-instrumentation parity. Full original graph fingerprints match at endpoints. No tolerance was widened.


## Focused consumer confirmation

A separate serial run uses the same engine, fixtures and methods, with one warmup and five measured repeats per method. Original results above remain unchanged.

| Fixture / ticks | Native ms | Previous public ms (range) | Extended public ms (range) | Native speedup | Runtime change vs previous |
|---|---:|---:|---:|---:|---:|
| early / 2000 | 308.627 | 161.857 (160.856–162.759) | 158.263 (150.667–205.666) | 1.950× | -2.22% |
| consumer_50000 / 2000 | 441.142 | 275.605 (266.874–347.543) | 270.562 (267.575–283.586) | 1.630× | -1.83% |
| consumer_50000 / 10000 | 2156.720 | 1354.261 (1340.338–1612.556) | 1369.565 (1358.976–2392.777) | 1.575× | +1.13% |

Confirmation binary/discrete/RNG parity: 72/72; no numerical error. No original slow sample was discarded.
