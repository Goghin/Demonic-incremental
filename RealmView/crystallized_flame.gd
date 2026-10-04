
class_name CrystallizedFlame
extends Node2D


@export var float_height: float = 4.0
@export var float_speed: float = 1.5
@export var rotation_amount: float = 0.025
@export var animation_speed: float = 12.0
var orbit_phase: float = 0.0
var individual_orbit_speed: float = 0.20
var individual_orbit_radius: float = 7.0

const FLAME_WAVE_SCENE = preload(
	"res://RealmView/flame_wave.gd"
)


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


# --------------------------------
# Prestige destruction
# --------------------------------

var destruction_active: bool = false
var destruction_delay: float = 0.0
var destruction_timer: float = 0.0
var destruction_progress: float = 0.0

var destruction_base_scale: Vector2 = Vector2.ONE

var crack_paths: Array[PackedVector2Array] = []

var visual_center: Vector2 = Vector2.ZERO
var visual_radius: float = 40.0

var explosion_active: bool = false


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

	orbit_phase = randf_range(0.0, TAU)

	individual_orbit_speed = randf_range(
		0.75,
		1.25
	)

	individual_orbit_radius = randf_range(
		5.0,
		10.0
	)



	sprite.pause()
	sprite.frame = animation_frame

	_update_visual_geometry()

	# Draw our destruction effects above the sprite.
	z_index = 1
	sprite.z_index = -1


func _process(delta: float) -> void:
	var time: float = Time.get_ticks_msec() * 0.001

	if not destruction_active:
		# --------------------------------
		# Normal floating animation
		# --------------------------------

		var float_phase_current: float = (
			time
			* float_speed
			* individual_float_speed
			+ float_phase
		)

		var orbit_phase_current: float = (
			time
			* individual_orbit_speed
			+ orbit_phase
		)

		var orbit_offset := Vector2(
			cos(orbit_phase_current),
			sin(orbit_phase_current)
		) * individual_orbit_radius

		position = (
			base_position
			+ orbit_offset
		)

		# Keep the existing vertical bobbing,
		# but make it independent of the orbit.

		position.y += (
			sin(float_phase_current)
			* float_height
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

	# --------------------------------
	# Destruction animation
	# --------------------------------

	destruction_timer += delta

	if destruction_timer < destruction_delay:
		return

	var active_time: float = (
		destruction_timer - destruction_delay
	)

	const DESTRUCTION_DURATION: float = 1.44

	destruction_progress = clamp(
		active_time / DESTRUCTION_DURATION,
		0.0,
		1.0
	)

	# Keep the flame animation moving faster as it destabilizes.
	_update_animation(
		delta,
		animation_speed
		* individual_animation_speed
		* (1.0 + destruction_progress * 3.0)
	)

	# Stop the normal floating movement.
	position = base_position
	rotation = base_rotation

	# --------------------------------
	# Crystal growth / instability
	# --------------------------------

	var pulse: float = sin(
		destruction_progress * TAU * 3.0
	)

	var scale_multiplier: float = 1.0

	if destruction_progress < 0.55:
		scale_multiplier = (
			1.0
			+ destruction_progress * 0.18
			+ max(pulse, 0.0) * 0.10
		)

	elif destruction_progress < 0.78:
		var growth_progress: float = (
			destruction_progress - 0.55
		) / 0.23

		scale_multiplier = lerp(
			1.10,
			1.50,
			growth_progress
		)

	else:
		var burst_progress: float = (
			destruction_progress - 0.78
		) / 0.22

		scale_multiplier = lerp(
			1.50,
			1.85,
			burst_progress
		)

	scale = destruction_base_scale * scale_multiplier

	# --------------------------------
	# Fade only at the very end
	# --------------------------------

	if destruction_progress > 0.82:
		var fade_progress: float = (
			destruction_progress - 0.82
		) / 0.18

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

	explosion_active = false

	_update_visual_geometry()
	_build_cracks()

	queue_redraw()


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
		) * 0.28
	)


func _build_cracks() -> void:
	crack_paths.clear()

	var radius: float = visual_radius

	for i in range(6):
		var angle: float = (
			float(i) * TAU / 6.0
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
				-radius * 0.10,
				radius * 0.10
			)

			path.append(
				visual_center
				+ direction * distance
				+ perpendicular * offset
			)

		crack_paths.append(path)


func _create_flame_wave() -> void:
	var wave := FLAME_WAVE_SCENE.new() as FlameWave

	if wave == null:
		return

	var parent := get_parent()

	if parent == null:
		return

	parent.add_child(wave)

	wave.position = position
	#wave.rotation = deg_to_rad(-18.0)
	
	wave.max_radius = 500.0
	wave.expansion_speed = 600.0
	wave.wave_width = 22.0


func _draw() -> void:
	if not destruction_active:
		return

	var p: float = destruction_progress

	# --------------------------------
	# Unstable glow
	# --------------------------------

	var glow_progress: float = clamp(
		p * 1.8,
		0.0,
		1.0
	)

	var pulse: float = (
		0.70
		+ sin(p * TAU * 4.0) * 0.30
	)

	var glow_alpha: float = (
		glow_progress
		* pulse
		* 0.55
	)

	var glow_radius: float = (
		visual_radius
		* (1.15 + p * 0.35)
	)

	draw_circle(
		visual_center,
		glow_radius,
		Color(
			1.0,
			0.18,
			0.01,
			glow_alpha
		)
	)

	draw_circle(
		visual_center,
		glow_radius * 0.55,
		Color(
			1.0,
			0.70,
			0.12,
			glow_alpha * 1.5
		)
	)

	# --------------------------------
	# Cracks
	# --------------------------------

	var crack_progress: float = clamp(
		(p - 0.03) / 0.42,
		0.0,
		1.0
	)

	for crack in crack_paths:
		if crack.size() < 2:
			continue

		var visible_points := PackedVector2Array()

		for point in crack:
			visible_points.append(
				visual_center
				+ (
					point - visual_center
				) * crack_progress
			)

		draw_polyline(
			visible_points,
			Color(
				1.0,
				0.20,
				0.01,
				0.85 * glow_progress
			),
			7.0,
			true
		)

		draw_polyline(
			visible_points,
			Color(
				1.0,
				0.95,
				0.45,
				1.0 * glow_progress
			),
			2.5,
			true
		)

	# --------------------------------
	# FLAME WAVE
	# --------------------------------

	if p < 0.68:
		return

	var burst_progress: float = (
		p - 0.68
	) / 0.32

	# Create the flame wave once.
	if not explosion_active:
		explosion_active = true
		_create_flame_wave()

	# Keep a small white-hot core behind
	# the expanding wave.

	var core_alpha: float = (
		1.0 - burst_progress
	)

	draw_circle(
		visual_center,
		visual_radius * 0.65,
		Color(
			1.0,
			0.72,
			0.12,
			core_alpha * 0.85
		)
	)

	draw_circle(
		visual_center,
		visual_radius * 0.30,
		Color(
			1.0,
			1.0,
			0.85,
			core_alpha
		)
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
