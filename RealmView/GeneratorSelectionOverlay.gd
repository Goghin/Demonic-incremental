class_name GeneratorSelectionOverlay
extends Node2D


var realm_view: RealmView
var selected_generator_id: String = ""
var particle_time: float = 0.0


func _process(delta: float) -> void:
	particle_time += delta
	queue_redraw()


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
		_draw_dormant_particles(generator_position, generator_id.hash())
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


func _draw_dormant_particles(
	center: Vector2,
	seed_value: int
) -> void:
	# Warm ember motes make even small, unbuilt machines easy to spot.
	for particle_index in range(5):
		var phase: float = (
			particle_time * (1.15 + float(particle_index % 3) * 0.18)
			+ float(seed_value % 97) * 0.07
			+ float(particle_index) * TAU / 5.0
		)
		var radius: float = 17.0 + float(particle_index % 3) * 3.0
		var particle_position: Vector2 = center + Vector2(
			cos(phase) * radius,
			sin(phase) * radius * 0.68 - 2.0
		)
		var flicker: float = 0.65 + 0.35 * sin(particle_time * 4.0 + particle_index)
		var glow_color: Color = Color(1.0, 0.34, 0.06, 0.18 * flicker)
		var ember_color: Color = Color(1.0, 0.56, 0.16, 0.95 * flicker)
		draw_circle(particle_position, 4.0, glow_color)
		draw_circle(particle_position, 1.5 + float(particle_index % 2) * 0.5, ember_color)
