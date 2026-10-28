# Exact ordered consumers and Lava Mite controllers

## Implemented scope

Base `43b3897c4062b96aca81401a7115ff9707ea8c46`, branch `feature/cycle-auto-run`. The experimental packet now supports arbitrary registered input resources and ordered multi-input continuous generators. The native Lava Mite throttle/hysteresis logic and native controller-dependent input rates participate in the same exact loop. Output eligibility remains Heat/Matter/Ash; existing automation, cycles, relic, Essence and external-event restrictions remain.

Every tick is still 0.1 seconds. There is no speculative checkpoint, approximate batching, net-flow equation, production integration, formula/balance/save change or new runtime dependency. Production files and the existing game.gd:771 issue are untouched. Original untracked files are preserved.

This is **synchronous simulation-core** support. It supports the current dormancy penalty as a numerical input, including a nonzero penalty, and changed penalties between public calls. It does **not** advance TimeManager's offline dormancy ramp, wall-clock recovery countdown or clocks. Full end-to-end Lava Mite dormancy is not claimed.

## 1. Authoritative order and numerical semantics

Source: `simulation/simulation.gd:update`, `_get_available_operating_delta`, `consume_inputs`, `produce_outputs`; `Generators/generator.gd:get_input_rate`, `get_input_consumption_per_second`, `can_start_operating`, `get_production_rate`.

1. Capture tick-start Heat; reconcile interval/realm bookkeeping; process automatic upgrades.
2. Visit unlocked generators in registration order. Update the native throttle controller even when paused, inactive or level zero. Inactive cycles retain their native controller/bookkeeping position but perform no flow work.
3. For a stopped ordinary generator, test unlock, level, pause and cycle conditions. Offline startup visits inputs in definition order. A positive balance passes without rate evaluation. An empty/nonpositive input blocks startup only when its evaluated rate is positive.
4. Determine operating duration. Visit all inputs in definition order **before any input writes**. Compute each rate, skip nonpositive rates, return zero immediately for an empty required resource, otherwise take `min(duration, available / rate)`. Finish with `max(duration, 0.0)`.
5. Consume inputs in definition order. Read that input's current balance, **re-evaluate** its rate against the current state, calculate `rate * duration`, clamp by the current balance with `min`, and skip nonpositive consumption. Write the balance with the original setter and record consumption immediately. Later inputs see these writes. Availability is not recomputed after each consumption.
6. Produce unlocked outputs in definition order. Evaluate the rate after all input writes, multiply by operating duration, then perform native resource/statistics writes. Discrete output adds to its original fractional phase, floors each tick, writes/records positive whole units and subtracts them from the phase. Later outputs see earlier output writes. Subsequent generators see all these transactions.
7. Stop the generator if `duration < 0.1 - 0.000001`. Exhaustion exactly at 0.1 leaves `operating` true until the next availability check; this is tested rather than normalized away.
8. Apply native Matter decay (including Heat conversion), then Heat leak using tick-start Heat and the unchanged native stiff solver. Update both automation managers and offline bookkeeping in their original positions.

The ordinary input formula is left-associated base rate × mode input multiplier, followed by applicable INPUT_DRAW modifier/sensitivity applications in their original order, followed by level scaling (or 1 when scaling is disabled). Static folding stops at the first dynamic dependency; subsequent constant factors remain separate tape entries. Dynamic resource-dependent modifiers and matching dynamic sensitivities execute at their original evaluation point. No numerical operation is reassociated to combine input totals.

Two inputs can reference the same resource. Native duration calculation considers each separately rather than dividing by their summed demand; consumption then clamps sequentially. The new packet deliberately preserves this behavior. Duplicate-input and competing-generator tests protect against an apparently cleaner net-flow implementation changing gameplay.

Pure computations: base rate/modifier/sensitivity evaluation, availability, normal/throttled reserve tests. Mutable operations: controller throttle assignment, operating-state transitions, input/output balance setters, phase writes, discovery/peaks/counters, automatic effects, log/signal histories and environmental accounting. Native setters and accounting remain in use.

## 2. Ordered packet and ownership

`exact_flow_packet.gd:InputOperation` retains the original GeneratorIO definition, ResourceState reference, resource ID and optional compiled Rate. `Machine.inputs` is an ordered array built once from the active mode. It owns no shadow balances or new generator objects. `single_input` and `multiple_inputs` are derived execution metadata; they introduce no second authoritative state.

