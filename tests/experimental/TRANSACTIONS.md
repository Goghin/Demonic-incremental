# Experimental simulation transactions

## Implemented scope and result

Starting checkout: `feature/cycle-auto-run`, `48d460cc715e1ed879b43d0d36ab15c78febb149`. No branch creation/switching. Existing unrelated Ogg and two UID files are preserved. All implementation is experimental; the sole change outside this directory registers a regression group.

Implemented: an identity-preserving in-memory graph checkpoint, a transaction lifecycle, an owned signal journal, and binary differential regression tests. This is a synchronous **simulation-core** transaction for the audited `Simulation.update(delta, true)` path with exclusive access to its state. It is not a transaction around a running scene tree, TimeManager, disk-backed GameplayLog, save/load, prestige, UI or an entire adaptive runner. Those boundaries remain unsupported. No adaptive eligibility, numerical integration, production code, formulas, balance, timing or save formats change. The previous restricted checkpoint and baseline remain operational and unchanged.

Representative tests use the exact reached saves from `core_progression.json`, including primary `forge_competing`, plus `core_event_fixture.json` for a real completion. Separate synthetic automation and RNG unit fixtures exercise capabilities not earned in those reached saves. Synthetic capabilities are not coverage claims for representative gameplay.

## Authoritative execution and dependencies

The inspected `simulation/simulation.gd:update` performs automatic upgrades, then visits generators in registration order. Each consumes inputs before producing outputs; subsequent generators see those writes. It updates Mite throttling before operation eligibility. Cycle generators use current mode duration, current resource-dependent speed, available input duration and completion effects. After production it applies Matter decay and Heat leak, then generator autobuyers and upgrade autobuyers, and interval/offline bookkeeping. Upgrade application can append/replace modifiers, sensitivities and event effects, unlock modes/IO, and alter thresholds/dormancy parameters. Relic completion consumes the shared gameplay RNG and mutates inventory plus item IDs. Completion signals can escape the state graph.

| Owner | State/dependencies | Treatment |
|---|---|---|
| GameState → ResourceState | Balances, discovery, thresholds, interval produced/consumed/lost, tracking flag, realm index; setters also record peaks | Capture fields and nested containers; restore raw fields without invoking gameplay setters |
| GameState → Generator → definition → mode → IO | Levels, unlock/pause/operating/throttle flags, fractional output progress, active cycle/progress, auto-run, mode ID, activation critical snapshot; mode/IO unlocks live inside definition objects | Capture the entire script graph, including mutable flags under definitions |
| Generator → modifiers/sensitivities/event effects | Dynamic resource/formula dependencies, effect order and source IDs, production modifier cache | Capture objects, arrays and cache references/content; never rebuild on rollback |
| GameState → Upgrade/UpgradeSystem | Levels, definition registry, requirements; UpgradeSystem uses weak GameState reference | Capture levels and graph; retain weak reference object; computed `state` alias is not assigned |
| GeneratorAutomationManager | Per-ID enabled/cooldown/waiting state, affordability cache, enabled-ID index and dirty flag | Capture all fields and dictionaries; purchases go through normal simulation APIs |
| UpgradeAutomationManager | Cooldown/enabled states, exclusive preferences, enabled-ID index/dirty flag | Capture all fields; preserve registry/iteration order |
| RelicManager | Inventory, positions, machine slots, equipment, next relic/item IDs, generated definitions in entries, shared RNG reference | Capture graph; retain existing items and RNG identity; remove candidate additions by restoring collections |
| ResourceStatistics (lifetime/run/offline) | Per-resource total produced/consumed/lost/peak and overflow/decay | Capture each existing statistics object and nested counters |
| EternalFlameState/upgrade manager | Persistent levels/technology, flame/spent/prestige/total CF counters and upgrade registry | Capture; prestige/reset operations themselves are outside supported execution scope |
| AchievementManager | Unlocked/seen IDs, highest CF this run | Capture; reject unowned signal listeners |
| RealmConfiguration/RealmEffects | Config inputs, derived multipliers/thresholds, lock state | Capture both; avoid recomputation/roundoff or changing identity during rollback |
| Simulation | Offline automatic-upgrade index/count/realm key, interval clocks, diagnostics and profiling dictionaries | Capture; reject active wall-clock profiling |
| Gameplay log + transaction_events | In-memory purchase/upgrade/transition events; normal/critical/relic/downlevel/unlock signal order | Capture only the exact fixture TickLog with invalid clock and optional exact owned journal |
| RNG | `RandomNumberGenerator.seed`, `.state`; same object used by RelicManager | Dedicated native adapter: restore seed first, state second; no reseeding or replay |
| WeakRef | Three immutable back-reference objects to the owning GameState | Retain originals; do not assign computed manager aliases and create new WeakRefs |
| Definitions/configuration | Formula/IO/mode metadata, registries, stateless generation manager | Conservatively capture script fields even when immutable within update; constants are immutable and not copied |
| RealmLayout/Script resources | Visual layout/texture geometry and executable scripts, never written/read for numerical evolution by supported update path | Explicit immutable opaque leaves; retain identity; editing/reloading them during a transaction is unsupported |
| TimeManager/adaptive runner/scene tree | Session/game/prestige/offline/dormancy clocks, scheduling/yields, runner elapsed/samples/counters | Outside transaction scope; do not execute or mutate them inside a core transaction |
| GameplayLog filesystem, UI/audio, arbitrary signal listeners, deferred callbacks | Effects outside the ownership graph | Unsafe; refuse begin for an attached filesystem logger, connected external signals, valid Callable, Node, unsupported script or native mutable object |

