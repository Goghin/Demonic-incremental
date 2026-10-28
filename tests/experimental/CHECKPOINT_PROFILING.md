# Checkpoint profiling and compact runtime descriptors

## Outcome and scope

Base: `ae889322811165c7590ed9b76683543401e7dcd9`, branch `feature/cycle-auto-run`. The original `transaction_checkpoint.gd` is unchanged. `simulation_transaction.gd` now defaults to `compact_checkpoint.gd`; its optional third constructor argument selects the original implementation for tests. No production source, gameplay formula, balance, save format, adaptive eligibility/integration, or resource-flow algorithm changes. The four pre-existing untracked files are preserved. The `game.gd:771` editor issue is outside this change.

Implemented optimizations are shared audited instance-field descriptors, compact graph storage, and identity lookup buckets. **Every field and nested mutable value captured by the reference remains captured.** This is deliberately less selective than a checkpoint that omits configuration: the profile justified eliminating representation overhead first. No mutable definition array/dictionary is assumed immutable; no derived cache is reconstructed. Checkpoint graph node counts remain the same in differential fixtures.

The original and compact implementations retain the same isolated synchronous simulation-core boundary, TickLog restriction, owned signal journal, RNG adapter, weak back-references and external-side-effect exclusions. Whole-TimeManager/runner rollback and production UI/filesystem logging are not supported.

## Baseline reproduction and architecture

Before optimization, the existing full suite passed 89 groups and the original nine-fixture transaction tests passed. Their raw correctness outcomes are retained in the baseline/final validation record. Comparable performance comes from the new serial harness using the **unchanged original implementation**, not the older machine's report or timings collected alongside regression work.

The reference snapshot walks GameState and all admitted script objects recursively. Each scalar is wrapped in a `{"literal": value}` dictionary, each graph reference in `{"ref": id}`, each dictionary entry in a pair array, and each object in a record containing a newly constructed field-name dictionary. This repeats field maps across 77 Upgrade objects/definitions, 92 effects, 84 modifiers and other objects in the Forge graph. Property metadata is enumerated per object. Snapshot targets retain original object/container identities; no Object/Resource is cloned. Containers are searched linearly with `is_same`.

Capture constructs that graph. Advance runs the authoritative offline update. Restore clears/refills original containers and assigns raw object fields; RNG seed precedes state, and computed manager `state` aliases are skipped. Verification traverses the graph again. Commit simply releases the snapshot; rollback performs restore, verification and release. Thousands of token dictionaries therefore cost both allocation time and release time. The original numerical/state oracle is still used for complete binary fingerprints even when compact transactions are under test.

## Measurement method

`checkpoint_benchmark.gd` uses the same early, mid and primary `forge_competing` saves, a fresh Simulation, attached offline ResourceStatistics, invalid-clock TickLog and owned signal journal for both implementations. Setup/save loading is outside timed sections. Candidate windows match the original transaction tests: 100 exact ticks for early/Forge, 600 for mid. A rejected snapshot is captured, advanced, restored, verified and released. A second snapshot advances the same restored state and is released to measure commit. All verification failures terminate the harness.

`run_checkpoint_benchmarks.py` runs two serial blocks in reverse order: reference→compact, then compact→reference. Each process records eight samples per fixture; the first is excluded as cold/warmup. Final medians use **14 warm samples per fixture/implementation**. Quartiles use the inclusive method. Wall-clock microseconds include scheduler noise. No concurrent Godot validation/benchmark process ran during these final paired blocks. Raw cold/warmup samples are retained.

Capture, restoration, post-restore verification, rejected-snapshot release and commit release are timed separately. Rejection overhead is the per-sample sum of capture + restore + verify + release, excluding advancement. These are checkpoint-layer measurements; transaction wrapper ownership checks/dispatch are not timed separately. Existing lifecycle tests still exercise that wrapper. Candidate advancement is retained in the raw data and is not credited as a checkpoint optimization.