The general multi-input path has distinct startup, availability and consumption passes. It re-evaluates the consumption rate for **each** input after preceding input writes. It makes no per-tick dictionaries or temporary input arrays. Sources and single-input machines retain a specialized path: a rate may be reused between startup/availability/consumption because the admitted pure base methods make no intervening resource changes. This preserves the previous early-game optimization.

Controller-dependent input operations have no compiled input tape: they call `Generator.get_input_consumption_per_second` directly. Ordinary consumers retain the audited Rate compiler. All output phases, modifier-cache initialization and live output/statistics writes use the previous exact implementation. The packet's lifetime and reference/alias contract remain one exclusive synchronous public call, ending at return or an automatic-action boundary. No reference is retained across calls and no bulk synchronization is needed.

## 3. Reviewed Lava Mite controller contract

`exact_flow_controller.gd` is a small capability selector and dependency descriptor. Its only generator-specific selection is Lava Mite Colony's existing native semantics. The generic IO loop contains no generator-ID-specific branch. The existing simulation helper remains responsible for updating all throttle flags, including resetting stray flags on other generators. No alternative throttle formula is implemented.

| Contract item | Exact treatment |
|---|---|
| Runtime state | Original `is_throttled`, `operating`, pause/level/mode and GameState dormancy penalty |
| Read dependencies | Current Heat/Ash (and actual mode inputs), ordered definitions, level, modifiers, sensitivities, mode multipliers and current penalty |
| Write dependencies | Controller writes only `is_throttled`; ordinary flow writes resources, runtime flags and accounting afterward |
| Placement | Native `_update_lava_mite_throttle_state` before startup and availability at that generator's registration position |
| Throttle entry | Native normal and throttled rates evaluated in input order; entry occurs when normal > throttled and the normal one-second reserve exceeds the available balance |
| Recovery hysteresis | Native normal override for every input; recover only when **all** normal one-second input reserves are available. Equality is sufficient; Heat and Ash just-below/equal/just-above reserves have explicit regression witnesses |
| Rate selection | Native input-rate API applies current throttle state. Throttling suppresses dynamic Ash-dependent escalation except `lava_mite_dormancy`; it does not bypass unrelated modifiers or sensitivities |
| Ordinary transitions | Entry/recovery, partial operation and stopping require no packet rebuild because controller input rates are live |
| TimeManager | Core reads the existing state penalty; TimeManager alone owns dormancy onset/ramp and real-time recovery. No TimeManager is called or copied |
| Invalidation | Level, mode, definitions, modifiers, sensitivities and penalty changes between calls are rebuilt/read afresh; automatic effects run in a complete native tick before reconstruction |

Normal, throttled, recovery, high-Ash and fixed-dormancy numerical states are supported. The repeated-transition test alternates actual resource availability and penalty values across 40 calls and observes 40 native-equivalent throttle transitions. This diagnostic intentionally edits stocks; it is not progression or performance evidence.

Unsupported: advancing offline dormancy clocks or live recovery within a retained packet, yields/concurrent edits, script reload, live UI/external callbacks and filesystem logging. A scheduling integration must stop the public call, let TimeManager update its state, then make another call. That future integration is not implemented here. The API takes a Simulation and tick count, not a TimeManager or an offline-clock schedule; it does not claim to detect an unobservable external thread violating exclusive access.

## 4. Invalidation and exact fallback

No ordinary resource write invalidates structure. Actual input rates/feedback and native controller transitions remain dynamic. Automatic upgrade eligibility is checked before the tick: release the plan, run the whole native tick (including cascading effects), and attempt a new plan on the next tick. Public calls always rebuild, covering input array reordering, IO amounts, resource references, level, pause, mode, sensitivity, upgrades and unlock changes. Input structure is never cached across a return to the caller.

Enabled automation, active or auto-run cycles, relic inventory/equipment, Essence modifiers/sensitivities or unlocked Essence output, prestige planning, unknown implementation scripts, unsafe logger/observer boundaries and resource transfers remain native fallback. The first reason is recorded in runtime counters; benchmark observations additionally inventory independent automation/cycle/Essence/relic blockers without disabling them. An unsupported call stays native for its remaining ticks; eligibility is reconsidered at the next public call. Transfer→ordinary reentry tests verify resumption.

### Resource transfers: reviewed, still unsupported

