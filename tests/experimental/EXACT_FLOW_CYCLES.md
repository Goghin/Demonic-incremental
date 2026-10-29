# Exact ordered kernel: Infernal Forge cycles

Base `b29c599381223a9a7238da1c90f96c5b0fd94f69`, branch `feature/cycle-auto-run`.

## Audited lifecycle and dependencies (before implementation)

Sources: `simulation/simulation.gd` update, buy_generator, update_cycle_generator, offline auto-run, complete_cycle and completion-event helpers; `Generators/generator.gd`, generator/mode/IO definitions, InfernalForge factory; UpgradeRegistry Ash/event upgrades; both native automation managers; GameState resource/accounting methods; SaveManager cycle serialization; existing transaction, exact, consumer and automation tests and reports.

Startup is a native purchase: check unlock, no active cycle, crafting recipe, cost; consume recipe if any, debit/account activation cost, increment level only when mode requests it, reset progress, snapshot relic critical chance, activate and append purchase history. No Forge resource input is reserved at startup. Heat/Matter inputs are continuously spent as the cycle runs. Manual startup is an external public-call boundary; auto-run startup happens at the generator position.

Tick order: capture tick-start Heat/bookkeeping; automatic upgrades; generators in registration order, with native controller update before cycle processing; Matter decay and Heat conversion; Heat leak; generator automation then upgrade automation; offline bookkeeping. Native cycle processing is separate from continuous execution.

For a non-auto offline cycle: if inactive, attempt enabled/unpaused auto startup or return; restart operating through native partial-input startup; read current mode duration; compute pre-consumption speed and remaining-time/speed; clamp requested duration to this tick; calculate native multi-input availability; if positive consume inputs sequentially, produce ordinary outputs, then recalculate speed and add elapsed times speed. At duration minus 1e-6, clamp progress and complete; otherwise insufficient duration stops operation. Thus Ash output can change speed between the remaining-time calculation and progress increment. No cached duration/speed can replace these calls.

Offline auto-run uses the native remaining-delta loop. It tests pause, attempts startup, tests operation, duration and current speed, refuses nonpositive speed, consumes/produces/advances, subtracts actual elapsed duration and completes at the same epsilon. Completion can restart using remaining delta; purchases spend current resources at that exact point. There is no merged-completion calculation. The non-auto path has different zero-speed behavior and must not be unified with auto-run. A non-auto paused cycle already marked operating also bypasses the startup pause gate; auto-run checks pause at loop entry and clears operating. These existing semantics are retained, not repaired.

Completion first resolves ordered trigger events (RNG draws only for probabilities strictly between zero and one). It evaluates each completion resource output with live level, production modifiers and conditional event multipliers. Native CF reward sets balance/production/discovery/peaks, emits normal/critical notification, then records all current Heat lost and zeros Heat. Inventory rewards/crafting are a separate unsupported capability. Finally it sorts level-loss consequences by event_order, draws conditional probabilities in native order, emits actual level reduction, and resets active/operating/progress/critical snapshot. Effects only mutate the completing generator level, resources, accounting and owned signal history within the admitted no-inventory scope; they cannot append new modifiers or unlock IO.

Completion outputs use base amount times the live level (when scaling is enabled), then native production modifiers and conditional event multipliers. They do **not** pass through continuous fractional-floor accumulation or the ordinary output timing path; even a discrete-tagged completion output follows native direct reward writes. Forge critical chance is resolved by its completion-event effects and live source-upgrade levels/additive modifiers. The activation critical snapshot is preserved by the native API, but its random-relic use belongs to the still-unsupported relic crafting path; it does not replace Forge event rolls.

Ash cycle-speed penalties are dynamic CYCLE_SPEED modifiers, evaluated every tick and again after input/output writes, with native mode sensitivity, realm scaling and threshold formulas. Completion reward modifiers read the post-output resources. Native functions own all floating-point associations, event order and RNG. Save/load stores active/progress, auto-run, mode, production phases and exact critical snapshot encoding; native reload rebuilds effects and restores unsaved operating state normally.

Pure calculations: cost/availability, duration, modifier/sensitivity/speed/critical chance evaluation. Mutations: resource debit/consumption/output/Heat loss, accounting/discovery, activation/operating/progress/snapshot, level changes, RNG draws, owned histories/signals and auto-run purchases. External UI callbacks, logs/clocks, inventory recipes and relic outputs remain outside this synchronous core. Achievements are scene-level observers, not invoked by this isolated native update; external listeners stay refused.

## Implemented narrow contract

