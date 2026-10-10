class_name GeneratorAutomationManager
extends RefCounted


const AUTOMATABLE_GENERATOR_IDS: Array[String] = [
	"atomic_friction",
	"molecular_agitation",
	"thermal_furnace",
	"thermal_compressor",
	"lava_mite_colony",
	"matter_furnace"
]

const BASE_COOLDOWN: float = 5.0
const MINIMUM_COOLDOWN: float = 0.5
const COOLDOWN_MULTIPLIER_PER_LEVEL: float = 0.8


var state: GameState
var automation_states: Dictionary = {}


func _init(game_state: GameState) -> void:
	state = game_state

	for generator_id in AUTOMATABLE_GENERATOR_IDS:
		automation_states[generator_id] = {
			"enabled": false,
			"remaining_cooldown": 0.0,
			"waiting_for_resources": false,
			"waiting_cost": 0.0,
			"waiting_resource_id": "",
			"waiting_level": -1,
			"waiting_operation_mode_id": "",
			"waiting_modifier_count": -1,
			"waiting_realm_cost_multiplier": -1.0
		}


func get_automation_technology_id(
	generator_id: String
) -> String:
	return "generator_automation_" + generator_id


func get_cooldown_upgrade_id(
	generator_id: String
) -> String:
	return "generator_automation_cooldown_" + generator_id


func is_automation_unlocked(
	generator_id: String
) -> bool:
	if not automation_states.has(generator_id):
		return false

	return state.eternal_flame_state.is_technology_unlocked(
		get_automation_technology_id(generator_id)
	)


func is_enabled(
	generator_id: String
) -> bool:
	if not automation_states.has(generator_id):
		return false

	return bool(
		automation_states[generator_id]["enabled"]
	)


func set_enabled(
	generator_id: String,
	enabled: bool
) -> bool:
	if not automation_states.has(generator_id):
		return false

	if enabled and not is_automation_unlocked(generator_id):
		return false

	automation_states[generator_id]["enabled"] = enabled
	automation_states[generator_id]["waiting_for_resources"] = false

	if enabled:
		automation_states[generator_id]["remaining_cooldown"] = (
			get_cooldown(generator_id)
		)
	else:
		automation_states[generator_id]["remaining_cooldown"] = 0.0

	return true


func toggle(
	generator_id: String
) -> bool:
	if not automation_states.has(generator_id):
		return false

	return set_enabled(
		generator_id,
		not is_enabled(generator_id)
	)


func get_cooldown(
	generator_id: String
) -> float:
	var upgrade_level: int = (
		state.eternal_flame_state.get_upgrade_level(
			get_cooldown_upgrade_id(generator_id)
		)
	)

	return max(
		MINIMUM_COOLDOWN,
		BASE_COOLDOWN * pow(
			COOLDOWN_MULTIPLIER_PER_LEVEL,
			upgrade_level
		)
	)


func update(delta: float, simulation: Simulation) -> void:
	for generator_id in AUTOMATABLE_GENERATOR_IDS:
		var profile_start_usec: int = 0
		if simulation.profiling_enabled:
			profile_start_usec = Time.get_ticks_usec()

		if not is_enabled(generator_id):
			if simulation.profiling_enabled:
				simulation._record_profile_time(
					"generator_automation_loop_checks",
					profile_start_usec
				)
			continue

		if not is_automation_unlocked(generator_id):
			if simulation.profiling_enabled:
				simulation._record_profile_time(
					"generator_automation_loop_checks",
					profile_start_usec
				)
			continue

		var generator = state.get_generator(generator_id)

		if generator == null or not generator.unlocked:
			if simulation.profiling_enabled:
				simulation._record_profile_time(
					"generator_automation_loop_checks",
					profile_start_usec
				)
			continue

		var automation: Dictionary = automation_states[generator_id]

		# While waiting, compare the resource balance against the cached
		# cost. Recalculate the cost only if known cost inputs changed.
		if automation["waiting_for_resources"]:
			if simulation.profiling_enabled:
				simulation._record_profile_time(
					"generator_automation_loop_checks",
					profile_start_usec
				)

			var waiting_start_usec: int = 0
			if simulation.profiling_enabled:
				waiting_start_usec = Time.get_ticks_usec()

			if _waiting_cost_needs_refresh(generator, automation):
				_cache_waiting_cost(generator, automation)

			var waiting_resource_id: String = str(
				automation["waiting_resource_id"]
			)
			var waiting_cost: float = float(
				automation["waiting_cost"]
			)
			var current_amount: float = state.get_resource_amount(
				waiting_resource_id
			)

			if current_amount >= waiting_cost:
				# Run the normal full validation before buying. The cached
				# threshold only avoids recalculating affordability every tick.
				if simulation.can_buy_generator(generator_id):
					_attempt_purchase(generator_id, simulation, true)
				else:
					# The real cost/conditions may have changed; refresh the
					# cache so the next tick uses the current requirement.
					_cache_waiting_cost(generator, automation)

			if simulation.profiling_enabled:
				simulation._record_profile_time(
					"generator_automation_waiting_checks",
					waiting_start_usec
				)
			continue

		# Otherwise, wait for the cooldown to expire.
		automation["remaining_cooldown"] = max(
			0.0,
			float(automation["remaining_cooldown"]) - delta
		)

		if automation["remaining_cooldown"] > 0.0:
			if simulation.profiling_enabled:
				simulation._record_profile_time(
					"generator_automation_loop_checks",
					profile_start_usec
				)
			continue

		if simulation.profiling_enabled:
			simulation._record_profile_time(
				"generator_automation_loop_checks",
				profile_start_usec
			)
		var purchase_start_usec: int = 0
		if simulation.profiling_enabled:
			purchase_start_usec = Time.get_ticks_usec()
		_attempt_purchase(generator_id, simulation)
		if simulation.profiling_enabled:
			simulation._record_profile_time(
				"generator_automation_purchase_attempts",
				purchase_start_usec
			)


