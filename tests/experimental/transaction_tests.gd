extends RefCounted

const Fixtures = preload("res://tests/experimental/core_fixtures.gd")
const AutomationFixtures = preload("res://tests/experimental/autobuyer_fixtures.gd")
const Events = preload("res://tests/experimental/transaction_events.gd")
const Transaction = preload("res://tests/experimental/simulation_transaction.gd")
const Checkpoint = preload("res://tests/experimental/transaction_checkpoint.gd")
var failures: Array[String] = []
var measurements: Array[Dictionary] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func fingerprint(simulation: Simulation, journal: RefCounted = null) -> PackedByteArray:
	var snapshot: RefCounted = Checkpoint.new()
	check(snapshot.capture(simulation, journal), snapshot.error)
	var result: Array = []
	for record: Dictionary in snapshot.records:
		result.append([record["kind"], record.get("fields", {}), record.get("items", [])])
	return var_to_bytes(_stable(result))


func run_all() -> Dictionary:
	for scenario: String in ["early", "mid", "forge_competing", "forge_running", "forge"]:
		_exercise(Fixtures.make_state(scenario), Fixtures.make_state(scenario), scenario, 600 if scenario == "mid" else 100)
	for scenario: String in ["upgrades", "consumption", "mixed"]:
		_exercise(AutomationFixtures.make_state(scenario), AutomationFixtures.make_state(scenario), "automation/" + scenario, 600)
	var witness: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/experimental/core_event_fixture.json"))
	_exercise(Fixtures.from_save(witness["before"]), Fixtures.from_save(witness["before"]), "real_forge_completion", 20)
	_identity_and_partial()
	_rng_events()
	_lifecycle()
	return {"failures": failures, "measurements": measurements}


func _exercise(state: GameState, control: GameState, label: String, ticks: int) -> void:
	state.simulation_statistics = ResourceStatistics.new()
	control.simulation_statistics = ResourceStatistics.new()
	control.lava_palette = state.lava_palette.duplicate(true)
	control.gameplay_rng.seed = state.gameplay_rng.seed
	control.gameplay_rng.state = state.gameplay_rng.state
	var simulation := Simulation.new(state)
	var reference := Simulation.new(control)
	var journal: RefCounted = Events.new()
	var reference_journal: RefCounted = Events.new()
	journal.attach(simulation)
	reference_journal.attach(reference)
	var transaction: RefCounted = Transaction.new(simulation, journal)
	var before: PackedByteArray = fingerprint(simulation, journal)
	var capture_bytes: int = 0
	var capture_usec: int = 0
	var restore_usec: int = 0
	var advance_usec: int = 0
	var commit_usec: int = 0
	var records: int = 0
	var forge_active: bool = state.get_generator("infernal_forge").cycle_active
	for attempt: int in range(3):
		var started: int = Time.get_ticks_usec()
		var memory_before: int = OS.get_static_memory_usage()
		if not transaction.begin():
			check(false, label + ": begin: " + transaction.error)
			return
		capture_bytes = maxi(capture_bytes, OS.get_static_memory_usage() - memory_before)
		capture_usec += Time.get_ticks_usec() - started
		records = transaction._checkpoint.records.size()
		started = Time.get_ticks_usec()
		for tick: int in range(ticks):
			check(transaction.advance(0.1), label + ": advance failed")
		advance_usec += Time.get_ticks_usec() - started
		if label in ["automation/upgrades", "automation/consumption"]:
			var purchased: bool = false
			for event: Dictionary in state.gameplay_log.events:
				purchased = purchased or event["category"] == "purchase"
			check(purchased, label + ": no actual speculative purchase")
		if label == "automation/consumption":
			check(state.get_upgrade("thermal_conversion").level > control.get_upgrade("thermal_conversion").level, "Speculative upgrade buyer purchased no modifier upgrade")
		if label == "real_forge_completion":
			check(forge_active and not state.get_generator("infernal_forge").cycle_active, "Witness did not cross a real Forge completion")
		# Explicit mutation coverage includes aliases, newly allocated objects,
		# phase/mode fields, RNG and relic rewards in addition to real updates.
		state.gameplay_rng.randi()
		state.relic_manager.add_stackable_item("relic_shard", 3)
		state.resources[ResourceIds.HEAT].amount += 17.25
		state.gameplay_interval_produced[ResourceIds.HEAT] = 13.5
		state.get_generator("atomic_friction").level += 2
		state.get_generator("atomic_friction").operation_mode_id = "probe"
		started = Time.get_ticks_usec()
		check(transaction.rollback(), label + ": rollback: " + transaction.error)
		restore_usec += Time.get_ticks_usec() - started
		check(fingerprint(simulation, journal) == before, label + ": immediate rollback differs at attempt " + str(attempt))
		check(fingerprint(simulation, journal) == fingerprint(reference, reference_journal), label + ": control differs immediately")
	# Authoritative continuation must retain all binary state and log events.
	for tick: int in range(ticks):
		simulation.update(0.1, true)
		reference.update(0.1, true)
		if tick % 10 == 0 or tick == ticks - 1:
			check(fingerprint(simulation, journal) == fingerprint(reference, reference_journal), label + ": continuation differs at tick " + str(tick))
	check(transaction.begin(), label + ": commit begin failed")
	for tick: int in range(ticks):
		transaction.advance(0.1)
		reference.update(0.1, true)
	var candidate: PackedByteArray = fingerprint(simulation, journal)
	var started: int = Time.get_ticks_usec()
	check(transaction.commit(), label + ": commit failed")
	commit_usec = Time.get_ticks_usec() - started
	check(fingerprint(simulation, journal) == candidate, label + ": commit changed candidate")
	simulation.update(0.1, true)
	reference.update(0.1, true)
	check(fingerprint(simulation, journal) == fingerprint(reference, reference_journal), label + ": committed continuation differs")
	for draw: int in range(128):
		check(state.gameplay_rng.randi() == control.gameplay_rng.randi(), label + ": subsequent RNG differs")
	measurements.append({"scenario": label, "ticks_per_attempt": ticks, "capture_static_memory_delta_bytes_max": capture_bytes, "records": records, "encoded_bytes": before.size(), "capture_usec_mean": capture_usec / 3.0, "restore_and_verify_usec_mean": restore_usec / 3.0, "candidate_usec_mean": advance_usec / 3.0, "commit_usec": commit_usec})