A reviewed adapter selects Forge capability outside the generic flow loop and validates native modes/IO/event effects, excludes inventory/transfer/unsupported resource dependencies, and invokes the unmodified native cycle update at the original generator position. It keeps live generator/definition/state identities and no copied phases. Other idle cycle generators retain the previous inert behavior; active/auto-running unreviewed generators fall back.

Cycle level changes invalidate after the tick, before the next header. Same-tick continuation is safe because continuous tapes never cache balances and generator-level modifiers remain dynamic native evaluations; completion consequences only change the completing generator. Automatic resource requirements are checked live at the next header. Ordinary completion without level/configuration changes does not require reconstruction. Automation invalidation must OR with cycle invalidation. Unsupported native purchase effects remain guarded on the next build.

The implementation and validation contracts are detailed below.

## Live ownership and dependency contract

| Owner | Fields/dependencies | Handling |
|---|---|---|
| Generator runtime | `cycle_active`, `cycle_progress`, `cycle_critical_chance_snapshot`, `operating`, `level`, `operation_mode_id`, `auto_run_cycles`, pause/throttle flags | Original instance; native cycle methods read/write directly; compare final level for invalidation |
| Generator output/cache | `production_progress`, `_production_modifier_cache` | Native ordinary cycle outputs retain original fractional phases and lazy cache references |
| Generator definition/mode | Ordered inputs/outputs/completion outputs, `cycle_duration`, level scaling, activation cost/level flag | Original references; validated at construction; current native getters own all cycle evaluation |
| Generator effects | Modifiers, sensitivities, ordered event effects, live source-upgrade levels | Native evaluation before/after IO and at completion; reviewed effects cannot mutate another machine's configuration |
| GameState resources/accounting | Balances, discovery, lifetime/run/offline statistics, interval counters, environmental/prestige counters | Existing native setters/accounting; no shadow resources or synchronization |
| GameState RNG | Owned native `gameplay_rng.seed/state` | Native ordered draws only; custom RNG scripts rejected; measurement clone never touches the authoritative generator |
| Eternal/upgrade state | Auto-run technology, permanent Heat multiplier, current upgrade levels/effects | Native technology/eligibility checks; constant Heat multiplier cached only until a public/invalidation boundary |
| Simulation and event sinks | Automatic-upgrade indices, offline bookkeeping, purchase log, normal/critical/downlevel signals | Native calls plus owned journal; no connections added by a packet; external observers/loggers remain refused |
| External owners | TimeManager clocks/dormancy, scene achievement/UI updates, disk logs/save/load/prestige | No execution within an exclusive packet; these remain separate synchronization/integration boundaries |

## Implemented execution and invalidation

`exact_flow_cycles.gd` is the small capability validator. It selects the reviewed Forge definition outside the generic packet loop, verifies every mode/IO and base event-effect script, requires the state-owned native RNG (custom RNG scripts are refused), rejects recipes/inventory/random-relic rewards, transfer modes and unsupported resource outputs/Essence inputs. Existing global guards still reject relic inventory/equipment, Essence modifiers/sensitivities, custom scripts, unowned callbacks/logs/clocks, instrumentation/prestige and concurrent edits. Idle unreviewed cycle machines retain the old inert path; active/auto-running unreviewed cycles explicitly fall back. No production code changes.

Each Machine retains its original Generator reference and cycle capability. At the existing cycle branch, after the native controller update, the packet calls **`simulation.update_cycle_generator(generator, 0.1, true, cycle_heat_multiplier)`** when active or flagged for auto-run. The supplied Heat multiplier is evaluated using the original native API at construction and remains constant over an admitted packet, exactly like the existing continuous Heat tape. There is no cycle-phase copy, elapsed-time aggregation, completion scheduler, alternate RNG sampler, reward formula or crafting implementation. Native ordinary cycle outputs remain native as well; only the surrounding continuous resource flows use compact tapes.

The native method owns startup affordability/spending, snapshot, progress, Ash feedback, input limiting, discrete phases, completion calls, CF/statistics/Heat loss, normal/critical/downlevel signals, RNG and auto-run loops. Idle Forge with no auto flag safely skips the pure native early return. Flagged-but-technology-locked auto-run still executes native technology checks and cannot start. Paused/stopped/operating differences follow the actual native path, including its different manual and auto-run pause handling; nothing is normalized by the adapter.

The packet compares **its cycle generator's level before and after the native call**. A changed final level invalidates the plan after that tick. Cycle invalidation is ORed with the existing post-automation purchase witness, preserving both causes. The native probe separately labels net level-change calls that completed versus startup-only calls; native automatic-header ticks may contribute to this diagnostic count without being kernel invalidations. `cycle_invalidations` counts kernel calls whose final level changed; `structural_invalidations` counts affected packet ticks. It is not a count of all completion signals or internal intermediate level changes.

