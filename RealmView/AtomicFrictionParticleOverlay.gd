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

	# Higher levels make particles launch faster and travel farther.
	var intensity: float = 1.0 + 0.05 * sqrt(level - 1.0)

	for i in range(particle_count):
		var p_seed: float = float(i) * 17.31

		# Each particle repeatedly launches outward from the machine, then fades.
		var launch_speed: float = (0.55 + fmod(p_seed, 0.35)) * intensity
		var cycle: float = fmod(
			time * launch_speed + fmod(p_seed * 0.37, 1.0),
			1.0
		)
		var angle: float = p_seed * 2.39996
		var direction: Vector2 = Vector2(
			cos(angle),
			sin(angle) * 0.78
		).normalized()

		var max_distance: float = 10.0 + min(level - 1.0, 20.0) * 0.25
		var travel_distance: float = 2.0 + cycle * max_distance
		var particle_position: Vector2 = direction * travel_distance

		# Fade in at launch and fade out as the particle escapes.
		var fade_in: float = clamp(cycle * 7.0, 0.0, 1.0)
		var fade_out: float = clamp((1.0 - cycle) * 3.0, 0.0, 1.0)
		var alpha: float = fade_in * fade_out * 0.9
		var particle_size: float = (
			0.3 * min(1.0 + 0.08 * sqrt(level - 1.0), 1.2)
		)

		var particle_color: Color
		var trail_color: Color
		var spark_core_color: Color
		if operation_mode_id == "intensified_friction":
			particle_color = Color(0.18, 1.0, 0.28, alpha)
			trail_color = Color(0.55, 1.0, 0.35, alpha * 0.75)
			spark_core_color = Color(0.85, 1.0, 0.72, alpha)
		else:
			# Normal operation matches Infernal Condensation's fiery orange palette.
			particle_color = Color(1.0, 0.35, 0.04, alpha)
			trail_color = Color(1.0, 0.65, 0.12, alpha * 0.75)
			spark_core_color = Color(1.0, 0.98, 0.72, alpha)

		# Short streaks make the outward movement read as a burst, not a wave.
		var trail_length: float = 1.5 + cycle * 2.5
		draw_line(
			particle_position - direction * trail_length,
			particle_position,
			trail_color,
			1.0
		)
		draw_circle(particle_position, particle_size, particle_color)
		draw_circle(
			particle_position,
			particle_size * 0.55,
			spark_core_color
		)