func _lifecycle() -> void:
	var simulation := Simulation.new(Fixtures.make_state("early"))
	var transaction: RefCounted = Transaction.new(simulation)
	check(not transaction.commit() and not transaction.rollback() and not transaction.advance(0.1), "Inactive operations accepted")
	check(transaction.begin() and not transaction.begin(), "Nested transaction accepted")
	var second: RefCounted = Transaction.new(simulation)
	check(not second.begin(), "Second wrapper nested transaction accepted")
	check(not transaction.advance(-1.0) and not transaction.advance(INF), "Invalid delta accepted")
	check(transaction.rollback(), "Lifecycle rollback failed")
	var before: PackedByteArray = fingerprint(simulation)
	var abandoned: RefCounted = Transaction.new(simulation)
	check(abandoned.begin(), "Abandoned probe begin failed")
	abandoned.advance(0.1)
	abandoned = null
	check(fingerprint(simulation) == before, "Abandoned transaction was not restored")
	check(transaction.begin() and transaction.rollback(), "Abandoned transaction retained ownership lock")
	var callback: Callable = func(_id: String) -> void: pass
	simulation.generator_unlocked.connect(callback)
	check(not transaction.begin(), "External signal listener accepted")
	simulation.generator_unlocked.disconnect(callback)
	simulation.state.gameplay_log.clock = func() -> float: return 0.0
	check(not transaction.begin(), "External logger clock accepted")
	simulation.state.gameplay_log = GameplayLog.new()
	check(not transaction.begin(), "Filesystem logger accepted")
	simulation.state.gameplay_log = null
	var node := Node.new()
	simulation.state.gameplay_log = node
	check(not transaction.begin(), "Native Node accepted")
	simulation.state.gameplay_log = null
	node.free()
	check(not transaction.begin(), "Missing event sink accepted")


func _rng_state() -> GameState:
	# Synthetic RNG unit fixture, separate from representative timing fixtures.
	var state: GameState = Fixtures.make_state("forge_competing")
	state.gameplay_rng.seed = 123456
	state.set_resource_amount(ResourceIds.HEAT, 1000000.0)
	state.set_resource_amount(ResourceIds.MATTER, 1000000.0)
	var forge: Generator = state.get_generator("infernal_forge")
	forge.level = 3
	forge.operation_mode_id = "fast"
	var critical := UpgradeEffect.new(UpgradeEffectTypes.REGISTER_EVENT_EFFECT, forge.definition.id)
	critical.event_trigger = UpgradeEffectTypes.EVENT_CYCLE_COMPLETED
	critical.event_action = UpgradeEffectTypes.EVENT_ACTION_TRIGGER
	critical.event_id = "forge_critical"
	critical.event_chance = 0.5
	var downlevel := UpgradeEffect.new(UpgradeEffectTypes.REGISTER_EVENT_EFFECT, forge.definition.id)
	downlevel.event_trigger = UpgradeEffectTypes.EVENT_CYCLE_COMPLETED
	downlevel.event_action = UpgradeEffectTypes.EVENT_ACTION_DECREASE_GENERATOR_LEVEL
	downlevel.event_chance = 0.5
	downlevel.event_value = 1.0
	forge.event_effects = [critical, downlevel]
	state.get_generator("relic_shard_extractor").operation_mode_id = "forge_relic"
	return state


