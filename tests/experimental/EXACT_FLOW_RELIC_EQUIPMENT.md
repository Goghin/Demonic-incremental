# Exact kernel: stable relic equipment

Base `eeb85dce1c9d79ad0e65cbb8c5d1d7e351097478`, branch `feature/cycle-auto-run`.

## Pre-implementation audit and boundary decision

Inspected actual HEAD/working tree; native simulation, generator/IO/cycle definitions, both automation managers, GameState, RelicManager/RelicGenerationManager, permanent slot upgrades, save/load, UI equipment callbacks, prior exact-flow reports and regression tests. Tracked tree was clean. Unrelated untracked files are preserved.

Relics are instance dictionaries in RelicManager.inventory. Their stable `instance_id` refers to saved rolled generated definitions, primary `rolled_value`, optional `secondary_stat` and ordered additional secondaries. Tiers1/2/3 are Common/Uncommon/Rare, with0/1/2 bonus effects. Weighted generation rolls primary/secondary effects and targets, names/affixes and possible tier promotion through the shared owned gameplay RNG. This experiment does not generate or reinterpret rolls during ticks.

Equipment maps generator IDs to slot dictionaries (legacy strings remain accepted). Equip checks capacity, instance existence and active-cycle target lock; removes the instance from previous holders and replaces the target slot dictionary. Unequip edits/removes that mapping; notably its manager method has no active-cycle check, while the UI enforces locks. Inventory positions and crafting-slot ownership are separate maps. Machine-slot moves and consumption can replace nested maps, remove entries or merge stacks. None is immutable merely because it is a dictionary.

Native GameState.rebuild_relic_modifiers first removes prior relic modifiers/sensitivities and clears production caches. It visits equipped generators in dictionary insertion order, numeric slots0..capacity−1, then primary, first secondary, additional secondaries in array order. It creates ordinary Modifier/ModifierSensitivity instances. Blank targets mean matching IO on the equipped generator, not all generators. Universal sensitivity expands only existing non-relic sensitivity targets, avoiding recursive relic sensitivity. Rebuild timing matters: ordinary native upgrades append effects in their existing order and do not automatically rebuild equipment. The packet must compile the current native arrays without sorting, merging or reconstructing effects.

Native equip/move/unequip APIs do not emit a core mutation counter. UI handlers explicitly rebuild relic modifiers and save afterward. Load and realm reset also rebuild. This means a lightweight universal asynchronous inventory/equipment detector does not exist. The supported contract is exclusive synchronous Kernel.run: no yields/external edits while a packet lives, existing external signal/clock/logger/custom-script guards remain. Every public return releases the packet; legal equipment/inventory/load/slot edits plus their native rebuild between calls are seen before the next optimized tick. Direct retained-packet edits remain unsupported.

Within reviewed synchronous updates, continuous generators only consume/produce resources and runtime phases; native Forge's reviewed resource-only completion callbacks alter resources, own level, RNG and histories, not inventory/equipment. Native automation only purchases its configured continuous generators/upgrades and does not equip/move relics. General/automatic upgrade handlers contain no equipment mutation. A recipe-bearing enabled autobuyer could consume inventory at purchase, so that pattern must be explicitly refused. Active/auto-running unreviewed Crucible cycles, inventory/random-relic completion modes and external equipment-changing callbacks remain native fallback.

## Effect inventory and timing

Every current generator effect uses existing native modifier paths. No new relic formula is required.

| Effect ID | Target / operation | Roll source | Timing / dependencies | Capability |
|---|---|---|---|---|
| output_increase / output_decrease | PRODUCTION: blank, Heat, Matter or Ash | Generated per-tier range / saved roll | Holder's ordered output, after inputs; mode/level structural | Existing rate tape; transfer bypass retained |
| input_draw_reduction / input_draw_increase | INPUT_DRAW: blank, Heat, Matter or Ash | Generated per-tier range / saved roll | Startup, availability and sequential consumption; native Mite suppression rules | Existing tape/native controller API; transfer bypass retained |
| ash_contamination_sensitivity_reduction | Sensitivity for ashen_contamination and ashen_contamination_cycle_speed | Saved roll | Native modifier evaluation, including Forge live speed; live Ash | Native sensitivity multiplication |
| thermic_mass_sensitivity_reduction / increase | thermic_mass sensitivity | Saved roll | Native Heat/resource feedback; live Matter | Native modifier/sensitivity path |
| crystallization_sensitivity_reduction | crystallization sensitivity | Saved roll | Native compounding power penalty; live CF/Essence sensitivities | Preserve native multiplication/power association |
| heat_reservoir_boost | Dynamic PRODUCTION Heat | Saved strength/threshold/exponent | Each output with then-current Heat; strongest at low stock | Native inverse-resource-boost evaluation in dynamic suffix |
| matter_reservoir_boost | Dynamic PRODUCTION Matter | Saved strength/threshold/exponent | Each output after prior inputs/outputs, live Matter | Native dynamic suffix |
| cycle_speed_increase | CYCLE_SPEED on cycle holder | Saved roll | Native progress/speed calculations before/after IO; live Ash sensitivities | Native Forge cycle path |
| critical_chance | Additive EVENT_CHANCE critical_chance | Saved additive roll | Native Forge completion event chance and clamp, in modifier order | Native RNG/event boundary |

