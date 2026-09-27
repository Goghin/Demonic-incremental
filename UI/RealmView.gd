class_name RealmView
extends Control


var state: GameState


const ISLAND_CENTER := Vector2(300.0, 300.0)
const BASE_RADIUS := Vector2(205.0, 95.0)


func setup(game_state: GameState) -> void:
	state = game_state
	queue_redraw()


func _process(_delta: float) -> void:
	if state == null:
		return

	queue_redraw()


func _draw() -> void:
	_draw_background()

	if state == null:
		return

	_draw_ash()
	_draw_island()
	_draw_lava()
	_draw_core()
	_draw_generator_markers()
	_draw_atmosphere()


func _draw_background() -> void:
	draw_rect(
		Rect2(Vector2.ZERO, size),
		Color("#08060d")
	)

	# Subtle stars.
	var stars = [
		Vector2(65, 105),
		Vector2(145, 42),
		Vector2(245, 125),
		Vector2(385, 62),
		Vector2(475, 150),
		Vector2(560, 82),
		Vector2(720, 135),
		Vector2(850, 58),
		Vector2(1010, 125),
		Vector2(1120, 75),
		Vector2(1180, 205),
		Vector2(920, 255),
		Vector2(710, 235)
	]

	for star in stars:
		draw_circle(star, 1.5, Color("#6b6175"))


func _draw_island() -> void:
	var density = float(state.realm_configuration.density)
	var integrity = float(state.realm_configuration.integrity)

	var width_scale = 1.0 + min(density * 0.015, 0.35)
	var depth_scale = 1.0 + min(density * 0.008, 0.20)

	var points := PackedVector2Array()
	var point_count := 24

	for i in range(point_count):
		var angle = TAU * float(i) / float(point_count)
		var variation = 1.0 + 0.08 * sin(float(i) * 2.7)
		var point = ISLAND_CENTER + Vector2(
			cos(angle) * BASE_RADIUS.x * width_scale * variation,
			sin(angle) * BASE_RADIUS.y * depth_scale * variation
		)
		points.append(point)

	# Shadow / underside.
	var underside := PackedVector2Array()
	for point in points:
		underside.append(point + Vector2(0, 48))

	draw_colored_polygon(
		underside,
		Color("#17121d")
	)

	# Main rock.
	var rock_strength = min(integrity * 0.02, 0.35)
	var rock_color = Color(
		0.16 + rock_strength,
		0.10 + rock_strength * 0.55,
		0.13 + rock_strength * 0.35
	)

	draw_colored_polygon(
		points,
		rock_color
	)

	# Crust highlight.
	var crust := PackedVector2Array()
	for point in points:
		crust.append(point + Vector2(0, -7))

	draw_polyline(
		crust,
		Color("#46303a"),
		3.0,
		true
	)


func _draw_lava() -> void:
	var intensity = float(state.realm_configuration.intensity)
	var heat = state.get_resource_amount(ResourceIds.HEAT)

	var heat_factor = clamp(
		log(max(heat, 1.0)) / log(1000000.0),
		0.0,
		1.0
	)

	var activity = clamp(
		0.20
		+ intensity * 0.025
		+ heat_factor * 0.35,
		0.20,
		1.0
	)

	var lava_color = Color(
		0.75 + activity * 0.20,
		0.12 + activity * 0.18,
		0.025
	)

	var cracks = [
		[Vector2(145, 305), Vector2(190, 292), Vector2(225, 310)],
		[Vector2(372, 280), Vector2(405, 300), Vector2(438, 288)],
		[Vector2(245, 342), Vector2(280, 330), Vector2(318, 345)],
		[Vector2(330, 215), Vector2(345, 245), Vector2(365, 260)]
	]

	for crack in cracks:
		draw_polyline(
			PackedVector2Array(crack),
			lava_color,
			max(2.0, 2.0 + activity * 2.0),
			true
		)


