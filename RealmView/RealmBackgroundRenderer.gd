class_name RealmBackgroundRenderer
extends RefCounted


const DISTANT_PARTICLE_COUNT: int = 65
const PARTICLE_ANGLE_STEP: float = 2.399
const HAZE_VERTICAL_OFFSET: float = -25.0
const HAZE_RADIUS: float = 250.0
const PARTICLE_MIN_DISTANCE: float = 120.0
const PARTICLE_DISTANCE_SPREAD: float = 360.0
const PARTICLE_DISTANCE_MULTIPLIER: int = 73
const PARTICLE_VERTICAL_SCALE: float = 0.65
const PARTICLE_MIN_SIZE: float = 0.4
const PARTICLE_SIZE_SPREAD: float = 1.6


func draw_background(owner: RealmView) -> void:
	var center: Vector2 = owner.size * owner.ISLAND_CENTER_RATIO

	# RealmView is zoomed during rebirth. Counter-transform the background
	# so it remains full-screen while the realm artwork itself scales.
	var inverse_scale: Vector2 = Vector2.ONE
	if not is_zero_approx(owner.scale.x) and not is_zero_approx(owner.scale.y):
		inverse_scale = Vector2(
			1.0 / owner.scale.x,
			1.0 / owner.scale.y
		)

	var background_position: Vector2 = owner.pivot_offset - (
		owner.pivot_offset * inverse_scale
	)
	owner.draw_set_transform(
		background_position,
		0.0,
		inverse_scale
	)

	# ------------------------------------------------------------
	# Background
	# ------------------------------------------------------------

	owner.draw_rect(
		Rect2(Vector2.ZERO, owner.size),
		Color(0.04, 0.029, 0.074, 1.0)
	)

	# ------------------------------------------------------------
	# Ambient haze
	# ------------------------------------------------------------

	owner.draw_circle(
		center + Vector2(0, HAZE_VERTICAL_OFFSET),
		HAZE_RADIUS,
		Color(0.16, 0.07, 0.22, 0.12)
	)

	# ------------------------------------------------------------
	# Distant realm particles
	# ------------------------------------------------------------

	for i in range(DISTANT_PARTICLE_COUNT):
		var angle: float = float(i) * PARTICLE_ANGLE_STEP

		var distance: float = PARTICLE_MIN_DISTANCE + fmod(
			float(i * PARTICLE_DISTANCE_MULTIPLIER),
			PARTICLE_DISTANCE_SPREAD
		)

		var particle_position: Vector2 = (
			center +
			Vector2(
				cos(angle) * distance,
				sin(angle) * distance * PARTICLE_VERTICAL_SCALE
			)
		)

		var particle_size: float = PARTICLE_MIN_SIZE + fmod(
			float(i),
			PARTICLE_SIZE_SPREAD
		)

		owner.draw_circle(
			particle_position,
			particle_size,
			Color(0.55, 0.36, 0.65, 0.30)
		)

	# Restore the normal RealmView transform for subsequent drawing.
	owner.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
