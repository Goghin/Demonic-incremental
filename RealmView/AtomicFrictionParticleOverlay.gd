class_name AtomicFrictionParticleOverlay
extends Node2D

var time: float = 0.0
var active: bool = false
var generator_level: int = 1
var operation_mode_id: String = "normal"

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
		var p_seed: float = float(i) * 17.31

		var phase: float = (
			time * (5.0 + fmod(p_seed, 4.0)) * intensity
			+ p_seed
		)

		var cycle: float = fmod(
			time * (0.65 + fmod(p_seed, 0.4)) * intensity
			+ p_seed,
			1.0
		)

		# Particles remain clustered around the machine.
		var radius: float = (
			3.0
			+ fmod(p_seed * 2.7, 7.0)
			+ sin(phase) * (1.5 + 0.25 * (intensity - 1.0))
		)

		var angle: float = (
			p_seed + sin(phase * 0.7) * 0.8
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

		var particle_color: Color
		if operation_mode_id == "intensified_friction":
			particle_color = Color(0.18, 1.0, 0.28, alpha)
		else:
			# Normal operation uses the same fiery orange palette as Infernal Condensation.
			particle_color = Color(1.0, 0.35, 0.04, alpha)

		draw_circle(
			particle_position,
			particle_size,
			particle_color
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
				cos(angle + sin(p_seed) * 0.5),
				sin(angle + sin(p_seed) * 0.5)
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

			var spark_color: Color
			var spark_core_color: Color
			if operation_mode_id == "intensified_friction":
				spark_color = Color(0.55, 1.0, 0.35, spark_alpha)
				spark_core_color = Color(0.85, 1.0, 0.72, spark_alpha)
			else:
				spark_color = Color(1.0, 0.85, 0.3, spark_alpha)
				spark_core_color = Color(1.0, 0.98, 0.72, spark_alpha)

			draw_line(
				spark_start,
				spark_end,
				spark_color,
				1.0
			)

			draw_circle(
				spark_end,
				0.65 * min(intensity, 1.5),
				spark_core_color
			)
