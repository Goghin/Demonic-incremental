class_name AtomicFrictionAnimationController
extends RefCounted


const BASE_ROTATION_SPEED: float = -0.45
const BASE_PULSE_SPEED: float = 1.2

const ROTATION_LEVEL_BONUS: float = 0.12
const PULSE_LEVEL_BONUS: float = 0.20

var time: float = 0.0


func update(
	generator: Generator,
	sprite: Sprite2D,
	delta: float
) -> void:
	if not sprite.visible or not generator.is_operating():
		return

	var level: int = generator.level

	time += delta

	var rotation_speed: float = (
		BASE_ROTATION_SPEED *
		(1.0 + ROTATION_LEVEL_BONUS * sqrt(float(level)))
	)

	var pulse_speed: float = (
		BASE_PULSE_SPEED *
		(1.0 + PULSE_LEVEL_BONUS * sqrt(float(level)))
	)

	sprite.rotation += rotation_speed * delta

	var pulse: float = (
		sin(time * pulse_speed) + 1.0
	) / 2.0

	var pulse_scale: float = lerp(0.58, 0.7, pulse)

	var base_scale: Vector2 = sprite.get_meta(
		"atomic_friction_base_scale"
	)

	sprite.scale = base_scale * pulse_scale