Why it is safe to finish subsequent generators in the same tick:

- Reviewed native completion effects mutate only the completing generator's level, its runtime, live resources/accounting, RNG and owned event history. They cannot change another generator's level, IO, mode, modifier/sensitivity arrays, thresholds or realm effects.
- No compact tape caches resource balances. Dynamic resource and dynamic generator-level modifiers remain live native suffix evaluations. A downstream source sees CF reward, Heat loss and final Forge level immediately. Explicit after-Forge resource/level dependency probes protect this assertion.
- A cycle machine uses the native API and never the continuous machine's cached level/start/output coefficients. A startup/downlevel pair returning to the original final level therefore needs no reconstruction: later generators and the next header see the same final configuration, while intermediate native events have already occurred in order.
- Any persistent level change rebuilds before the next header, so previously blocked automatic generator-level requirements are reconsidered. Resource-only automatic requirements remain live `event_due()` checks. Newly eligible automatic upgrades still execute a whole native tick before reconstruction.
- Completion with unchanged final configuration does **not** reconstruct merely because CF, progress, RNG or Heat changed. There is no repeated checkpoint overhead. Native automation continues after environmental accounting and retains its original purchase invalidation.

Public calls always release packets and reconstruct on reentry. Manual startup, player level/definition edits, legal mode selection, upgrades, pause, auto flag changes, resource changes and TimeManager updates between calls use fresh structure. A caller must not yield/edit during a retained packet. Direct packet users must check `event_due()` and discard invalidated packets; the existing stale-step assertion remains.

The contract is extensible by reviewing another capability in the adapter, not by adding generator-specific formulas to the flow loop. Relic Crucible requires an inventory/recipe/random-relic/ID/equipment contract and remains refused. Future event actions that mutate global structure require a new same-tick boundary; the current validator rejects unreviewed actions rather than guessing.

## Fixtures and validation design

The original `forge_competing` save and its existing legal entry pause actions are unchanged. Active Forge, enabled generator buyer, competing consumers, Mites, Ash feedback, environmental effects and upgrades remain present. The unaltered `core_event_fixture.json:before` provides the actual first-craft completion with the original duration and resource scarcity. Both are primary native controls.

`cycle_progression_builder.gd` reuses the previous automation milestone's legal native purchase/pause policy, ending before prestige: 33,544 ticks complete two real Forge crafts, saving a second manual cycle in progress, an approaching first completion and the state after repeated crafting. The recorded action ledger uses original APIs, prices, modes, resources and earned effects. It grants no resources or technology. These saves retain enabled Atomic Friction automation and active Mites; they are separate from the unchanged original fixture. Exact ticks/actions/levels are retained in `cycle_progression.json` (the generated tick count is authoritative).

A separate bounded `cycle_auto_unlock_exploration.gd` attempts to earn and purchase the 30-flame permanent auto-run unlock through real prestige and native policy. Its 600,000-tick policy only earned one additional eight-flame reward, then stalled below the target. Its raw `cycle_auto_unlock_exploration.json` records this **failed fixture-construction experiment**; it is not used by tests or benchmarks and is not proof that auto-run is globally unreachable. Running that optional script intentionally returns failure when it cannot construct its requested fixture. No unearned auto-run state is labeled progression-reachable.

Auto-run performance/transition scenarios are explicitly **controlled diagnostics**, with an explicit technology grant. Other controlled probes cover idle/manual startup, active/partial/exact-boundary/empty inputs, locked auto-run, unaffordable auto startup, paused auto/manual operating states, zero speed, high Ash, mode-filtered events, critical probability edges, guaranteed and random downlevels, same-tick completion plus generator/upgrade purchases, dynamic CF/level dependencies downstream, next-header automatic requirements after auto startup, live cycle-speed upgrades, repeated call reconstruction and unsupported inventory/recipe/Essence/other-cycle rejection.

`completion_heavy` is an adversarial diagnostic, not progression: it uses the existing fast mode, large source/condenser levels, a diagnostic speed modifier and explicit critical/downlevel effects to generate repeated native completions. Costs, duration definitions, RNG implementation and reward implementation are still native. The stock/level/effect/technology edits are visible in the fixture source. It is never evidence of representative full-game throughput. Native Heat loss prevents immediate restart until resources become available; the actual remaining-delta/retry behavior is preserved, not replaced with an assumption that one completion always equals one tick.

