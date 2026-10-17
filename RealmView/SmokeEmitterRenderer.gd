class_name SmokeEmitterRenderer
extends Node2D

var emitter_size: float = 1.0
var emission_rate: float = 1.0
var smoke_opacity: float = 0.7

var _spawn_accumulator: float = 0.0
var _particles: Array[Dictionary] = []


func configure(new_size: float, new_emission_rate: float, new_opacity: float) -> void:
	emitter_size = clampf(new_size, 0.25, 3.0)
	emission_rate = clampf(new_emission_rate, 0.1, 3.0)
	smoke_opacity = clampf(new_opacity, 0.05, 1.0)
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
		"seed": randi()
	})


func _draw() -> void:
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
		var puff_seed: int = int(particle["seed"])
		var base := Color(0.28, 0.28, 0.30, alpha * 0.72)
		var light := Color(0.43, 0.43, 0.45, alpha * 0.55)
		var dark := Color(0.17, 0.17, 0.19, alpha * 0.75)

		_draw_smoke_blob(puff_center, puff_size, base, puff_seed)
		_draw_smoke_blob(puff_center + Vector2(-puff_size * 0.36, -puff_size * 0.12), puff_size * 0.66, light, puff_seed + 7)
		_draw_smoke_blob(puff_center + Vector2(puff_size * 0.32, puff_size * 0.08), puff_size * 0.72, dark, puff_seed + 13)


func _draw_smoke_blob(center: Vector2, radius: float, color: Color, seed_value: int) -> void:
	var points := PackedVector2Array()
	var vertex_count: int = 8
	for vertex in range(vertex_count):
		var angle: float = TAU * float(vertex) / float(vertex_count)
		var variation: float = 0.78 + float(abs((seed_value * (vertex + 3) * 17) % 31)) / 100.0
		var point_radius: float = radius * variation
		points.append(center + Vector2(cos(angle) * point_radius, sin(angle) * point_radius * 0.82))
	draw_colored_polygon(points, color)
