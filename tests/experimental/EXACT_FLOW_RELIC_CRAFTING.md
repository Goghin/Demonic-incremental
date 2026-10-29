# Exact kernel: native Relic Crucible crafting

Starting/inspected HEAD `182e562d4fddea47f405042e081893b82861e97f`, existing branch `feature/cycle-auto-run`. Initial tracked tree clean; unrelated untracked files are preserved. Changes stay under `tests/`.

## Authoritative architecture and lifecycle audit

Sources reviewed: `simulation/simulation.gd`, `Generators/generator.gd`, `RelicShardExtractor.gd`, GameState registration, RelicManager, RelicGenerationManager, gameplay_random, both automation managers, permanent cycle technologies/slot upgrades, requirements, save/load, equipment UI locks, current exact packet/cycle/equipment contracts, prior technical reports, fixtures and regression tests.

GameState configures the factory as **Relic Crucible**: level starts at 1; IO does not scale with level; no mode increments level on activation. Separate native level purchases cost 100 Matter times 1.25 per purchased level, max level 41. A level adds 0.005 to random-relic critical probability, capped at max(0.25, mode base). The base activation cost is 10 Matter with level scaling 1.0 and mode multiplier 1.0; native realm, COST and COST_SCALING modifiers are still evaluated through get_cost. Costs are consumed/accounted through native APIs, not reserved or refunded later.

| Mode | Startup recipe | Duration | Per-second input | Native completion |
|---|---|---:|---|---|
| Extraction / normal | none | 60 s | 100/60 Matter | 1 Relic Shard |
| Recycle Relic | one selected relic | 30 s | none | 3 Relic Shards |
| Combine Shards | 10 Relic Shards | 20 s | none | 1 Greater Relic Shard |
| Forge Relic | 10 Relic Shards | 90 s | none | requested tier 1, 5% base promotion chance |
| Forge Greater Relic | 5 Greater Relic Shards | 180 s | none | requested tier 2, 5% base promotion chance |

Startup (`Simulation.buy_generator`): validate generator/unlock/no active cycle, check every indexed machine-slot recipe requirement, compute affordability, consume native recipe, debit/account Matter, apply native activation level rule, reset progress, snapshot native effective crafting critical chance, set cycle_active and append purchase history. Recipe consumption removes or decrements native inventory entries and machine-slot mappings. There is no second recipe calculation in the kernel.

Tick order: tick-start Heat/bookkeeping, automatic upgrades, registered generators in original order; each native controller update precedes cycle execution. Crucible follows Forge in native registration. Then Matter decay/Heat conversion, Heat leak, generator automation, upgrade automation and offline bookkeeping. A preceding Forge can spend Heat, produce CF/Ash, roll RNG and emit events before Crucible completion; the shared draw order must remain unchanged.

Non-auto offline cycle handling is native: restart operating only if native conditions pass; read current duration; evaluate pre-input speed and remaining-time/speed; clamp requested delta to 0.1 s; calculate partial input duration; consume sequential inputs, produce ordinary outputs, then reevaluate speed for progress. Complete at native duration minus 1e-6, or stop operating after partial exhaustion. Crucible extraction can starve/recover; recipe modes have no ongoing resource inputs after startup. Dynamic speed must not be frozen at startup. A manually paused already-operating non-auto cycle follows the existing native path; no pause behavior is repaired here.

Completion (`Simulation.complete_cycle`): resolve native trigger events; resource completion outputs/modifiers/events first; native item outputs next; native random-relic generation and insertion next; emit native crafting notification; apply native completion consequences; reset active, operating, progress and critical snapshot. Native item rewards merge existing stacks (including machine-owned stacks), create new instance IDs/positions and expand beyond the initial 24 inventory squares. No inventory-full rejection or new capacity rule is introduced. Relic generation does not equip the reward or rebuild generator effects.

Auto-run requires both the generator flag and its native technology (Crucible unlock costs 45 permanent flames). Native offline remaining-delta handling performs startup, recipe/affordability checks, progress and completion/restart immediately at the generator position, consuming only actual elapsed operating time. A partially consumed machine stack can fund another craft; an absent recipe or unaffordable activation stops restart. There is no automatic inventory-to-machine refill. Both native automation managers lack a Crucible buyer; they continue their normal supported purchases after environmental effects.

There is no public craft-cancel/refund API in the audited implementation. Mode changes are locked while active. Pause/starvation, save/load and auto-run disable are actual supported interruption boundaries; test those instead of inventing cancellation.

## RNG audit

Random-relic generation uses `RelicManager._gameplay_rng`; normally it aliases `GameState.gameplay_rng`, also used by Forge events. Distinct native RNG instances are allowed and retained, never rebound or copied. Scripted manager RNGs are explicitly refused. The native generation manager must have its original script.

Crafting rarity is the requested mode tier plus critical promotion to the next configured tier, not a weighted tier roll. Tier metadata fixes bonus-stat count (0/1/2). Critical probability is snapshotted at startup; zero/one endpoints consume no critical draw, otherwise native sample_unit consumes one PCG word. Each primary/secondary effect selection uses one weighted sample_unit; strength uses native sample_range (normally three words, one on its exponent-zero early return); optional target choice uses native randi_range. Primary base-name selection uses randi_range; prefix/suffix placement comes from effect data, with no independent affix draw. Secondary count/excluded-group ordering is native. Native randi_range may use rejection, so a fixed total word count is not assumed.

