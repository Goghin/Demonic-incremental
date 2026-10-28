# Exact ordered kernel: native generator and upgrade automation

Base: `caadfe6360795b2f294777a9b0c3d4ecda501ef9`, branch `feature/cycle-auto-run`. All implementation changes are under `tests/`; production mechanics, costs, cooldowns and offline entry points are unchanged. This is an opt-in synchronous simulation-core experiment, not a production offline runner.

## 1. Authoritative tick order and automation semantics

Audited sources: `simulation/simulation.gd` (`update`, `update_automatic_upgrades`, both purchase APIs and upgrade-effect application), `Game/GeneratorAutomationManager.gd`, `Game/UpgradeAutomationManager.gd`, `Generators/generator.gd`, `Upgrades/UpgradeSystem.gd`, `Upgrades/upgrade_effect.gd`, `game_state.gd` resource/discovery/accounting methods and the existing packet/controller implementation.

Each authoritative `Simulation.update(0.1, true)` does:

1. Read tick-start Heat; reconcile interval and realm bookkeeping.
2. Apply eligible automatic upgrades in the native registry order, including effects/unlocks and automatic-index invalidation.
3. Evaluate the Eternal Furnace multiplier and process generators in registration order. Controller updates, availability, sequential input consumption, outputs, fractional floors and accounting retain the consumer milestone's exact order.
4. Apply native Matter decay, including Heat conversion, then native Heat leak using tick-start Heat.
5. Run native **generator automation**, then native **upgrade automation**.
6. Perform the native offline interval bookkeeping.

New levels/effects bought in step 5 influence the next tick's production, never preceding production in the same tick. A newly satisfied automatic requirement is evaluated at the following tick header. A generator purchase can reduce the resources available to an upgrade buyer later in the same tick. Matter-decay conversion can fund purchases before automation. No purchase checks are skipped or combined across elapsed time.

### Generator buyers

Enabling starts the full initial cooldown and clears waiting; disabling clears waiting and sets its timer to zero. Native cooldown is `max(0.5, 5.0 * pow(0.8, permanent_upgrade_level))`. Native offline enabled IDs preserve `AUTOMATABLE_GENERATOR_IDS` order. Enabled/unlocked technology and generator checks remain native.

A cooling buyer decrements its timer with the original floating-point operations; its native loop retains overshoot on successful purchases. A failed attempt leaves timer zero, enters `waiting_for_resources`, caches cost metadata and stops consuming that update's remaining delta. A waiting buyer checks once per update; it remains ready while unaffordable, and a successful waiting purchase starts a full new cooldown without carrying the waiting delta into it.

The waiting cache stores cost/resource, level, mode ID, modifier count and realm-cost multiplier. It refreshes using the existing native predicate and confirms affordability with `Simulation.can_buy_generator` before buying. Native upgrade application invalidates waiting resource IDs so a cost reduction can enable a purchase on the next tick. The kernel never replaces that cache or its invalidation logic.

### Upgrade buyers

Enabling starts the native 10-second cooldown. A failed scan leaves timer zero so the buyer scans on the next update without another cooldown; success starts the full cooldown. Cooling success retains native overshoot; ready-at-entry success gets a full cooldown. Tree order is Atomic Friction, Molecular Agitation, thermal furnace, Lava Mites, matter furnace, thermal compressor, then general. Within a tree the native upgrade registry insertion order determines priority. Requirements, visibility, maximum levels, selected exclusive preferences, resources and native costs determine eligibility. General filtering excludes automatic upgrades and the Infernal Forge strip. Native purchase APIs apply effects and account for costs; no second purchase implementation exists.

Pure checks include affordability, requirement and cache predicates. Timer changes, waiting/cache updates, enabled-index maintenance, resource debits, levels, effects, unlocks, discovery/statistics, native signals and purchase histories are state mutations. Only the latter structural changes require packet reconstruction; the native manager state remains live throughout.

## 2. Automation boundary and structural invalidation

`exact_flow_automation.gd` provides a small experimental boundary contract, not a controller or purchase framework. `Packet.build` determines whether any buyer is enabled. The no-buyer path avoids per-tick log watermarks. Both native managers still execute in their authoritative position in either case.