func _rng_actions(simulation: Simulation) -> void:
	for index: int in range(12):
		for id: String in ["infernal_forge", "relic_shard_extractor"]:
			var generator: Generator = simulation.state.get_generator(id)
			generator.level = maxi(1, generator.level)
			generator.cycle_active = true
			generator.cycle_critical_chance_snapshot = 0.25
			# Dedicated core completion adapter probe. Real timed advancement is
			# separately covered by the reached first-Forge completion witness.
			simulation.complete_cycle(generator)


func _rng_events() -> void:
	var simulation := Simulation.new(_rng_state())
	var reference := Simulation.new(_rng_state())
	var journal: RefCounted = Events.new()
	var reference_journal: RefCounted = Events.new()
	journal.attach(simulation)
	reference_journal.attach(reference)
	var transaction: RefCounted = Transaction.new(simulation, journal)
	var before: PackedByteArray = fingerprint(simulation, journal)
	check(transaction.begin(), "RNG transaction begin failed")
	_rng_actions(simulation)
	check(simulation.state.gameplay_rng.state != reference.state.gameplay_rng.state, "RNG probe consumed no draws")
	check(simulation.state.relic_manager.inventory.size() > reference.state.relic_manager.inventory.size(), "RNG probe generated no relics")
	var outcomes: Array[String] = []
	for event: Dictionary in journal.events:
		outcomes.append(event["event"])
	check(outcomes.has("normal") and outcomes.has("critical") and outcomes.has("relic") and outcomes.has("downlevel"), "RNG probe lacks critical/normal/relic/downlevel outcomes")
	check(transaction.rollback(), "RNG rollback failed")
	check(fingerprint(simulation, journal) == before, "RNG immediate rollback differs")
	_rng_actions(simulation)
	_rng_actions(reference)
	check(fingerprint(simulation, journal) == fingerprint(reference, reference_journal), "RNG outcomes/inventory/event history differ after rollback")
	for index: int in range(128):
		check(simulation.state.gameplay_rng.randi() == reference.state.gameplay_rng.randi(), "RNG sequence drift after gameplay rolls")


func _stable(value: Variant) -> Variant:
	# Independent states intentionally have different object IDs. Runtime
	# objects are graph references; only immutable leaves need normalization.
	if value is Object:
		return [value.get_class(), value.resource_path if value is Resource else ""]
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = _stable(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_stable(item))
		return result
	return value


func _identity_and_partial() -> void:
	var simulation := Simulation.new(Fixtures.make_state("forge_competing"))
	var state: GameState = simulation.state
	var generator: Generator = state.get_generator("thermal_furnace")
	var resources: Dictionary = state.resources
	var heat: ResourceState = state.resources[ResourceIds.HEAT]
	var phases: Dictionary = generator.production_progress
	var modifiers: Array[Modifier] = generator.modifiers
	state.last_prestige_report["alias"] = modifiers
	state.last_prestige_report["cycle"] = state.last_prestige_report
	var transaction: RefCounted = Transaction.new(simulation)
	var before: PackedByteArray = fingerprint(simulation)
	check(transaction.begin(), "Identity probe begin failed")
	simulation.update(0.1, true)
	generator.production_progress = {}
	generator.modifiers = []
	generator.get_operation_mode().outputs[0].unlocked = false
	state.resources = {}
	state.gameplay_interval_consumed[ResourceIds.HEAT] = 123.0
	state.gameplay_interval_lost[ResourceIds.MATTER] = 456.0
	check(transaction.rollback(), "Partial candidate rollback failed")
	check(is_same(resources, state.resources) and heat == state.resources[ResourceIds.HEAT], "Resource identity replaced")
	check(is_same(phases, generator.production_progress) and is_same(modifiers, generator.modifiers), "Generator phase/modifier identity replaced")
	check(is_same(state.last_prestige_report["alias"], modifiers) and is_same(state.last_prestige_report["cycle"], state.last_prestige_report), "Shared/cyclic containers lost alias topology")
	check(state.generator_automation_manager.state == state and state.upgrade_system.state == state and state.relic_manager._gameplay_rng == state.gameplay_rng, "Manager references became stale")
	check(fingerprint(simulation) == before, "Partial candidate restoration differs")
	state.last_prestige_report.clear() # Release the deliberately cyclic test value.