Generated dictionaries retain full primary definition, name, rarity/color, roll, secondary/additional rolls, critical flag/requested tier, deterministic instance ID and position. Native insertion and notification names remain native, including their current display-name behavior. No generation, probability, naming, reward or RNG formula is duplicated. Complete graph comparisons and follow-on sequence checks are required, not merely name/rarity comparisons.

## Equipment and inventory boundary audit

Current permanent definitions provide **no Crucible equipment slot**. Native equip therefore rejects it even idle; no invented earned crafting-equipment fixture can be claimed. Companion generators can retain actual equipped relics while crafting. Native cycle-speed modifier execution can be probed diagnostically through native Modifier objects, without claiming a reachable Crucible slot.

Native equip rejects an active target cycle; UI also blocks unequip and drags from/into locked generator equipment. Machine ingredient slots are separately editable; startup-spent ingredients are not reserved there. Low-level RelicManager.unequip and some machine-slot APIs do not impose the same UI lock. Equip does not clear an existing machine-slot mapping; malformed/cross-owned aliases can therefore exist through low-level calls. These are preexisting native semantics, not repaired or newly restricted. The kernel exposes no inventory/equipment management API and delegates recipe/inventory work to native methods. A native recipe can remove an entry without rebuilding its old equipment-derived arrays; those arrays remain authoritative until the caller's native rebuild, exactly as in native execution.

The packet retains no inventory entry, position, machine-slot or equipped-slot dictionary. Inventory rewards/recipe spending alone do not change IO structure, native equipment arrays or any inventory-based automatic requirement (none exists). Thus no per-progress-tick inventory scan, copy or rebuild is needed. Native own-level changes retain existing structural invalidation. Public calls release packets; external edits/load/mode/level changes use fresh packets. External completion callbacks still force a whole native tick/interval, preserving same-tick callback order and enabling later public reentry.

## Implemented contract

`exact_flow_cycles.gd` has a small reviewed capability registry outside the general IO loop: resource-only Forge and inventory-capable Crucible. The Crucible capability validates native inventory/generation runtime and its actual RNG through `exact_flow_crafting.gd`. Existing mode/IO/resource/event-action validation is retained; unreviewed generators/events, custom runtimes/RNGs and external observers retain explicit fallback. Continuous recipe-bearing autobuyers remain unsupported. Native `update_cycle_generator` performs the entire lifecycle at the registration position; no cycle or generation engine is added.

The implementation and validation results are recorded below.

## Ownership, invalidation and supported scope

No packet field points to an inventory entry or slot dictionary. Native RelicManager retains the inventory array, entry dictionaries, positions, equipped maps, machine maps and monotonically increasing instance counters. Native recipe methods may decrement/remove entries or replace nested slot maps; reward methods append/merge entries in the authoritative structures. Equipment effects remain the existing native Modifier/ModifierSensitivity arrays until a native rebuild. The kernel does not infer equipment changes from inventory size, recompute rolls, delete dangling native aliases or force a rebuild after every reward.

The capability registry selects reviewed native cycle roles, not generator-specific formulas in the IO loop. All five current Crucible modes are handled through the same native lifecycle. Native manager/generation scripts and unscripted RNGs are required; recipe/reward dictionaries with non-scalar conversion/callback data are explicitly refused. The scope is native API/save-created inventory state in an isolated synchronous core. Arbitrary external callbacks and concurrent edits remain outside that contract.

A completion with unchanged configuration retains its packet. Inventory insertion itself cannot satisfy a new inventory-based automatic requirement, since current RequirementTypes only include resources, generator levels and upgrade levels/purchases. Source-owned level changes still invalidate; native automatic-upgrade boundaries and automation purchases retain their existing rebuild rules. A public return always releases the packet, allowing manual startup, ingredient moves/refill, mode changes, upgrades, equipment rebuilds and save/load before fresh execution. Native restart affordability/recipe checks remain live. An unsupported public interval remains native until return; reentry is reevaluated on the next call.

The live two-RNG diagnostic retains distinct native Forge/gameplay and crafting streams. Production saves serialize the gameplay stream; they do not introduce an additional private-stream save format. Default GameState construction binds the inventory manager to that stream; same-object load follows existing native reference behavior. Kernel execution neither replaces nor reseeds either RNG. Validation views now include both RNG seeds/states on every tick, in addition to the original graph identity checks.

## Fixtures and validation design

`relic_crafting_progression_builder.gd` continues the unchanged earned `automation_progression.json` settled state, pays native Reliquary/MA/Mite slot costs (5+3+5 permanent flames), receives/equips the actual native starter, and retains both enabled Atomic Friction autobuyers. Its legal purchase/pause policy starts native extraction, accumulates/spends actual shard recipes, then completes two native random crafts. The route takes **78,976 core ticks** and contains no resource, level, technology, roll or rarity grants. These are earned **native-core continuations**, not end-to-end TimeManager/client offline playthroughs. Native synchronous update(0.1, true) is the explicit time scope, as for existing progression fixtures.

Nine snapshots include the first affordable/activated Crucible in a native continuation of the unchanged early save, plus seven snapshots of the equipped post-prestige route: access, first extraction start, active extraction, first random craft, actual near-completion, repeated random craft and the state after two completions. The early branch waits for actual native production to reach affordability, without prior purchases or grants. This is the first affordable point of that saved continuation, not a claim about every possible first-realm policy. Both original buyers, live Mites and real resource feedback remain present. The action ledger and native saved RNG/inventory are retained in `relic_crafting_progression.json`. The existing snapshots/files are unchanged.