For enabled automation, immediately before **both** native managers the packet records the owned `TickLog.events.size()`. After both return, a changed length marks the packet invalid. The kernel finishes that tick's offline bookkeeping, releases the packet and rebuilds before the next production/header. It does not insert an unnecessary native tick for a supported purchase. Multiple purchases in one tick cause one invalidation. A direct packet caller must obey `event_due()`; stepping an already invalidated packet asserts. Packets are one-shot builds and never survive a public `Kernel.run` return.

Why this narrow witness is sufficient in the admitted execution scope:

- Exact native `Simulation.buy_generator` always appends a purchase after all successful effects, including activation without level increment. Failed affordability/recipe checks do not make structural changes in admitted states.
- Exact native `buy_upgrade` increments level and applies **all** effects before appending its purchase. Unlock events may append sooner; any append is conservatively sufficient. Effects can add modifiers/sensitivities, unlock generators/IO/modes, update dormancy parameters or register cycle effects. None can continue through the old tape after this boundary.
- Cooldown changes, waiting/cost-cache maintenance, failed checks and enabled-index refreshes do not mutate resource-flow configuration or append a purchase. They need no rebuild.
- Automatic upgrades occur separately at the header. The original `event_due()` checks their live resource requirements; an eligible automatic boundary executes a **whole native tick**, then reconstructs. Non-resource requirements blocked at construction cannot change silently: a qualifying purchase invalidates the packet first.
- Base GameState discovery setters only update discovery and statistics; they do not apply configuration effects. Generator processing and environment accounting retain the previous exact contract.

The witness relies on exact admitted scripts and an append-only owned in-memory TickLog with no valid clock. This is not a promise that an arbitrary gameplay logger is a mutation journal. Added automation guards reject custom effect scripts and operation-mode scripts, including dormant purchase targets. Existing guards reject custom simulations/managers/upgrades/requirements/resources, unsupported cached dependencies, external signal callbacks, clock/logging integrations and profiling/prestige boundaries. Owned signal journaling is permitted and its event order is compared. No production counter or global bookkeeping was added. Future native purchase/effect changes must retain the append-after-effects witness or introduce a reviewed explicit invalidation boundary; matching a base script path does not replace auditing a changed implementation.

Resource balances, phases, statistics, cooldowns and manager dictionaries remain the original objects. Packet tapes/reference arrays are derived and released after invalidation; no authoritative object is replaced and no bulk write-back occurs. Live resource changes, native controller throttling and sensitivity evaluation do not invalidate ordinary structure. Mode/level/definition/enable/disable/preference edits by the caller are handled by reconstruction on every public entry. Yields/concurrent edits during an exclusive call remain unsupported.

If a purchase enables an unsupported output, modifier, cycle or transfer, the following build refuses it and the remainder of that public call executes natively. A later public call can reconsider eligibility. Tests explicitly purchase an Essence output, require exactly one kernel tick followed by native fallback, and verify ordinary fallback/resumption across separate public calls.

## 3. Fixtures and exact differential validation

The original early, consumer-stage, mid and Forge snapshots are unchanged. In particular, the original mid's enabled Atomic Friction autobuyer, prices, cooldowns and stocks are unchanged. It is naturally unable to buy during the tested intervals: it reaches a genuine failed attempt and many waiting checks while resource feedback and Lava Mites continue. Lack of purchases is measured, not removed by funding it.

`automation_progression_builder.gd` creates an additional legitimate upgrade-automation fixture. Starting from the original Forge snapshot, it performs 33 recorded legal player actions and native ticks, follows the source ledger's purchase/pause strategy, completes real Forge cycles and earns a real prestige reward. After 33,551 ticks, reward 8 raises Eternal Flames from 8 to 16, prestige count to 9 and lifetime Crystallized Flame to 11. The earned technology permits both buyers to be enabled through their checked native APIs. The player saves Heat by pausing condensation, using the source policy's normal pause action; Lava Mites and both buyers remain active. No stocks, prices, cooldowns or earned effects are edited. `automation_progression.json` records the policy/actions and entry/2,000-native-tick-settled saves. Save loading restores enabled buyers with native initial cooldowns, as in the existing fixtures; save files do not pretend to preserve unsaved runtime timers.

