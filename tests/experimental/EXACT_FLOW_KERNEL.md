# Compact exact ordered simulation kernel

Historical milestone report for `43b3897`. The current multi-input/controller extension is documented in [EXACT_FLOW_CONSUMERS.md](EXACT_FLOW_CONSUMERS.md); the earlier scope and measurements below are retained as baseline evidence.

## Implemented result and boundary

Base: `c06e43a5002f4c6fbdb1586c8b8a4ca5469e75c5`, branch `feature/cycle-auto-run`. This experiment reduces work **inside each authoritative 0.1-second tick**. It neither skips ticks nor introduces analytical/approximate batching. Production source, formulas, balance, saves, prestige/relic mechanics, existing adaptive eligibility and branch selection are unchanged. The six pre-existing untracked files are preserved; game.gd:771 is untouched.

The packet is a **reference-backed execution plan**, not a second GameState or a detached numeric world. Cached IO/resource references, rate coefficients and ordered modifier tapes avoid repeated definition traversal while the live resource balances, phases, statistics, runtime flags and event histories remain authoritative. Every required resource/statistics write still occurs in its original position. The prototype is opt-in under tests/experimental and is not wired into production offline catch-up.

The actual reached early fixture is eligible, with both Heat producers, input-limited Condensation, discrete Matter output, Matter-held Heat feedback, Ash contamination and environmental effects intact. Mid and Forge fixtures remain exact fallback. Coverage and speedups below apply to this early subsystem, not a mature full game.

## 1. Authoritative path and profiling method

The source order is retained from simulation/simulation.gd: read tick-start Heat and reconcile interval/realm flags; automatic upgrades; registered generators in order; throttle update; start/availability; consume inputs; ordered output rates/phase floors/resource writes; Matter decay and its Heat conversion; Heat leak; generator and upgrade automation; offline bookkeeping. Actual formulas, sensitivities and leak/decay branches are documented in ORDERED_FLOW_BATCHING.md and remain unchanged.

`kernel_profile.gd` measures 2,000 ticks for early, mid and Forge and a 20-tick real completion witness. Three repetitions separately run: instrumentation-disabled authoritative simulation; native Simulation profiling; and detailed experimental subclass probes. Detail probes wrap generator rates/sensitivity/phase access, static/dynamic modifier multipliers, statistics and history writes. A timed in-memory signal journal measures handlers, including a real Forge completion. All probe runs are checked for exact numerical/discrete/RNG parity against uninstrumented controls.

The detailed probes replace objects only in disposable diagnostic states. They copy the original fields and preserve rate/effect order, adjusting modifier-cache references to point to the corresponding probes. Automatic upgrades can append ordinary uninstrumented modifiers; the raw `unprofiled_added_modifiers` count identifies that limitation. Native major-phase profiling still covers their work. No such subclasses are used by the kernel or final throughput benchmarks.

Times are **inclusive, instrumented wall-clock estimates**, not a pure-math CPU decomposition. Rate time includes modifier/lookup work; output time includes rate and accounting work; generator processing contains all of them. They must not be added. Phase accessor probes measure phase dictionary/function access, not a separately timed CPU floor instruction. Statistics probes cover recorded history/counters; event-log probes cover actual logged events. Zero event counts in a representative window are reported as zero observations, not proof that signals are universally free.

GDScript function dispatch, property access, dictionary lookup and native mathematical calls cannot be cleanly separated by these wrappers. Source-level operation counts and the end-to-end removal of repeated structural work provide additional evidence. Dictionary.values() generator-array construction and repeated mode/modifier traversal are present in the native loop; the packet removes those repeated traversals without suppressing numerical updates or accounting. Allocator-accounted packet deltas are estimates of retained incremental allocation, not total allocation churn or RSS peaks.

## 2. Cached versus dynamic computation