All current generated effects are supported on holders for which native methods apply them. Nonmatching targets and continuous cycle/critical effects retain native inactivity. Positive and negative rolls retain their values/stacking. Definition-driven rarity/affix/target metadata is passive during a tick. Unsupported custom modifier semantics/scripts retain explicit rejection. No cost/efficiency or reward effect is invented.

Forge's event-based critical chance is evaluated LIVE at completion by `_get_effective_event_chance`; no extra RNG draws or alternate reward implementation. Its startup `cycle_critical_chance_snapshot` belongs to native random-relic crafting: the native getter uses crafting-mode base plus generator levels, not an independently invented relic bonus. Active random-relic crafting remains unsupported. Do not conflate the Forge event chance with that snapshot. Durations/speed/Ash penalties, ordinary outputs, completion rewards, Heat loss, downlevels and auto-run restarts stay native.

## Implemented capability and ownership

Only the experimental admission contract changed. `exact_flow_equipment.gd` validates the native inventory/generation runtimes, the reviewed resource-only automation purchase scope, and relic-derived modifier types/formulas. `exact_flow_packet.gd` replaces blanket inventory/slot rejection with that contract and validates relic modifiers in both the authoritative array and any existing production cache. The ordered `step`, native cycle adapter, rate evaluator, purchase APIs and environmental formulas are unchanged.

The packet retains original Generator, ResourceState and dynamic Modifier references, as before. It retains **no relic-instance, inventory-position, equipment-slot or definition dictionary**. Static factors are compiled in original multiplication order only when neither the native modifier nor an applicable sensitivity is dynamic. After the first dynamic factor, subsequent factors stay in their original ordered suffix; native `get_effective_multiplier` reads live resources/sensitivities at each operation. Relic reservoir effects therefore cannot become stale coefficients. All runtime objects and inventory dictionaries remain owned by GameState/RelicManager. Packet release neither replaces those objects nor rewrites equipment.

The inventory and equipment remain mutable authoritative data, not immutable configuration. Within the supported synchronous scope their only role is the previously rebuilt native effect arrays. Rarity, affixes, roll ranges and generator applicability metadata are passive definition data during such an interval. Their mutable saved instances are preserved without copying or reinterpretation. The original identity-aware graph oracle verifies inventory, nested dictionaries, equipment aliases, effect objects and caches, rather than comparing only balances.

Effect categories are: A, ordinary static production/input modifiers and constant sensitivities through existing paths; B, reservoir feedback and sensitivities acting on live dynamic production/input/cycle formulas; C, cycle speed and completion critical effects through native cycle/event methods; D, active Crucible/inventory crafting, unreviewed semantics or external mutation callbacks. An effect can have A/B numerical behavior while its holder still requires D fallback. No current effect is made effective on a generator or mode where native gameplay ignores it.

## Invalidation and unsupported operations

- Every public `Kernel.run` begins without a packet and releases it before returning. Equip/unequip/move, inventory edits, load, slot changes, modes and native rebuilds between calls are observed before the next optimized tick. This is a synchronous execution contract, not an asynchronous equipment monitor.
- A bare native equip without the UI's rebuild intentionally leaves the old native arrays effective in both implementations. The kernel must not repair that caller state by rebuilding early.
- Existing automatic-upgrade checks release the packet before the native boundary tick. Generator/upgrade purchases and Forge level changes retain the existing structural invalidation/reconstruction path. Ordinary resource changes, cooldown checks and stable equipment require no new rebuilding.
- No reviewed interior continuous-generator, native Forge or automation operation equips or moves an item. Enabled recipe-bearing generator buyers are rejected as `equipment_inventory_purchase`; this prevents an unreviewed purchase from consuming passive ingredients.
- External signal callbacks are rejected before the tick as `external_observer`, even when they happen to perform only an equipment edit. Native simulation executes the callback at its original signal position. A later public call can reenter after disconnection.
- Active or auto-running Crucible cycles remain `unsupported_cycle_contract`; inventory recipe/random-relic reward mutations are not optimized. An unsupported public interval stays native until its return, even if crafting completes during it. The next public call reevaluates eligibility.
- Unknown manager scripts, relic modifier types/formulas and existing unknown modifier/sensitivity scripts are explicit refusals. Nonempty passive inventory and inactive machine ingredients alone are allowed.
- Direct mutation while holding an internal Packet, concurrent edits, arbitrary callbacks, live UI/logging and external TimeManager clocks remain unsupported. No equipment mutation counter or production API was added. Those operations must use native execution or a new public boundary.

