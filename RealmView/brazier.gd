class_name Brazier
extends Control


@export var brazier_size: float = 1.0


var stat_name: String = ""
var stat_value: int = 0

var displayed_stat_strength: float = 0.0
var target_stat_strength: float = 0.0

var flame_time: float = 0.0
var base_scale: Vector2


func _ready() -> void:
	base_scale = Vector2(
		brazier_size,
		brazier_size
	)

	scale = base_scale

	queue_redraw()


func _process(delta: float) -> void:
	flame_time += delta

	# Smoothly move toward the current stat strength.
	displayed_stat_strength = move_toward(
		displayed_stat_strength,
		target_stat_strength,
		delta * 3.0
	)

	queue_redraw()


func set_stat(stat: String) -> void:
	stat_name = stat

	queue_redraw()


func set_stat_value(value: int) -> void:
	stat_value = max(value, 0)

	target_stat_strength = clamp(
		float(stat_value) / 100.0,
		0.0,
		1.0
	)


func get_stat_color() -> Color:
	match stat_name:
		"stability":
			return Color(
				0.20,
				0.85,
				0.30
			)

		"density":
			return Color(
				0.20,
				0.45,
				1.0
			)

		"integrity":
			return Color(
				0.65,
				0.20,
				0.95
			)

		"intensity":
			return Color(
				1.0,
				0.80,
				0.12
			)

		"resonance":
			return Color(
				0.10,
				0.90,
				0.90
			)

		_:
			return Color(
				1.0,
				0.35,
				0.08
			)


func _draw() -> void:
	var stat_color: Color = get_stat_color()

	# ------------------------------------------------------------
	# Stat strength
	# ------------------------------------------------------------

	var stat_strength: float = displayed_stat_strength

	# No flame or glow when the stat has no investment.
	if stat_strength <= 0.001:
		return

	# ------------------------------------------------------------
	# Flame position
	# ------------------------------------------------------------

	var flame_y: float = lerp(
		-5.0,
		-10.0,
		stat_strength
	)

	# ------------------------------------------------------------
	# Flame size
	# ------------------------------------------------------------

	var flame_size: float = lerp(
		0.40,
		1.0,
		stat_strength
	)

	# ------------------------------------------------------------
	# Flicker
	# ------------------------------------------------------------

	var flicker: float = (
		sin(flame_time * 7.0) * 0.08 +
		sin(flame_time * 13.0) * 0.04
	)

	# ------------------------------------------------------------
	# Glow
	# ------------------------------------------------------------

	var glow_radius: float = lerp(
		12.0,
		32.0,
		stat_strength
	)

	var glow_alpha: float = lerp(
		0.08,
		0.18,
		stat_strength
	) + flicker

	draw_circle(
		Vector2(0, flame_y),
		glow_radius,
		Color(
			stat_color.r,
			stat_color.g,
			stat_color.b,
			glow_alpha
		)
	)

	# ------------------------------------------------------------
	# Flame
	# ------------------------------------------------------------

	var flame_scale: float = (
		1.0 +
		sin(flame_time * 9.0) * 0.08 +
		sin(flame_time * 17.0) * 0.04
	)

	var flame_height: float = (
		18.0 *
		flame_size *
		flame_scale
	)

	var flame_width: float = (
		7.0 *
		flame_size *
		flame_scale
	)

	var flame_points: PackedVector2Array = PackedVector2Array([
		Vector2(
			-flame_width,
			flame_y + 3.0 * flame_size
		),

		Vector2(
			-flame_width * 0.65,
			flame_y - flame_height * 0.35
		),

		Vector2(
			-flame_width * 0.25,
			flame_y - flame_height
		),

		Vector2(
			0,
			flame_y - flame_height * 0.65
		),

		Vector2(
			flame_width * 0.35,
			flame_y - flame_height * 0.95
		),

		Vector2(
			flame_width * 0.75,
			flame_y - flame_height * 0.30
		),

		Vector2(
			flame_width,
			flame_y + 3.0 * flame_size
		)
	])

	draw_colored_polygon(
		flame_points,
		Color(
			stat_color.r,
			stat_color.g,
			stat_color.b,
			0.90
		)
	)

	# ------------------------------------------------------------
	# Inner flame
	# ------------------------------------------------------------

	var inner_height: float = flame_height * 0.58
	var inner_width: float = flame_width * 0.55

	var inner_points: PackedVector2Array = PackedVector2Array([
		Vector2(
			-inner_width,
			flame_y + 2.0
		),

		Vector2(
			-inner_width * 0.45,
			flame_y - inner_height * 0.35
		),

		Vector2(
			0,
			flame_y - inner_height
		),

		Vector2(
			inner_width * 0.55,
			flame_y - inner_height * 0.30
		),

		Vector2(
			inner_width,
			flame_y + 2.0
		)
	])

	var inner_color: Color = stat_color.lerp(
		Color(1.0, 0.9, 0.65),
		0.45
	)

	draw_colored_polygon(
		inner_points,
		inner_color
	)