| Data | Cache policy | Invalidation/boundary |
|---|---|---|
| Generator registration order, unlocked membership, active mode, IO order/flags, resource IDs/references | Build once for a synchronous call | Discard on return; rebuild after an automatic-action tick. Mode/unlock/definition changes between calls are read afresh. |
| Level, level-scaling flag, mode multipliers, realm production multipliers, Eternal Furnace multiplier | Fold the same left-associated prefix as native production | No level/purchase/cycle changes are permitted inside a packet. Before any eligible automatic action the whole tick runs natively and the packet is discarded. |
| Static Modifier plus static matching sensitivities | Evaluate once; fold before the first dynamic factor or retain a separate suffix float afterward | Base scripts only; no external callback/yield/concurrent edits. New packet for every public call. |
| Resource-dependent modifiers and matching resource-dependent sensitivities | Evaluate with the actual Modifier.get_effective_multiplier at each original output/input position | Never freeze Matter-held, Ash or other admitted dynamic values across ticks. Essence dependencies remain unsupported. |
| Input rate within a single-input generator's one tick | Reuse the deterministic rate between availability and consumption | There is only one supported input and no intervening resource mutation. Base modifier/sensitivity methods are pure. Multi-input and transfer modes are excluded. |
| Heat leak, Matter decay, their coefficients/thresholds and implicit solver | Delegate to unchanged production environmental methods every tick | No copied loss formula or replacement numerical method. Threshold changes between calls or during native event ticks are naturally visible. |
| Resource amounts, fractional phases, operating/throttle flags, counters/peaks/discovery, RNG | Remain in original live objects/dictionaries | No detached copy, delayed reconciliation, phase reconstruction or RNG replay. |
| Disabled automation indexes | Retain actual manager update calls each tick | They remain observable native state; enabled automation is never optimized. |
| Automatic-upgrade eligibility | Build a list with only non-resource requirements that can become relevant; check resource-dependent eligibility before each tick | Non-resource blockers are constant while levels/upgrades cannot change. Any eligible action exits before writes; native update handles registry/cascade ordering, then rebuild. |
| Production modifier cache | Honor the authoritative cache, including existing contents; initialize missing entries lazily at the same first production point | No eager cache mutation during build. Existing stale-cache behavior from direct unsupported edits is not silently repaired. |

Static and dynamic factors are not reassociated. Once a dynamic factor occurs, subsequent constants are multiplied separately in native order. A static modifier with a dynamic sensitivity is dynamic for compilation purposes. Crystallization-specific arithmetic and all other modifier formulas remain in the original helper. The input's level scaling is applied **after** its modifier chain as in get_input_consumption_per_second; the output's level/realm factors occur before its modifiers.

## 3. Packet architecture and ownership

`exact_flow_packet.gd` contains typed Machine, Output and Rate records:

- Machine retains the original Generator, fixed start-eligibility metadata, its single input resource/rate (if any), and output operations in definition order.
- Output retains its original ResourceState reference, ID, discrete flag, compiled rate and lazy-cache-initialization flag.
- Rate retains a binary64 prefix, ordered suffix entries (constant floats or original Modifier references), and input-final level scale. It contains no approximate curve and no aggregate output count.
- The packet retains Simulation and relevant Upgrade references. It owns only its plan objects/arrays/scalars, not cloned game objects or definitions. No retained cache survives the public run call.

Build is read-only, checked with the original complete graph fingerprint. Native production-cache arrays are created only when native execution would first request them. Existing arrays/object identities are preserved. Direct resource/phase references remove lookups; GameState setters and record methods still update discovery, peaks, lifetime/run/offline accounting and prestige-related totals in their original order. Environmental methods remain unchanged.

There is no final resource/phase write-back. In-place writes **are synchronization**, and their full cost is included inside both isolated kernel and end-to-end timings. `writeback_usec = 0` denotes no additional bulk end-of-run operation, not excluded synchronization work. Statistics are not bulk-reconstructed from balances.

The packet is one-shot. Its internal step() requires the synchronous owner to have checked event_due(). The supported public API is exact_flow_kernel.gd:run(ticks), which builds afresh, checks automatic boundaries, performs kernel or native ticks, and releases the packet before returning. Reentrant calls and negative tick counts are refused. The low-level packet interface exists for controlled validation/isolated measurement, not as a persistent caller-owned cache.