Memory is `OS.get_static_memory_usage()` after capture minus before checkpoint construction. This is an allocator-accounted **estimate of incremental retained allocation**, not an exact resident-memory peak. It excludes already-loaded Script bytecode and shared constant metadata. No serialized-size claim is used for heap accounting. The compact descriptor's process-lifetime validation cache contributes about 2,356 extra bytes in the first early capture versus warm captures in both final blocks; that is separate from shared compiled descriptor/code memory, which is not isolated here. Cold CPU results are retained rather than attributed solely to validation.

Subsystem probes separately snapshot selected live subgraphs, five times per block. Synthetic roots/selection dictionaries are built outside the probe. The probes overlap through shared dependencies and are **non-additive**: automation includes weak references but not the referenced GameState; upgrade state includes its definitions; generator runtime includes effects. They establish where copying/traversal costs reside, not an exclusive allocation partition. An additional, clearly diagnostic Forge profile creates twelve random relics using a fixed RNG seed; it is not a representative reachability fixture or a coverage claim.

## State classification and reference ownership

| Category | Owners/fields | Compact contract and lifetime |
|---|---|---|
| A: immutable configuration | Executable Script resources, semantic formula/type/name metadata, and presentation RealmLayout | Script and RealmLayout remain the original explicit opaque exceptions. Semantic metadata on gameplay definition objects is physically writable and still snapshotted conservatively. Only read-only descriptor field-name arrays and scalar value storage are shared as immutable metadata. Script reload/layout editing remain outside scope. |
| B: authoritative runtime | ResourceState.amount; discovery/threshold/interval dictionaries; generator level, flags, mode, output remainders, cycle progress/critical snapshot; automation enabled/cooldown/waiting/cost caches; upgrade levels; mode/IO unlocks; event_source_upgrade_id; relic inventory/positions/equipment/machine slots/generated definitions/next IDs; RNG seed/state; statistics; prestige counters; owned event histories | All original fields and nested arrays/dictionaries/objects are retained as graph targets and copied into separate value/reference arrays. Original target identities are retained strongly until resolution. Integer links refer to original graph targets, never candidate replacements. No live mutable container is used as the snapshot's value storage. |
| C: derived | Generator production modifier cache, automation enabled-ID indexes/dirty flags, Simulation automatic-upgrade index/count/realm key, RealmEffects and derived interval bookkeeping | Captured and restored exactly. Reconstructing these was not shown to be cheaper or safer; cache arrays can share modifier objects and their identities are observable. Duration/speed/remaining cycle time remain derived from captured mode/progress/resources/effects. |
| D: external/unsupported | TimeManager/runner clocks and scheduling, live UI/audio, arbitrary/deferred callbacks, filesystem GameplayLog, script reload, unknown script/native state, packed mutable arrays in the live graph, concurrent mutation/yields/message-queue pumping | Same explicit exclusions. Begin refuses detectable unsupported graph/observer state. The boundary must not execute external owners. Unsupported native objects encountered before capture do not get silently shared. |

`runtime_state_descriptors.gd:FIELDS` enumerates every previously inventoried instance field, including configuration, private caches and nested-definition ownership references. The existing per-field appendix/inventory in TRANSACTIONS.md remains applicable; its I fields are not newly omitted. The compact descriptor is checked against the complete actual script-variable list on first use of each exact Script, excluding only the three pre-existing computed weak `state` aliases. Schema additions/removals/order changes fail closed until reviewed. New scripts/subclasses require descriptors. Executable scripts must stay stable for the supported session; reload is outside scope. Signal connections are inspected on every object/capture, rather than cached by class, so dynamically added external observers cannot bypass a warmed descriptor.

The descriptor constant arrays are read-only and live for the loaded Script's lifetime. The small validation map strongly retains validated Script objects for that lifetime. Per-checkpoint `targets` strongly retains all original objects/containers. `values` contains scalar values or existing opaque immutable leaves; `links` contains integer target indexes with -1 for a scalar. `fields` points to shared descriptor metadata, not generator mode/IO collections. Object ID maps and type/size bucket lists hold integers. These indexes are checkpoint-local and are released at resolution. No cache binds a descriptor to a particular generator ID or instance.

## Implementation and incremental decisions