Other fixtures are controlled diagnostics: mode startup through native APIs; real durations and 5% probability; seeded critical/noncritical witnesses; Common/Uncommon/promoted Rare rewards and multiple rolled stats; repeated auto crafts using the actual technology and machine stacks; missing recipe, failed affordability, partial/exact exhaustion; live numeric speed modifiers; pause; stack overflow; inventory beyond 24 squares; both Forge/Crucible completions in registration order; separate RNG streams; Essence/Nexum/automation mixtures. Diagnostic resources, source levels/unlocks and auto technology are explicitly granted, never described as earned. The late mixed diagnostic retains active resource consumers, feedback and both cycle generators. The older canonical cycle diagnostic is save-loaded with a fixed saved visual palette; its original artificial stocks/paused flows make it a scope check, not representative performance evidence.

There is no earned equipped-Crucible fixture because no native slot exists. Earned crafting uses actual equipped companion generators. The speed diagnostic uses a native dynamic CYCLE_SPEED Modifier directly and is explicitly synthetic, without changing the production formula or claiming a legal equipment slot. Native UI lock methods, unlock on completion, ingredient moves while active, native level purchase without changing the current critical snapshot, and snapshot refresh at subsequent startup are checked at public boundaries.

Differentials capture the extended and archived previous kernel after every tick, comparing both to authoritative Simulation.update(0.1, true). Full original identity-aware graph checks cover admission nonmutation and endpoints; boundary tests compare full graphs immediately after each tick. Complete serialized relic properties and inventory state, not notification names alone, are included. Follow-on 128-word sequences are checked for both actual RNGs using private clones. No numerical tolerance is used for equality. Custom RNG/event/transfer/metadata patterns are rejected explicitly; native callbacks that equip rewards or purchase a level execute through fallback, then optimized execution resumes after disconnection.

The original 97 regression groups remain registered. Prior tests that asserted crafting must fall back now positively require admitted execution while retaining every native tick/RNG/reward assertion. The old unknown-cycle test uses an actually unreviewed cycle identity rather than the newly reviewed Crucible. The new regression group runs a representative critical Rare craft, repeated auto crafts, joint completion, an earned completion boundary and all adversarial boundary/profiler checks. The separate `run_all` retains the larger long-duration matrix; this avoids duplicating every long case inside the already large full regression suite.

## Benchmark methodology

The archived 182e562 kernel/packet/cycle/equipment scripts match Git source after archive preload remapping. Other execution helpers remain unchanged; the validation-only view records both RNG streams. Native, previous public kernel, extended public kernel and the existing adaptive reference receive identical deterministic starting states in the same process/host. The previous 27 scenarios are retained, with additional active/full-lifecycle/auto/critical/combined/earned crafting intervals. One warmup and three measured repeats alternate method order; min–max and medians retain all measured samples. A separate six-measurement confirmation covers selected regressions. The main run was interrupted after 23 complete scenarios; their full samples were retained and the remaining scenarios resumed on the same checked engine/CPU. No measured scenario was truncated or combined across the interruption. Resume only skips completed scenarios and runs outside all timed regions.

Fixture construction and lightweight runner initialization are outside timing, matching prior methodology. Public run timings include packet construction/release/rebuilds, native cycle processing, startup/restart within the interval, recipe spending, native generation/insertion/signals, accounting, automation and fallback. A manually prestarted fixture pays startup during fixture construction; auto-start/restart costs remain inside public runtime. The earned 600-tick interval stays within an actual craft; the 1,000-tick interval includes its completion. The 10,000-tick manual intervals contain post-completion idle time and are not presented as continuously crafting. No exact replay is used for runtime eligibility and no callback cost is subtracted.

Only throughput benchmarks run while no other Godot validation is active. Separate intrusive probes delegate to native Simulation/RelicManager/RelicGenerationManager methods. Inventory and RNG references are transferred unchanged into the probe, whose script is explicitly ineligible for optimized execution. Every-tick probe/control parity is checked independently. Timers report native item merge/insertion, recipe consumption, generation and encompassing random reward/completion costs. Random reward time minus nested generation time estimates insertion/copy/wrapper work; it is not an exact disjoint allocator profile. Nested timers must not be added again to their parent totals.

Packet memory is the engine static-memory retained delta around construction, an estimate rather than exact heap/peak usage. Inventory save-data byte counts are **serialized payload sizes**, not heap allocation. No extra inventory snapshot or definition copy is added by kernel execution; native generation retains its original necessary copies. Active/progress/no-progress tick counters distinguish actual crafting from paused/starved/post-completion intervals.

The adaptive reference owns a TimeManager and bounds its elapsed tail. It retains the earlier milestone's separately reported dormancy/numerical differences from fixed core ticks; its flags/deviations remain descriptive, not an exactness oracle. Repeated external equipment-change calls are outside its fresh-interval API and remain explicitly omitted for that diagnostic. Both exact kernels must match native whole graphs, events, phases, resources and both RNGs byte-for-byte.

Reproduction from repository root:

```sh
python tests/experimental/run_relic_crafting.py --godot /path/to/godot --mode fixtures
python tests/experimental/run_relic_crafting.py --godot /path/to/godot --mode tests
python tests/experimental/run_relic_crafting.py --godot /path/to/godot --mode regression
python tests/experimental/run_relic_crafting.py --godot /path/to/godot --mode benchmark
CRAFT_BENCH_CONFIRM=1 python tests/experimental/run_relic_crafting.py --godot /path/to/godot --mode benchmark
python tests/experimental/summarize_relic_crafting.py
```