## 4. Synchronization, invalidation and supported lifetime

All external actions occur between run calls. Every call rebuilds from current authoritative objects, so level, mode, pause, upgrade, output-unlock, sensitivity, threshold, resource-object and phase-dictionary changes cannot reuse old packet data. A mode/effect/equipment change that leaves the supported domain causes native fallback rather than stale execution. The tests reuse the same Kernel object across such changes.

Within a synchronous packet, ordinary numerical writes do not modify cached structural inputs. Enabled buyers, active cycles, prestige operations and relic effects are excluded. The only admitted source of structural change is a pending automatic upgrade; eligibility is checked before any writes in that tick. The packet is released, one complete native tick applies the upgrade/cascade and ordered gameplay, and a fresh packet is attempted on the next tick. This is tested with Thermic Mass activation after a real integer Matter output: one native event tick between otherwise compiled ticks.

Maximum safe lifetime is the exclusive synchronous interval until return or a detected automatic event, **not a fixed wall-clock duration**. There is no yield, frame callback, message-queue pumping or concurrent mutation. Script reload is unsupported. A future integration yielding between frames must end the current call and rebuild afterward; it cannot retain the packet. Caller-controlled TimeManager/dormancy contexts are outside the core experiment.

## 5. Supported and unsupported mechanics

Supported: continuous source IO; a single Heat input; Heat/Matter/Ash outputs; actual static and resource-dependent modifiers; non-Essence resource-dependent sensitivities; partial-input start/stop; exact per-tick fractional accumulation/floor timing; thresholded decay/leak including the production stiff solver; all original statistics, discovery, peaks and related counters; native no-op initialization of disabled managers. Inactive cycles and level-zero controllers retain their native controller/bookkeeping behavior.

Exact fallback: enabled generator/upgrade automation, active/auto-run cycles, positive-level non-Heat consumers (including Mites), transfers/multi-input modes, Essence outputs/dependencies, populated relic inventory/equipment/machine slots, prestige planning, profiling/diagnostic simulation, unknown overriding scripts and external observers/logger clocks. The kernel is not advertised as supporting active Mite throttling, Forge/Crucible cycles, buyers, random crafting or prestige transitions. Their native behavior, including RNG and event ordering, is retained and tested through fallback.

The general kernel contains no generator IDs. Scope is based on actual definitions, IO and supported base-script contracts; the existing controller helper is delegated rather than copied. The permanent Heat upgrade lookup is the same built-in Eternal Furnace calculation used by native production. Future controller-specific adapters need reviewed contracts; changing a definition's semantics is not made safe merely by matching IO shape. Current implementation-source hashes are retained for that audit boundary.

## 6. Differential validation and invalidation tests

Single-tick, 10-, 100- and 2,000-consecutive-tick early tests compare every individual tick. The reached prefix-68 fixture contains the real first Matter output at tick 69. Diagnostic fixtures place stocks below/at/above leak and decay thresholds, near zero, in stiff/high production conditions and near the Thermic Mass join, and place phases at wrapping boundaries. A funded diagnostic purchases an actual threshold upgrade through native APIs; it is not counted as reachable performance coverage.

Per-tick views include binary resources/statistics and environmental counters, generator runtime/phase/unlock state, levels/upgrades, relic/technology/prestige state, log/signal histories, RNG seed/state, interval bookkeeping and structural caches. Final endpoints additionally use the original complete identity-aware checkpoint fingerprint. No numerical tolerance is used to pass kernel comparisons: required byte equality yields zero deviation. Benchmark numeric errors are also recorded explicitly. Trace collection is disabled for throughput.