Native transfer input rates bypass input modifiers and use base × input multiplier, then level scaling. Every transfer output instead uses the **first input's** base rate × level × input multiplier, bypassing output amounts, production modifiers, realm bonuses and Eternal Furnace. That multiplication association differs from the input association. Discrete output handling still occurs afterward. Multiple-input transfers consequently have special semantics beyond ordinary input consumption. Supporting actual compression/expansion resources also broadens output eligibility beyond Heat/Matter/Ash. This secondary capability remains explicitly rejected (`unsupported_transfer_mode`); no transfer mode is routed through ordinary formulas. A dedicated reviewed rate adapter is the necessary next contract if this becomes relevant.

## 5. Fixtures and differential validation

The original early, mid and Forge fixtures are unchanged. Additional `consumer_9500`, `consumer_20000` and `consumer_50000` saves come from `consumer_progression_builder.gd`: load the existing reached early snapshot at ledger tick 8396 and replay the **unchanged** legal purchase/pause ledger through tick 50000, before the first Forge activation at 52080. Every action checks original visibility, affordability, ledger price and resulting level. No grants, automation disable, cycle removal, relic removal or balance edits are made. All five Mite levels are earned through the original purchase APIs. `consumer_progression.json` preserves saves and action counts; the original ledger is their reproducible provenance.

These are first-realm consumer-stage states, not replacements for the mature eight-prestige mid fixture. Their particular player strategy legitimately has no enabled buyers or active crafting yet. All earned effects, Ash contamination, dynamic input escalation, discovery, environmental mechanics and resource feedback remain active. Offline intervals perform no new manual purchases, as with the existing early benchmark.

Controlled edge cases are separately labeled: funded/partial/empty/near-zero/exact-boundary inputs; duplicate inputs; competing consumers; an integer resource source registered before its consumer; dynamic second-input draw and sensitivity reading the first consumed resource; output feedback reading a consumed resource; high-Ash Mites; throttle entry/recovery; fixed nonzero dormancy; transfer rejection. Custom IO probes use ordinary base definitions and APIs; they are never primary realistic performance evidence.

`consumer_tests.gd` compares binary views after **every tick**, with the original identity-aware whole-graph fingerprint at endpoints and before/after read-only construction. Coverage includes three 2,000-tick reached intervals and a 10,000-tick reached run, diagnostic sequences, 40 reconstructed controller calls, input-order/level/rate changes, zero-level activation, fallback and resumption. Explicit witnesses ensure the dynamic-input case distinguishes sequential re-evaluation from a shared resource snapshot, the partial cases consume positive amounts, exact-boundary exhaustion retains the original operating flag, and earlier integer output is consumed within that same tick.

Existing exact-kernel tests still exercise automatic upgrade boundaries, all resource thresholds, reconstruction, transaction interoperability, real Forge completion and RNG-dependent fallback. The former Mite-reentry rejection assertion now requires actual kernel execution and no safety rejection, allowing a legitimate native automatic-upgrade tick. No tolerance or parity assertion is weakened. The new consumer regression group is registered alongside all prior groups.

Binary views include resources/production/consumption/peaks, generator phases/runtime/throttles, levels/unlocks/upgrades, inventory/prestige/technology, dormancy value, log/signal history, automation/cache state, RNG and interval/offline bookkeeping. Complete graph fingerprints provide an additional endpoint check. The reached-save tests additionally require real Mite operation; every tick of the measured reached intervals observes an operating colony. Numerical comparison tolerances in raw benchmark diagnostics are inherited; pass/fail for kernels uses complete byte equality, not those tolerances.

## 6. Benchmark method and interpretation

`consumer_benchmark.gd` compares native exact, the actual prior public kernel and prebuilt prior packet, extended public kernel and isolated extended packet, plus the existing adaptive runner as a reference. `baselines/exact_flow_43b3897_packet.gd` is the exact committed old packet; its paired old kernel differs only in the preload path to that retained packet. Both run against unchanged production code and the same deterministic states as the new version. No old timing from another run/environment is used to calculate the before/after speedups.

Four repetitions alternate method order; the first is warmup, leaving three samples. Report medians and observed min/max ranges, not confidence intervals. Each method starts from an identical state, resetting offline statistics in the same way. Oracle capture/comparison, fixture loading and fixture progression are outside all timed regions. Profiling, tracing and flow telemetry are disabled during throughput. Separate untimed diagnostic runs measure controller transitions, exact input-depletion writes (including tick-boundary exhaustion), partial operations, automatic boundaries and phase costs.

