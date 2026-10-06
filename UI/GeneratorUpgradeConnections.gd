class_name GeneratorUpgradeConnections
extends Control


var layout: GeneratorUpgradeLayout
var node_size := Vector2(70, 70)

const LINE_WIDTH := 3.0


func setup(
	upgrade_layout: GeneratorUpgradeLayout,
	upgrade_node_size: Vector2
	) -> void:

	layout = upgrade_layout
	node_size = upgrade_node_size

	queue_redraw()


func _draw() -> void:

	if layout == null:
		return

	for connection in layout.connections:

		var from_id: String = connection["from"]
		var to_id: String = connection["to"]

		if not layout.positions.has(from_id):
			continue

		if not layout.positions.has(to_id):
			continue

		_draw_connection(
			layout.positions[from_id],
			layout.positions[to_id]
		)


func _draw_connection(
	from_position: Vector2,
	to_position: Vector2
	) -> void:

	var from_bottom := Vector2(
		from_position.x + node_size.x / 2.0,
		from_position.y + node_size.y
	)

	var to_top := Vector2(
		to_position.x + node_size.x / 2.0,
		to_position.y
	)

	var line_color := Color(
		0.55,
		0.55,
		0.60,
		1.0
	)

	# Straight vertical connection.
	if is_equal_approx(
		from_bottom.x,
		to_top.x
	):

		draw_line(
			from_bottom,
			to_top,
			line_color,
			LINE_WIDTH,
			true
		)

		return

	# Route the connection through a horizontal
	# section halfway between the two nodes.

	var middle_y := (
		from_bottom.y
		+ to_top.y
	) / 2.0

	var first_point := Vector2(
		from_bottom.x,
		middle_y
	)

	var second_point := Vector2(
		to_top.x,
		middle_y
	)

	draw_line(
		from_bottom,
		first_point,
		line_color,
		LINE_WIDTH,
		true
	)

	draw_line(
		first_point,
		second_point,
		line_color,
		LINE_WIDTH,
		true
	)

	draw_line(
		second_point,
		to_top,
		line_color,
		LINE_WIDTH,
		true
	)