The entry interval includes successful purchases and production feedback. The settled interval includes long waiting. Neither replaces the unchanged original mid benchmark. They are progression-reachable core intervals, not proof of arbitrary mature-game acceleration.

Controlled diagnostics are clearly separate: initial 5/10-second cooldowns, production-funded and decay-funded purchases, generator-versus-upgrade competition, two-generator competition, reversed registry/tree priority, dependent upgrades, effect/sensitivity/threshold application, cost-cache invalidation, next-header automatic unlock, no-level activation, general-tree filtering, unsupported Essence unlock and repeated purchases. These use small explicit definitions/stocks for edge isolation. `purchase_heavy` deliberately funds a paused generator and sets its actual configured permanent cooldown upgrade to maximum; this is a reconstruction stress test, never representative progression evidence. Ordinary prices/formulas remain native even there.

`automation_kernel_tests.gd` compares detailed binary state after **every tick**, with the original identity-aware whole-graph fingerprint at endpoints and before/after read-only packet construction. The view includes resources, accumulators, runtime phases, manager timers/waiting/cost caches/enabled indices, upgrade/unlock state, relic inventory, statistics, discoveries, histories, RNG, modifiers/sensitivities/event effects and simulation cache bookkeeping. Diagnostics assert concrete purchase ticks/order and next-tick boundaries, not just end balances. External-call tests change enable state, preference and supported/unsupported modes and require exact fallback/resumption. Existing transaction, ordered-flow, consumer, throttle, Forge-completion and RNG tests remain in the full suite; no tolerance is widened.

Full validation: **94 regression groups passed, zero failures, parser warnings or runtime errors**. All 93 pre-existing groups remain registered and pass. `automation_kernel_regression.log` retains the complete output; dedicated fixture, differential and benchmark logs are adjacent. Real Forge completion and RNG-dependent outcomes remain covered by the unchanged existing groups.

## 4. Benchmark method and telemetry

Run on Linux with official Godot **4.6.1.stable.official.14d19694e**. `automation_kernel_environment.json` records the actual host, hashes and validation commands. This does **not** establish Windows Godot 4.7.2 compatibility. The existing editor-only `game.gd:771` issue is untouched; these runs invoke headless script entry points without an editor import.

Reproduction from the repository root:

```sh
python tests/experimental/run_automation_kernel.py --godot /path/to/godot --mode fixtures
python tests/experimental/run_automation_kernel.py --godot /path/to/godot --mode tests
python tests/experimental/run_automation_kernel.py --godot /path/to/godot --mode benchmark
python tests/experimental/summarize_automation_kernel.py
/path/to/godot --headless --path . --script res://tests/run_regression_tests.gd
```

Fixture regeneration is optional and separate from timed runs. The driver treats parser warnings/runtime errors as failures. Benchmark and full regression processes run serially. Each scenario runs native, archived public/isolated, extended public/isolated and adaptive reference from identical deterministic states; reverse method order on alternating repeats, discard the first warmup and report three-run medians and min–max. Original whole-graph equality is checked **after** timing every non-adaptive method. Approximate adaptive results remain a reference, never the equality oracle. The archives reproduce `caadfe63` exactly except the old kernel's packet preload path; normalized source hashes are verified.

Public time includes initial construction, event checks, native automation, accounting, invalidation, reconstruction and fallback. Isolated time excludes initial construction and explicitly subtracted reconstruction, retaining native automatic boundary ticks. Its dispatch differs from public dispatch; differences between medians are not a setup-cost estimator. Independent intrusive runs measure construction/release/kernel/native/event-check microseconds and flows. No checkpoint, commit, rollback or approximate resource batching is used.