The dedicated suite records candidate binary views and compares authoritative `Simulation.update(0.1, true)` after every tick. Detailed views now include current mode duration in addition to resources, progress, snapshot, output phases, automation state/caches, levels/unlocks, modifiers/sensitivities/events, accounting/history and RNG. The identity-aware original graph fingerprint compares all endpoint state and asserts construction is read-only. No numerical tolerances are used for equality. Explicit witnesses require actual completions, same-tick purchases, repeated stress crafts, random draw/no-draw boundaries, level invalidation, second-header automatic activation and fallback/resumption.

Existing assertions that Forge must always fall back are replaced by positive kernel-execution assertions; their binary equality checks remain. All old transaction, consumer, Mite, automation, real Forge, RNG and offline regression groups remain registered. A new cycle group is added. The recovered final full suite passes **95 groups, 0 failures**, retaining all 94 previous groups. Its complete output is saved in `cycle_kernel_regression.log`; the strict wrapper also rejects parser warnings and runtime errors.

## Benchmark methodology and interpretation

The previous packet/kernel are archived from `b29c599`; the kernel's packet preload is the only archive adjustment. Normalized source equality is checked against Git. Fixtures, engine and method ordering match within this run; no comparison uses timings from the user's Windows machine.

Each scenario runs native, archived public/isolated, extended public/isolated and adaptive reference, four repeats with alternating forward/reverse method order. Repeat zero is warmup, three measured runs provide medians and min–max. Deterministic initial states are recreated outside timing. Original whole-graph byte equality, numerical/phase/discrete/RNG comparisons occur after timing for every non-adaptive sample. Approximate adaptive results are a reference, not a correctness oracle. Standalone tests, benchmarks and the full regression suite run serially during throughput measurements.

Public timings include construction, per-tick flow/cycle/native completion calls, all accounting, automation, event checks, invalidation, reconstruction and native fallback. Isolated timings explicitly exclude initial build and reconstruction; native header/fallback ticks remain included. Different dispatch paths and sample variance can invert isolated/public medians; their difference is not setup timing. Native cycle processing is not claimed to be accelerated independently: savings come from compact surrounding continuous flows.

Separate intrusive diagnostic runs measure build/release, kernel/native/event check and native cycle time, completions, downlevels, auto attempts/successes and normal/critical notifications. The subclass used to time native completion delegates directly to `super`; every-tick diagnostic/control comparisons verify observational parity and it is explicitly rejected by kernel guards. Its Forge cycle time includes completion/startup; completion time is a nested subset and must not be added again. These clocks include intrusive wrapper/timer overhead and are not an additive decomposition of the throughput medians. A further native `profiling_enabled` run records existing subphase totals/call counts and verifies its gameplay endpoint against the kernel; those overlapping sections must not be summed. Kernel cycle time covers kernel-executed calls; native header ticks are accounted separately.

RNG word counts are reconstructed outside throughput by cloning initial seed/state, advancing `randi()` until the final authoritative state matches, with an explicit bound and failure on no match. These are PCG **word counts**, not abstract event-check counts; Forge's native strict-probability `sample_unit` consumes one word, endpoints consume none. No authoritative RNG is advanced by measurement. Critical outcomes and event ordering remain compared independently.

Packet memory uses the engine's static allocation delta across isolated construction. It is a retained allocation **estimate**, excluding the pre-existing state/shared script code, not exact heap/peak allocation or RSS. The adapter adds scalar packet/machine capability/diagnostic fields and one-time mode validation; native cycle calls may allocate their existing completion dictionaries/arrays/events. There is no extra state graph, journal, checkpoint or per-tick structural fingerprint. Construction/rebuild frequency and raw allocation estimates are reported separately.

Reproduce from the repository root:

```sh
python tests/experimental/run_cycle_kernel.py --godot /path/to/godot --mode fixtures
python tests/experimental/run_cycle_kernel.py --godot /path/to/godot --mode tests
python tests/experimental/run_cycle_kernel.py --godot /path/to/godot --mode benchmark
python tests/experimental/run_cycle_kernel.py --godot /path/to/godot --mode regression
python tests/experimental/summarize_cycle_kernel.py
python tests/experimental/run_cycle_kernel.py --godot /path/to/godot --mode scope
```

The driver fails on nonzero status, parser warnings or runtime errors. The failed optional auto-unlock exploration is separate from these validated modes. Actual engine/host and source/raw hashes are retained in `cycle_kernel_environment.json`. Linux Godot 4.6.1 results do **not** establish Windows Godot 4.7.2 compatibility. No editor import is run and unrelated production/editor issues are untouched.

## Remaining architectural limits

