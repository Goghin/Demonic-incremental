class_name AtomicFrictionParticleOverlay
extends Node2D

var time: float = 0.0
var active: bool = false
var generator_level: int = 1

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	if not active:
		return


	var level: float = float(max(generator_level, 1))



	# Particle count increases with level, with diminishing returns.
	var particle_count: int = int(
		2.0 + min(max(level - 1.0, 0.0) * 14.0 / 99.0, 14.0)
	)

	# Higher levels make particles vibrate faster.
	var intensity: float = 1.0 + 0.05 * sqrt(level - 1.0)

	for i in range(particle_count):
		var seed: float = float(i) * 17.31

		var phase: float = (
			time * (5.0 + fmod(seed, 4.0)) * intensity
			+ seed
		)

		var cycle: float = fmod(
			time * (0.65 + fmod(seed, 0.4)) * intensity
			+ seed,
			1.0
		)

		# Particles remain clustered around the machine.
		var radius: float = (
			3.0
			+ fmod(seed * 2.7, 7.0)
			+ sin(phase) * (1.5 + 0.25 * (intensity - 1.0))
		)

		var angle: float = (
			seed + sin(phase * 0.7) * 0.8
		)

		var particle_position: Vector2 = Vector2(
			cos(angle) * radius,
			sin(angle) * radius * 0.75
		)

		# Particle brightness increases slightly with level.
		var alpha: float = clamp(
			0.45
			+ 0.35 * (0.5 + 0.5 * sin(phase))
			+ 0.08 * (intensity - 1.0),
			0.0,
			1.0
		)

		var particle_size: float = (
			0.3 * min(1.0 + 0.08 * sqrt(level - 1.0), 1.2)
		)

		draw_circle(
			particle_position,
			particle_size,
			Color(0.05, 0.85, 0.78, alpha)
		)

		# Sparks escape more often as the machine levels up.
		var spark_threshold: float = max(
			0.62,
			0.78 - 0.025 * sqrt(level - 1.0)
		)

		if cycle > spark_threshold:
			var spark_progress: float = (
				(cycle - spark_threshold)
				/ (1.0 - spark_threshold)
			)

			var spark_direction: Vector2 = Vector2(
				cos(angle + sin(seed) * 0.5),
				sin(angle + sin(seed) * 0.5)
			)

			var spark_start: Vector2 = (
				particle_position + spark_direction * 2.0
			)

			var spark_length: float = (
				2.0 + spark_progress * 5.0
			) * min(intensity, 2.0)

			var spark_end: Vector2 = (
				spark_start + spark_direction * spark_length
			)

			var spark_alpha: float = (
				1.0 - spark_progress
			)

			draw_line(
				spark_start,
				spark_end,
				Color(0.35, 0.95, 1.0, spark_alpha),
				1.0
			)

			draw_circle(
				spark_end,
				0.65 * min(intensity, 1.5),
				Color(0.8, 1.0, 1.0, spark_alpha)
			)