Forge completion uses native startup, availability, consumption, speed, rewards, RNG and signals. Equipment cannot be newly equipped on an active cycle through native `equip_relic`; native manager unequip behavior remains unchanged. A same-seed diagnostic proves that the live equipped critical bonus changes a native ordinary craft into a critical one, and the kernel matches native RNG/state exactly. This is separate from the random-relic startup snapshot and does not enable random relic crafting.

## Fixtures and reproducibility

Existing early, consumer, mid, Forge, earned Essence and earned feedback snapshots are unchanged. The archived eeb85dc kernel/packet/cycle scripts differ from the originals only in their archive preload paths; the remaining dependencies are unchanged production/helper scripts.

`relic_equipment_progression_builder.gd` begins from the unchanged earned `automation_progression.json` settled save. It spends the native permanent-currency costs of Reliquary (5), Molecular Agitation attunement (3) and Mite attunement (5), obtains the native generated Common starter, equips it and snapshots `one`. Both original enabled Atomic Friction buyers remain enabled. A deterministic policy performs affordable native purchases, conserves Matter by pausing Matter Furnace, extracts shards through actual Crucible cycles, moves ten shards into the actual recipe slot, pays/starts a native random relic cycle, and equips a matching earned reward after completion. Snapshot `multiple` is taken after the actual craft is finished; an active craft is not disabled to manufacture eligibility. The action ledger, native RNG and save snapshots are retained in `relic_equipment_progression.json`. There are no resource, level, roll or upgrade grants on this route. The paid slot capacity is one per applicable holder in current definitions; several equipped relics means several holders, not invented extra slots.

All other new fixtures are **controlled diagnostics**, explicitly granting native unlocks/slots, resource stocks or levels. Rolls, rarity, primary/secondary effects and target variants are generated through production APIs. Target-search attempts leave their unwanted relics in passive inventory. The `stacked` case finds a naturally generated Rare with two matching production stats in its one slot. These are not represented as earned progression. Forge near-completion cases deliberately position progress near the boundary. The repeated auto-run stress grants very large source/Mite levels to pay native activation costs and control native Ash accumulation while retaining leak, decay, contamination and feedback; it is not representative Forge performance evidence.

Reproduction (from repository root, with a Godot 4.6.1 executable):

```sh
python tests/experimental/run_relic_equipment.py --godot /path/to/godot --mode fixtures
python tests/experimental/run_relic_equipment.py --godot /path/to/godot --mode tests
python tests/experimental/run_relic_equipment.py --godot /path/to/godot --mode regression
python tests/experimental/run_relic_equipment.py --godot /path/to/godot --mode scope
python tests/experimental/run_relic_equipment.py --godot /path/to/godot --mode reference
python tests/experimental/run_relic_equipment.py --godot /path/to/godot --mode benchmark
```

Run simulations serially for timing comparisons. The wrapper records stdout/stderr, enforces a timeout and rejects parser/runtime errors, warnings and fatal messages. No editor scan or change to unrelated production issues is required.

## Benchmark methodology

All four methods use identical deterministic states on the same host/engine: direct native `Simulation.update(0.1, true)`, the archived eeb85dc public kernel, the extended public kernel, and the existing adaptive reference. Each scenario has one retained warmup and three measured repeats, alternating method order. Medians and measured ranges below exclude warmup; no slow sample is discarded. Fixture construction, lightweight runner-object initialization and full-graph verification are outside the timed interval, as in the prior benchmark; actual per-call packet construction is inside. Public timings include packet construction, release/reconstruction, guards, native modifier/cycle/accounting calls and fallback. External equip/rebuild work is included for the mutation diagnostic. No checkpoint or speculative replay is used.

The adaptive reference requires a fresh, scale-one TimeManager interval and does not support repeated external mutation/public-call boundaries on the same runner. It is therefore explicitly omitted for the repeated equipment-change diagnostic; its other whole-interval samples remain unchanged reference measurements, not new adaptive eligibility.