Independent reentry cases cover level/pause/modifier changes, direct cached-modifier target edits, sensitivities, thresholds, phase-dictionary replacement, ResourceState replacement, output unlocks, real purchases, mode changes, relic inventory and automation/Mite activation. Existing-cache behavior is honored rather than corrected. Dynamic Matter sensitivity is evaluated per tick. Unknown manager overrides and external signal observers are explicitly rejected at packet construction. A live automatic-upgrade boundary exits and rebuilds. A transaction test captures through the existing compact checkpoint, runs the exact kernel across Matter output, rolls back, verifies the original complete state, and resumes against exact control.

Fallback tests retain real Forge completion and RNG-dependent crafting. A targeted native fallback completes a Forge and random Relic Crucible cycle, verifies changed RNG/inventory and compares all subsequent tick views. The complete regression suite also retains the previous transaction, critical-outcome and real-completion groups. No production checkpoint implementation is replaced.

## 7. Throughput and construction measurement

`exact_flow_benchmark.gd` alternates method order over four repetitions, excluding the first as warmup and reporting three comparable samples. It compares:

1. Authoritative Simulation.update(0.1,true).
2. Prebuilt isolated packet, including event checks, native event/fallback ticks and all live writes, excluding construction/reconstruction. No event is skipped to obtain isolated throughput.
3. Public exact kernel including construction, invalidation/release, event checks, native fallbacks and synchronization.
4. Existing core_investigation_runner as-is, balanced mode with the prior benchmark short-exact bypass set to zero.

The isolated packet is built before the timer; rebuild times at native automatic boundaries are explicitly subtracted for that isolated metric only. Public-kernel wall time includes all such work. Every method starts from the same reached fixture, prefix and offline statistics context. Setup/oracle snapshots are outside all timed regions. Ordinary profiling and per-tick kernel phase clocks are disabled in throughput samples. Separate intrusive phase-profile rows break out build, event check, kernel, fallback and release. Zero per-phase counters in ordinary rows mean **not collected**, not zero CPU cost.

The realistic longer early run is 36,000 ticks / one simulated hour. It retains all mechanics present in the reached save, without ablation, stock grants or feedback changes. Mid/Forge use 2,000 ticks and report actual coverage/fallback overhead. One- and ten-tick early runs show construction amortization. Retained packet allocation estimates use OS.get_static_memory_usage after build minus before constructor; they are not serialized size, exact allocator churn or RSS measurements. Shared scripts/definition memory is not charged as newly copied state.

The existing adaptive prototype remains a reference, not the kernel's oracle: its accumulated-elapsed endpoint clipping can differ slightly from constant 0.1 calls, and its TimeManager advances dormancy over the one-hour run. Those original behaviors and raw parity/error fields are preserved. This core-only kernel leaves that external context unchanged and is checked against the constant-tick authoritative control. The representative early fixture has no active dormancy-dependent producer, but metadata/context differences still matter to a full-state comparison.

## 8. Future opportunities and limitations

| Direction | Assessment |
|---|---|
| Modifier evaluation | Cached static factors and ordered dynamic suffixes demonstrably reduce interpreter/object work. Further pure-operator adapters could reduce dynamic lookup/call overhead; no formula approximation is needed. |
| Dependency graph | The current IO/tape and automatic blocker analysis are a starting point. Explicit read/write dependencies could support narrower invalidation and additional native controllers. No general graph compiler is implemented. |
| Statistics allocation/access | Live setters/counter calls remain substantial necessary work. Reviewed cached counter-slot adapters may reduce dictionary/function overhead while preserving insertion, peak and alias semantics. Not implemented. |
| Environmental math | Kept natively exact. It is small in the ordinary early window but can dominate stiff diagnostic states. Parameter caching requires a separately reviewed native evaluation contract; no replacement integrator is introduced. |
| Integer outputs/prefix composition | Every original floor occurs at the correct tick. This milestone does not skip or compose those events. A faster exact map is a safer oracle for future certified work, not a proof that aggregation now works. |
| Mites/automation/cycles/relics | Essential for mature-save coverage; current mid/Forge coverage is zero. Add reviewed exact multi-input/controller and event invalidation adapters before claiming full-game benefits. |
| C# / GDExtension | A native whole-packet loop may reduce remaining dispatch/dictionary overhead. Per-modifier language-boundary calls could erase gains. This is a projected option, not a measured result; no new language or runtime dependency is added. |

