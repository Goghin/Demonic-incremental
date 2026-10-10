class_name UpgradeAutomationManager
extends RefCounted


const AUTOMATABLE_GENERATOR_IDS: Array[String] = [
	"atomic_friction",
	"molecular_agitation",
	"thermal_furnace",
	"lava_mite_colony",
	"matter_furnace"
]

const BASE_COOLDOWN: float = 10.0


var state: GameState
var automation_states: Dictionary = {}
var exclusive_preferences: Dictionary = {}


func _init(game_state: GameState) -> void:
	state = game_state

	for generator_id in AUTOMATABLE_GENERATOR_IDS:
		automation_states[generator_id] = {
			"enabled": false,
			"remaining_cooldown": 0.0
		}


func get_automation_technology_id(generator_id: String) -> String:
	return "upgrade_automation_" + generator_id


func is_automation_unlocked(generator_id: String) -> bool:
	if not automation_states.has(generator_id):
		return false

	return state.eternal_flame_state.is_technology_unlocked(
		get_automation_technology_id(generator_id)
	)


func is_enabled(generator_id: String) -> bool:
	if not automation_states.has(generator_id):
		return false

	return bool(automation_states[generator_id]["enabled"])


func set_enabled(generator_id: String, enabled: bool) -> bool:
	if not automation_states.has(generator_id):
		return false

	if enabled and not is_automation_unlocked(generator_id):
		return false

	var automation: Dictionary = automation_states[generator_id]
	automation["enabled"] = enabled
	automation["remaining_cooldown"] = BASE_COOLDOWN if enabled else 0.0
	return true


func set_exclusive_preference(upgrade_id: String, selected: bool) -> void:
	var upgrade: Upgrade = state.get_upgrade(upgrade_id)
	if upgrade == null or upgrade.definition.exclusivity_group == "":
		return

	var generator_id: String = upgrade.definition.generator_id
	if not automation_states.has(generator_id):
		return

	if selected:
		# Selecting one option clears other options in the same exclusive group.
		for other_value in state.upgrades.values():
			var other_upgrade: Upgrade = other_value
			if other_upgrade.definition.generator_id != generator_id:
				continue
			if other_upgrade.definition.exclusivity_group != upgrade.definition.exclusivity_group:
				continue
			exclusive_preferences[other_upgrade.definition.id] = (
				other_upgrade.definition.id == upgrade_id
			)
	else:
		exclusive_preferences[upgrade_id] = false


func is_exclusive_preference_selected(upgrade_id: String) -> bool:
	return bool(exclusive_preferences.get(upgrade_id, false))


func update(delta: float, simulation: Simulation) -> void:
	for generator_id in AUTOMATABLE_GENERATOR_IDS:
		if not is_enabled(generator_id):
			continue
		if not is_automation_unlocked(generator_id):
			continue

		var generator = state.get_generator(generator_id)
		if generator == null or not generator.unlocked:
			continue

		var automation: Dictionary = automation_states[generator_id]
		automation["remaining_cooldown"] = max(
			0.0,
			float(automation["remaining_cooldown"]) - delta
		)
		if float(automation["remaining_cooldown"]) > 0.0:
			continue

		_attempt_purchase(generator_id, simulation)


func _attempt_purchase(generator_id: String, simulation: Simulation) -> void:
	for upgrade_value in state.upgrades.values():
		var upgrade: Upgrade = upgrade_value
		var definition: UpgradeDefinition = upgrade.definition

		if definition.generator_id != generator_id:
			continue
		if upgrade.is_maxed():
			continue
		if definition.exclusivity_group != "":
			if not is_exclusive_preference_selected(definition.id):
				continue
		if not simulation.can_buy_upgrade(definition.id):
			continue

		if simulation.buy_upgrade(definition.id):
			automation_states[generator_id]["remaining_cooldown"] = BASE_COOLDOWN
			return

	# Avoid checking every frame when no eligible upgrade is affordable.
	automation_states[generator_id]["remaining_cooldown"] = BASE_COOLDOWN


func reset_for_new_run() -> void:
	for generator_id in AUTOMATABLE_GENERATOR_IDS:
		var automation: Dictionary = automation_states[generator_id]
		if automation["enabled"] and is_automation_unlocked(generator_id):
			automation["remaining_cooldown"] = BASE_COOLDOWN
		else:
			automation["enabled"] = false
			automation["remaining_cooldown"] = 0.0


func get_save_data() -> Dictionary:
	var saved_states: Dictionary = {}
	for generator_id in AUTOMATABLE_GENERATOR_IDS:
		saved_states[generator_id] = {
			"enabled": automation_states[generator_id]["enabled"]
		}

	return {
		"trees": saved_states,
		"exclusive_preferences": exclusive_preferences.duplicate(true)
	}


func load_save_data(data: Dictionary) -> void:
	var tree_data: Dictionary = data.get("trees", {})
	if tree_data.is_empty():
		# Accept an empty/new save without changing the default-off state.
		tree_data = {}

	for generator_id in AUTOMATABLE_GENERATOR_IDS:
		var saved_state = tree_data.get(generator_id, {})
		if not saved_state is Dictionary:
			continue

		var should_enable: bool = (
			bool(saved_state.get("enabled", false))
			and is_automation_unlocked(generator_id)
		)
		automation_states[generator_id]["enabled"] = should_enable
		automation_states[generator_id]["remaining_cooldown"] = (
			BASE_COOLDOWN if should_enable else 0.0
		)

	exclusive_preferences.clear()
	var saved_preferences = data.get("exclusive_preferences", {})
	if saved_preferences is Dictionary:
		for upgrade_id in saved_preferences:
			var upgrade: Upgrade = state.get_upgrade(str(upgrade_id))
			if upgrade == null or upgrade.definition.exclusivity_group == "":
				continue
			if not automation_states.has(upgrade.definition.generator_id):
				continue
			exclusive_preferences[str(upgrade_id)] = bool(saved_preferences[upgrade_id])

	# Normalize preferences so no exclusive group has multiple selections.
	for generator_id in AUTOMATABLE_GENERATOR_IDS:
		var selected_groups: Dictionary = {}
		for upgrade_value in state.upgrades.values():
			var upgrade: Upgrade = upgrade_value
			var upgrade_id: String = upgrade.definition.id
			if upgrade.definition.generator_id != generator_id:
				continue
			if upgrade.definition.exclusivity_group == "":
				continue
			if not is_exclusive_preference_selected(upgrade_id):
				continue
			var group_id: String = upgrade.definition.exclusivity_group
			if selected_groups.has(group_id):
				exclusive_preferences[upgrade_id] = false
			else:
				selected_groups[group_id] = upgrade_id
