class_name EternalFlameUpgradeConnections
extends Control


var layout: EternalFlameUpgradeLayout

const LINE_WIDTH := 3.0
const LINE_COLOR := Color(0.58, 0.40, 0.22, 0.85)


func setup(upgrade_layout: EternalFlameUpgradeLayout) -> void:
	layout = upgrade_layout
	queue_redraw()


func _draw() -> void:
	if layout == null:
		return

	for connection in layout.connections:
		var from_id: String = connection["from"]
		var to_id: String = connection["to"]
		if not layout.positions.has(from_id) or not layout.positions.has(to_id):
			continue
		_draw_connection(
			layout.positions[from_id],
			layout.positions[to_id]
		)


func _draw_connection(from_position: Vector2, to_position: Vector2) -> void:
	var from_center := from_position + Vector2(
		EternalFlameUpgradeLayout.NODE_SIZE.x / 2.0,
		EternalFlameUpgradeLayout.NODE_SIZE.y
	)
	var to_center := to_position + Vector2(
		EternalFlameUpgradeLayout.NODE_SIZE.x / 2.0,
		0.0
	)

	var middle_y: float = (from_center.y + to_center.y) / 2.0
	var first_point := Vector2(from_center.x, middle_y)
	var second_point := Vector2(to_center.x, middle_y)

	draw_line(from_center, first_point, LINE_COLOR, LINE_WIDTH, true)
	draw_line(first_point, second_point, LINE_COLOR, LINE_WIDTH, true)
	draw_line(second_point, to_center, LINE_COLOR, LINE_WIDTH, true)
