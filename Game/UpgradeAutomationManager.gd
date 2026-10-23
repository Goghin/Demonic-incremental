class_name UpgradeAutomationManager
extends RefCounted


const AUTOMATABLE_GENERATOR_IDS: Array[String] = [
	"atomic_friction",
	"molecular_agitation",
	"thermal_furnace",
	"lava_mite_colony",
	"matter_furnace",
	"thermal_compressor"
]

# Automation scopes are data-driven so future general-upgrade trees can use
# the same manager without changing the purchase loop.
const GENERAL_TREE_ID: String = "general"
const BASE_COOLDOWN: float = 10.0


# GameState owns this manager. Use a weak back-reference to avoid a
# RefCounted ownership cycle.
var _state_ref: WeakRef
var state: GameState:
	get:
		if _state_ref == null:
			return null
		return _state_ref.get_ref() as GameState
	set(value):
		_state_ref = weakref(value) if value != null else null
var automation_states: Dictionary = {}
var exclusive_preferences: Dictionary = {}


func _init(game_state: GameState) -> void:
	state = game_state

	for generator_id in AUTOMATABLE_GENERATOR_IDS:
		automation_states[generator_id] = {
			"enabled": false,
			"remaining_cooldown": 0.0
		}
	automation_states[GENERAL_TREE_ID] = {
		"enabled": false,
		"remaining_cooldown": 0.0
	}


func get_automation_technology_id(tree_id: String) -> String:
	return "upgrade_automation_" + tree_id


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
	var tree_ids: Array[String] = AUTOMATABLE_GENERATOR_IDS.duplicate()
	tree_ids.append(GENERAL_TREE_ID)

	for tree_id in tree_ids:
		if not is_enabled(tree_id):
			continue
		if not is_automation_unlocked(tree_id):
			continue

		if tree_id != GENERAL_TREE_ID:
			var generator = state.get_generator(tree_id)
			if generator == null or not generator.unlocked:
				continue

		var automation: Dictionary = automation_states[tree_id]
		var remaining_delta: float = maxf(delta, 0.0)

		# Preserve cooldown overshoot so the result does not depend as heavily
		# on how many simulation updates happened during the same elapsed time.
		while true:
			var cooldown: float = maxf(
				float(automation["remaining_cooldown"]),
				0.0
			)
			if cooldown > remaining_delta:
				automation["remaining_cooldown"] = cooldown - remaining_delta
				break

			remaining_delta = maxf(remaining_delta - cooldown, 0.0)
			automation["remaining_cooldown"] = 0.0
			if not _attempt_purchase(tree_id, simulation):
				# No upgrade is affordable. The failed check still starts the
				# normal cooldown; account for the unused part of this step.
				var elapsed_after_failed_check: float = fmod(
					remaining_delta,
					BASE_COOLDOWN
				)
				automation["remaining_cooldown"] = (
					BASE_COOLDOWN - elapsed_after_failed_check
				)
				break
			if remaining_delta <= 0.0:
				break


func _attempt_purchase(tree_id: String, simulation: Simulation) -> bool:
	for upgrade_value in state.upgrades.values():
		var upgrade: Upgrade = upgrade_value
		var definition: UpgradeDefinition = upgrade.definition

		if not _upgrade_belongs_to_tree(definition, tree_id):
			continue
		if upgrade.is_maxed():
			continue
		if definition.exclusivity_group != "":
			if not is_exclusive_preference_selected(definition.id):
				continue
		if not simulation.can_buy_upgrade(definition.id):
			continue

		if simulation.buy_upgrade(definition.id, "upgrade_autobuyer"):
			automation_states[tree_id]["remaining_cooldown"] = BASE_COOLDOWN
			return true

	# Avoid checking every frame when no eligible upgrade is affordable.
	automation_states[tree_id]["remaining_cooldown"] = BASE_COOLDOWN
	return false


func _upgrade_belongs_to_tree(
	definition: UpgradeDefinition,
	tree_id: String
) -> bool:
	if tree_id == GENERAL_TREE_ID:
		# General automation targets persistent global upgrades, not the
		# separate generator-unlock/effect strip or automatic effects.
		return (
			definition.generator_id == ""
			and not definition.automatic
			and definition.upgrade_group_id != "infernal_forge"
		)

	return definition.generator_id == tree_id


func reset_for_new_run() -> void:
	var tree_ids: Array[String] = AUTOMATABLE_GENERATOR_IDS.duplicate()
	tree_ids.append(GENERAL_TREE_ID)
	for tree_id in tree_ids:
		var automation: Dictionary = automation_states[tree_id]
		if automation["enabled"] and is_automation_unlocked(tree_id):
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
	saved_states[GENERAL_TREE_ID] = {
		"enabled": automation_states[GENERAL_TREE_ID]["enabled"]
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

	var tree_ids: Array[String] = AUTOMATABLE_GENERATOR_IDS.duplicate()
	tree_ids.append(GENERAL_TREE_ID)
	for tree_id in tree_ids:
		var saved_state = tree_data.get(tree_id, {})
		if not saved_state is Dictionary:
			continue

		var should_enable: bool = (
			bool(saved_state.get("enabled", false))
			and is_automation_unlocked(tree_id)
		)
		automation_states[tree_id]["enabled"] = should_enable
		automation_states[tree_id]["remaining_cooldown"] = (
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