No production offline entry point is changed. External clocks/dormancy progression, callbacks, filesystem logging, prestige planning, relic inventory/equipment/crafting, Essence dependencies, transfer modes and unreviewed active/auto cycles remain unsupported. Dormancy penalties fixed for one synchronous call retain the consumer contract. Native startup/consumption/modifier/completion costs and mandatory automation scans are still paid every tick.

The next capability should be selected from the measured independent blockers rather than equating Forge coverage with full-game support. Relic Crucible inventory/crafting and Essence/transfer dependencies need separate audits. TimeManager remains necessary before claiming actual client offline/dormancy integration. Completion/restart code remains native by design; any future optimization must preserve the pre-/post-Ash speed evaluations and native reward/RNG order.


## Interpretation of the matched measurements

Original `forge_competing` now executes **100%** of 2,000 and 10,000 ticks in the kernel, with 1.291× and 1.278× median native speed. Relative to archived b29c599 public execution, runtime falls 23.81% and 29.77%. Each interval uses one packet and no reconstruction. The unchanged resource competition prevents a completion in those intervals: this is acceleration of that actual resource-flow workload plus native active-cycle availability/progress checks, not a claim of representative repeated crafting throughput.

Actual completion is exercised separately: the original first-craft witness completes at tick 1, produces its first CF and retains one packet; the reached near-completion fixture crosses at tick 5. Their 2,000-tick public speedups are 1.604× and 1.540×. The reached second-cycle active snapshot achieves 1.505×. The reached repeated-crafting snapshot is taken **after** the second craft, with manual auto-run disabled; its subsequent 10,000-tick interval is an idle-cycle/resource-flow regression, not ten thousand ticks of repeated completions. No active cycle or enabled buyer is removed from a representative save.

The controlled 2,000-tick completion stress records **32 completions, 31 successful auto starts, 2,031 auto purchase attempts, 17 critical and 15 normal outcomes, 32 RNG words and 32 downlevels**. All events and final RNG match native execution byte-exactly. It uses **two builds**, with one cycle-level invalidation: subsequent native start/completion pairs return to the same final level and leave no cached cycle coefficient stale. Median public speedup is 1.810×. Its synthetic source levels/speed/event effects make it diagnostic evidence only; no mature-game auto-run speedup is inferred. The separate `auto` row exercises unsuccessful restart affordability after its completion and has zero successful starts.

Preserved native acceleration: early 2,000/36,000 ticks is 1.885×/1.738×; consumer 2,000/10,000 is 1.615×/1.456×; original mid is 1.275×/1.309×. There are regressions against the already optimized archive: early public medians are 3.53%/4.65% slower, consumer long is 2.87% slower, mid 6.41%/2.44% slower, and reached post-crafting idle state is **13.11% slower**. These regressions are retained. The ranges for these regression cases overlap; three measurements do not establish statistical significance or isolate the cause. Additional capability checks/bookkeeping introduce work, but one-time validation cannot by itself explain the entire longer-runtime difference. There is no claim of uniform improvement over the previous kernel.

The intrusive original Forge runs spend 84,030/418,336 µs in native cycle calls out of 505,944/2,315,094 µs of kernel execution (about **16.6%/18.1%**). Native completion/reward/RNG is therefore not the dominant cost there. Native profiles show generator processing dominating environmental effects and automation; rate calculations are substantial overlapping subphases. Setup/release is 707+106 µs at 2,000 ticks and 937+98 µs at 10,000, with no rebuild churn. In the completion diagnostic, completion time is only 1,713 µs in the separate native probe; kernel cycle calls occupy about 11% of its intrusive execution. These observations support retaining native completion while focusing subsequent optimization profiles on the remaining resource-flow/modifier work. They do not provide a disjoint breakdown of every individual rate/modifier cost.

Retained packet deltas range from roughly 9–33 KiB in supported scenarios; original Forge is 32,620 bytes. Some old-supported estimates decrease despite adding scalar fields. No memory optimization is claimed: global engine allocation deltas are sensitive to temporary/lazy allocator behavior and are not exact per-object/peak measurements. New explicit overhead is four packet scalars, one machine capability Boolean and two kernel counter entries, plus one-time capability validation. No phase/state copies or speculative checkpoints are introduced.


## Final validation, independent blockers and next milestone

**95/95 regression groups pass**, preserving all 94 earlier groups. The fresh dedicated cycle run also passes 20,700 named-interval tick comparisons plus reentry, probability-edge and instrumentation checks, with no parser warnings or runtime errors. The saved benchmark has **256/256** archived/current public/isolated whole-graph byte-equality samples, zero measured numerical error, exact phases/events/discrete state and exact RNG. Validation was rerun after recovering the interrupted runtime; the completed matched benchmark JSON was preserved and verified rather than rerun or mixed with new timings. Its temporary stdout log was unavailable after recovery. `cycle_kernel_environment.json` separates preserved benchmark metadata from the refreshed validation host and records source/raw hashes.