The early result indicates substantial removable GDScript traversal/dispatch overhead; the mathematical formulas did not need to change. Profiling cannot turn that into an exact percentage of pure math versus interpreter time. Broader Windows/client performance needs profiling on the actual save, UI/TimeManager context and build.

The user's Windows/Godot 4.7.2 observation—roughly 710,000 of 965,000 ticks in about 30 minutes—is not a controlled baseline and is not compared numerically with these Linux headless runs. This prototype is not integrated into that catch-up and does not accelerate unsupported mature fixtures. Linux Godot 4.6.1 results do not establish Windows Godot 4.7.2 compatibility.

## 9. Reproduction and retained artifacts

```sh
python tests/experimental/run_exact_flow.py --godot /path/to/godot
/path/to/godot --headless --path . --script tests/run_regression_tests.gd
```

The Python driver supports tests/profile/benchmark/all modes and treats nonzero exit, WARNING and ERROR as failures, with a process timeout. Raw files: kernel_profile_results.json, exact_flow_validation.json and exact_flow_benchmark_results.json. summarize_exact_flow.py regenerates the summary and measured-result tables from those raw records. The accompanying environment record contains source/log hashes and the actual engine/host identity. All profiling subclasses are experimental-only and disabled in throughput runs. No clean editor parse is claimed; game.gd:771 remains outside scope.

## 10. Final measured results

Linux x86_64, AMD EPYC 9V74, official Godot 4.6.1. Three measured samples per method after one excluded warmup. Each cell is median milliseconds (minimum–maximum). Samples alternate execution order; ranges describe observed stability, not confidence intervals.

| Fixture / ticks | Native exact | Isolated packet | Public kernel | Existing prototype | Kernel speedup | Kernel coverage |
|---|---:|---:|---:|---:|---:|---:|
| early / 1 | 0.371 (0.304–0.525) | 0.186 (0.182–0.466) | 0.835 (0.809–0.855) | 1.007 (0.754–1.014) | 0.444× | 100.00% |
| early / 10 | 1.506 (1.360–1.606) | 0.749 (0.664–1.066) | 1.181 (1.105–1.306) | 2.352 (1.732–2.791) | 1.275× | 100.00% |
| early / 2000 | 216.354 (212.543–217.484) | 108.412 (104.571–117.699) | 107.922 (106.289–110.130) | 230.856 (227.605–244.305) | 2.005× | 100.00% |
| early / 36000 | 4266.007 (4139.162–4387.965) | 2349.398 (2277.570–2547.326) | 2492.413 (2188.825–3033.324) | 4869.482 (4527.715–5047.764) | 1.712× | 100.00% |
| early_event / 2000 | 204.987 (203.251–248.542) | 106.231 (106.170–126.243) | 111.949 (103.584–127.331) | 281.323 (227.790–290.404) | 1.831× | 100.00% |
| forge_competing / 2000 | 773.718 (716.518–790.099) | 755.386 (725.733–760.941) | 704.374 (671.059–712.190) | 774.102 (716.446–780.386) | 1.098× | 0.00% |
| mid / 2000 | 244.172 (237.413–266.038) | 240.585 (237.092–261.217) | 248.206 (245.942–262.976) | 297.991 (256.001–303.212) | 0.984× | 0.00% |

The isolated and public loops are independently timed. Small inversions between their medians reflect run-to-run scheduling/cache noise; subtracting those medians does not measure setup cost. One-tick results are especially noisy and do not amortize construction. No mature-fixture speedup is claimed: they execute native fallback, their relative overhead/noise is reported, and their kernel coverage is zero.