func _draw_core() -> void:
	var intensity = float(state.realm_configuration.intensity)
	var stability = float(state.realm_configuration.stability)
	var heat = state.get_resource_amount(ResourceIds.HEAT)

	var heat_factor = clamp(
		log(max(heat, 1.0)) / log(1000000.0),
		0.0,
		1.0
	)

	var stability_factor = clamp(
		stability * 0.02,
		0.0,
		0.75
	)

	var intensity_factor = clamp(
		intensity * 0.025,
		0.0,
		0.75
	)

	var glow = clamp(
		0.15 + heat_factor * 0.45 + intensity_factor,
		0.15,
		1.0
	)

	# Outer glow.
	draw_circle(
		ISLAND_CENTER + Vector2(0, -10),
		75.0 + intensity_factor * 35.0,
		Color(0.65, 0.08, 0.02, glow * 0.10)
	)

	# Stable realms have a tighter, calmer core.
	var core_radius = lerp(34.0, 20.0, stability_factor)

	draw_circle(
		ISLAND_CENTER + Vector2(0, -10),
		core_radius + 12.0,
		Color(0.95, 0.22, 0.03, glow * 0.18)
	)

	draw_circle(
		ISLAND_CENTER + Vector2(0, -10),
		core_radius,
		Color(1.0, 0.38, 0.05, 0.65 + glow * 0.25)
	)

	draw_circle(
		ISLAND_CENTER + Vector2(0, -10),
		core_radius * 0.45,
		Color("#fff0b0")
	)


func _draw_generator_markers() -> void:
	var positions = [
		Vector2(205, 270),
		Vector2(270, 245),
		Vector2(355, 245),
		Vector2(405, 275),
		Vector2(235, 320),
		Vector2(375, 325),
		Vector2(305, 365)
	]

	var index := 0

	for generator in state.generators.values():
		if not generator.unlocked:
			continue

		if index >= positions.size():
			break

		var position = positions[index]
		var level_factor = clamp(
			log(float(generator.level) + 1.0) / log(101.0),
			0.0,
			1.0
		)

		var marker_size = 5.0 + level_factor * 9.0

		# Larger markers are a crude stand-in for larger machines.
		draw_rect(
			Rect2(
				position - Vector2(marker_size, marker_size),
				Vector2(marker_size * 2.0, marker_size * 2.0)
			),
			Color("#302633")
		)

		draw_rect(
			Rect2(
				position - Vector2(marker_size * 0.65, marker_size * 0.65),
				Vector2(marker_size * 1.3, marker_size * 1.3)
			),
			Color("#9b5360")
		)

		index += 1


func _draw_ash() -> void:
	var ash = state.get_resource_amount(ResourceIds.ASH)
	var ash_factor = clamp(
		log(max(ash, 1.0)) / log(1000000.0),
		0.0,
		1.0
	)

	if ash_factor <= 0.0:
		return

	var ash_color = Color(
		0.22,
		0.20,
		0.24,
		ash_factor * 0.28
	)

	var clouds = [
		Vector2(130, 220),
		Vector2(450, 230),
		Vector2(170, 385),
		Vector2(430, 375),
		Vector2(280, 175)
	]

	for cloud in clouds:
		draw_circle(
			cloud,
			18.0 + ash_factor * 28.0,
			ash_color
		)


func _draw_atmosphere() -> void:
	var stability = float(state.realm_configuration.stability)
	var integrity = float(state.realm_configuration.integrity)
	var resonance = float(state.realm_configuration.resonance)

	# Small orbiting particles are placeholders for future realm effects.
	var calmness = clamp(
		(stability + integrity) * 0.015,
		0.0,
		0.7
	)

	var particle_alpha = 0.25 + resonance * 0.01

	for i in range(10):
		var angle = float(i) * 0.63
		var radius = 125.0 + float(i % 3) * 28.0
		var position = ISLAND_CENTER + Vector2(
			cos(angle) * radius,
			sin(angle) * radius * 0.42
		)

		draw_circle(
			position,
			1.5 + calmness,
			Color(0.72, 0.42, 0.48, particle_alpha)
		)