Generator automation's nested affordability state includes `waiting_for_resources`, `waiting_cost`, `waiting_resource_id`, `waiting_level`, `waiting_operation_mode_id`, `waiting_modifier_count`, `waiting_realm_cost_multiplier`, `remaining_cooldown` and `enabled`. No waiting cache is treated as disposable. There is no separate input phase/accumulator in the current implementation: inputs consume amounts directly. Lifetime/run/offline statistics are the production/consumption accumulators, while `production_progress` holds fractional discrete output.

`transaction_state_inventory.json` records every script field actually visited in the primary Forge graph, with owner/instance counts. The appendix below classifies each listed field. Null/offline statistics and populated signal-journal state are additionally exercised in tests. Immutable constants are not instance fields.

## API and lifecycle

```gdscript
var events = preload("res://tests/experimental/transaction_events.gd").new()
events.attach(simulation) # Once, on an isolated simulation with TickLog.
var transaction = preload("res://tests/experimental/simulation_transaction.gd").new(simulation, events)
if transaction.begin():
	transaction.advance(0.1)
	# Inspect simulation.state and events.events synchronously here.
	transaction.rollback() # Or commit(), retaining candidate state.
# On begin failure: inspect transaction.error and preserve exact fallback.
```

`transaction_checkpoint.gd:capture` and `restore` provide the lower-level reusable checkpoint contract. Normal callers should use the lifecycle wrapper. `begin` captures before any candidate update; it rejects nesting both in the same wrapper and other wrappers around the same GameState. Inactive advance/commit/rollback, negative/nonfinite deltas and repeated begin are rejected with `false`/`error`, without a gameplay mutation. Invalid calls leave an active checkpoint available for rollback. No scene-tree yield, external concurrent mutation or connection change may occur between begin and resolution. Abandoning an active wrapper restores its checkpoint and releases ownership in PREDELETE; explicit resolution is preferred and tested.

`advance` calls the authoritative offline update without changing its semantics. Commit releases the checkpoint, with no copying or partially applied restore. Rollback restores then verifies the captured graph before releasing it; failed verification retains the checkpoint and reports failure. Candidate inspection is direct read-only access, not a second shared mutable copy. Lower-level checkpoint data is implementation state and must not be edited by callers. Separate GameStates must not share mutable runtime objects while transactions are active.