| Fixture / ticks | Build median µs (public) | Release median µs | Additional retained packet bytes (estimate) | Kernel µs/tick | Exact fallback ticks |
|---|---:|---:|---:|---:|---:|
| early / 1 | 430 | 11 | 20708 | 835.00 | 0 |
| early / 10 | 449 | 9 | 20708 | 118.10 | 0 |
| early / 2000 | 375 | 42 | 20708 | 53.96 | 0 |
| early / 36000 | 619 | 42 | 20708 | 69.23 | 0 |
| early_event / 2000 | 444 | 47 | 20708 | 55.97 | 0 |
| forge_competing / 2000 | 223 | 0 | 0 | 352.19 | 2000 |
| mid / 2000 | 179 | 1 | 0 | 124.10 | 2000 |

No transaction capture/commit/rollback is needed on the accepted kernel path: this is deterministic exact execution, not a speculative candidate requiring replay. Transaction interoperability is validated separately. All in-place resource/statistics/phase synchronization is included in kernel tick time; no extra bulk write-back is performed.

The separate intrusive phase-profile rows in exact_flow_summary.json expose event checks, tick execution, fallback, build and release. These clock-instrumented timings are not used for throughput speedups.

| Native inclusive profiling (2,000 ticks), ms | Early | Mid | Forge |
|---|---:|---:|---:|
| generator_processing | 199.91 | 220.16 | 712.46 |
| available_operating_duration | 10.63 | 28.11 | 88.02 |
| input_consumption | 20.43 | 49.08 | 125.17 |
| output_production | 117.65 | 91.25 | 248.67 |
| production_rate_calculation | 64.31 | 38.23 | 164.23 |
| automatic_upgrades | 34.12 | 21.95 | 22.11 |
| generator_automation | 2.15 | 16.46 | 22.31 |
| upgrade_automation | 1.99 | 2.02 | 3.41 |
| heat_leak | 3.68 | 3.71 | 22.43 |
| matter_decay | 2.12 | 2.06 | 2.60 |
| cycle_generator_processing | 2.08 | 2.07 | 95.16 |

Generator processing dominates the major-phase profile. Output/rate and repeated modifier work are expensive in early gameplay; Forge also adds substantial input, availability and cycle work. These inclusive categories overlap. The detailed profile retains static/dynamic multiplier, sensitivity, fractional-phase accessor, statistics, history and signal measurements; it approximately doubles Forge runtime and therefore is not a throughput baseline.

| Detailed early probes / 2,000 ticks | Calls (median) | Inclusive ms (median) |
|---|---:|---:|
| generator/get_input_consumption_per_second | 12000 | 23.144 |
| generator/get_modifier_sensitivity | 40000 | 17.651 |
| generator/get_production_progress | 2000 | 0.973 |
| generator/get_production_rate | 10000 | 158.685 |
| generator/set_production_progress | 2000 | 0.868 |
| modifier/effective_dynamic | 14000 | 51.445 |
| modifier/effective_static | 26000 | 61.712 |
| modifier/raw_dynamic | 14000 | 22.167 |
| modifier/raw_static | 26000 | 11.625 |
| statistics/record_consumed | 6000 | 4.695 |
| statistics/record_produced | 24090 | 18.797 |
| statistics/update_highest | 20060 | 18.117 |

The real completion witness observed 1 signal(s), 2 µs in their handler(s), and 0 history writes taking 0 µs (detailed medians). Early throughput observed no signals/history events during that window; counters and peaks still execute.

**Correctness:** all kernel and isolated benchmark samples (including warmup and the one-hour run) have complete binary endpoint equality, discrete/RNG parity and zero measured resource/statistics deviation against the constant-tick control. Every-tick regression views pass, including thresholds, integer-output phases, automatic upgrade invalidation, rollback/resumption and fallback random outcomes. No tolerance was expanded. Baseline full suite: 91 passing groups. Final full suite: 92 passing groups, zero failures, parser warnings or runtime errors in final validation logs.

**Next milestone:** extend exact controller/multi-input and event invalidation contracts to the real mature fixtures, then profile a real Windows save with its TimeManager/UI context. Keep exact ordered ticks as the oracle. Current results justify reduced per-tick overhead in supported early gameplay; they do not establish full-game acceleration, approximate batching eligibility or Windows compatibility.
