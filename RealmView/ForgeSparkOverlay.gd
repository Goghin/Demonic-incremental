class_name ForgeSparkOverlay
extends Node2D


const BASE_PARTICLE_COUNT: int = 10
const PARTICLES_PER_LEVEL: int = 2
const MAX_PARTICLE_COUNT: int = 120
const BASE_SPEED: float = 0.35
const SPEED_PER_LEVEL: float = 0.08
const BASE_STREAK_LENGTH: float = 2.8
const STREAK_LENGTH_PER_LEVEL: float = 0.025

var time: float = 0.0
var active: bool = false
var generator_level: int = 1


func _process(delta: float) -> void:
	if not active:
		return

	time += delta
	queue_redraw()


func _draw() -> void:
	if not active:
		return

	var level: int = max(generator_level, 1)
	var particle_count: int = min(
		BASE_PARTICLE_COUNT + (level - 1) * PARTICLES_PER_LEVEL,
		MAX_PARTICLE_COUNT
	)
	var speed_multiplier: float = 1.0 + (level - 1) * SPEED_PER_LEVEL
	var streak_length: float = BASE_STREAK_LENGTH + (level - 1) * STREAK_LENGTH_PER_LEVEL

	for i in range(particle_count):
		var seed: float = float(i) * 17.31

		var cycle: float = fposmod(
			time * (BASE_SPEED + fposmod(seed, 0.25)) * speed_multiplier
			+ seed,
			1.0
		)

		# Sparks begin around the outer rim and travel inward.
		var angle: float = (
			float(i) * TAU / float(particle_count)
			+ sin(seed) * 0.25
		)

		var distance: float = lerp(
			24.0,
			1.0,
			cycle
		)

		var wobble: float = sin(
			time * 5.0 * speed_multiplier + seed
		) * 1.0

		var radial_direction: Vector2 = Vector2(cos(angle), sin(angle))
		var spark_position: Vector2 = radial_direction * max(distance + wobble, 0.0)
		var inward_length: float = min(streak_length, max(distance, 0.0))
		var inner_endpoint: Vector2 = spark_position - radial_direction * inward_length

		# Brighter, elongated streaks point toward the forge's center.
		var alpha: float = sin(cycle * PI) * 0.92
		var spark_size: float = 0.55 + fposmod(seed, 0.4)
		var spark_color: Color = Color(1.0, 0.78, 0.28, alpha)

		draw_line(
			spark_position,
			inner_endpoint,
			Color(1.0, 0.86, 0.48, alpha * 0.95),
			max(spark_size * 0.8, 0.55),
			true
		)
		draw_circle(
			spark_position,
			spark_size,
			spark_color
		)
