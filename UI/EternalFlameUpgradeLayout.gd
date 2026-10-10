class_name EternalFlameUpgradeLayout
extends RefCounted


var positions: Dictionary = {}
var connections: Array[Dictionary] = []


const NODE_SIZE := Vector2(95, 56)
const COLUMN_SPACING := 112.0
const ROW_SPACING := 76.0
const ORIGIN := Vector2(16, 16)


func _init() -> void:
	# Independent realm upgrades occupy the top row.
	add_node("eternal_furnace", 0, 0)
	add_node("realm_attunement", 1, 0)
	add_node("infernal_foundation", 2, 0)
	add_node("essence_extraction", 3, 0)

	# Starting generator levels form a compact progression on the left.
	add_node("accelerated_friction", 0, 1)
	add_node("accelerated_agitation", 0, 2)
	add_node("established_colony", 0, 3)
	add_node("accelerated_condensation", 1, 3)

	# First group of generator automation unlocks and cooldown upgrades.
	add_node("unlock_generator_automation_atomic_friction", 1, 1)
	add_node("generator_automation_cooldown_atomic_friction", 1, 2)
	add_node("unlock_generator_automation_molecular_agitation", 2, 1)
	add_node("generator_automation_cooldown_molecular_agitation", 2, 2)
	add_node("unlock_generator_automation_thermal_furnace", 3, 1)
	add_node("generator_automation_cooldown_thermal_furnace", 3, 2)

	# Remaining generator automation upgrades continue further down.
	add_node("unlock_generator_automation_thermal_compressor", 2, 3)
	add_node("generator_automation_cooldown_thermal_compressor", 2, 4)
	add_node("unlock_generator_automation_lava_mite_colony", 3, 3)
	add_node("generator_automation_cooldown_lava_mite_colony", 3, 4)
	add_node("unlock_generator_automation_matter_furnace", 0, 4)
	add_node("generator_automation_cooldown_matter_furnace", 0, 5)

	# Upgrade autobuyers are independent permanent unlocks.
	add_node("unlock_upgrade_automation_atomic_friction", 0, 6)
	add_node("unlock_upgrade_automation_molecular_agitation", 1, 6)
	add_node("unlock_upgrade_automation_thermal_furnace", 2, 6)
	add_node("unlock_upgrade_automation_lava_mite_colony", 3, 6)
	add_node("unlock_upgrade_automation_matter_furnace", 0, 7)

	add_connection("accelerated_friction", "accelerated_agitation")
	add_connection("accelerated_agitation", "established_colony")
	add_connection("accelerated_agitation", "accelerated_condensation")
	add_connection("unlock_generator_automation_atomic_friction", "generator_automation_cooldown_atomic_friction")
	add_connection("unlock_generator_automation_molecular_agitation", "generator_automation_cooldown_molecular_agitation")
	add_connection("unlock_generator_automation_thermal_furnace", "generator_automation_cooldown_thermal_furnace")
	add_connection("unlock_generator_automation_thermal_compressor", "generator_automation_cooldown_thermal_compressor")
	add_connection("unlock_generator_automation_lava_mite_colony", "generator_automation_cooldown_lava_mite_colony")
	add_connection("unlock_generator_automation_matter_furnace", "generator_automation_cooldown_matter_furnace")


func add_node(upgrade_id: String, column: int, row: int) -> void:
	positions[upgrade_id] = ORIGIN + Vector2(
		column * COLUMN_SPACING,
		row * ROW_SPACING
	)


func add_connection(from_upgrade_id: String, to_upgrade_id: String) -> void:
	connections.append({
		"from": from_upgrade_id,
		"to": to_upgrade_id
	})


func get_map_size() -> Vector2:
	var max_x: float = ORIGIN.x
	var max_y: float = ORIGIN.y
	for position_value in positions.values():
		var position: Vector2 = position_value
		max_x = max(max_x, position.x + NODE_SIZE.x)
		max_y = max(max_y, position.y + NODE_SIZE.y)
	return Vector2(max_x + ORIGIN.x, max_y + ORIGIN.y)