The strict runner streams logs, rejects nonzero exits/errors/warnings/fatal messages, and allows up to two hours for the full reflection-heavy validation corpus. No editor import is performed and unrelated editor issues remain unchanged. Linux execution does not establish Windows 4.7.2 compatibility.

## Integration readiness: next study, not production replacement

The remaining boundary is primarily orchestration: external observers/logger clocks/filesystem side effects, prestige planning, custom runtimes/effects, unreviewed cycle identities and live TimeManager behavior. Supported native crafting inventory mutations are no longer an independent reason for fallback. Player equipment/inventory edits remain public-call boundaries; arbitrary interior callbacks still use native execution. Current reviewed resource/transfer, continuous controller, automation, Forge and crafting paths remain synchronous core capabilities.

Actual TimeManager.simulate_offline resets/binds its statistics and automation indexes; updates real offline/prestige clocks and stabilization before each step; writes dormancy penalty; advances scaled game time; then increments tick/progress counters. The final real/game step can be shorter than 0.1 s. It yields according to a frame work budget (or legacy 100-step schedule), emits final progress, and later resets current duration, configures recovery, updates timestamp and releases state.simulation_statistics. Core Kernel.run(ticks) deliberately does none of this. Calling run(1) repeatedly would preserve a public boundary but reconstruct a packet every tick and could lose the performance benefit.

The game connects crafting/Forge UI notifications and effects before offline processing, gathers achievements around the await, saves afterward and builds the results panel from TimeManager-owned statistics. Its current results resource list and inventory/toast paths are separate; inventory rewards must not be mistaken for ordinary resource production. External listeners currently force fallback. Native log clock evaluation occurs at its existing pre-/post-step position and cannot be replaced by end-of-batch timestamps. Save/load must refresh native effect/reference state and preserve the exact active chance snapshot; loading progress must remain monotonic and finish even for fractional/short intervals.

A separate **experimental TimeManager integration study** is the recommended next milestone: preserve real/game clock order, dormancy/recovery, statistics ownership, fractional tails, scale limits, stabilization boundaries, native event ordering and frame-yield scheduling while retaining packets only within an audited synchronous work slice. Audit notification/log observers before relaxing any guard; validate zero/short/long intervals, save/load, common frame checkpoints, rewards, achievements and RNG against native TimeManager. No production substitution, new event framework or external adapter is implemented here.

## Measured results

Final Linux validation uses Godot **4.6.1.stable.official.14d19694e**. The original pre-change suite passed 97/97 groups. The final complete suite passed **98/98**, retaining all 97 original registered groups and their numerical/event/RNG assertions. The new representative regression group compares 5,120 tick endpoints against both native and the archive, plus boundary, alias, observer, UI-lock and profiler tests.

The separate long suite passed **56,000 tick endpoints**, comparing both exact kernels to native (**112,000 byte comparisons**), across 26 controlled diagnostics and seven earned snapshots. Detailed tick views now include both actual RNG seeds/states as well as resources, phases, modes, equipment/inventory, effects, automation, statistics and event history. It also verifies 128 subsequent words for each RNG using private clones. Both actual distinct-stream and shared-stream fixtures pass. Complete generated definitions, tier/color/name, rolls, primary/bonus effects, critical/requested tier, IDs, positions and counters match exactly. All endpoint graph and read-only admission assertions pass without tolerances.

A production-probability 5% critical Greater craft produces an actual promoted Rare with both secondary bonuses. Repeated standard auto-run produces three native relics with identical serialized properties and RNG. Same-tick Forge and Crucible completions preserve native registration/signal order. The 45-tick boundary sequence includes native starvation/recovery, pause, active load, successful/failed startup, level purchase without changing the active chance snapshot, active ingredient transfer, auto restart failure/refill and public reentry. External callbacks equip a newly generated reward and purchase a level through native APIs while optimized execution falls back; reentry matches full native graphs. Native UI lock/unlock checks pass. The low-level equipped/machine alias diagnostic preserves native semantics through recipe deletion and later native effect rebuild.

The separate intrusive native profiler passes **3,000 every-tick comparisons** against uninstrumented native execution and retains inventory/RNG identities. It is explicitly refused as a kernel runtime. Both additional early-access snapshots pass 2,000 endpoints each against native and the archive, bringing the combined matrix to **60,000 endpoints / 120,000 exact-kernel byte comparisons**, excluding extra boundary/profiler checks. Their complete graphs and both 128-word follow-on RNG checks also pass. They were added after the long suite began; all seven earlier snapshots were verified unchanged.

Final regression/dedicated/smoke logs contain no parser warnings or runtime errors. During implementation an older unsupported-crafting expectation was migrated to a positive execution assertion, with its tick/RNG/reward checks retained; a diagnostic visual palette was canonicalized from the saved fixture to ensure identical initial graphs. Neither correction changes gameplay or widens numerical tolerances. No Windows 4.7.2 validation is claimed.

Performance tables are populated below from the retained matched samples.


## Changed-file guide

