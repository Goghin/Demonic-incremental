class_name GeneratorSelectionOverlay
extends Node2D


var realm_view: RealmView
var selected_generator_id: String = ""


func set_selected_generator(generator_id: String) -> void:
	if selected_generator_id == generator_id:
		return

	selected_generator_id = generator_id
	queue_redraw()


func _draw() -> void:
	if realm_view == null:
		return

	if selected_generator_id == "" or realm_view.realm_layout == null:
		return

	var selected_position: Vector2 = realm_view._get_generator_position(
		selected_generator_id
	)
	draw_arc(
		selected_position,
		30.0,
		0.0,
		TAU,
		40,
		Color(1.0, 0.48, 0.16, 0.95),
		3.0,
		true
	)
	draw_arc(
		selected_position,
		35.0,
		0.0,
		TAU,
		40,
		Color(1.0, 0.48, 0.16, 0.35),
		1.0,
		true
	)