1. Preserve the original implementation as the oracle. Introduce full audited field descriptors and parallel target/kind/field/value/reference arrays. Replace per-value dictionaries and per-entry pair arrays with scalar slots and integer links. Retain all configuration traversal. The initial compact variant passed all nine fixtures before the next change. `checkpoint_compact_step1.json` retains its exploratory seven-sample raw run; it is superseded by the final order-balanced comparison and is not used for final percentage claims.
2. Narrow container identity lookup by `typeof` and `size`, then test `is_same` against prior targets in that bucket. Equal-but-distinct containers remain distinct. During the supported synchronous capture, admitted field getters do not mutate container sizes; candidate execution occurs only after capture. Cycles are registered before traversing children. Hashing container contents was avoided because equality/hashes do not establish identity and cyclic/large contents would add work.
3. Keep original mutable definition/configuration capture, cache restoration, signal checks and lifecycle behavior. Selective immutable-container sharing, derived-cache reconstruction, pooling and write interception were not implemented. They would add audit surface while the representation changes already produce a substantial measured benefit.

The lifecycle wrapper still rejects inactive operations/nesting, retains a checkpoint on verification failure and restores an abandoned active transaction. Commit does not copy/apply state; it only releases the captured originals and storage. Restoration never reconnects signals, replays RNG, replaces manager instances or invokes gameplay resource setters. Field descriptors contain no generator IDs. Future generator classes can participate through a reviewed complete descriptor and any required native-state adapter.

## Correctness evidence

The nine original fixtures are retained for both implementations: early, mid, three Forge variants, three automation fixtures and the reached first-Forge-completion witness. Each implementation performs 27 mixed rejected candidates and nine committed candidates, with the original complete binary fingerprint immediately after each rollback, during authoritative continuation, at commit and after a following exact tick. There are no new numeric tolerances. The separate RNG probe requires normal/critical/downlevel/relic outcomes and subsequent exact RNG draws.

The paired validation runner also shares initial RNG/presentation values across implementation runs and compares their final binary endpoint fingerprints directly. This normalization is only for independently initialized fixtures; it changes no resource, level, upgrade or mechanic. Every run still has an independent exact control, and the original full-state fingerprint includes all supported runtime metadata and alias topology.

New contract probes run against both implementations. They mutate deeply nested dictionaries/arrays/objects, equal-but-distinct dictionaries, shared modifier/phase references, generated relic metadata, equipment, mode duration/completion metadata, output amounts, effect source metadata, fractional production and Forge progress. They interleave repeated rejections and commits, verify original item/container identities, exercise unsuccessful generator purchases and restored waiting/cost/cooldown state, and reject packed data plus a dynamically added deferred signal listener after warming the schema cache. Existing real completion, successful purchase, critical outcome, lifecycle, abandoned-transaction and external logger tests remain intact.

## Readiness and next experiment

The transaction boundary can safely mutate supported output remainders and active Forge progress, and rejected candidates restore all captured core state. Its remaining cost is meaningful: these measurements support low-frequency/coarse probes, not free checkpoints at every 0.1-second tick. At roughly 15–20 ms capture and 26–32 ms rejected overhead on this host, the CPU-only ceiling is about 50–65 captures or 31–39 rejected attempts per wall-clock second before advancement/other work. This is an upper bound, not a recommended rate. A few attempts per second are practical for an experiment; an adaptive speedup still needs intervals that amortize this cost. Around 0.8–0.93 MiB of incremental allocation per active snapshot is modest for one synchronous transaction, though repeated allocation/collection still matters.

The largest remaining work is traversing complete upgrade/effect/configuration graphs, scanning same-size container buckets, native property gets/sets, verification and per-object signal inspection. Large future relic inventories/event histories will increase the cost. The twelve-relic diagnostic quantifies that direction without predicting a mature-save budget. There is no measured adaptive coverage or end-to-end simulator throughput improvement.

