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
	if realm_view == null or realm_view.realm_layout == null:
		return

	_draw_new_generator_markers()

	if selected_generator_id == "":
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


func _draw_new_generator_markers() -> void:
	if realm_view.state == null:
		return

	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	for generator_value in realm_view.state.generators.values():
		var generator: Generator = generator_value
		if not generator.unlocked or generator.level > 0:
			continue

		var generator_id: String = generator.definition.id
		if not realm_view.realm_layout.generator_layout_positions.has(generator_id):
			continue

		var generator_position: Vector2 = realm_view._get_generator_position(
			generator_id
		)
		var badge_position: Vector2 = generator_position + Vector2(-22.0, -31.0)
		draw_rect(
			Rect2(badge_position, Vector2(44.0, 15.0)),
			Color(0.16, 0.09, 0.045, 0.96),
			true
		)
		draw_rect(
			Rect2(badge_position, Vector2(44.0, 15.0)),
			Color(1.0, 0.58, 0.19, 0.95),
			false,
			1.0
		)
		draw_string(
			font,
			badge_position + Vector2(0.0, 11.0),
			"BUILD",
			HORIZONTAL_ALIGNMENT_CENTER,
			44.0,
			9,
			Color(1.0, 0.76, 0.42, 1.0)
		)
