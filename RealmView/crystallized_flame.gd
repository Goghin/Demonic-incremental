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


# Prestige destruction

var destruction_active: bool = false
var destruction_delay: float = 0.0
var destruction_timer: float = 0.0
var destruction_progress: float = 0.0

var destruction_base_scale: Vector2 = Vector2.ONE

var crack_paths: Array[PackedVector2Array] = []

var visual_center: Vector2 = Vector2.ZERO
var visual_radius: float = 40.0


@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	base_position = position
	base_rotation = rotation

	float_phase = randf_range(0.0, TAU)
	individual_float_speed = randf_range(0.85, 1.15)
	individual_animation_speed = randf_range(0.90, 1.10)

	rotation_phase = randf_range(0.0, TAU)
	individual_rotation_amount = (
		rotation_amount * randf_range(0.75, 1.25)
	)

	animation_frame = randi_range(0, 11)
	animation_direction = 1 if randf() > 0.5 else -1

	sprite.pause()
	sprite.frame = animation_frame

	_update_visual_geometry()

	# Put our own drawing above the sprite.
	z_index = 1
	sprite.z_index = -1


func _update_visual_geometry() -> void:
	visual_center = Vector2.ZERO

	var texture: Texture2D = null

	if sprite.sprite_frames != null:
		texture = sprite.sprite_frames.get_frame_texture(
			sprite.animation,
			animation_frame
		)

	if texture == null:
		return

	var texture_size: Vector2 = texture.get_size()

	visual_radius = (
		min(
			texture_size.x,
			texture_size.y
		)
		* 0.28
	)
func _process(delta: float) -> void:
	var time: float = Time.get_ticks_msec() * 0.001

	if not destruction_active:
		var float_phase_current: float = (
			time
			* float_speed
			* individual_float_speed
			+ float_phase
		)

		position.y = (
			base_position.y
			+ sin(float_phase_current) * float_height
		)

		var rotation_phase_current: float = (
			time
			* float_speed
			* 0.7
			+ rotation_phase
		)

		rotation = (
			base_rotation
			+ sin(rotation_phase_current)
			* individual_rotation_amount
		)

		_update_animation(
			delta,
			animation_speed
			* individual_animation_speed
		)

		return

	# -------------------------
	# Destruction animation
	# -------------------------

	destruction_timer += delta

	if destruction_timer < destruction_delay:
		return

	var active_time: float = (
		destruction_timer - destruction_delay
	)

	const DESTRUCTION_DURATION: float = 0.72

	destruction_progress = clamp(
		active_time / DESTRUCTION_DURATION,
		0.0,
		1.0
	)

	_update_animation(
		delta,
		animation_speed
		* individual_animation_speed
		* (1.0 + destruction_progress * 3.0)
	)

	var pulse: float = sin(
		destruction_progress * TAU * 2.5
	)

	var scale_multiplier: float = (
		1.0
		+ destruction_progress * 0.10
		+ max(pulse, 0.0) * 0.08
	)

	if destruction_progress > 0.78:
		var burst_progress: float = (
			destruction_progress - 0.78
		) / 0.22

		scale_multiplier += burst_progress * 0.35

	scale = destruction_base_scale * scale_multiplier

	# Freeze normal floating movement.
	position = base_position
	rotation = base_rotation

	if destruction_progress >= 0.86:
		var fade_progress: float = (
			destruction_progress - 0.86
		) / 0.14

		modulate.a = 1.0 - fade_progress

	queue_redraw()

	if destruction_progress >= 1.0:
		visible = false