Additional phase clocks, native cycle probes and flow counters run in separate untimed executions. Packet memory is an allocator retained-delta **estimate** from `OS.get_static_memory_usage` around construction, not exact heap ownership, peak allocation or serialized size. It includes packet objects/references and excludes preexisting GameState, inventory, rolls and immutable script metadata. Previous rejected packets allocate very little because they construct no IO tape. Dynamic evaluation counters cover the compact rate tapes; native controller/cycle internals are not counted as compact tape operations. Equipment boundary counts are external diagnostic operations, not an interior mutation detector.

## Correctness results

Linux Godot **4.6.1.stable.official.14d19694e**, x86_64, Linux 6.18.55. Engine binary and fixture hashes are in `relic_equipment_environment.json`; CPU is also recorded in each benchmark file. Initial pre-change suite: **96 passed, 0 failed**. Final complete suite: **97 passed, 0 failed**, preserving all 96 original group names. Final validation logs contain no parser warnings or runtime errors. This validates Linux script execution, not Windows 4.7.2 or editor startup.

The new group and separate rerun each perform **10,900 tick endpoints**, comparing both the extended kernel and archived previous kernel against native execution (**21,800 byte comparisons per run**). Detailed views include every resource/accumulator, runtime/mode, ordered modifier and sensitivity fields, automation timers/caches, statistics, inventory/equipment, event history and RNG. There are additionally **77 identity-aware whole-graph comparisons with native**, and **37 read-only admission/rejection graph checks**. All pass, without numerical tolerances. Existing rollback, multi-input, controller, automation, resource/transfer, Forge and RNG groups remain passing.

Coverage includes all twelve native generated effect IDs, Common/Uncommon/Rare rolls, matching and inactive targets, blank-target effects, weakening/strengthening input/output modifiers, stacked production types on one Rare, multiple native bonus stats, resource reservoir feedback, Essence/Nexum, input exhaustion and inactive machine ingredients. Matter-reservoir testing equips the actual Matter producer. Current generated definitions have no wildcard-all-sensitivity roll; that native rebuild path is audited and retained, not invented as earned loot.

Forge tests exercise native speed, combined Ash sensitivity, actual completion and auto-run. The controlled equipped auto-run case completes **10 cycles over 3,000 ticks**, with exact phases, rewards, history and RNG; nine native level transitions invalidate the packet. A strict RNG witness uses seed **3**: native live equipped chance is **0.337983719258439** versus base **0.25**. The same native draw yields a critical reward of **4** with equipment and ordinary reward of **2** after native unequip/rebuild; the extended kernel matches the equipped native whole graph. No second crafting/chance engine is introduced.

The 36-tick public-boundary sequence covers bare equip, rebuild, unequip, move, capacity removal/restoration, native generator purchase, mode change, inventory mutation, real random-relic craft completion, fallback and reentry. It has 34 kernel ticks and two native boundaries. Five additional save/load/reentry ticks compare full graphs. An external completion callback changes equipment at its actual native signal point: three ticks explicitly fall back, then five optimized ticks resume after disconnection. Native active-cycle equip lock rejection is tested. Unknown relic modifier type, unknown formula and recipe-bearing buyer are rejected without mutating the graph.

The scope audit retains canonical mixed/transfer/Essence diagnostics and their original saves. Each has nine optimized ticks and one native automatic-upgrade boundary out of ten. The canonical active Crucible/inventory cycle case remains **0/10 kernel ticks**, explicitly `unsupported_cycle_contract`; its passive inventory is no longer a separate blocker. Native fallback parity passes in every audited case.

### Adaptive reference is a different clock contract

The first benchmark harness incorrectly required whole-graph equality from the existing adaptive **reference** as well as the two exact kernels. That run failed 32 reference-only assertions; all previous/extended-kernel comparisons passed. Its unmodified raw timings, parity flags and failure log are retained as `relic_equipment_benchmark_initial_results.json` and `relic_equipment_benchmark_initial.log`. It is not counted as a passing benchmark run. The corrected harness retains strict byte equality for both exact kernels and separately records the reference's numerical, phase/discrete, event and RNG deviation, matching the distinction in earlier benchmark infrastructure. No kernel assertion or tolerance was relaxed.

`relic_equipment_reference_audit.gd` diagnoses the mismatch independently. The adaptive runner advances its owned TimeManager and writes `lava_mite_dormancy_penalty`; direct synchronous core ticks do not. At 36,000 early ticks the adaptive penalty is **0.195652173912901**, versus core **0**, with resource deviation zero and discrete/events/RNG equal. At 10,000 mid ticks it is **0.0260869565217391**, with maximum resource deviation **8.41199540579929e-11** and fractional/discrete inequality; events and RNG remain equal. The reference also bounds its last tick by accumulated elapsed duration, unlike the fixed 0.1-second core comparison. Raw first graph differences are retained. The exact kernels retain zero deviation from fixed native ticks. Reference timings below are descriptive and do not establish equivalent end-to-end offline behavior when its clock context differs.