- Capability admission: `exact_flow_crafting.gd`, `exact_flow_cycles.gd`; equipment contract documentation: `exact_flow_equipment.gd`.
- Validation: `exact_flow_view.gd` (both RNG streams), `relic_crafting_tests.gd`, `run_relic_crafting_tests.gd`, and the new group in `tests/run_regression_tests.gd`. Existing exact/cycle/equipment tests retain their parity assertions and now recognize reviewed Crucible execution.
- Reproducibility: `relic_crafting_fixtures.gd`, `relic_crafting_progression_builder.gd`, `relic_crafting_progression.json`, `relic_crafting_benchmark.gd`, `crafting_native_probe.gd`, `run_relic_crafting.py`, `summarize_relic_crafting.py`, and four `baselines/exact_flow_182e562_*` scripts.
- Evidence: `relic_crafting_environment.json`, baseline/final/dedicated/boundary/early-access logs and validation JSON, benchmark raw samples and summaries. The quick benchmark is explicitly a smoke run, not the reported performance source.
- Documentation: this report and a forward link in `EXACT_FLOW_RELIC_EQUIPMENT.md`.

The production source, compact packet, resource-flow kernel, formulas, RNG/generation code and save format are unchanged. This milestone adds no checkpoints, approximation, runtime dependency or production integration.

## Matched performance results

Host: **INTEL(R) XEON(R) PLATINUM 8573C**, Linux x86_64, Godot 4.6.1. Values below are end-to-end medians in milliseconds (three measured runs after one warmup). Positive Δ previous means slower than the previous kernel. No samples/outliers were removed. Min/max and individual samples are retained in `relic_crafting_benchmark_summary.json` and `relic_crafting_benchmark_results.json`.

### Retained scenarios

| Fixture | Ticks | Native ms | Previous ms | Extended ms | Adaptive ms | Native speedup | Coverage | Δ previous |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| early | 2,000 | 316.73 | 172.15 | 155.46 | 342.21 | 2.04× | 100.000% | -9.69% |
| early | 36,000 | 6082.91 | 3208.38 | 3292.37 | 6855.17 | 1.85× | 100.000% | +2.62% |
| consumer_50000 | 2,000 | 409.91 | 268.63 | 256.40 | 442.64 | 1.60× | 100.000% | -4.55% |
| consumer_50000 | 10,000 | 2053.66 | 1330.55 | 1306.55 | 2262.32 | 1.57× | 100.000% | -1.80% |
| mid | 2,000 | 332.49 | 231.69 | 237.88 | 356.20 | 1.40× | 99.900% | +2.68% |
| mid | 10,000 | 2443.91 | 2085.10 | 2014.22 | 3238.03 | 1.21× | 99.980% | -3.40% |
| forge_competing | 2,000 | 1053.22 | 818.39 | 780.37 | 1184.22 | 1.35× | 100.000% | -4.65% |
| forge_competing | 10,000 | 5794.65 | 4502.98 | 4520.35 | 5852.29 | 1.28× | 100.000% | +0.39% |
| earned_essence | 10,000 | 5245.16 | 3800.49 | 4055.77 | 5967.43 | 1.29× | 100.000% | +6.72% |
| earned_feedback | 10,000 | 5431.94 | 3548.72 | 3376.77 | 6137.78 | 1.61× | 100.000% | -4.85% |
| passive | 2,000 | 693.17 | 410.74 | 414.31 | 741.63 | 1.67× | 99.950% | +0.87% |
| one | 2,000 | 906.61 | 645.82 | 555.74 | 868.45 | 1.63× | 99.950% | -13.95% |
| multiple | 2,000 | 977.10 | 936.86 | 645.06 | 1273.38 | 1.51× | 99.950% | -31.15% |
| input_compressor | 2,000 | 809.16 | 466.09 | 463.27 | 844.34 | 1.75× | 99.950% | -0.60% |
| sensitivity | 2,000 | 782.82 | 490.70 | 488.05 | 804.37 | 1.60× | 99.950% | -0.54% |
| forge_critical | 2,000 | 615.13 | 339.16 | 352.78 | 586.21 | 1.74× | 99.950% | +4.02% |
| forge_speed | 2,000 | 556.14 | 319.47 | 308.21 | 592.64 | 1.80× | 99.950% | -3.52% |
| forge_sensitivity | 2,000 | 602.93 | 337.61 | 325.48 | 602.57 | 1.85× | 99.950% | -3.59% |
| forge_completion | 2,000 | 649.45 | 339.60 | 361.62 | 602.83 | 1.80× | 99.950% | +6.48% |
| forge_auto | 3,000 | 1533.98 | 1086.77 | 1105.07 | 1451.12 | 1.39× | 99.967% | +1.68% |
| essence_relics | 2,000 | 701.06 | 489.42 | 466.65 | 905.96 | 1.50× | 99.950% | -4.65% |
| nexum_relics | 2,000 | 1107.47 | 560.81 | 658.07 | 1364.73 | 1.68× | 99.950% | +17.34% |
| relic_heavy | 2,000 | 843.75 | 531.79 | 517.29 | 880.51 | 1.63× | 99.950% | -2.73% |
| reached_one | 10,000 | 3296.12 | 2703.65 | 2629.93 | 3662.42 | 1.25× | 100.000% | -2.73% |
| reached_multiple | 10,000 | 3674.97 | 3192.96 | 2884.36 | 3894.56 | 1.27× | 100.000% | -9.67% |
| equipment_changes | 2,000 | 922.72 | 611.86 | 603.36 | omitted | 1.53× | 99.950% | -1.39% |
| crafting | 2,000 | 816.78 | 749.93 | 477.18 | 815.71 | 1.71× | 99.950% | -36.37% |

### Additional crafting scenarios