The scope audit save-loads five **diagnostic** older fixtures and compares ten kernel/control ticks at their endpoints. All five whole-graph comparisons pass:

| Diagnostic | First runtime gate | Independent inventory | Outcome |
|---|---|---|---|
| transfer | unsupported_transfer_mode | Thermal Compressor expansion transfer | 10 native fallback ticks |
| late_both | none | No active cycles, relic inventory or Essence modifiers | 10 kernel ticks; not progression/performance evidence |
| mixed | unsupported_output/nexum | Active Forge passes the cycle contract | 10 native fallback ticks |
| essence | unsupported_output/essence | Essence output remains unaudited | 10 native fallback ticks |
| cycles | relic_inventory | Relic inventory plus an independently unreviewed active Relic Crucible | 10 native fallback ticks |

Recommend **exact Essence output/modifier support with a reached Essence fixture** next: it is an observed independent resource gate and can build on the existing ordered IO/rate contract without prematurely expanding inventory crafting. Nexum/transfer semantics remain a separate reviewed flow capability. Relic Crucible is the next cycle capability, requiring inventory/recipe/instance-ID/generated-definition/RNG and slot-effect auditing; simply whitelisting its ID would be unsafe. TimeManager integration is still needed for full client offline/dormancy claims. Native cycle and reward calls need no rewrite to retain the measured Forge benefit.

<!-- MEASURED_RESULTS -->

## Measured results

Milliseconds below are medians of three measured runs; one preceding warmup per method/scenario is excluded. Ranges are measured min–max, not confidence intervals.

| Fixture / ticks | Native ms | Previous public ms | Extended public ms | Adaptive reference ms | Speedup vs native | Kernel coverage |
|---|---:|---:|---:|---:|---:|---:|
| early / 2000 | 219.090 | 112.268 | 116.227 | 250.184 | 1.885× | 100.000% |
| early / 36000 | 4466.263 | 2455.081 | 2569.227 | 4858.062 | 1.738× | 100.000% |
| consumer_50000 / 2000 | 317.142 | 196.442 | 196.318 | 363.328 | 1.615× | 100.000% |
| consumer_50000 / 10000 | 1509.656 | 1008.064 | 1036.998 | 1686.053 | 1.456× | 100.000% |
| mid / 2000 | 233.254 | 171.923 | 182.944 | 278.655 | 1.275× | 99.900% |
| mid / 10000 | 1335.764 | 995.958 | 1020.308 | 1516.369 | 1.309× | 99.980% |
| forge_competing / 2000 | 796.557 | 810.007 | 617.160 | 815.118 | 1.291× | 100.000% |
| forge_competing / 10000 | 3229.802 | 3599.367 | 2527.840 | 3651.975 | 1.278× | 100.000% |
| real_completion / 2000 | 375.707 | 375.760 | 234.215 | 410.238 | 1.604× | 100.000% |
| reached_manual_active / 2000 | 787.309 | 766.442 | 523.007 | 771.214 | 1.505× | 100.000% |
| reached_manual_near / 2000 | 716.185 | 668.084 | 465.170 | 690.624 | 1.540× | 100.000% |
| reached_repeated / 10000 | 3526.362 | 2181.027 | 2466.976 | 3644.916 | 1.429× | 100.000% |
| active / 2000 | 112.208 | 113.086 | 96.749 | 149.036 | 1.160× | 100.000% |
| auto / 2000 | 118.840 | 115.845 | 103.860 | 126.338 | 1.144× | 100.000% |
| ash_heavy / 2000 | 103.378 | 129.123 | 86.697 | 112.338 | 1.192× | 100.000% |
| completion_heavy / 2000 | 403.030 | 376.016 | 222.721 | 415.048 | 1.810× | 100.000% |