## Matched performance measurements

AMD EPYC 9V74 80-Core Processor; same Linux engine/host for each compared method. Times below are median milliseconds; bracketed ranges are measured min–max. Positive change means slower than the archived kernel. The initial reference-assertion failure is excluded from these final medians.

### Existing fixtures

| Fixture / ticks | Native ms | Previous ms [range] | Extended ms [range] | Adaptive reference ms | Native speedup | Change vs previous | Kernel coverage |
|---|---:|---:|---:|---:|---:|---:|---:|
| early / 2000 | 225.555 | 116.574 [112.789–122.699] | 120.304 [112.607–127.537] | 259.126 | 1.875× | +3.20% | 100.00% |
| early / 36000 | 5093.466 | 2639.250 [2553.208–2663.413] | 2529.982 [2486.546–2612.522] | 5210.347 | 2.013× | -4.14% | 100.00% |
| consumer_50000 / 2000 | 333.019 | 229.119 [208.590–230.182] | 210.295 [209.734–214.120] | 361.432 | 1.584× | -8.22% | 100.00% |
| consumer_50000 / 10000 | 1711.266 | 993.379 [909.959–1102.293] | 982.331 [939.663–1013.493] | 1603.631 | 1.742× | -1.11% | 100.00% |
| mid / 2000 | 262.338 | 185.069 [160.288–200.089] | 182.609 [162.884–186.198] | 291.362 | 1.437× | -1.33% | 99.90% |
| mid / 10000 | 1552.186 | 1147.275 [1113.129–1164.188] | 1040.397 [1015.217–1150.615] | 1525.291 | 1.492× | -9.32% | 99.98% |
| forge_competing / 2000 | 771.179 | 549.381 [527.797–569.493] | 533.643 [500.691–601.116] | 698.664 | 1.445× | -2.86% | 100.00% |
| forge_competing / 10000 | 3252.396 | 2318.754 [2317.751–2393.259] | 2460.871 [2378.617–2735.395] | 3265.804 | 1.322× | +6.13% | 100.00% |
| earned_essence / 10000 | 3185.224 | 2122.131 [1978.487–2221.009] | 2143.464 [2062.446–2169.881] | 3280.951 | 1.486× | +1.01% | 100.00% |
| earned_feedback / 10000 | 3148.830 | 2180.089 [2177.640–2254.929] | 2166.937 [2121.596–2287.237] | 3232.187 | 1.453× | -0.60% | 100.00% |

### New equipment fixtures

| Fixture / ticks | Native ms | Previous ms [range] | Extended ms [range] | Adaptive reference ms | Native speedup | Change vs previous | Kernel coverage |
|---|---:|---:|---:|---:|---:|---:|---:|
| passive / 2000 | 496.662 | 517.110 [495.269–539.202] | 311.876 [291.789–325.454] | 533.890 | 1.592× | -39.69% | 99.95% |
| one / 2000 | 481.931 | 558.450 [492.602–593.974] | 372.378 [305.099–388.563] | 601.982 | 1.294× | -33.32% | 99.95% |
| multiple / 2000 | 620.817 | 610.309 [604.225–613.211] | 404.711 [378.088–407.054] | 644.391 | 1.534× | -33.69% | 99.95% |
| input_compressor / 2000 | 533.399 | 563.572 [513.090–587.498] | 330.113 [307.608–339.222] | 605.821 | 1.616× | -41.42% | 99.95% |
| sensitivity / 2000 | 551.129 | 564.395 [530.428–603.139] | 361.482 [354.021–369.080] | 647.707 | 1.525× | -35.95% | 99.95% |
| forge_critical / 2000 | 485.659 | 486.228 [473.344–510.114] | 295.123 [285.293–319.928] | 574.055 | 1.646× | -39.30% | 99.95% |
| forge_speed / 2000 | 421.925 | 410.761 [404.312–531.987] | 245.117 [219.610–247.488] | 463.682 | 1.721× | -40.33% | 99.95% |
| forge_sensitivity / 2000 | 457.547 | 436.299 [346.706–440.641] | 242.199 [210.618–246.030] | 379.226 | 1.889× | -44.49% | 99.95% |
| forge_completion / 2000 | 478.690 | 465.361 [441.014–466.024] | 262.712 [252.211–265.656] | 455.982 | 1.822× | -43.55% | 99.95% |
| forge_auto / 3000 | 1166.359 | 1145.660 [1110.873–1286.218] | 851.552 [837.940–938.666] | 1203.668 | 1.370× | -25.67% | 99.97% |
| essence_relics / 2000 | 538.414 | 552.074 [505.852–561.546] | 321.974 [321.973–344.917] | 575.242 | 1.672× | -41.68% | 99.95% |
| nexum_relics / 2000 | 605.349 | 553.810 [527.241–565.905] | 348.148 [339.181–377.534] | 589.277 | 1.739× | -37.14% | 99.95% |
| relic_heavy / 2000 | 707.895 | 633.355 [627.788–641.818] | 388.838 [383.090–421.998] | 660.669 | 1.821× | -38.61% | 99.95% |
| reached_one / 10000 | 2027.609 | 2096.868 [2047.831–2306.044] | 1758.738 [1659.511–1845.999] | 2232.629 | 1.153× | -16.13% | 100.00% |
| reached_multiple / 10000 | 2402.484 | 2504.880 [2308.044–3229.447] | 2068.681 [1979.220–2242.935] | 2912.608 | 1.161× | -17.41% | 100.00% |
| equipment_changes / 2000 | 557.325 | 615.053 [593.187–638.741] | 456.309 [453.065–507.701] | unsupported boundary | 1.221× | -25.81% | 99.95% |
| crafting / 2000 | 513.959 | 515.289 [502.704–608.904] | 521.470 [516.693–570.800] | 520.511 | 0.986× | +1.20% | 0.00% |