| Fixture | Ticks | Native ms | Previous ms | Extended ms | Adaptive ms | Native speedup | Coverage | Δ previous |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| idle | 2,000 | 811.32 | 490.95 | 485.96 | 840.55 | 1.67× | 99.950% | -1.02% |
| extraction | 2,000 | 833.89 | 989.69 | 644.49 | 1073.82 | 1.29× | 99.950% | -34.88% |
| forge_standard | 2,000 | 816.87 | 814.62 | 575.79 | 1054.42 | 1.42× | 99.950% | -29.32% |
| critical_standard | 2,000 | 803.19 | 952.01 | 558.68 | 1029.89 | 1.44× | 99.950% | -41.32% |
| critical_greater | 2,000 | 894.63 | 879.01 | 529.14 | 872.23 | 1.69× | 99.950% | -39.80% |
| combine | 2,000 | 1467.13 | 1515.28 | 960.85 | 1745.94 | 1.53× | 99.950% | -36.59% |
| recycle | 2,000 | 1093.82 | 796.87 | 501.77 | 832.55 | 2.18× | 99.950% | -37.03% |
| auto_standard | 3,000 | 1271.53 | 1259.04 | 803.82 | 1276.77 | 1.58× | 99.967% | -36.16% |
| auto_extraction | 3,000 | 1376.86 | 1365.16 | 868.20 | 1375.33 | 1.59× | 99.967% | -36.40% |
| auto_no_matter | 3,000 | 1220.61 | 1235.50 | 809.85 | 1338.96 | 1.51× | 99.967% | -34.45% |
| automation | 2,000 | 910.74 | 947.05 | 677.53 | 1081.24 | 1.34× | 99.950% | -28.46% |
| forge_together | 2,000 | 978.00 | 842.53 | 551.20 | 703.03 | 1.77× | 99.950% | -34.58% |
| separate_rng | 2,000 | 1615.11 | 807.19 | 554.00 | 785.93 | 2.92× | 99.950% | -31.37% |
| full_inventory | 2,000 | 928.03 | 870.71 | 507.27 | 870.67 | 1.83× | 99.950% | -41.74% |
| stack_overflow | 2,000 | 1587.16 | 947.45 | 570.41 | 906.08 | 2.78× | 99.950% | -39.80% |
| canonical_cycles | 2,000 | 801.94 | 599.75 | 374.65 | 413.65 | 2.14× | 99.950% | -37.53% |
| late_mixed | 2,000 | 858.10 | 834.70 | 556.24 | 897.71 | 1.54× | 99.950% | -33.36% |
| earned_craft_first_craft | 600 | 225.55 | 232.47 | 163.36 | 230.71 | 1.38× | 100.000% | -29.73% |
| earned_craft_first_craft | 1,000 | 511.51 | 439.04 | 511.27 | 477.00 | 1.00× | 100.000% | +16.45% |
| earned_craft_first_affordable | 2,000 | 369.45 | 196.79 | 171.03 | 408.64 | 2.16× | 100.000% | -13.09% |
| earned_craft_first_activated | 2,000 | 407.11 | 375.17 | 221.89 | 395.19 | 1.83× | 100.000% | -40.86% |
| earned_craft_first_extraction | 2,000 | 693.91 | 708.70 | 561.17 | 751.22 | 1.24× | 100.000% | -20.82% |
| earned_craft_extraction_active | 2,000 | 722.47 | 707.76 | 538.34 | 785.18 | 1.34× | 100.000% | -23.94% |
| earned_craft_first_craft | 10,000 | 3956.27 | 4763.55 | 3067.14 | 4644.32 | 1.29× | 100.000% | -35.61% |
| earned_craft_repeat_craft | 10,000 | 6098.49 | 5826.18 | 4967.15 | 5185.15 | 1.23× | 100.000% | -14.74% |
| earned_craft_after_repeated | 10,000 | 5368.22 | 4805.13 | 4865.37 | 6005.90 | 1.10× | 100.000% | +1.25% |

### Confirmation and measurement stability

Six measured runs after one warmup, with balanced alternating method order. This is separate evidence; main medians above remain unchanged. Ranges are min–max. It does not justify projecting a speedup onto unmeasured gameplay.

| Fixture / ticks | Previous median [range] ms | Extended median [range] ms | Native speedup | Δ previous |
|---|---:|---:|---:|---:|
| early / 2,000 | 190.94 [181.93–255.66] | 200.67 [175.00–521.83] | 2.15× | +5.09% |
| early / 36,000 | 4137.95 [3868.18–4407.64] | 4383.82 [3999.30–5805.94] | 1.70× | +5.94% |
| forge_competing / 10,000 | 4036.59 [3938.70–4132.12] | 3977.48 [3947.68–4068.15] | 1.41× | -1.46% |
| earned_essence / 10,000 | 3275.64 [2987.29–3675.13] | 3209.58 [3058.02–3451.01] | 1.47× | -2.02% |
| nexum_relics / 2,000 | 426.96 [411.46–458.51] | 418.88 [411.11–446.89] | 1.68× | -1.89% |
| forge_completion / 2,000 | 513.79 [434.42–1551.29] | 497.59 [349.94–562.93] | 1.49× | -3.15% |
| earned_craft_first_craft / 600 | 242.56 [181.89–372.88] | 196.72 [150.49–217.17] | 1.50× | -18.90% |
| earned_craft_first_craft / 1,000 | 330.85 [304.03–518.64] | 294.42 [255.41–513.49] | 1.09× | -11.01% |

### Activity, native callbacks and retained memory estimates