Native-only telemetry probes delegate to the actual manager methods. Attempt failures count actual `_attempt_purchase` calls, while unaffordable cached waiting checks are counted separately. Waiting-cache refreshes count actual predicate refreshes. Upgrade waiting checks count attempts with timer ready at update entry; cooldown-expiry scans are separate. Timer-decrement and positive-to-zero transitions are counted from native before/after timers; purchases retain their native reset semantics. Probes are refused by the kernel and never used in throughput. Dedicated every-tick instrumentation/control tests and full-interval endpoint checks prove the counters do not change gameplay. Successful-purchase totals can exceed structural invalidation ticks when both managers buy in one tick.

Packet memory is estimated by `OS.get_static_memory_usage()` before/after isolated construction, excluding the existing state and history. It measures a retained engine allocation delta, not exact heap footprint, peak churn or process RSS. Build counts include refused build attempts. Build/release counts and source inspection explain additional allocations: one enabled scan and two packet booleans; no per-tick signature dictionaries, no copies of state, no new manager caches. Purchase ticks allocate reconstructed IO/rate tapes and native effect/history objects. No-purchase ticks add two O(1) log-size reads; native purchase/waiting work remains mandatory. Full raw rows, flow/controller counters, blocker inventories and instrumentation results are retained in the benchmark/validation JSON files.

## 5. Remaining scope and next experiment

Enabled native generator and upgrade buyers are supported. Purchase-heavy operation may lose the kernel advantage because every successful tick reconstructs; measured stress results below must be retained even if slower. Failed/waiting intervals should need no structural churn. Early/consumer performance is compared with the archived kernel in the same environment, not the previous Windows results; the min–max ranges limit attribution of small differences.

Original Forge still has an active Infernal Forge cycle and zero kernel coverage. Automation is no longer an independent rejection; its initial/final blocker inventory identifies cycles separately. Existing relic inventory/equipment, Essence feedback/output, resource transfers, active/auto-running cycles, prestige planning, arbitrary observers/loggers and TimeManager integration remain unsupported. No Forge acceleration is claimed for fallback-only measurements. Fixed dormancy state remains the consumer contract; advancing external dormancy clocks is not implemented.

Measured end-to-end interpretation: original mid improves from zero coverage to 99.900% at 2,000 ticks and 99.980% at 10,000, at 1.468× and 1.344× native speed. Only two automatic-header ticks need native execution. The reached entry performs 5 generator and 9 upgrade purchases across 12 invalidation ticks, with 15 rebuilds (16 build attempts including initial), three native header ticks, and 1.263× public speedup. Settled progression retains both buyers, has no purchases during 10,000 ticks, and reaches 100% coverage with one build and 1.180× speedup. This supports both purchase and long-wait behavior without artificial funding.

Early speedups remain 1.803× / 1.828× at 2,000 / 36,000 ticks. Against the archived kernel in this environment, the short early median is **7.63% slower**, with non-overlapping three-sample ranges; the longer median is 9.46% faster with overlapping ranges. The implementation adds invalidation checks/branches even with buyers disabled; runtime scheduling variation also appears throughout these GDScript samples. These measurements cannot attribute the entire difference, and the short regression is not hidden. Consumer-stage medians are 1.873× / 1.383× native, with -9.40% / +5.42% runtime change versus the archive and overlapping ranges. All preserve the original native speed advantage; no claim of uniform improvement over the prior kernel is made.

The deliberately purchase-heavy diagnostic achieves 100% kernel coverage but only 0.777× native speed (28.74% slower). Its 123 native successes invalidate 123 ticks, resulting in 124 total build attempts and 6.783 ms of construction in the separate phase-clock run. Isolated execution is cheaper than public execution, exposing reconstruction overhead. This is a concrete remaining limitation, not grounds for weakening invalidation or skipping checks. Native upgrade registry scans and waiting checks also remain per tick: the reached entry makes 999 failed upgrade scans and the settled long interval makes 9,900. This mandatory work limits attainable throughput even without reconstruction; a later profile can evaluate cheaper native-equivalent indexing or selective tape rebuilding separately. Forge's fallback-only timing ratios reflect scheduling/loop variance, not Forge acceleration; both the old and new kernels execute all its production natively.

