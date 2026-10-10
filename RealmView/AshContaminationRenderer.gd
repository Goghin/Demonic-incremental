class_name AshContaminationRenderer
extends Node2D


var effect_center: Vector2 = Vector2.ZERO
var realm_width: float = 0.0
var ash_amount: float = 0.0


func update_visuals(
	center: Vector2,
	width: float,
	ash: float
) -> void:
	effect_center = center
	realm_width = width
	ash_amount = ash
	queue_redraw()


func _draw() -> void:
	if ash_amount <= 0.0:
		return

	var ash_factor: float = min(
		log(ash_amount + 1.0) / 10.0,
		1.0
	)

	var particle_count: int = int(
		8.0 +
		ash_factor * 35.0
	)

	for i in range(particle_count):
		var angle: float = float(i) * 2.71

		var distance: float = (
			realm_width *
			(
				0.55 +
				fmod(float(i * 13), 100.0) / 180.0
			)
		)

		var particle_position: Vector2 = (
			effect_center +
			Vector2(
				cos(angle) * distance,
				sin(angle) * distance * 0.45 - 35.0
			)
		)

		draw_circle(
			particle_position,
			1.5 + ash_factor * 2.0,
			Color(
				0.40,
				0.40,
				0.42,
				0.15 + ash_factor * 0.35
			)
		)