These are separate **single intrusive probe runs**, not throughput medians. Active/progress counts distinguish actual crafting from post-completion idle time. Completion time includes native callbacks; random reward includes generation/insertion. Nested durations must not be summed. Payload sizes are serialized bytes; packet estimates are engine retained-memory deltas, not exact heap or peak allocation.

| Fixture / ticks | Active / progress | Crafts | Native auto successes / attempts | Builds / structural invalidations | Packet estimate B | Inventory payload B before→after | Native completion µs | Generation calls / µs |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| forge_standard / 2,000 | 900 / 900 | 1 | 0 / 0 | 2 / 0 | 31020 | 1216→1988 | 454 | 1 / 375 |
| critical_greater / 2,000 | 1800 / 1800 | 1 | 0 / 0 | 2 / 0 | 31020 | 1216→2848 | 977 | 1 / 771 |
| auto_standard / 3,000 | 2700 / 2700 | 3 | 2 / 302 | 2 / 0 | 31020 | 1388→3560 | 1507 | 3 / 1241 |
| auto_extraction / 3,000 | 3000 / 3000 | 5 | 4 / 4 | 2 / 0 | 31020 | 1216→1344 | 311 | 0 / 0 |
| automation / 2,000 | 900 / 900 | 1 | 0 / 0 | 41 / 39 | 31020 | 1216→1988 | 325 | 1 / 249 |
| forge_together / 2,000 | 1 / 1 | 1 | 0 / 0 | 2 / 0 | 28788 | 3276→4016 | 740 | 1 / 148 |
| separate_rng / 2,000 | 1 / 1 | 1 | 0 / 0 | 2 / 0 | 28788 | 3276→4036 | 356 | 1 / 148 |
| full_inventory / 2,000 | 900 / 900 | 1 | 0 / 0 | 2 / 0 | 31020 | 21056→21828 | 661 | 1 / 545 |
| stack_overflow / 2,000 | 300 / 300 | 1 | 0 / 0 | 2 / 0 | 31020 | 1344→1472 | 45 | 0 / 0 |
| late_mixed / 2,000 | 900 / 900 | 1 | 0 / 0 | 21 / 19 | 39128 | 3568→4340 | 337 | 1 / 261 |
| earned_craft_first_craft / 600 | 600 / 600 | 0 | 0 / 0 | 1 / 0 | 27288 | 1216→1216 | 0 | 0 / 0 |
| earned_craft_first_craft / 1,000 | 900 / 900 | 1 | 0 / 0 | 1 / 0 | 27288 | 1216→2184 | 369 | 1 / 299 |
| earned_craft_first_activated / 2,000 | 2000 / 114 | 0 | 0 / 0 | 1 / 0 | 23604 | 212→212 | 0 | 0 / 0 |
| earned_craft_first_craft / 10,000 | 900 / 900 | 1 | 0 / 0 | 1 / 0 | 27288 | 1216→2184 | 739 | 1 / 274 |
| earned_craft_repeat_craft / 10,000 | 900 / 900 | 1 | 0 / 0 | 1 / 0 | 27288 | 2184→3040 | 2815 | 1 / 2115 |

Every main run of the previous and extended kernel matches native whole-graph state: **424 comparisons** including warmups. The eight confirmation scenarios add **112 comparisons**, for **536** total. Numerical, phase, event and both RNG-state deviation is zero. Complete generated relic dictionaries and inventory identity relationships are included. All raw failure arrays are empty.

The adaptive reference is byte-unequal in 48/208 main samples; its existing TimeManager/dormancy statistics and any numerical/discrete/event/RNG differences are retained in the raw rows. These reference differences are not attributed to the extended exact kernel or counted as exact validation. The exact kernels use no numerical tolerance.

Packet construction, releases, rebuilds and native completion are included in public timings. Progress and inventory rewards do not cause an invalidation by themselves. The repeated-standard diagnostic produces three random relics and only the existing structural-boundary rebuilds; native failed auto restarts continue to be checked, not skipped. Native generation/insertion cost remains authoritative and is not an optimization target here. No per-tick inventory copy or scan is introduced.

## Performance assessment

The earned interval entirely inside a real craft is **1.38× native in the main run and 1.50× in confirmation**, with 100% coverage. The earned completion interval is **1.00× / 1.09×**, respectively: its main result is effectively tied, so this is not evidence that every craft interval is faster. The 10,000-tick earned first/repeat craft intervals are 1.29× / 1.23× native; they include post-completion idle time. Controlled extraction and three-craft auto-run are 1.29× / 1.58× native in the main matrix. These results demonstrate exact crafting-core coverage and useful acceleration in the tested states, not a full-game or GUI/offline speedup.

Existing long-scenario main speedups are early 1.85×, consumer 1.57×, mid 1.21×, Forge 1.28×, earned Essence 1.29× and earned feedback 1.61×. Their original resources, automation, feedback and active cycles were retained. Coverage is 100% except original mid-game's 99.98% automatic-upgrade boundary. Earned crafting snapshots have 100% coverage; controlled crafting generally has one native automatic-upgrade tick (99.95% at 2,000 ticks). These are admission/coverage measurements independently of speedup.