func _attempt_purchase(
	generator_id: String,
	simulation: Simulation,
	affordability_already_checked: bool = false
) -> void:
	var automation: Dictionary = automation_states[generator_id]
	var generator = state.get_generator(generator_id)

	# Waiting generators have already passed this check in update().
	if not affordability_already_checked:
		if not simulation.can_buy_generator(generator_id):
			automation["waiting_for_resources"] = true
			automation["remaining_cooldown"] = 0.0
			if generator != null:
				_cache_waiting_cost(generator, automation)
			return

	if simulation.buy_generator(generator_id):
		automation["waiting_for_resources"] = false
		automation["remaining_cooldown"] = get_cooldown(generator_id)
	else:
		# A purchase can still fail if its conditions change.
		automation["waiting_for_resources"] = true
		automation["remaining_cooldown"] = 0.0
		if generator != null:
			_cache_waiting_cost(generator, automation)


func _waiting_cost_needs_refresh(
	generator: Generator,
	automation: Dictionary
) -> bool:
	return (
		str(automation["waiting_resource_id"])
			!= generator.definition.cost_resource_id
		or int(automation["waiting_level"]) != generator.level
		or str(automation["waiting_operation_mode_id"])
			!= generator.operation_mode_id
		or int(automation["waiting_modifier_count"])
			!= generator.modifiers.size()
		or not is_equal_approx(
			float(automation["waiting_realm_cost_multiplier"]),
			state.realm_effects.generator_cost_multiplier
		)
	)


func _cache_waiting_cost(
	generator: Generator,
	automation: Dictionary
) -> void:
	automation["waiting_cost"] = generator.get_cost(state)
	automation["waiting_resource_id"] = generator.definition.cost_resource_id
	automation["waiting_level"] = generator.level
	automation["waiting_operation_mode_id"] = generator.operation_mode_id
	automation["waiting_modifier_count"] = generator.modifiers.size()
	automation["waiting_realm_cost_multiplier"] = (
		state.realm_effects.generator_cost_multiplier
	)


func reset_for_new_run() -> void:
	for generator_id in AUTOMATABLE_GENERATOR_IDS:
		var automation: Dictionary = automation_states[generator_id]

		automation["waiting_for_resources"] = false

		if automation["enabled"]:
			automation["remaining_cooldown"] = get_cooldown(generator_id)
		else:
			automation["remaining_cooldown"] = 0.0


func get_save_data() -> Dictionary:
	var saved_states: Dictionary = {}

	for generator_id in AUTOMATABLE_GENERATOR_IDS:
		saved_states[generator_id] = {
			"enabled": automation_states[generator_id]["enabled"]
		}

	return saved_states


func load_save_data(data: Dictionary) -> void:
	for generator_id in AUTOMATABLE_GENERATOR_IDS:
		var saved_state = data.get(generator_id, {})

		if not saved_state is Dictionary:
			continue

		# Do not enable automation if its permanent unlock is missing.
		var should_enable: bool = (
			bool(saved_state.get("enabled", false))
			and is_automation_unlocked(generator_id)
		)

		automation_states[generator_id]["enabled"] = should_enable
		automation_states[generator_id]["waiting_for_resources"] = false

		if should_enable:
			automation_states[generator_id]["remaining_cooldown"] = (
				get_cooldown(generator_id)
			)
		else:
			automation_states[generator_id]["remaining_cooldown"] = 0.0