Public timings include packet construction, eligibility/invalidation, disposal, automatic native event ticks, native fallback and all in-place resource/statistics synchronization. Isolated packets exclude construction/reconstruction but include event checks, fallback and every live write; they do not defer accounting. Initial retained allocation is estimated by `OS.get_static_memory_usage` after construction minus before; this is neither exact heap churn nor peak RSS. Rejected builds can retain no packet and thus report zero incremental retained bytes.

The existing adaptive runner has its own elapsed-endpoint clipping and TimeManager dormancy advancement. Its raw errors/context differences remain visible, as in the previous report; it is **not** the oracle for this fixed-penalty synchronous core experiment. Native, previous and extended kernels must all have complete binary equality. No throughput gain attributed to a fallback-only fixture is claimed as a capability speedup.

## 7. Architectural assessment and next milestone

Generalized consumption removes repeated structure lookup while retaining every rate evaluation whose inputs may have changed. Timings measure the whole supported core interval, not an isolated speedup of the native Mite input-rate formula; controlled ordinary multi-input probes are separately labeled diagnostics. The native controller API intentionally leaves substantial rate/modifier traversal work in controlled machines; optimizing its normal/throttled tapes would need a separate reviewed filter contract and stronger sensitivity tests. This milestone prioritizes safe capability over that extra optimization.

The first incremental measurement showed about 7% early overhead from additional wrapper calls. Inlining the already-proven single-input tape access and retaining a cached multi-input capability flag removed that wrapper cost in the short comparison. This does not guarantee zero overhead for every duration; final long-run changes are reported explicitly below. No formula or call whose state could change was eliminated. Final comparable measurements, rather than those development samples, are reported below.

Invalidation remains bounded: structure rebuild at public entry and native automatic-action ticks; controller transitions and resource exhaustion do not reconstruct the packet. There is no write interception, journal, per-field synchronization phase or broad controller framework. Additional exact generators can share the ordered IO machinery; special semantics require reviewed adapters, not ID branches in the general loop.

The unchanged mature fixtures determine the next capability: report all their independent blockers before choosing automation or cycles. Enabled automation remains a separate architectural boundary because it buys levels/upgrades after generator processing and can change next-tick tapes. Cycles additionally introduce progress/completion, RNG, item rewards and auto-run. Neither capability is implemented in this milestone. TimeManager integration is necessary for a full offline dormancy run, but not for fixed-penalty exact-core consumer/controller experiments or their performance comparison.

Actual engine/host, final parity, coverage and timing tables are generated from retained JSON records below. Linux Godot 4.6.1 validation does not establish Windows Godot 4.7.2 compatibility. No measured speedup here implies full-game or production offline acceleration.

## Reproduction

```sh
python tests/experimental/run_consumers.py --godot /path/to/godot --mode fixtures
python tests/experimental/run_consumers.py --godot /path/to/godot
/path/to/godot --headless --path . --script tests/run_regression_tests.gd
python tests/experimental/summarize_consumers.py
```

Fixture generation is explicit and is not repeated during timed benchmarks. `CONSUMER_BENCH_QUICK=1` selects only short development scenarios; final retained results use the full scenario list. The Python runner treats nonzero exit, ERROR and WARNING as failures. Raw progression, validation, measurements, summaries, environment/source hashes and final logs are preserved under this directory. Earlier milestone raw benchmark/validation records remain historical artifacts.


Final validation: **93 regression groups passed, 0 failed**, retaining all prior 92 groups. No parser warnings or runtime errors occur in the final retained logs. The standalone consumer suite also passes all six reserve-edge witnesses, all 40 repeated throttle transitions and actual Mite operation on every tick of the reached-save differential intervals.

## Final measurements

Official 4.6.1-stable (official), Linux x86_64, AMD EPYC 9V74 80-Core Processor. All times below are milliseconds unless labeled otherwise. One warmup excluded, three measured repetitions. Raw samples and ranges are retained in consumer_summary.json.