`reached_one` and `reached_multiple` are the earned fixtures. The other new rows are controlled diagnostics. All supported new rows improve over previous inventory-forced native execution; active crafting remains fallback-only and its 0.986× timing is a slowdown, not acceleration. Original Forge timings contain an active cycle but no completion within these intervals; actual completed crafts are separately validated and measured in diagnostic completion/auto-run rows.

### Construction, memory and operation counters

Separate untimed diagnostic executions; phase clocks are intrusive. Builds include the initial build; a public return always releases the packet. Retained KiB is an allocator estimate per single build, not inventory duplication or total simulation memory.

| Fixture / ticks | Builds / structural invalidations | Native fallback ticks | Total build µs | Retained KiB | Compact dynamic evaluations | Normal / critical completions | RNG words |
|---|---:|---:|---:|---:|---:|---:|---:|
| early / 2000 | 1 / 0 | 0 | 232 | 23.05 | 14000 | 0 / 0 | 0 |
| early / 36000 | 1 / 0 | 0 | 483 | 23.05 | 252000 | 0 / 0 | 0 |
| consumer_50000 / 2000 | 1 / 0 | 0 | 442 | 20.02 | 10000 | 0 / 0 | 0 |
| consumer_50000 / 10000 | 1 / 0 | 0 | 617 | 20.02 | 50000 | 0 / 0 | 0 |
| mid / 2000 | 3 / 0 | 2 | 1191 | 23.12 | 13604 | 0 / 0 | 0 |
| mid / 10000 | 3 / 0 | 2 | 1542 | 23.12 | 69604 | 0 / 0 | 0 |
| forge_competing / 2000 | 1 / 0 | 0 | 680 | 34.68 | 26000 | 0 / 0 | 0 |
| forge_competing / 10000 | 1 / 0 | 0 | 621 | 34.68 | 130000 | 0 / 0 | 0 |
| earned_essence / 10000 | 1 / 0 | 0 | 620 | 28.82 | 90000 | 0 / 0 | 0 |
| earned_feedback / 10000 | 1 / 0 | 0 | 820 | 28.82 | 90000 | 0 / 0 | 0 |
| passive / 2000 | 16 / 14 | 1 | 11684 | 36.75 | 20914 | 0 / 0 | 0 |
| one / 2000 | 2 / 0 | 1 | 1001 | 30.29 | 21988 | 0 / 0 | 0 |
| multiple / 2000 | 17 / 15 | 1 | 16784 | 36.77 | 23196 | 0 / 0 | 0 |
| input_compressor / 2000 | 16 / 14 | 1 | 12909 | 36.75 | 21988 | 0 / 0 | 0 |
| sensitivity / 2000 | 2 / 0 | 1 | 2179 | 30.27 | 19989 | 0 / 0 | 0 |
| forge_critical / 2000 | 2 / 0 | 1 | 1833 | 28.11 | 19990 | 0 / 1 | 1 |
| forge_speed / 2000 | 2 / 0 | 1 | 1042 | 28.11 | 19990 | 0 / 1 | 1 |
| forge_sensitivity / 2000 | 2 / 0 | 1 | 1358 | 28.11 | 19990 | 0 / 1 | 1 |
| forge_completion / 2000 | 2 / 0 | 1 | 1256 | 28.11 | 19990 | 0 / 1 | 1 |
| forge_auto / 3000 | 11 / 9 | 1 | 9242 | 28.11 | 29990 | 4 / 6 | 10 |
| essence_relics / 2000 | 16 / 14 | 1 | 14803 | 36.75 | 20893 | 0 / 0 | 0 |
| nexum_relics / 2000 | 16 / 14 | 1 | 12500 | 36.75 | 20913 | 0 / 0 | 0 |
| relic_heavy / 2000 | 20 / 18 | 1 | 14042 | 36.77 | 21989 | 0 / 0 | 0 |
| reached_one / 10000 | 1 / 0 | 0 | 454 | 20.04 | 40000 | 0 / 0 | 0 |
| reached_multiple / 10000 | 1 / 0 | 0 | 578 | 26.67 | 90000 | 0 / 0 | 0 |
| equipment_changes / 2000 | 101 / 0 | 1 | 56645 | 30.29 | 21309 | 0 / 0 | 0 |
| crafting / 2000 | 1 / 0 | 2000 | 1277 | 35.30 | 0 | 0 / 0 | 6 |