## Capture and restoration contracts

This does not use generic Object duplication, JSON, or production save/load. Only explicit audited owner scripts are admitted. Their GDScript instance properties are traversed, including inherited and private cache fields. Encountered unsupported scripts are refused before their property getters are traversed. Unknown native objects and packed arrays require a dedicated adapter and are refused rather than silently skipped. A new script/subclass must undergo scope review. New scalar/container/script fields on admitted owners are automatically captured; new external object types fail closed.

Each object gets a stable checkpoint record. Arrays and dictionaries are tracked by identity (`is_same`), with separately encoded entries and references. Each record strongly retains its original object/container. Capture handles aliases and cycles, without duplicating RefCounted objects or introducing new weak back-references. Restoration clears/refills each original container in original order and assigns original property references. Candidate-created objects become unreachable when their candidate collections/references are removed. Old modifier/IO/statistics/item instances remain usable by existing references. Restoration of known script fields performs plain assignments; the three computed `state` properties are skipped in favor of `_state_ref`. Resource balances are written to ResourceState.amount directly, avoiding double peak/production accounting. No signal is connected/disconnected by restoration.

The immutable exceptions are actual executable Script resources and RealmLayout presentation resources. A transaction may retain/restore their pointer but must not mutate their internals. All gameplay definition objects are traversed instead, because mode and IO unlock flags really are mutable. RNG uses a dedicated native adapter. WeakRefs are immutable pointer leaves in the graph. Valid Callables are refused, including TickLog's externally supplied clock. The only allowed signal callbacks are immediate, unbound, exact methods on the exact optional transaction_events script, on Simulation's matching signals. Deferred/reference-counted/bound/arbitrary callbacks and all other connected signals are refused. The journal's event array participates in the same checkpoint.

Runtime errors in GDScript are not exceptions that this infrastructure can catch. After partially completed synchronous advancement, the caller still has a valid checkpoint and can roll back. The deliberately partial candidate test replaces collection properties, clears resource ownership and changes mode IO state before restoring. Engine crashes, process termination, script reload, native object freeing and external reentrancy cannot be recovered by an in-memory checkpoint.

## Output and cycle phases

No production support was necessary. `Generator.production_progress` and `set_production_progress` already expose fractional output remainder. Whole outputs are derived by the existing flooring operation; rollback restores both the pre-floor remainder and all resource/statistical effects.

Cycles already expose `cycle_active`, `cycle_progress`, `operating`, `operation_mode_id`, `auto_run_cycles` and `cycle_critical_chance_snapshot`. All are captured, including the pre-completion state and post-completion consequences. `get_cycle_duration()` reads mode data; current Ash/modifier-sensitive speed comes from Simulation's existing calculation. Remaining progress/time and progress percent are derived, not independent writable clocks. Restoring mode data, progress, resources, effects, sensitivities and controller flags restores the next authoritative tick's speed/completion behavior exactly. Neither cycle duration nor resource-dependent speed is frozen or approximated. The real witness crosses completion on its first loaded 0.1-second tick.

## Validation

The dedicated suite rejects three candidates consecutively per scenario, compares the complete binary graph immediately after each rollback, and resumes authoritative exact ticks against an independent control. It compares all runtime objects, nested fields, definition unlocks, caches, statistics, inventory and RNG; only immutable object IDs are normalized across independent controls. There is no float tolerance and no lossy JSON comparison. Continuation snapshots occur on the first tick, every ten ticks and the final tick; event arrays retain full order. Commit preserves the candidate fingerprint and a following exact tick matches control. A further 128 RNG draws match exactly.

