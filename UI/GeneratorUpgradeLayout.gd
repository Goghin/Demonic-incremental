class_name GeneratorUpgradeLayout
extends RefCounted


var positions: Dictionary = {}
var connections: Array[Dictionary] = []


const COLUMN_SPACING := 90.0
const ROW_SPACING := 100.0
const ORIGIN := Vector2(20, 20)


func add_position(
	upgrade_id: String,
	position: Vector2
	) -> void:

	positions[upgrade_id] = position


func add_node(
	upgrade_id: String,
	column: int,
	row: int
	) -> void:

	var position := ORIGIN + Vector2(
		column * COLUMN_SPACING,
		row * ROW_SPACING
	)

	add_position(
		upgrade_id,
		position
	)


func add_connection(
	from_upgrade_id: String,
	to_upgrade_id: String
	) -> void:

	connections.append({
		"from": from_upgrade_id,
		"to": to_upgrade_id
	})