Early and original Forge packets retain the same measured bytes as their archived equivalents (23,604 and 35,508 bytes). Earned one/two equipment packets retain approximately 20.0/26.7 KiB; the archived rejection object is 2,456 bytes because it creates no usable packet. No relic-definition or inventory copy is introduced. The rejected active-crafting packet can retain a partially constructed tape (36,144 bytes in this observation), which is immediately released. Memory observations are not exact allocation ownership or peaks.

The equipment mutation diagnostic includes **100 external equipment/rebuild boundaries**, causing **101 builds** including one automatic-upgrade reconstruction; no stale packet crosses a return. There are no admitted interior equipment mutations and therefore no new interior equipment counter. Repeated Forge auto-run has 11 builds, nine level-change invalidations, 10 completions (four ordinary, six critical), 10 RNG words and native restarts. Stable earned equipment requires just one packet over 10,000 ticks. Full per-phase/cycle, flow-operation, release and native auto-run-attempt metrics are in the raw observations.

Final main benchmark: **108/108 extended** and **108/108 archived** samples are byte-exact against native, including retained warmups; numerical/statistical error is zero, and phases/discrete/events/RNG match. The 104 adaptive reference samples have 72 whole-graph matches and 84 discrete/phase matches; events and RNG match in all 104. They are not counted toward exact-kernel parity. Their maximum absolute resource/statistics deviations are 576.736912614899 and 27,136.6117520332 in the deliberately huge auto-run stress state; the raw deviations and clock-context explanation above prevent treating that reference as byte-exact.

### Balanced-order confirmation and regressions

A separate serial confirmation retains one warmup and **six measured repeats**, balancing previous/extended order three times each. The original samples remain unchanged.

| Fixture / ticks | Native ms | Previous ms [range] | Extended ms [range] | Native speedup | Change vs previous |
|---|---:|---:|---:|---:|---:|
| early / 2000 | 201.622 | 112.149 [104.654–127.683] | 116.661 [106.521–143.235] | 1.728× | +4.02% |
| forge_competing / 10000 | 3687.851 | 2633.570 [2548.853–2803.627] | 2693.463 [2568.991–2857.428] | 1.369× | +2.27% |

Confirmation exact-kernel parity is **28/28** archived/extended comparisons, including warmups. Together with the main run, **244/244 exact-kernel benchmark comparisons** pass with zero numerical, phase, event and RNG deviation. Confirmation reference measurements remain separately classified under its clock contract.

Small regressions are real limitations of these observations: early 2,000-tick median runtime increases 3.20% in the main run and 4.02% in confirmation; original Forge 10,000 ticks increases 6.13% in the main run and 2.27% in confirmation. Earned Essence is 1.01% slower than the archive in the main run. Other signs vary between the initial and final measurements, and min–max ranges overlap substantially. No assertion that previous throughput is identical is justified. The extended kernel remains faster than native in those supported cases, but capability expansion is not a speed optimization for already eligible states.

Investigation verified identical **source** for `step`, startup/availability helpers, rate classes and kernel/cycle execution; no inventory lookup or extra evaluation was inserted into the hot loop. The changes add admission-time runtime/script/type/formula checks. The one-build early/Forge intervals spend well under a millisecond in construction, which cannot explain an entire multi-percent long-interval timing shift. Confirmation Forge native-cycle work is 482,482 µs of 2,658,961 µs intrusively timed kernel work; most cost remains ordered flows/modifier/accounting work. A causal explanation for the remaining runtime shift is not established; host scheduling or bytecode/script layout are hypotheses, not measured findings. No speculative optimization is added to conceal it. More isolated profiling would be appropriate if this small regression becomes a release criterion.