Primary windows are early 10 seconds, mid 60 seconds (crossing Mite unlock), Forge variants 10 seconds, and real completion 2 seconds. Three supplemental automation scenarios run 60 seconds, requiring actual purchases in upgrade/consumption fixtures and actual `thermal_conversion` purchase. The RNG fixture executes twelve Forge plus twelve Relic Crucible completions, requiring normal/critical/downlevel/relic outcomes, inventory growth and changed RNG before rejection. Repeating those operations after rollback matches control inventory, outcomes, event order, resources, statistics and RNG, followed by 128 exact draws. This synthetic direct-completion adapter probe is separate from the reached timed completion witness.

Identity tests replace resource/phase/modifier collections, mutate mode output unlocks and add shared/cyclic aliases, then verify original ResourceState, dictionary, array, RNG and weak manager references. Lifecycle tests cover inactive operations, same/second-wrapper nesting, invalid deltas, abandoned transaction cleanup and rejection of external listeners, valid logger clocks, filesystem loggers, Nodes and missing event sinks. These tests validate the supported core subset; they do not certify TimeManager or UI rollback.

Final validation and serial measurements are recorded below. Linux Godot 4.6.1 results do not establish Windows Godot 4.7.2 compatibility. The existing editor parse failure at `game.gd:771` was observed and left untouched; an editor import is therefore not a clean project-wide validation.

## Cost and next milestone

The correctness reference captures configuration graphs conservatively and creates many small token dictionaries. Linear identity lookup for containers adds quadratic capture work; graph verification traverses every record after restoration. Checkpoint release/commit also costs time because it releases those tokens. `encoded_bytes` is the binary comparison payload, **not** actual heap usage. The static-memory delta around capture estimates allocated checkpoint storage plus allocator effects and retained references, without cloning textures. Test fingerprints/control simulation are outside measured transaction phases. Three rejection timings are means, not confidence intervals; different tick-window lengths must not be compared as equal advancement workloads.

This is unsuitable for per-tick or frequent tiny speculative attempts. Keep it as a correctness oracle. Next, introduce audited per-owner runtime field descriptors and immutable-definition sharing, preserving writable mode/IO unlocks, output remainders, cycle state and exact cache identity. Measure smaller checkpoints before enabling frequent probing. Add an explicit owned TimeManager/runner clock adapter and a buffered external-event publication contract before attempting end-to-end offline transactions. Production UI/log integration needs commit-time event dispatch and a separately reviewed observer contract, not silent signal suppression. Only after those prerequisites should an experimental writable phase vector and ordered resource-flow batching be designed. Existing adaptive eligibility and exact fallback remain in force until independent event/resource-flow proofs exist.

## Measured results (Linux Godot 4.6.1)

Standalone serial transaction run: **zero failures** across nine differential fixture cases, 27 rejected mixed candidates, nine commits, the separate RNG completion probe, and lifecycle/identity probes. Exact parity was required immediately after rollback and during resumed authoritative execution, with no numeric tolerance.

| Fixture | Candidate ticks | Graph records | Binary payload KiB | Capture heap delta MiB | Capture ms | Advance ms | Restore + verify + release ms | Commit/release ms | Rejection overhead ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| early | 100 | 1018 | 473.0 | 4.72 | 34.81 | 11.55 | 27.00 | 3.63 | 61.82 |
| mid | 600 | 985 | 460.0 | 4.60 | 30.06 | 56.30 | 23.00 | 3.41 | 53.06 |
| forge_competing | 100 | 1134 | 528.4 | 5.30 | 35.72 | 33.39 | 26.84 | 5.44 | 62.56 |
| forge_running | 100 | 1134 | 528.4 | 5.30 | 36.06 | 29.81 | 25.53 | 4.52 | 61.59 |
| forge | 100 | 1134 | 528.4 | 5.30 | 41.51 | 25.59 | 31.04 | 4.65 | 72.55 |
| automation/upgrades | 600 | 954 | 442.1 | 4.42 | 28.99 | 49.32 | 22.96 | 4.11 | 51.95 |
| automation/consumption | 600 | 958 | 445.1 | 4.45 | 32.27 | 212.98 | 24.34 | 4.23 | 56.60 |
| automation/mixed | 600 | 978 | 455.0 | 4.55 | 30.20 | 242.27 | 24.42 | 3.55 | 54.62 |
| real_forge_completion | 20 | 1100 | 510.8 | 5.11 | 37.70 | 4.52 | 24.70 | 4.17 | 62.41 |

