class_name FlameWave
extends Node2D

var radius: float = 0.0
var max_radius: float = 500.0
var expansion_speed: float = 450.0

var wave_width: float = 32.0
var wave_alpha: float = 1.0

var finished: bool = false

var triggered_crystals: Array[CrystallizedFlame] = []

func _ready() -> void:
	# Randomize each wave slightly.
	# Keep the variation controlled so the chain
	# reaction still feels coherent.

	var speed_variation: float = randf_range(
		0.85,
		1.15
	)

	var size_variation: float = randf_range(
		0.90,
		1.12
	)

	var width_variation: float = randf_range(
		0.85,
		1.15
	)

	expansion_speed *= speed_variation
	max_radius *= size_variation
	wave_width *= width_variation

	z_index = 10
	queue_redraw()

func _process(delta: float) -> void:
	if finished:
		return

	radius += expansion_speed * delta

	_check_crystals()

	var fade_start: float = max_radius * 0.70

	if radius > fade_start:
		var fade_progress: float = (
			radius - fade_start
		) / (max_radius - fade_start)

		wave_alpha = 1.0 - fade_progress

	queue_redraw()

	if radius >= max_radius:
		finished = true
		queue_free()

func _check_crystals() -> void:
	var realm_view := get_parent()

	if realm_view == null:
		return

	if not realm_view is RealmView:
		return

	for crystal in realm_view.crystallized_flames:
		if crystal == null:
			continue

		if not is_instance_valid(crystal):
			continue

		if crystal in triggered_crystals:
			continue

		if crystal.destruction_active:
			continue

		var distance: float = global_position.distance_to(
			crystal.global_position
		)

		if distance <= radius:
			triggered_crystals.append(crystal)

			var reaction_delay: float = randf_range(
				0.05,
				0.20
			)

			print(
				"Flame wave reached ",
				crystal.name,
				" delay=",
				reaction_delay
			)

			crystal.begin_destruction(
				reaction_delay
		)

func _draw() -> void:
	if wave_alpha <= 0.0:
		return

	const PERSPECTIVE_Y: float = 0.38

	var points := PackedVector2Array()

	const POINT_COUNT: int = 128

	for i in range(POINT_COUNT + 1):
		var angle: float = (
			TAU
			* float(i)
			/ float(POINT_COUNT)
		)

		var distortion: float = (
			1.0
			+ sin(
				angle * 7.0
				+ radius * 0.025
			) * 0.035
			+ sin(
				angle * 11.0
				- radius * 0.018
			) * 0.020
		)

		var x: float = (
			cos(angle)
			* radius
			* distortion
		)

		var y: float = (
			sin(angle)
			* radius
			* PERSPECTIVE_Y
			* distortion
		)

		points.append(
			Vector2(x, y)
		)

# --------------------------------
# Outer infernal glow
# --------------------------------

	draw_polyline(
		points,
		Color(
			1.0,
			0.05,
			0.0,
			wave_alpha * 0.20
		),
		wave_width * 3.0,
		true
	)

	# --------------------------------
	# Main flame body
	# --------------------------------

	draw_polyline(
		points,
		Color(
			1.0,
			0.20,
			0.01,
			wave_alpha * 0.70
		),
		wave_width * 1.55,
		true
	)

	# --------------------------------
	# Orange-hot core
	# --------------------------------

	draw_polyline(
		points,
		Color(
			1.0,
			0.62,
			0.06,
			wave_alpha * 0.95
		),
		wave_width * 0.62,
		true
	)

	# --------------------------------
	# White-hot center
	# --------------------------------

	draw_polyline(
		points,
		Color(
			1.0,
			0.96,
			0.70,
			wave_alpha * 0.90
		),
		wave_width * 0.18,
		true
	)
