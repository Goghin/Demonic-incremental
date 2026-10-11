class_name RealmBackgroundRenderer
extends RefCounted


const DISTANT_PARTICLE_COUNT: int = 65
const PARTICLE_ANGLE_STEP: float = 2.399


func draw_background(
	owner: Control,
	center: Vector2
) -> void:
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
		center + Vector2(0, -25),
		250.0,
		Color(0.16, 0.07, 0.22, 0.12)
	)

	# ------------------------------------------------------------
	# Distant realm particles
	# ------------------------------------------------------------

	for i in range(DISTANT_PARTICLE_COUNT):
		var angle: float = float(i) * PARTICLE_ANGLE_STEP

		var distance: float = 120.0 + fmod(
			float(i * 73),
			360.0
		)

		var particle_position: Vector2 = (
			center +
			Vector2(
				cos(angle) * distance,
				sin(angle) * distance * 0.65
			)
		)

		var particle_size: float = 0.4 + fmod(
			float(i),
			1.6
		)

		owner.draw_circle(
			particle_position,
			particle_size,
			Color(0.55, 0.36, 0.65, 0.30)
		)