The next scoped experiment should be **exact native cycle-generator execution with explicit phase/completion invalidation**, starting with Infernal Forge. Automation now removes the original mid blocker; cycles remain the independent original Forge blocker. Completion-time rewards, RNG, critical snapshots, auto-run costs and event callbacks need their own audited boundary. Relics/Essence and TimeManager remain subsequent capabilities. This work does not implement any of them or establish full-client/offline speedups.

<!-- MEASURED_RESULTS -->

## Measured results

Milliseconds below are medians of three measured runs; one preceding warmup per method/scenario is excluded. Ranges are measured min–max, not confidence intervals.

| Fixture / ticks | Native ms | Previous public ms | Extended public ms | Adaptive reference ms | Speedup vs native | Kernel coverage |
|---|---:|---:|---:|---:|---:|---:|
| early / 2000 | 197.546 | 101.782 | 109.543 | 229.723 | 1.803× | 100.000% |
| early / 36000 | 4433.242 | 2679.037 | 2425.636 | 5201.631 | 1.828× | 100.000% |
| consumer_50000 / 2000 | 369.516 | 217.741 | 197.273 | 331.592 | 1.873× | 100.000% |
| consumer_50000 / 10000 | 1493.213 | 1024.201 | 1079.697 | 1739.013 | 1.383× | 100.000% |
| mid / 2000 | 305.336 | 375.841 | 207.997 | 339.704 | 1.468× | 99.900% |
| mid / 10000 | 1662.004 | 1818.648 | 1237.046 | 1737.788 | 1.344× | 99.980% |
| reached_entry / 2000 | 333.640 | 334.196 | 264.185 | 329.902 | 1.263× | 99.850% |
| reached_settled / 10000 | 2099.717 | 2229.799 | 1779.038 | 2404.416 | 1.180× | 100.000% |
| forge_competing / 2000 | 957.594 | 784.247 | 819.530 | 867.601 | n/a (native fallback) | 0.000% |
| waiting / 2000 | 27.426 | 28.463 | 22.940 | 22.789 | 1.196× | 100.000% |
| effects / 2000 | 62.766 | 67.413 | 34.347 | 120.027 | 1.827× | 100.000% |
| purchase_heavy / 2000 | 25.585 | 27.572 | 32.939 | 42.410 | 0.777× | 100.000% |

| Fixture / ticks | Previous public range ms | Extended public range ms | Runtime change vs previous | Previous isolated ms | Extended isolated ms | Previous / extended retained packet bytes (estimate) |
|---|---:|---:|---:|---:|---:|---:|
| early / 2000 | 100.811–105.751 | 109.440–110.851 | +7.63% | 108.937 | 103.984 | 22988 / 23100 |
| early / 36000 | 2373.857–2760.589 | 2406.862–2506.898 | -9.46% | 2423.700 | 2522.448 | 22988 / 23100 |
| consumer_50000 / 2000 | 190.081–244.514 | 189.583–212.225 | -9.40% | 221.226 | 215.271 | 19824 / 19936 |
| consumer_50000 / 10000 | 1010.631–1096.678 | 1011.723–1083.665 | +5.42% | 1051.724 | 1021.056 | 19824 / 19936 |
| mid / 2000 | 239.777–390.994 | 202.156–239.961 | -44.66% | 279.396 | 195.522 | 0 / 23172 |
| mid / 10000 | 1591.606–1849.732 | 1216.215–1239.594 | -31.98% | 1828.900 | 1363.497 | 0 / 23172 |
| reached_entry / 2000 | 314.443–340.793 | 237.956–288.109 | -20.95% | 319.094 | 241.690 | 0 / 7744 |
| reached_settled / 10000 | 2153.173–2262.507 | 1717.496–1843.922 | -20.22% | 2271.124 | 1782.439 | 0 / 19960 |
| forge_competing / 2000 | 756.337–975.995 | 767.966–1059.048 | +4.50% | 801.841 | 810.197 | 0 / 0 |
| waiting / 2000 | 28.322–33.635 | 22.157–26.096 | -19.40% | 26.965 | 22.902 | 0 / 5064 |
| effects / 2000 | 61.321–86.260 | 32.688–38.324 | -49.05% | 64.125 | 33.196 | 0 / 7424 |
| purchase_heavy / 2000 | 27.452–28.561 | 28.924–33.419 | +19.47% | 26.961 | 23.374 | 0 / 5064 |

