class_name CrystallizedFlame
extends Node2D


@export var float_height: float = 4.0
@export var float_speed: float = 1.5
@export var rotation_amount: float = 0.025
@export var animation_speed: float = 12.0


var base_position: Vector2
var base_rotation: float = 0.0

var animation_timer: float = 0.0
var animation_frame: int = 0
var animation_direction: int = 1

var float_phase: float = 0.0
var individual_float_speed: float = 1.0
var individual_animation_speed: float = 1.0
var rotation_phase: float = 0.0
var individual_rotation_amount: float = 0.025


@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	base_position = position
	base_rotation = rotation

	# ------------------------------------------------------------
	# Randomize individual movement
	# ------------------------------------------------------------

	float_phase = randf_range(
		0.0,
		TAU
	)

	individual_float_speed = randf_range(
		0.85,
		1.15
	)

	individual_animation_speed = randf_range(
		0.90,
		1.10
	)

	rotation_phase = randf_range(
		0.0,
		TAU
	)

	individual_rotation_amount = (
		rotation_amount *
		randf_range(0.75, 1.25)
	)

	# Start each crystal at a different point in its animation.
	animation_frame = randi_range(
		0,
		11
	)

	animation_direction = (
		1 if randf() > 0.5 else -1
	)

	sprite.pause()
	sprite.frame = animation_frame


func _process(delta: float) -> void:
	var time: float = Time.get_ticks_msec() * 0.001

	# ------------------------------------------------------------
	# Floating
	# ------------------------------------------------------------

	var float_phase_current: float = (
		time *
		float_speed *
		individual_float_speed +
		float_phase
	)

	position.y = (
		base_position.y +
		sin(float_phase_current) *
		float_height
	)

	# ------------------------------------------------------------
	# Gentle individual rotation
	# ------------------------------------------------------------

	var rotation_phase_current: float = (
		time *
		float_speed *
		0.7 +
		rotation_phase
	)

	rotation = (
		base_rotation +
		sin(rotation_phase_current) *
		individual_rotation_amount
	)

	# ------------------------------------------------------------
	# Ping-pong animation
	# ------------------------------------------------------------

	animation_timer += delta

	var frame_delay: float = (
		1.0 /
		max(
			animation_speed *
			individual_animation_speed,
			0.1
		)
	)

	if animation_timer < frame_delay:
		return

	animation_timer -= frame_delay

	animation_frame += animation_direction

	if animation_frame >= 11:
		animation_frame = 10
		animation_direction = -1

	elif animation_frame <= 0:
		animation_frame = 1
		animation_direction = 1

	sprite.frame = animation_frame

func set_base_position(
	new_position: Vector2
	) -> void:

	base_position = new_position
	position = new_position

func set_base_transform(
	new_position: Vector2,
	new_rotation: float
	) -> void:

	base_position = new_position
	position = new_position

	base_rotation = new_rotation
	rotation = new_rotation
