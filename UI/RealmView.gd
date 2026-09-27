
class_name RealmView
extends Control


var state: GameState


func setup(game_state: GameState) -> void:
	state = game_state
	queue_redraw()


func _process(_delta: float) -> void:
	if state != null:
		queue_redraw()


func _draw() -> void:
	if state == null:
		return

	var center: Vector2 = size * Vector2(0.68, 0.55)
	var realm: RealmConfiguration = state.realm_configuration

	var density: int = realm.density
	var intensity: int = realm.intensity
	var stability: int = realm.stability
	var integrity: int = realm.integrity
	var resonance: int = realm.resonance

	var ash: float = state.get_resource_amount(
		ResourceIds.ASH
	)

	var scale_factor: float = 1.0 + min(
		float(density),
		100.0
	) * 0.003

	var sx: float = 190.0 * scale_factor
	var sy: float = 78.0 * scale_factor


	# ----------------------------------------------------------------
	# Background
	# ----------------------------------------------------------------

	draw_rect(
		Rect2(Vector2.ZERO, size),
		Color(0.015, 0.008, 0.025)
	)


	# ----------------------------------------------------------------
	# Distant realm particles
	# Resonance currently only affects ambience.
	# ----------------------------------------------------------------

	var particle_count: int = 35 + resonance * 2

	for i in range(particle_count):
		var angle: float = float(i) * 2.399
		var distance: float = 120.0 + fmod(
			float(i * 73),
			360.0
		)

		var position: Vector2 = center + Vector2(
			cos(angle) * distance,
			sin(angle) * distance * 0.65
		)

		var particle_size: float = 1.0 + fmod(
			float(i),
			2.0
		)

		draw_circle(
			position,
			particle_size,
			Color(0.45, 0.28, 0.55, 0.25)
		)


	# ----------------------------------------------------------------
	# Heat / intensity aura
	# ----------------------------------------------------------------

	var intensity_value: float = min(
		float(intensity),
		100.0
	)

	var glow_radius: float = 115.0 + intensity_value * 1.5
	var glow_alpha: float = 0.08 + intensity_value * 0.002

	draw_circle(
		center + Vector2(0, 12),
		glow_radius,
		Color(1.0, 0.18, 0.03, glow_alpha)
	)


	# ----------------------------------------------------------------
	# Floating island
	# ----------------------------------------------------------------

	var island_points: PackedVector2Array = _island_points(
		center,
		sx,
		sy
	)

	draw_colored_polygon(
		island_points,
		Color(0.075, 0.065, 0.085)
	)

	var edge_width: float = 1.0 + min(
		float(integrity),
		50.0
	) * 0.025

	draw_polyline(
		island_points,
		Color(0.30, 0.22, 0.32, 0.8),
		edge_width,
		true
	)


	# ----------------------------------------------------------------
	# Floating rock underside
	# ----------------------------------------------------------------

	var underside := PackedVector2Array([
		center + Vector2(-sx * 0.72, 28),
		center + Vector2(-sx * 0.45, 105 + density),
		center + Vector2(-sx * 0.15, 145 + density * 0.5),
		center + Vector2(0, 92 + density),
		center + Vector2(sx * 0.40, 70 + density * 0.5),
		center + Vector2(sx * 0.70, 25)
	])

	draw_colored_polygon(
		underside,
		Color(0.045, 0.038, 0.052)
	)


	# ----------------------------------------------------------------
	# Infernal core
	# ----------------------------------------------------------------

	var core_radius: float = 25.0 + intensity_value * 0.18

	draw_circle(
		center + Vector2(0, 10),
		core_radius + 18.0,
		Color(1.0, 0.12, 0.02, 0.10)
	)

	draw_circle(
		center + Vector2(0, 10),
		core_radius,
		Color(0.95, 0.20, 0.035, 0.75)
	)

	draw_circle(
		center + Vector2(0, 7),
		core_radius * 0.55,
		Color(1.0, 0.55, 0.10, 0.95)
	)


	# ----------------------------------------------------------------
	# Lava channels
	# ----------------------------------------------------------------

	var lava_line_count: int = 3 + int(
		min(
			intensity / 15,
			8
		)
	)

	for i in range(lava_line_count):
		var x: float = -sx * 0.72 + (
			float(i) * sx * 1.35 /
			float(max(lava_line_count - 1, 1))
		)

		var lava_alpha: float = 0.65 - min(
			float(stability),
			50.0
		) * 0.006

		draw_line(
			center + Vector2(x, 15),
			center + Vector2(
				x,
				80 + fmod(float(i * 19), 45.0)
			),
			Color(1.0, 0.22, 0.035, lava_alpha),
			2.0
		)


	# ----------------------------------------------------------------
	# Generators
	# ----------------------------------------------------------------

	_draw_generators(
		center,
		sx,
		sy
	)


	# ----------------------------------------------------------------
	# Ash
	# ----------------------------------------------------------------

	_draw_ash(
		center,
		sx,
		ash
	)


	# ----------------------------------------------------------------
	# Heat leak
	# ----------------------------------------------------------------

	_draw_heat_leak(
		center,
		sx
	)