| Fixture / ticks | Native | Previous public | Extended public | Adaptive reference | Extended / native speedup | Extended coverage |
|---|---:|---:|---:|---:|---:|---:|
| consumer_20000 / 2000 | 364.702 | 334.428 | 226.230 | 369.260 | 1.612× | 100% |
| consumer_50000 / 2000 | 348.071 | 366.794 | 236.221 | 393.331 | 1.473× | 100% |
| consumer_50000 / 10000 | 1555.982 | 1584.618 | 990.535 | 1691.212 | 1.571× | 100% |
| consumer_9500 / 2000 | 337.879 | 318.066 | 210.308 | 372.629 | 1.607× | 100% |
| early / 2000 | 225.331 | 126.784 | 114.422 | 254.316 | 1.969× | 100% |
| early / 36000 | 4832.249 | 2516.034 | 2681.662 | 5102.634 | 1.802× | 100% |
| forge_competing / 2000 | 757.131 | 764.716 | 817.808 | 855.147 | 0.926× | 0% |
| mid / 2000 | 270.762 | 276.072 | 269.605 | 299.381 | 1.004× | 0% |
| mite_entry / 2000 | 66.227 | 70.780 | 53.509 | 85.603 | 1.238× | 100% |
| mite_recovery / 2000 | 131.022 | 131.641 | 108.199 | 150.933 | 1.211× | 100% |
| multi_dynamic / 2000 | 79.019 | 75.718 | 51.744 | 95.195 | 1.527× | 100% |
| multi_partial / 2000 | 67.978 | 69.326 | 42.028 | 88.183 | 1.617× | 100% |

The original mid and Forge fixtures still have zero kernel coverage; their apparent relative speed changes are fallback-loop/scheduling measurements, not acceleration of those mechanics. Diagnostic scenarios (mite_*, multi_*) are controlled cases, not mature-game speedup evidence.

| Fixture / ticks | Previous isolated | Extended isolated | Isolated speedup vs native | Public build µs | Public release µs | Packet bytes (retained estimate) |
|---|---:|---:|---:|---:|---:|---:|
| consumer_20000 / 2000 | 356.160 | 247.157 | 1.476× | 371 | 53 | 19824 |
| consumer_50000 / 2000 | 352.262 | 232.296 | 1.498× | 358 | 50 | 19824 |
| consumer_50000 / 10000 | 1483.070 | 920.036 | 1.691× | 436 | 55 | 19824 |
| consumer_9500 / 2000 | 312.807 | 204.482 | 1.652× | 373 | 56 | 26592 |
| early / 2000 | 131.260 | 118.957 | 1.894× | 398 | 50 | 22988 |
| early / 36000 | 2547.595 | 2624.625 | 1.841× | 723 | 52 | 22988 |
| forge_competing / 2000 | 789.908 | 794.927 | 0.952× | 187 | 3 | 0 |
| mid / 2000 | 281.393 | 280.166 | 0.966× | 367 | 5 | 0 |
| mite_entry / 2000 | 76.802 | 53.446 | 1.239× | 454 | 40 | 12808 |
| mite_recovery / 2000 | 133.287 | 107.245 | 1.222× | 343 | 42 | 12808 |
| multi_dynamic / 2000 | 84.513 | 50.378 | 1.569× | 387 | 61 | 20964 |
| multi_partial / 2000 | 74.666 | 42.918 | 1.584× | 290 | 60 | 20804 |

There is no additional bulk write-back or checkpoint cost. Every live balance/phase/statistics write is included in both isolated and public kernel time. Independent samples and different loop dispatch/control paths can invert isolated/public medians; their difference is not a setup measurement.

| Fixture / ticks | Previous public range | Extended public range | Extended µs/tick | Public change vs previous |
|---|---:|---:|---:|---:|
| consumer_20000 / 2000 | 288.955–373.068 | 200.958–247.943 | 113.11 | -32.35% runtime |
| consumer_50000 / 2000 | 302.154–379.438 | 201.366–248.013 | 118.11 | -35.60% runtime |
| consumer_50000 / 10000 | 1542.339–1738.673 | 949.507–1055.413 | 99.05 | -37.49% runtime |
| consumer_9500 / 2000 | 307.361–318.753 | 201.740–214.942 | 105.15 | -33.88% runtime |
| early / 2000 | 118.209–133.831 | 114.001–129.399 | 57.21 | -9.75% runtime |
| early / 36000 | 2419.810–2794.748 | 2641.434–2809.972 | 74.49 | +6.58% runtime |
| forge_competing / 2000 | 718.944–765.595 | 810.632–818.744 | 408.90 | +6.94% runtime |
| mid / 2000 | 263.732–286.917 | 268.400–278.797 | 134.80 | -2.34% runtime |
| mite_entry / 2000 | 68.547–76.256 | 46.229–61.426 | 26.75 | -24.40% runtime |
| mite_recovery / 2000 | 130.420–133.060 | 99.912–129.750 | 54.10 | -17.81% runtime |
| multi_dynamic / 2000 | 74.962–93.253 | 50.658–57.496 | 25.87 | -31.66% runtime |
| multi_partial / 2000 | 67.469–76.234 | 41.598–44.481 | 21.01 | -39.38% runtime |