Reproduce confirmation and median summaries:

```sh
RELIC_BENCH_CONFIRM=1 python tests/experimental/run_relic_equipment.py --godot /path/to/godot --mode benchmark
python tests/experimental/summarize_relic_equipment.py
```

## Architectural assessment and next milestone

Stable equipment is supported without a second relic engine, inventory copy, per-tick inventory scan, mutation journal or production bookkeeping. Native modifier arrays and reviewed native cycle callbacks already carry the required behavior. Packet construction/invalidation stays manageable: stable earned fixtures use one packet per 10,000 ticks, while deliberately frequent external equipment edits pay a rebuild at each boundary. This is read-only observation of native equipment effects, not implementation of equipment management.

Remaining limitations are active/auto-running Crucible crafting and other unreviewed inventory-producing cycle contracts; interior inventory/equipment mutations; external UI/clock/logger callbacks; custom effect/runtime scripts; and live TimeManager/dormancy behavior. Existing reviewed Thermal Compressor transfer semantics remain supported; this work does not generalize arbitrary future transfer/custom operations. Native fallback keeps original ordering and can resume optimized execution at a later public call. No full-game or production offline acceleration is established.

The recommended next **core** experiment is a narrowly audited native Relic Crucible cycle adapter covering recipe spending, random generation/tier promotion, inventory/machine-slot mutation, RNG draw order and completion signals. The canonical inventory-cycle fixture is still completely native, providing a concrete coverage target. Preserve native reward handling, and review whether completion only changes passive inventory or also invalidates generator configuration. Do not add automatic equipment management to that contract.

Production offline integration should follow a separate explicit TimeManager/event boundary investigation. The adaptive-reference dormancy differences demonstrate that this is substantive execution state, not merely a reporting clock. The current exclusive synchronous core cannot simply be substituted into live offline processing. The user-reported Windows 4.7.2 validation applies to the starting revision's 96 groups; these new 97-group changes have only been validated on Linux 4.6.1.

## Changed-file manifest

All changes are under `tests/`. Production gameplay, save formats, existing fixture snapshots and unrelated files remain unchanged. The initial failed reference assertion run is retained explicitly as research evidence.

- `tests/experimental/EXACT_FLOW_RELIC_EQUIPMENT.md`
- `tests/experimental/baselines/exact_flow_eeb85dc_cycles.gd`
- `tests/experimental/baselines/exact_flow_eeb85dc_kernel.gd`
- `tests/experimental/baselines/exact_flow_eeb85dc_packet.gd`
- `tests/experimental/exact_flow_equipment.gd`
- `tests/experimental/exact_flow_packet.gd`
- `tests/experimental/exact_flow_tests.gd`
- `tests/experimental/relic_equipment_baseline.log`
- `tests/experimental/relic_equipment_benchmark.gd`
- `tests/experimental/relic_equipment_benchmark.log`
- `tests/experimental/relic_equipment_benchmark_confirmation.log`
- `tests/experimental/relic_equipment_benchmark_confirmation_results.json`
- `tests/experimental/relic_equipment_benchmark_initial.log`
- `tests/experimental/relic_equipment_benchmark_initial_results.json`
- `tests/experimental/relic_equipment_benchmark_results.json`
- `tests/experimental/relic_equipment_benchmark_summary.json`
- `tests/experimental/relic_equipment_environment.json`
- `tests/experimental/relic_equipment_fixtures.gd`
- `tests/experimental/relic_equipment_fixtures.log`
- `tests/experimental/relic_equipment_progression.json`
- `tests/experimental/relic_equipment_progression_builder.gd`
- `tests/experimental/relic_equipment_reference.log`
- `tests/experimental/relic_equipment_reference_audit.gd`
- `tests/experimental/relic_equipment_reference_audit.json`
- `tests/experimental/relic_equipment_regression.log`
- `tests/experimental/relic_equipment_regression_validation.json`
- `tests/experimental/relic_equipment_scope.log`
- `tests/experimental/relic_equipment_scope_audit.gd`
- `tests/experimental/relic_equipment_scope_audit.json`
- `tests/experimental/relic_equipment_tests.gd`
- `tests/experimental/relic_equipment_tests.log`
- `tests/experimental/relic_equipment_validation.json`
- `tests/experimental/run_relic_equipment.py`
- `tests/experimental/run_relic_equipment_tests.gd`
- `tests/experimental/summarize_relic_equipment.py`
- `tests/run_regression_tests.gd`