Proceed next with an **isolated core-only ordered resource-flow batching investigation**, using the compact checkpoint and original oracle. Keep current eligibility unchanged until the new algorithm's own ordering/phase/affordability proofs and differential tests justify changes. A core-only experiment does not require TimeManager or external-event adapters when it leaves those owners unchanged and stays synchronous. It must retain the same incoming dormancy/clock context, update only captured core state, and use the owned in-memory event journal. Advancing manager/runner clocks, emitting UI/file effects, spanning externally controlled context changes, yielding, or introducing unknown live native/script state would require a new adapter/boundary review or exact fallback. No such adapters or batching are implemented here.

## Reproduction and artifacts

```sh
python tests/experimental/run_checkpoint_benchmarks.py --godot /path/to/godot
/path/to/godot --headless --path . --script tests/experimental/run_checkpoint_validation.gd
/path/to/godot --headless --path . --script tests/run_regression_tests.gd
```

Raw files: `checkpoint_reference_measurements.json`, `checkpoint_compact_measurements.json`, exploratory `checkpoint_compact_step1.json`, and `checkpoint_differential_results.json`. `checkpoint_comparison.json` contains medians, quartiles and percentage reductions; `checkpoint_validation.json` records source/log hashes and validation environment. The original transaction_results.json/transaction_validation.json are preserved as historical artifacts. The standalone original transaction runner now writes current output to checkpoint_transaction_results.json to avoid overwriting that history.

All execution here uses official Linux x86_64 Godot 4.6.1, debug checks enabled, AMD EPYC 9V74 host. This does not establish Windows Godot 4.7.2 compatibility. The existing editor parse issue remains unchanged; a clean editor parse is not claimed.

## Final before/after measurements

Each value is median [25th–75th percentile]. Memory is MiB; times are milliseconds. Change is percentage cost reduction, computed from medians. Rejection is computed per sample before taking its median, so medians of components need not sum exactly.

### early

| Metric | Original | Compact | Reduction |
|---|---:|---:|---:|
| Checkpoint allocation estimate (MiB) | 4.724 [4.724–4.724] | 0.790 [0.790–0.790] | 83.3% |
| Capture (ms) | 33.194 [31.714–36.779] | 16.245 [16.043–16.545] | 51.1% |
| Restore only (ms) | 11.189 [10.702–13.404] | 4.324 [4.146–4.778] | 61.4% |
| Verification (ms) | 11.905 [11.041–12.898] | 4.750 [4.606–5.105] | 60.1% |
| Rejected snapshot release (ms) | 3.523 [2.760–3.991] | 0.272 [0.250–0.304] | 92.3% |
| Commit release (ms) | 3.792 [3.536–4.027] | 0.369 [0.314–0.411] | 90.3% |
| Rejected overhead excluding advance (ms) | 61.849 [58.636–64.746] | 25.895 [25.122–26.862] | 58.1% |
| Authoritative candidate advance (ms) | 10.982 [10.711–11.475] | 10.133 [9.973–10.346] | Not attributed to checkpoint |

### mid

| Metric | Original | Compact | Reduction |
|---|---:|---:|---:|
| Checkpoint allocation estimate (MiB) | 4.601 [4.601–4.601] | 0.773 [0.773–0.773] | 83.2% |
| Capture (ms) | 32.429 [31.589–33.907] | 15.278 [14.876–16.632] | 52.9% |
| Restore only (ms) | 10.652 [10.287–11.314] | 4.782 [4.566–4.902] | 55.1% |
| Verification (ms) | 10.758 [9.439–11.728] | 4.686 [4.576–4.945] | 56.4% |
| Rejected snapshot release (ms) | 2.836 [2.483–3.425] | 0.336 [0.308–0.359] | 88.2% |
| Commit release (ms) | 4.241 [4.030–4.443] | 0.619 [0.601–0.633] | 85.4% |
| Rejected overhead excluding advance (ms) | 57.514 [55.276–60.294] | 25.666 [24.581–26.566] | 55.4% |
| Authoritative candidate advance (ms) | 57.927 [55.985–60.133] | 52.660 [51.860–54.717] | Not attributed to checkpoint |

### forge_competing