Early public runtime changes versus the previous kernel are -9.75% at 2,000 ticks and +6.58% at 36,000 ticks; their observed ranges overlap. Both remain faster than native. The longer median regression is retained explicitly. Extra input-record indirection and disabled diagnostic branches add interpreter work; scheduling/cache variance is also visible, and three samples cannot attribute the whole difference to either. The consumer-stage speedups survive construction and all required synchronization; these states still have no running TimeManager schedule.

| Untimed diagnostic interval | Kernel / native ticks | Builds | Automatic event ticks | Throttle transitions | Partial-duration operations | Input exhaustion events | Empty duration checks |
|---|---:|---:|---:|---:|---:|---:|---:|
| early / 2000 | 2000 / 0 | 1 | 0 | 0 | 2000 | 2000 | 0 |
| early / 36000 | 36000 / 0 | 1 | 0 | 0 | 36000 | 32880 | 0 |
| mid / 2000 | 0 / 2000 | 1 | 0 | n/a | n/a | n/a | n/a |
| forge_competing / 2000 | 0 / 2000 | 1 | 0 | n/a | n/a | n/a | n/a |
| consumer_9500 / 2000 | 2000 / 0 | 1 | 0 | 1 | 2000 | 1850 | 0 |
| consumer_20000 / 2000 | 2000 / 0 | 1 | 0 | 0 | 0 | 0 | 0 |
| consumer_50000 / 2000 | 2000 / 0 | 1 | 0 | 0 | 0 | 0 | 0 |
| consumer_50000 / 10000 | 10000 / 0 | 1 | 0 | 0 | 0 | 0 | 0 |
| mite_entry / 2000 | 2000 / 0 | 1 | 0 | 1 | 0 | 1 | 1 |
| mite_recovery / 2000 | 2000 / 0 | 1 | 0 | 2 | 1 | 1 | 0 |
| multi_dynamic / 2000 | 2000 / 0 | 1 | 0 | 1 | 4 | 1 | 0 |
| multi_partial / 2000 | 2000 / 0 | 1 | 0 | 1 | 1 | 1 | 0 |

Partial operations count positive input-limited durations below the native stop epsilon, across all executed continuous generators. Empty duration checks count reached multi-input duration checks returning zero; empty startup rejection is earlier and is not included. Input exhaustion events count each positive sequential consumption that writes an input balance to exactly zero, including exact-boundary depletion; already-empty startup is not a new exhaustion event. Exact-boundary and startup exhaustion have dedicated binary regression witnesses. A partial-duration operation can leave a floating-point residual; no epsilon clamp is introduced. Flow event telemetry covers kernel-executed work; internal events during native fallback are not attributed. Rebuild count is builds minus one; controller transitions require no rebuild. The separate automatic-upgrade regression continues to require native boundary exit/reconstruction.

Independent blocker inventory at entry:

- mid: `{"active_or_auto_cycles": [], "enabled_automation": ["atomic_friction"], "essence_modifiers": [], "relic_inventory_entries": 0}`

- forge_competing: `{"active_or_auto_cycles": ["infernal_forge"], "enabled_automation": ["atomic_friction"], "essence_modifiers": [], "relic_inventory_entries": 0}`

**Parity:** 192 previous/extended public/isolated samples including warmup have complete byte equality, discrete/RNG equality and zero measured numerical error against constant-tick native control. The dedicated consumer suite compares 17600 individual tick views plus repeated/reentry views; the long reached test spans 10,000 ticks. Binary equality includes fractional phases, consumption/accounting, throttles and the fixed dormancy penalty. No tolerances were expanded.

**Next capability:** enabled generator/upgrade automation, with native ordering/cooldown/waiting-cache preservation and a post-purchase structural invalidation contract. It is the independent blocker in the original mid fixture. Active cycles remain an additional Forge blocker. TimeManager integration is separately necessary before claiming end-to-end dormancy behavior or offline-client speedups; rebuilding per tiny clock update could erase the measured benefit and must be measured.
