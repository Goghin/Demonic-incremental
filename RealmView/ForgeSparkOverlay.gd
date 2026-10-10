class_name ForgeSparkOverlay
extends Node2D

var time: float = 0.0
var active: bool = false

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	if not active:
		return

	for i in range(11):
		var seed: float = float(i) * 17.31

		var cycle: float = fmod(
			time * (0.35 + fmod(seed, 0.25)) +
			seed,
			1.0
		)

		# Evenly distributed directions around the forge.
		var angle: float = (
			float(i) * TAU / 9.0 +
			sin(seed) * 0.25
		)

		var distance: float = lerp(
			2.0,
			24.0,
			cycle
		)

		# Slight irregularity in the outward path.
		var wobble: float = sin(
			time * 5.0 +
			seed
		) * 1.0

		var spark_position := Vector2(
			cos(angle),
			sin(angle)
		) * (distance + wobble)

		var alpha: float = (
			sin(cycle * PI) *
			0.75
		)

		var spark_size: float = (
			0.45 +
			fmod(seed, 0.35)
		)

		draw_circle(
			spark_position,
			spark_size,
			Color(
				1.0,
				0.65,
				0.15,
				alpha
			)
		)