Separate intrusive phase-clock runs (excluded from throughput medians):

| Fixture / ticks | Kernel / native ticks | Builds (rebuilds = builds − 1) | Purchase invalidation ticks | Automatic header ticks | Build µs total | Release µs total | Kernel µs total | Native µs total |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| early / 2000 | 2000 / 0 | 1 | 0 | 0 | 350 | 55 | 106218 | 0 |
| early / 36000 | 36000 / 0 | 1 | 0 | 0 | 605 | 63 | 2344842 | 0 |
| consumer_50000 / 2000 | 2000 / 0 | 1 | 0 | 0 | 362 | 86 | 213897 | 0 |
| consumer_50000 / 10000 | 10000 / 0 | 1 | 0 | 0 | 413 | 55 | 1062811 | 0 |
| mid / 2000 | 1998 / 2 | 3 | 0 | 2 | 2775 | 257 | 183939 | 468 |
| mid / 10000 | 9998 / 2 | 3 | 0 | 2 | 1327 | 143 | 1095192 | 453 |
| reached_entry / 2000 | 1997 / 3 | 16 | 12 | 3 | 5671 | 555 | 241096 | 758 |
| reached_settled / 10000 | 10000 / 0 | 1 | 0 | 0 | 549 | 122 | 1692556 | 0 |
| forge_competing / 2000 | 0 / 2000 | 1 | 0 | 0 | 861 | 4 | 0 | 761183 |
| waiting / 2000 | 2000 / 0 | 1 | 0 | 0 | 496 | 28 | 23499 | 0 |
| effects / 2000 | 2000 / 0 | 5 | 4 | 0 | 778 | 68 | 36325 | 0 |
| purchase_heavy / 2000 | 2000 / 0 | 124 | 123 | 0 | 6783 | 480 | 21284 | 0 |

Native-manager telemetry comes from separate, verified-equivalent diagnostic executions, never the timed optimized path:

| Fixture / ticks | Generator success / failed attempts | Generator waiting checks / cache refreshes | Generator cooldown decrements / ready transitions | Upgrade success / failed attempts | Upgrade waiting checks | Upgrade cooldown decrements / ready transitions |
|---|---:|---:|---:|---:|---:|---:|
| early / 2000 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 | 0 / 0 |
| early / 36000 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 | 0 / 0 |
| consumer_50000 / 2000 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 | 0 / 0 |
| consumer_50000 / 10000 | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 0 | 0 / 0 |
| mid / 2000 | 0 / 1 | 1949 / 0 | 51 / 1 | 0 / 0 | 0 | 0 / 0 |
| mid / 10000 | 0 / 1 | 9949 / 0 | 51 / 1 | 0 / 0 | 0 | 0 / 0 |
| reached_entry / 2000 | 5 / 2 | 1698 / 6 | 298 / 2 | 9 / 999 | 998 | 994 / 2 |
| reached_settled / 10000 | 0 / 1 | 9949 / 0 | 51 / 1 | 0 / 9900 | 9899 | 101 / 1 |
| forge_competing / 2000 | 0 / 1 | 1949 / 0 | 51 / 1 | 0 / 0 | 0 | 0 / 0 |
| waiting / 2000 | 0 / 1 | 1999 / 0 | 0 / 0 | 0 / 0 | 0 | 0 / 0 |
| effects / 2000 | 0 / 0 | 0 / 0 | 0 / 0 | 4 / 1599 | 1599 | 398 / 1 |
| purchase_heavy / 2000 | 123 / 0 | 0 / 0 | 1877 / 0 | 0 / 0 | 0 | 0 / 0 |

Binary/discrete/RNG parity: **192/192** archived/current public/isolated samples including warmup; all numerical error fields zero. Dedicated automation differential suite: **32920** individual tick comparisons, plus reentry and diagnostic-instrumentation parity. Full original graph fingerprints match at endpoints. No tolerance was widened.
