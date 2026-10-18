class_name SmokeEmitterRenderer
extends Node2D

const SMOKE_TEXTURE: Texture2D = preload("res://Assets/smoke.png")
const COLUMN_FRAME_COUNT: int = 14
const COLUMN_FRAME_RATE: float = 12.0
const COLUMN_FRAME_DURATION: float = 1.0 / COLUMN_FRAME_RATE

var emitter_size: float = 1.0
var emission_rate: float = 1.0
var smoke_opacity: float = 0.7
var smoke_style: String = "puff"
var column_variant: int = 1

var _spawn_accumulator: float = 0.0
var _particles: Array[Dictionary] = []
var _column_frames: Array[Texture2D] = []
var _column_frame_index: int = 0
var _column_frame_accumulator: float = 0.0


func _ready() -> void:
	# Soften this effect without changing filtering for the rest of the game.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_load_column_frames()


func configure(
	new_size: float,
	new_emission_rate: float,
	new_opacity: float,
	new_style: String = "puff",
	new_variant: int = 1
) -> void:
	var clamped_size: float = clampf(new_size, 0.25, 3.0)
	var clamped_rate: float = clampf(new_emission_rate, 0.1, 3.0)
	var clamped_opacity: float = clampf(new_opacity, 0.05, 1.0)
	var clamped_variant: int = clampi(new_variant, 1, 5)
	var clamped_style: String = "column" if new_style == "column" else "puff"
	var style_changed: bool = smoke_style != clamped_style
	var variant_changed: bool = column_variant != clamped_variant

	if (
		not is_equal_approx(emitter_size, clamped_size)
		or not is_equal_approx(emission_rate, clamped_rate)
		or not is_equal_approx(smoke_opacity, clamped_opacity)
		or style_changed
		or variant_changed
	):
		emitter_size = clamped_size
		emission_rate = clamped_rate
		smoke_opacity = clamped_opacity
		smoke_style = clamped_style
		column_variant = clamped_variant

		if style_changed:
			_particles.clear()
			_spawn_accumulator = 0.0
			_column_frame_index = 0
			_column_frame_accumulator = 0.0
		if variant_changed:
			_load_column_frames()
		queue_redraw()


func _process(delta: float) -> void:
	if smoke_style == "column":
		if _column_frames.is_empty():
			return
		_column_frame_accumulator += delta
		while _column_frame_accumulator >= COLUMN_FRAME_DURATION:
			_column_frame_accumulator -= COLUMN_FRAME_DURATION
			_column_frame_index = (_column_frame_index + 1) % _column_frames.size()
		queue_redraw()
		return

	_spawn_accumulator += delta * emission_rate * 2.6
	while _spawn_accumulator >= 1.0:
		_spawn_particle()
		_spawn_accumulator -= 1.0

	for index in range(_particles.size() - 1, -1, -1):
		var particle: Dictionary = _particles[index]
		particle["age"] = float(particle["age"]) + delta
		var offset: Vector2 = particle["offset"]
		var drift: Vector2 = particle["drift"]
		particle["offset"] = offset + drift * delta
		_particles[index] = particle
		if float(particle["age"]) >= float(particle["lifetime"]):
			_particles.remove_at(index)

	queue_redraw()


func _load_column_frames() -> void:
	_column_frames.clear()
	for frame_number in range(1, COLUMN_FRAME_COUNT + 1):
		var frame_path: String = "res://Assets/Smokes/Smoke %d/Smoke %d_%d.png" % [
			column_variant,
			column_variant,
			frame_number
		]
		var frame_texture := load(frame_path) as Texture2D
		if frame_texture != null:
			_column_frames.append(frame_texture)
		else:
			push_warning("Could not load smoke animation frame: " + frame_path)
	_column_frame_index = 0
	_column_frame_accumulator = 0.0


func _spawn_particle() -> void:
	# Keep a hard cap so denser smoke remains inexpensive across all emitters.
	if _particles.size() >= 24:
		return

	_particles.append({
		"age": 0.0,
		"lifetime": randf_range(1.6, 2.8),
		"offset": Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0)),
		"drift": Vector2(randf_range(-9.0, 9.0), randf_range(-34.0, -20.0)),
		"size": randf_range(8.0, 14.0),
		"rotation": randf_range(-0.55, 0.55),
		"opacity": randf_range(0.65, 1.0)
	})


func _draw() -> void:
	if smoke_style == "column":
		_draw_animated_column()
	else:
		_draw_smoke_puffs()


func _draw_animated_column() -> void:
	if _column_frames.is_empty():
		return

	var frame: Texture2D = _column_frames[_column_frame_index]
	var frame_size: Vector2 = Vector2(frame.get_size()) * emitter_size
	# Keep smoke columns slightly slimmer without shortening their height.
	frame_size.x *= 0.82
	var alpha: float = smoke_opacity
	var tint := Color(1.0, 1.0, 1.0, alpha)
	draw_texture_rect(
		frame,
		# The emitter position is the column's base, so the editor handle
		# stays anchored where smoke emerges from the ground/source.
		Rect2(Vector2(-frame_size.x * 0.5, -frame_size.y), frame_size),
		false,
		tint
	)


func _draw_smoke_puffs() -> void:
	if SMOKE_TEXTURE == null:
		return

	for particle in _particles:
		var lifetime: float = float(particle["lifetime"])
		var progress: float = clampf(float(particle["age"]) / lifetime, 0.0, 1.0)
		var fade_in: float = clampf(progress / 0.14, 0.0, 1.0)
		var fade_out: float = clampf((1.0 - progress) / 0.32, 0.0, 1.0)
		var alpha: float = smoke_opacity * float(particle["opacity"]) * fade_in * fade_out
		if alpha <= 0.01:
			continue

		var puff_center: Vector2 = particle["offset"]
		var puff_size: float = float(particle["size"]) * emitter_size * lerpf(0.35, 1.45, progress)
		var rotation: float = float(particle["rotation"])
		var draw_size := Vector2.ONE * puff_size * 2.0

		draw_set_transform(puff_center, rotation, Vector2.ONE)
		draw_texture_rect(
			SMOKE_TEXTURE,
			Rect2(-draw_size * 0.5, draw_size),
			false,
			Color(0.88, 0.91, 0.92, alpha)
		)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