The rejection overhead column excludes advancement and is the mean capture + rollback cost over three consecutive rejected candidates. Commit is one measured release after a separately captured committed candidate. Allocations are Godot static-memory deltas at capture; they are estimates, not resident-memory peaks or copied GPU textures. The primary fixtures allocate approximately 4.6–5.3 MiB each, despite only 460–528 KiB of binary comparison data. No resources/RefCounted objects are cloned, but the large configuration graph and token/container allocations dominate. Frequent subsecond attempts would be prohibitively expensive in this correctness-first representation.

Reproduce:

```sh
godot --headless --path . --script tests/experimental/run_transaction_tests.gd
godot --headless --path . --script tests/run_regression_tests.gd
```

The standalone command updates `transaction_results.json` and `transaction_state_inventory.json`. Regression registration performs the same correctness checks without overwriting benchmark files.

## Field classification appendix

A = mutable authoritative state requiring capture (including ownership references and mutable nested entries). D = derived/recomputable, but captured exactly by this implementation to preserve cache identity and avoid recomputation changes. I = immutable definition/configuration within the supported update, conservatively captured unless explicitly stated. X = external effect, refused/outside scope. Every inventoried field is assigned below; nested automation dictionaries are detailed in the ownership table.

### `RandomNumberGenerator`

- **A**: `seed`, `state`.

### `WeakRef`

No script instance fields; WeakRef is retained as an immutable native reference; stateless generation constants are immutable configuration.

### `autobuyer_fixtures.gd::TickLog`

- **A**: `events`.
- **X**: `clock`.

### `res://Game/AchievementManager.gd`

- **A**: `unlocked_achievements`, `seen_generator_ids`, `highest_crystallized_flame_this_run`.

### `res://Game/GeneratorAutomationManager.gd`

- **A**: `automation_states`.
- **D**: `_offline_enabled_ids`, `_offline_index_dirty`.
- **I**: `_state_ref`.

### `res://Game/UpgradeAutomationManager.gd`

- **A**: `automation_states`, `exclusive_preferences`.
- **D**: `_offline_enabled_ids`, `_offline_index_dirty`.
- **I**: `_state_ref`.

### `res://Game/eternal_flame_state.gd`

- **A**: `eternal_flame`, `spent_flames`, `prestige_count`, `total_crystallized_flame`, `upgrade_levels`, `unlocked_technologies`.

### `res://Game/eternal_flame_upgrade.gd`

- **A**: `level`.
- **I**: `id`, `display_name`, `description`, `effect_type`, `effect_per_level`, `technology_id`, `target_generator_id`, `prerequisite_upgrade_id`, `prerequisite_level`, `prerequisite_generator_id`, `prerequisite_generator_level`, `automatic_level_prestige_requirements`, `automatic_min_prestiges`, `automatic_total_eternal_flame_requirement`, `max_level`, `base_cost`, `cost_multiplier`.

### `res://Game/eternal_flame_upgrade_manager.gd`

- **A**: `upgrades`.

### `res://Game/modifier.gd`

- **A**: `id`, `type`, `target_id`, `multiplier`, `source_upgrade_id`, `operation_mode_ids`, `dynamic_threshold`, `dynamic_exponent`, `dynamic`, `dynamic_resource_id`, `dynamic_formula`, `dynamic_generator_id`, `dynamic_realm_effect_id`, `dynamic_realm_effect_is_divisor`.

### `res://Game/modifiersensitivity.gd`

- **A**: `modifier_id`, `multiplier`, `source_upgrade_id`, `operation_mode_ids`, `dynamic`, `dynamic_formula`, `dynamic_resource_id`.

