class_name SmokeEmitterRenderer
extends Node2D

const SMOKE_TEXTURE: Texture2D = preload("res://Assets/smoke.png")

var emitter_size: float = 1.0
var emission_rate: float = 1.0
var smoke_opacity: float = 0.7

var _spawn_accumulator: float = 0.0
var _particles: Array[Dictionary] = []


func configure(new_size: float, new_emission_rate: float, new_opacity: float) -> void:
	var clamped_size: float = clampf(new_size, 0.25, 3.0)
	var clamped_rate: float = clampf(new_emission_rate, 0.1, 3.0)
	var clamped_opacity: float = clampf(new_opacity, 0.05, 1.0)
	if not is_equal_approx(emitter_size, clamped_size) or not is_equal_approx(emission_rate, clamped_rate) or not is_equal_approx(smoke_opacity, clamped_opacity):
		emitter_size = clamped_size
		emission_rate = clamped_rate
		smoke_opacity = clamped_opacity
		queue_redraw()


func _process(delta: float) -> void:
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


func _spawn_particle() -> void:
	# Bound the active count so many emitters remain inexpensive.
	if _particles.size() >= 18:
		return

	_particles.append({
		"age": 0.0,
		"lifetime": randf_range(1.6, 2.8),
		"offset": Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0)),
		"drift": Vector2(randf_range(-9.0, 9.0), randf_range(-34.0, -20.0)),
		"size": randf_range(7.0, 12.0),
		"rotation": randf_range(-0.35, 0.35)
	})


func _draw() -> void:
	if SMOKE_TEXTURE == null:
		return

	for particle in _particles:
		var lifetime: float = float(particle["lifetime"])
		var progress: float = clampf(float(particle["age"]) / lifetime, 0.0, 1.0)
		var fade_in: float = clampf(progress / 0.14, 0.0, 1.0)
		var fade_out: float = clampf((1.0 - progress) / 0.32, 0.0, 1.0)
		var alpha: float = smoke_opacity * fade_in * fade_out
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
			Color(1.0, 1.0, 1.0, alpha)
		)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
