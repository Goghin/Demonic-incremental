class_name FurnaceSwirlOverlay
extends Node2D

var time: float = 0.0
var active: bool = false
var speed_multiplier: float = 1.0

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	if not active:
		return

	var center := Vector2.ZERO

	for i in range(5):
		var phase: float = (
			time *
			(1.4 + i * 0.18) *
			speed_multiplier +
			i * TAU / 5.0
		)

		var cycle: float = fmod(
			time * 0.7 * speed_multiplier +
			i * 0.23,
			1.0
		)
		var inward: float = pow(cycle, 2.2)
		var radius: float = lerp(13.0, 2.5, inward)

		var orb_position := center + Vector2(
			cos(phase),
			sin(phase)
		) * radius

		orb_position += Vector2(
			sin(time * 3.0 + i * 2.1),
			cos(time * 2.4 + i * 1.7)
		) * 1.5

		var alpha: float = 0.7 * (1.0 - inward * 0.75)

		draw_circle(
			orb_position,
			1.8,
			Color(1.0, 0.35, 0.04, alpha)
		)

		draw_circle(
			orb_position,
			0.8,
			Color(1.0, 0.85, 0.3, alpha)
		)