### `res://Game/realm_configuration.gd`

- **I**: `stability`, `density`, `integrity`, `intensity`, `resonance`, `locked`.

### `res://Game/realm_effects.gd`

- **D**: `heat_leak_threshold`, `matter_decay_threshold`, `thermal_mass_multiplier`, `matter_production_multiplier`, `heat_production_realm_multiplier`, `heat_production_upgrade_multiplier`, `heat_production_multiplier`, `generator_cost_multiplier`, `ashen_contamination_multiplier`.

### `res://Game/relic_generation_manager.gd`

No script instance fields; WeakRef is retained as an immutable native reference; stateless generation constants are immutable configuration.

### `res://Game/relic_manager.gd`

- **A**: `inventory`, `inventory_positions`, `machine_slots`, `equipped`, `_next_instance_number`, `generation_manager`, `_next_item_instance_number`, `_gameplay_rng`.

### `res://Game/requirement.gd`

- **I**: `type`, `target_id`, `value`.

### `res://Game/resource_statistics.gd`

- **A**: `statistics`, `total_overflow`, `total_matter_decayed`.

### `res://Generators/generator.gd`

- **A**: `definition`, `level`, `cycle_critical_chance_snapshot`, `modifiers`, `event_effects`, `modifier_sensitivities`, `production_progress`, `initial_unlocked`, `unlocked`, `manually_paused`, `operating`, `is_throttled`, `cycle_active`, `cycle_progress`, `auto_run_cycles`, `operation_mode_id`.
- **D**: `_production_modifier_cache`.

### `res://Generators/generator_definition.gd`

- **I**: `id`, `display_name`, `base_cost`, `cost_multiplier`, `cost_resource_id`, `cycle_based`, `operation_modes`, `illustration_path`, `starting_level`, `scale_rates_with_level`, `level_upgrade_enabled`, `level_upgrade_resource_id`, `level_upgrade_base_cost`, `level_upgrade_cost_multiplier`, `level_upgrade_max_level`, `level_critical_chance_bonus`, `level_critical_chance_cap`.

### `res://Generators/generator_io.gd`

- **A**: `unlocked`.
- **I**: `resource_id`, `amount_per_second`, `discrete`, `starts_unlocked`.

### `res://Generators/generator_operation_mode.gd`

- **A**: `inputs`, `outputs`, `completion_outputs`, `unlocked`.
- **I**: `id`, `display_name`, `description`, `production_multiplier`, `input_multiplier`, `activation_cost_multiplier`, `increase_level_on_activation`, `cycle_duration`, `completion_item_outputs`, `completion_random_relic_tier`, `completion_critical_chance`, `crafting_input_requirements`, `initially_unlocked`, `is_resource_transfer`.

### `res://Resources/GameResource.gd`

- **I**: `id`, `display_name`.

### `res://Resources/resource_state.gd`

- **A**: `definition`, `amount`.

### `res://Upgrades/UpgradeSystem.gd`

- **I**: `_state_ref`.

### `res://Upgrades/upgrade.gd`

- **A**: `definition`, `level`.

### `res://Upgrades/upgrade_definition.gd`

- **I**: `id`, `display_name`, `description`, `cost_resource_id`, `cost`, `cost_multiplier`, `max_level`, `effects`, `requirements`, `automatic`, `exclusivity_group`, `upgrade_group_id`, `generator_id`, `technology_id`, `discovery_id`, `icon_path`.

### `res://Upgrades/upgrade_effect.gd`

- **A**: `event_source_upgrade_id` (assigned by `Simulation._apply_upgrade_effect` and shared with registered generator effects).
- **I**: `type`, `target_id`, `modifier_type`, `value`, `modifier_target_id`, `modifier_id`, `output_resource_id`, `operation_mode_id`, `operation_mode_ids`, `dynamic_formula`, `dynamic_resource_id`, `dynamic_generator_id`, `dynamic_realm_effect_id`, `dynamic_realm_effect_is_divisor`, `sensitivity_modifier_id`, `sensitivity_multiplier`, `dynamic_threshold`, `dynamic_exponent`, `sensitivity_dynamic_formula`, `sensitivity_dynamic_resource_id`, `dormancy_parameter`, `dormancy_value`, `event_trigger`, `event_action`, `event_id`, `event_condition_id`, `event_chance`, `event_value`, `event_resource_id`, `event_order`.