func _update_animation(
	delta: float,
	current_animation_speed: float
) -> void:
	animation_timer += delta

	var frame_delay: float = (
		1.0
		/ max(current_animation_speed, 0.1)
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

	_update_visual_geometry()


func begin_destruction(delay: float = 0.0) -> void:
	print(
		"DESTRUCTION ",
		name,
		" local=",
		position,
		" global=",
		global_position,
		" base=",
		base_position
	)
	
	
	
	destruction_active = true
	destruction_delay = max(delay, 0.0)
	destruction_timer = 0.0
	destruction_progress = 0.0

	destruction_base_scale = scale

	position = base_position
	rotation = base_rotation

	modulate.a = 1.0
	visible = true

	_update_visual_geometry()
	_build_cracks()

	queue_redraw()

func _build_cracks() -> void:
	crack_paths.clear()

	var radius: float = visual_radius

	for i in range(4):
		var angle: float = (
			float(i) * TAU / 4.0
			+ randf_range(-0.30, 0.30)
		)

		var direction: Vector2 = Vector2(
			cos(angle),
			sin(angle)
		)

		var perpendicular: Vector2 = Vector2(
			-direction.y,
			direction.x
		)

		var path := PackedVector2Array()

		path.append(
			visual_center
			+ direction * randf_range(1.0, 3.0)
		)

		for point_index in range(1, 4):
			var distance: float = (
				radius
				* float(point_index)
				/ 3.0
			)

			var offset: float = randf_range(
				-radius * 0.08,
				radius * 0.08
			)

			path.append(
				visual_center
				+ direction * distance
				+ perpendicular * offset
			)

		crack_paths.append(path)


func _draw() -> void:
	if not destruction_active:
		return

	# --------------------------------
	# Internal unstable glow
	# --------------------------------

	var glow_progress: float = clamp(
		destruction_progress * 1.7,
		0.0,
		1.0
	)

	var pulse: float = (
		0.65
		+ sin(destruction_progress * TAU * 3.0) * 0.25
	)

	var glow_alpha: float = (
		glow_progress
		* pulse
		* 0.35
	)

	var glow_radius: float = visual_radius * 1.15

	draw_circle(
		visual_center,
		glow_radius,
		Color(
			1.0,
			0.20,
			0.02,
			glow_alpha
		)
	)

	draw_circle(
		visual_center,
		glow_radius * 0.55,
		Color(
			1.0,
			0.65,
			0.12,
			glow_alpha * 1.8
		)
	)

	# --------------------------------
	# Cracks
	# --------------------------------

	var crack_progress: float = clamp(
		(destruction_progress - 0.05) / 0.38,
		0.0,
		1.0
	)

	for crack in crack_paths:
		if crack.is_empty():
			continue

		var visible_points := PackedVector2Array()

		for point in crack:
			visible_points.append(
				visual_center
				+ (
					point - visual_center
				) * crack_progress
			)

		if visible_points.size() < 2:
			continue

		# Outer glow.
		draw_polyline(
			visible_points,
			Color(
				1.0,
				0.25,
				0.02,
				0.65 * glow_progress
			),
			6.0,
			true
		)

		# Hot core.
		draw_polyline(
			visible_points,
			Color(
				1.0,
				0.85,
				0.35,
				0.95 * glow_progress
			),
			2.0,
			true
		)

	# --------------------------------
	# Final burst
	# --------------------------------

	if destruction_progress < 0.72:
		return

	var burst_progress: float = (
		destruction_progress - 0.72
	) / 0.28

	var burst_alpha: float = (
		1.0 - burst_progress
	)

	var burst_radius: float = (
		visual_radius * 0.25
		+ burst_progress * visual_radius * 1.2
	)

	draw_circle(
		visual_center,
		burst_radius * 0.30,
		Color(
			1.0,
			0.85,
			0.50,
			burst_alpha * 0.8
		)
	)

	for i in range(8):
		var angle: float = (
			float(i) * TAU / 8.0
			+ 0.12
		)

		var direction: Vector2 = Vector2(
			cos(angle),
			sin(angle)
		)

		var start_distance: float = (
			8.0
			+ burst_progress * 5.0
		)

		var end_distance: float = (
			burst_radius
			* randf_range(0.75, 1.15)
		)

		draw_line(
			visual_center
			+ direction * start_distance,
			visual_center
			+ direction * end_distance,
			Color(
				1.0,
				0.55,
				0.08,
				burst_alpha * 0.85
			),
			3.0,
			true
		)


func set_base_position(new_position: Vector2) -> void:
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