| Fixture / ticks | Previous public range ms | Extended public range ms | Runtime change vs previous | Previous isolated ms | Extended isolated ms | Previous / extended retained packet bytes (estimate) |
|---|---:|---:|---:|---:|---:|---:|
| early / 2000 | 107.269–126.636 | 114.017–123.960 | +3.53% | 113.915 | 126.098 | 23100 / 20716 |
| early / 36000 | 2320.730–2670.154 | 2365.030–2603.003 | +4.65% | 2498.753 | 2712.010 | 23100 / 20716 |
| consumer_50000 / 2000 | 191.126–201.275 | 194.025–201.631 | -0.06% | 209.041 | 205.804 | 19936 / 17608 |
| consumer_50000 / 10000 | 990.227–1055.947 | 967.956–1041.857 | +2.87% | 1028.483 | 1011.613 | 19936 / 17608 |
| mid / 2000 | 163.533–184.794 | 169.261–205.954 | +6.41% | 163.554 | 170.393 | 23172 / 20724 |
| mid / 10000 | 968.108–1029.493 | 1005.860–1112.639 | +2.44% | 1072.893 | 1073.628 | 23172 / 20724 |
| forge_competing / 2000 | 723.537–851.396 | 577.552–657.675 | -23.81% | 741.963 | 590.282 | 0 / 32620 |
| forge_competing / 10000 | 3548.225–3618.359 | 2506.501–2738.999 | -29.77% | 3548.059 | 2638.324 | 0 / 32620 |
| real_completion / 2000 | 374.793–379.641 | 183.844–255.746 | -37.67% | 389.739 | 194.930 | 0 / 25764 |
| reached_manual_active / 2000 | 723.686–797.043 | 472.395–634.673 | -31.76% | 720.417 | 557.822 | 0 / 25828 |
| reached_manual_near / 2000 | 664.534–705.056 | 413.263–475.044 | -30.37% | 697.113 | 482.583 | 0 / 25764 |
| reached_repeated / 10000 | 2124.143–2362.581 | 2166.944–2594.741 | +13.11% | 2368.621 | 2574.342 | 28100 / 25828 |
| active / 2000 | 108.908–121.287 | 91.169–97.527 | -14.45% | 114.557 | 97.915 | 0 / 9756 |
| auto / 2000 | 113.734–119.551 | 97.138–124.521 | -10.35% | 118.364 | 105.402 | 0 / 9692 |
| ash_heavy / 2000 | 96.390–133.173 | 80.626–89.447 | -32.86% | 103.422 | 89.625 | 0 / 9692 |
| completion_heavy / 2000 | 367.469–396.807 | 222.492–229.874 | -40.77% | 401.988 | 225.032 | 0 / 23580 |

Separate intrusive phase-clock runs (excluded from throughput medians):

| Fixture / ticks | Kernel / native ticks | Builds (rebuilds = builds − 1) | Structural invalidation ticks | Automatic header ticks | Build µs total | Release µs total | Kernel µs total | Native µs total | Kernel cycle µs | Cycle invalidations |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| early / 2000 | 2000 / 0 | 1 | 0 | 0 | 384 | 72 | 103270 | 0 | 0 | 0 |
| early / 36000 | 36000 / 0 | 1 | 0 | 0 | 494 | 80 | 2239770 | 0 | 0 | 0 |
| consumer_50000 / 2000 | 2000 / 0 | 1 | 0 | 0 | 629 | 81 | 189945 | 0 | 0 | 0 |
| consumer_50000 / 10000 | 10000 / 0 | 1 | 0 | 0 | 484 | 73 | 1027587 | 0 | 0 | 0 |
| mid / 2000 | 1998 / 2 | 3 | 0 | 2 | 1438 | 160 | 160446 | 512 | 0 | 0 |
| mid / 10000 | 9998 / 2 | 3 | 0 | 2 | 1680 | 184 | 1133543 | 526 | 0 | 0 |
| forge_competing / 2000 | 2000 / 0 | 1 | 0 | 0 | 707 | 106 | 505944 | 0 | 84030 | 0 |
| forge_competing / 10000 | 10000 / 0 | 1 | 0 | 0 | 937 | 98 | 2315094 | 0 | 418336 | 0 |
| real_completion / 2000 | 2000 / 0 | 1 | 0 | 0 | 475 | 93 | 190242 | 0 | 103 | 0 |
| reached_manual_active / 2000 | 2000 / 0 | 1 | 0 | 0 | 662 | 83 | 553443 | 0 | 98750 | 0 |
| reached_manual_near / 2000 | 2000 / 0 | 2 | 1 | 0 | 1504 | 199 | 472339 | 0 | 262 | 0 |
| reached_repeated / 10000 | 10000 / 0 | 1 | 0 | 0 | 548 | 91 | 2014396 | 0 | 0 | 0 |
| active / 2000 | 2000 / 0 | 1 | 0 | 0 | 434 | 61 | 91445 | 0 | 10763 | 0 |
| auto / 2000 | 2000 / 0 | 1 | 0 | 0 | 384 | 79 | 100166 | 0 | 16662 | 0 |
| ash_heavy / 2000 | 2000 / 0 | 1 | 0 | 0 | 354 | 66 | 80318 | 0 | 131 | 0 |
| completion_heavy / 2000 | 2000 / 0 | 2 | 1 | 0 | 1010 | 109 | 226539 | 0 | 24842 | 1 |