### `res://Upgrades/upgrade_group_definition.gd`

- **I**: `id`, `display_name`, `description`.

### `res://game_state.gd`

- **A**: `gameplay_log`, `gameplay_rng`, `gameplay_interval_produced`, `gameplay_interval_consumed`, `gameplay_interval_lost`, `track_gameplay_interval_statistics`, `gameplay_realm_run_index`, `resources`, `discovered_resources`, `resource_thresholds`, `generators`, `upgrades`, `upgrade_groups`, `upgrade_system`, `resource_statistics`, `current_run_statistics`, `achievement_manager`, `simulation_statistics`, `eternal_flame_state`, `realm_configuration`, `realm_effects`, `eternal_flame_upgrade_manager`, `relic_manager`, `generator_automation_manager`, `upgrade_automation_manager`, `realm_stabilized`, `prestige_planning`, `last_prestige_report`, `lava_mite_dormancy_penalty`, `heat_leak_threshold`, `total_overflow_this_prestige`, `total_matter_decayed_this_prestige`, `overflow_bonus_from_last_realm`, `matter_decay_threshold`, `lava_mite_dormancy_delay`, `lava_mite_dormancy_duration`, `lava_mite_dormancy_max_penalty`.
- **I**: `realm_layout_id`, `realm_layout`, `lava_palette`, `heat_leak_scaling`, `heat_leak_exponent`, `matter_decay_scaling`, `matter_decay_exponent`.

### `res://simulation/simulation.gd`

- **A**: `_gameplay_snapshot_elapsed`, `_gameplay_was_offline`, `_gameplay_snapshot_realm_run_index`, `state`, `profiling_enabled`, `profile_totals_usec`, `profile_call_counts`, `diagnostics_enabled`, `diagnostic_time_seconds`, `diagnostic_events`, `diagnostic_checkpoints`, `diagnostic_environmental_checkpoints`.
- **D**: `_offline_automatic_upgrades`, `_offline_upgrade_count`, `_offline_realm_run_index`.

### `res://tests/experimental/transaction_events.gd`

- **A**: `events`.

### Immutable visual leaves and external execution state

RealmLayout's island texture/aspect/scale/offset, lake geometry, flow definitions, generator/brazier positions, ash/matter pile positions/rotations and smoke-emitter definitions are **I** and explicitly opaque. These presentation fields are not modified by the supported core update. Script bytecode/resources and manager constant registries are **I**.

TimeManager's simulation statistics are captured only through the GameState reference when attached; its tick/total-tick/progress, active/offline/session/game/prestige/time-scale/dormancy/stabilization clocks and scheduling metrics, and the adaptive runner's elapsed/duration/samples/counters/attempts/manager are **X** for this boundary. They need separate adapters before calling their methods transactionally. Pending engine message-queue work is also outside this boundary: a transaction must run synchronously without pumping the message queue. The audited core update schedules no deferred work. Disk log writes, timestamps, UI/audio observers, saves, scene changes and script reloads are **X**. Valid TickLog clocks and unknown native/script state are rejected.

## Final regression record

The final source run completed **89 passed, 0 failed** (all 88 existing groups plus the new transactional group). Both the full regression log and serial transaction log contained no `ERROR`, `SCRIPT ERROR` or `WARNING`. The separately invoked editor import reproduced the existing `game.gd:771` parse error and is not reported as a passing editor check. No Windows Godot 4.7.2 run was performed. Source/log hashes and commands are retained in `transaction_validation.json`; measured transaction data is in `transaction_results.json`.