**Regressions are retained.** Early 36,000 ticks is +2.62% slower than the archive in the main run and +5.94% in confirmation; early 2,000 ticks is +5.09% in confirmation despite its faster main median. It remains 1.70× native in the longer confirmation. Source inspection identifies a plausible new cost: admission sets the idle Crucible's existing `Machine.native_cycle` flag true, so the unchanged packet loop reads its live active/auto-run flags instead of short-circuiting on the false capability flag. New contract validation also adds packet-build work. This is an inferred contribution, not a separately isolated causal timing result; broad sample ranges and shared-host scheduling remain important. No late hot-loop rewrite was introduced to conceal this tradeoff. A later narrowly measured idle-capability refinement could avoid these reads if its no-internal-start boundary is separately proven.

Main apparent slowdowns of earned Essence (+6.72%), relic-equipped Nexum (+17.34%), Forge completion (+6.48%) and the earned 1,000-tick completion (+16.45%) were not reproduced in the balanced confirmation (−2.02%, −1.89%, −3.15%, −11.01%). Both complete datasets remain visible. Forge-critical's +4.02% main regression is retained without a separate confirmation. Small positive and negative changes elsewhere must not be promoted into universal improvement claims. The main completion case's wide native/previous/extended ranges in the summary explain why one three-run median is insufficient for that claim.

Single-probe packet retention estimates span **14,192–39,128 bytes** and construction **443–2,951 µs**. These are estimates/single observations, not exact heap allocations or repeated medians. Earned crafting intervals use one build and zero cycle-triggered invalidations; controlled ordinary/auto crafts retain their existing automatic-upgrade/structural rebuild boundaries. The old near-completion equipment diagnostic has more rebuilds due to its original purchase-heavy configuration, not reward insertion. The completion timer in the activity table includes all native cycles, including Forge where combined. Native random reward, generation, recipe and insertion timings are separately retained in raw observations; overlapping timers are not additive. No exact transient allocation count is available.

The main remaining core costs are ordered resource/modifier/statistics work, native automation checks and native per-tick cycle processing. Generation/insertion stays native and is relatively infrequent; removing or approximating those calls is neither necessary nor justified. The additional capability needs no inventory snapshot, per-progress-tick full scan or copied definitions. It preserves exact startup snapshots, RNG identity/draw order, serialized rewards and native inventory growth.

The next milestone should be the separate **experimental TimeManager integration study** described above, with audited clock/statistics ownership and external observer boundaries. Current GUI callbacks can still force complete fallback, so this is not ready to replace production offline simulation directly. First quantify idle-capability guard overhead before relaxing any safety contract. Custom managers/RNGs, unreviewed events/effects/cycles, continuous recipe buyers, external mutation callbacks and unsupported orchestration retain explicit native fallback. No production integration is delivered here. Linux Godot 4.6.1 is the validated environment; Windows 4.7.2 and editor startup remain unverified.

## Committed file manifest

- `tests/experimental/EXACT_FLOW_RELIC_CRAFTING.md`
- `tests/experimental/EXACT_FLOW_RELIC_EQUIPMENT.md`
- `tests/experimental/baselines/exact_flow_182e562_cycles.gd`
- `tests/experimental/baselines/exact_flow_182e562_equipment.gd`
- `tests/experimental/baselines/exact_flow_182e562_kernel.gd`
- `tests/experimental/baselines/exact_flow_182e562_packet.gd`
- `tests/experimental/crafting_native_probe.gd`
- `tests/experimental/cycle_kernel_tests.gd`
- `tests/experimental/exact_flow_crafting.gd`
- `tests/experimental/exact_flow_cycles.gd`
- `tests/experimental/exact_flow_equipment.gd`
- `tests/experimental/exact_flow_tests.gd`
- `tests/experimental/exact_flow_view.gd`
- `tests/experimental/relic_crafting_baseline.log`
- `tests/experimental/relic_crafting_benchmark.gd`
- `tests/experimental/relic_crafting_benchmark.log`
- `tests/experimental/relic_crafting_benchmark_confirmation.log`
- `tests/experimental/relic_crafting_benchmark_confirmation_results.json`
- `tests/experimental/relic_crafting_benchmark_quick.json`
- `tests/experimental/relic_crafting_benchmark_results.json`
- `tests/experimental/relic_crafting_benchmark_smoke.log`
- `tests/experimental/relic_crafting_benchmark_summary.json`
- `tests/experimental/relic_crafting_boundaries.log`
- `tests/experimental/relic_crafting_boundaries_final.log`
- `tests/experimental/relic_crafting_boundaries_final_validation.json`
- `tests/experimental/relic_crafting_boundaries_validation.json`
- `tests/experimental/relic_crafting_early_first_activated.log`
- `tests/experimental/relic_crafting_early_first_activated_validation.json`
- `tests/experimental/relic_crafting_early_first_affordable.log`
- `tests/experimental/relic_crafting_early_first_affordable_validation.json`
- `tests/experimental/relic_crafting_environment.json`
- `tests/experimental/relic_crafting_fixtures.gd`
- `tests/experimental/relic_crafting_fixtures.log`
- `tests/experimental/relic_crafting_progression.json`
- `tests/experimental/relic_crafting_progression_builder.gd`
- `tests/experimental/relic_crafting_regression.log`
- `tests/experimental/relic_crafting_regression_validation.json`
- `tests/experimental/relic_crafting_tests.gd`
- `tests/experimental/relic_crafting_tests.log`
- `tests/experimental/relic_crafting_validation.json`
- `tests/experimental/relic_equipment_tests.gd`
- `tests/experimental/run_relic_crafting.py`
- `tests/experimental/run_relic_crafting_tests.gd`
- `tests/experimental/summarize_relic_crafting.py`
- `tests/run_regression_tests.gd`