| Metric | Original | Compact | Reduction |
|---|---:|---:|---:|
| Checkpoint allocation estimate (MiB) | 5.298 [5.298–5.298] | 0.930 [0.930–0.930] | 82.4% |
| Capture (ms) | 36.877 [35.492–37.814] | 19.544 [17.782–21.005] | 47.0% |
| Restore only (ms) | 12.023 [11.415–13.132] | 5.569 [5.216–6.377] | 53.7% |
| Verification (ms) | 12.248 [11.561–13.700] | 5.587 [5.218–6.348] | 54.4% |
| Rejected snapshot release (ms) | 3.997 [3.310–4.838] | 0.453 [0.439–0.487] | 88.7% |
| Commit release (ms) | 5.311 [4.633–5.740] | 0.708 [0.661–0.727] | 86.7% |
| Rejected overhead excluding advance (ms) | 66.823 [62.655–69.198] | 31.437 [28.711–33.407] | 53.0% |
| Authoritative candidate advance (ms) | 32.770 [32.091–37.807] | 33.292 [32.449–35.589] | Not attributed to checkpoint |

## Subsystem profile: primary Forge fixture

Median of ten isolated subgraph probes (five per block); allocation estimates in KiB, times in ms. Rows overlap and must not be summed. In particular, upgrade-state roots include definitions/effects, while level-values roots contain just the ID→level map.

| Subgraph | Original KiB | Compact KiB | Original ms | Compact ms |
|---|---:|---:|---:|---:|
| resources | 45.7 | 13.0 | 0.193 | 0.143 |
| generator_runtime_with_effects | 1000.2 | 189.1 | 5.112 | 2.588 |
| generator_definitions | 537.4 | 108.8 | 3.011 | 1.404 |
| output_accumulators | 15.5 | 8.0 | 0.021 | 0.024 |
| cycle_runtime | 39.5 | 10.4 | 0.055 | 0.058 |
| automation | 113.6 | 22.6 | 0.221 | 0.169 |
| upgrade_state_with_definitions | 3039.5 | 519.6 | 19.504 | 8.938 |
| upgrade_level_values | 85.8 | 13.3 | 0.146 | 0.109 |
| upgrade_definitions_effects | 2829.0 | 482.7 | 16.372 | 7.479 |
| relic_inventory_equipment | 7.1 | 5.7 | 0.011 | 0.013 |
| relic_effect_metadata | 5.1 | 4.5 | 0.015 | 0.014 |
| statistics_history | 73.1 | 16.5 | 0.226 | 0.135 |
| prestige | 555.4 | 79.7 | 2.873 | 1.194 |
| rng | 3.0 | 3.1 | 0.004 | 0.005 |
| signals | 4.2 | 4.0 | 0.014 | 0.012 |
| other_state | 65.1 | 15.0 | 0.157 | 0.115 |

Upgrade definitions/effects dominate: the isolated reference subgraph allocates about 2.8 MiB, compared with tiny output-phase/RNG/signal roots. The actual whole checkpoint is smaller than the sum of these overlapping probes because shared objects/containers are interned once. Compact storage substantially reduces this metadata representation without excluding it. RNG and tiny already-small roots can show negligible regressions from bookkeeping; they do not justify special-case complexity.

### Populated relic diagnostic

The following non-representative twelve-relic probes quantify nested generated-definition storage. Both implementations use the same seed and number of rolls.

| Root | Original KiB | Compact KiB | Original ms | Compact ms |
|---|---:|---:|---:|---:|
| relic_inventory_equipment | 335.6 | 52.0 | 0.577 | 0.527 |
| relic_effect_metadata | 320.7 | 49.9 | 0.537 | 0.453 |

## Final validation record

Baseline suite: **89 passed, 0 failed**. Final expanded suite: **90 passed, 0 failed**. Both original and compact implementations passed all nine differential fixtures (27 rejected and nine committed candidates each), the real timed Forge completion, RNG-dependent completion/relic outcomes, identity/lifecycle checks and new nested-data contracts. Direct original/compact endpoint fingerprint parity passed for all nine cases. Regression and differential logs contain no parser warnings, runtime errors or other ERROR/WARNING messages. Linux 4.6.1 results remain distinct from untested Windows 4.7.2 compatibility.