func _island_points(
	center: Vector2,
	sx: float,
	sy: float
	) -> PackedVector2Array:

	var points := PackedVector2Array()

	for i in range(24):
		var angle: float = TAU * float(i) / 24.0

		var wobble: float = 0.88 + (
			fmod(float(i * 17), 100.0) / 500.0
		)

		points.append(
			center + Vector2(
				cos(angle) * sx * wobble,
				sin(angle) * sy * wobble
			)
		)

	return points


func _draw_generators(
	center: Vector2,
	sx: float,
	sy: float
	) -> void:

	var active_generators: Array = []

	for generator in state.generators.values():
		if generator.unlocked and generator.level > 0:
			active_generators.append(generator)

	var count: int = active_generators.size()

	if count == 0:
		return

	for i in range(count):
		var generator: Generator = active_generators[i]

		var angle: float = (
			-PI * 0.85 +
			PI * 1.7 * float(i) /
			float(max(count - 1, 1))
		)

		var position: Vector2 = center + Vector2(
			cos(angle) * sx * 0.62,
			sin(angle) * sy * 0.45 - 8
		)

		var machine_size: float = 5.0 + (
			min(float(generator.level), 50.0) * 0.10
		)

		var machine_color: Color

		if generator.is_operating():
			machine_color = Color(
				1.0,
				0.32,
				0.08
			)
		else:
			machine_color = Color(
				0.60,
				0.32,
				0.18
			)

		draw_rect(
			Rect2(
				position - Vector2(
					machine_size,
					machine_size
				),
				Vector2(
					machine_size * 2.0,
					machine_size * 2.0
				)
			),
			machine_color
		)

		draw_line(
			position,
			center + Vector2(0, 10),
			Color(0.50, 0.20, 0.08, 0.18),
			1.0
		)


func _draw_ash(
	center: Vector2,
	sx: float,
	ash: float
	) -> void:

	if ash <= 0.0:
		return

	var ash_factor: float = min(
		log(ash + 1.0) / 10.0,
		1.0
	)

	var particle_count: int = int(
		8.0 + ash_factor * 35.0
	)

	for i in range(particle_count):
		var angle: float = float(i) * 2.71

		var distance: float = sx * (
			0.55 +
			fmod(float(i * 13), 100.0) / 180.0
		)

		var position: Vector2 = center + Vector2(
			cos(angle) * distance,
			sin(angle) * distance * 0.45 - 35
		)

		draw_circle(
			position,
			1.5 + ash_factor * 2.0,
			Color(
				0.35,
				0.35,
				0.36,
				0.15 + ash_factor * 0.35
			)
		)


func _draw_heat_leak(
	center: Vector2,
	sx: float
	) -> void:

	if state.get_heat_leak_per_second() <= 0.0:
		return

	var threshold: float = (
		state.realm_effects.heat_leak_threshold
	)

	var heat: float = state.get_resource_amount(
		ResourceIds.HEAT
	)

	var excess: float = clamp(
		(heat - threshold) /
		max(threshold, 1.0),
		0.0,
		1.0
	)

	var leak_count: int = 3 + int(
		excess * 10.0
	)

	for i in range(leak_count):
		var x: float = (
			-sx * 0.8 +
			float(i) * sx * 1.6 /
			float(max(leak_count - 1, 1))
		)

		draw_line(
			center + Vector2(x, 18),
			center + Vector2(
				x + sin(float(i)) * 10.0,
				-45.0 - excess * 35.0
			),
			Color(1.0, 0.28, 0.05, 0.35),
			1.5
		)