Native-cycle telemetry comes from separate, verified-equivalent diagnostic executions, never the timed optimized path:

| Fixture / ticks | Completions | Auto starts / attempts | Critical / normal | RNG randi words | Native completion µs | Native Forge cycle µs | Net level-change calls: completion / startup |
|---|---:|---:|---:|---:|---:|---:|---:|
| early / 2000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |
| early / 36000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |
| consumer_50000 / 2000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |
| consumer_50000 / 10000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |
| mid / 2000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |
| mid / 10000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 0 | 0 / 0 |
| forge_competing / 2000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 83884 | 0 / 0 |
| forge_competing / 10000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 472419 | 0 / 0 |
| real_completion / 2000 | 1 | 0 / 0 | 0 / 1 | 0 | 49 | 4086 | 0 / 0 |
| reached_manual_active / 2000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 94080 | 0 / 0 |
| reached_manual_near / 2000 | 1 | 0 / 0 | 0 / 1 | 0 | 47 | 3358 | 0 / 0 |
| reached_repeated / 10000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 14686 | 0 / 0 |
| active / 2000 | 0 | 0 / 0 | 0 / 0 | 0 | 0 | 11507 | 0 / 0 |
| auto / 2000 | 1 | 0 / 2000 | 0 / 1 | 0 | 40 | 17886 | 0 / 0 |
| ash_heavy / 2000 | 1 | 0 / 0 | 0 / 1 | 0 | 41 | 2020 | 0 / 0 |
| completion_heavy / 2000 | 32 | 31 / 2031 | 17 / 15 | 32 | 1713 | 29048 | 1 / 0 |

Native profiler (intrusive, overlapping microsecond totals; excluded from throughput):

| Fixture / ticks | Generator processing | Cycle processing subset | Input / output rate calculations | Environmental effects | Generator / upgrade automation | Automatic upgrades |
|---|---:|---:|---:|---:|---:|---:|
| early / 2000 | 195708 | 2190 | 3368 / 64189 | 8008 | 2174 / 1882 | 34577 |
| early / 36000 | 3732945 | 41515 | 63857 / 1232111 | 529071 | 42425 / 39388 | 655162 |
| consumer_50000 / 2000 | 289913 | 2506 | 23501 / 86707 | 25291 | 2856 / 2085 | 23752 |
| consumer_50000 / 10000 | 1648422 | 12587 | 124245 / 496272 | 146412 | 14063 / 14350 | 125492 |
| mid / 2000 | 234275 | 2201 | 18011 / 40607 | 9809 | 17869 / 2160 | 23723 |
| mid / 10000 | 1216202 | 10883 | 107547 / 193002 | 123918 | 86286 / 10315 | 107324 |
| forge_competing / 2000 | 697483 | 93368 | 78352 / 162966 | 27600 | 22481 / 2641 | 20357 |
| forge_competing / 10000 | 3457614 | 498864 | 409560 / 836096 | 107760 | 111113 / 13151 | 107366 |
| real_completion / 2000 | 385254 | 4305 | 33034 / 134612 | 9302 | 2947 / 2322 | 19902 |
| reached_manual_active / 2000 | 782863 | 109186 | 100262 / 196612 | 44114 | 26699 / 3317 | 22991 |
| reached_manual_near / 2000 | 612963 | 4101 | 77268 / 161813 | 50969 | 26423 / 2420 | 19025 |
| reached_repeated / 10000 | 2737268 | 18630 | 350330 / 753447 | 227229 | 89787 / 11085 | 88234 |
| active / 2000 | 81868 | 13100 | 6 / 14 | 23910 | 1952 / 2076 | 18674 |
| auto / 2000 | 84390 | 18501 | 4 / 14 | 23338 | 1986 / 1674 | 17328 |
| ash_heavy / 2000 | 68047 | 3383 | 7 / 15 | 20945 | 1815 / 1715 | 15899 |
| completion_heavy / 2000 | 353972 | 28167 | 10840 / 129763 | 32954 | 2459 / 2377 | 19445 |

Binary/discrete/RNG parity: **256/256** archived/current public/isolated samples including warmup; all numerical error fields zero. Dedicated cycle differential suite: **20700** individual tick comparisons, plus reentry and diagnostic-instrumentation parity. Full original graph fingerprints match at endpoints. No tolerance was widened.
