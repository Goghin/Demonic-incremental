class_name AshContaminationRenderer
extends Node2D


var effect_center: Vector2 = Vector2.ZERO
var realm_width: float = 0.0
var ash_amount: float = 0.0
var elapsed_time: float = 0.0

var randomizer: RandomNumberGenerator = RandomNumberGenerator.new()
var airborne_particles: Array[Dictionary] = []


func _ready() -> void:
	randomizer.randomize()


func _process(delta: float) -> void:
	if ash_amount <= 0.0:
		if not airborne_particles.is_empty():
			airborne_particles.clear()
			queue_redraw()
		return

	elapsed_time += delta

	var ash_factor: float = _get_ash_factor()
	var target_count: int = int(20.0 + ash_factor * 160.0)

	while airborne_particles.size() < target_count:
		airborne_particles.append(_create_particle())

	while airborne_particles.size() > target_count:
		airborne_particles.pop_back()

	for i in range(airborne_particles.size()):
		var particle: Dictionary = airborne_particles[i]
		particle["angle"] = float(particle["angle"]) + float(particle["angular_speed"]) * delta
		particle["phase"] = float(particle["phase"]) + float(particle["phase_speed"]) * delta
		airborne_particles[i] = particle

	queue_redraw()


func update_visuals(
	center: Vector2,
	width: float,
	ash: float
) -> void:
	effect_center = center
	realm_width = max(width, 1.0)
	ash_amount = max(ash, 0.0)
	queue_redraw()


func _get_ash_factor() -> float:
	return min(log(ash_amount + 1.0) / log(101.0), 1.0)


func _create_particle() -> Dictionary:
	return {
		"angle": randomizer.randf_range(0.0, TAU),
		"radius": randomizer.randf_range(0.45, 1.05),
		"angular_speed": randomizer.randf_range(-0.42, 0.42),
		"phase": randomizer.randf_range(0.0, TAU),
		"phase_speed": randomizer.randf_range(0.25, 0.75),
		"size": randomizer.randf_range(0.45, 1.25),
		"alpha": randomizer.randf_range(0.18, 0.48),
		"vertical_offset": randomizer.randf_range(-55.0, 25.0)
	}


func _draw() -> void:
	if ash_amount <= 0.0:
		return

	var ash_factor: float = _get_ash_factor()
	var particle_scale: float = 0.8 + ash_factor * 0.25

	for particle in airborne_particles:
		var angle: float = float(particle["angle"])
		var radius: float = float(particle["radius"]) * realm_width
		var phase: float = float(particle["phase"])
		var vertical_offset: float = float(particle["vertical_offset"])

		var swirl_radius: float = radius + sin(phase) * realm_width * 0.035
		var particle_position: Vector2 = effect_center + Vector2(
			cos(angle) * swirl_radius,
			sin(angle) * swirl_radius * 0.38 + vertical_offset + sin(phase * 0.7) * 5.0
		)

		var tangent: Vector2 = Vector2(
			-sin(angle),
			cos(angle) * 0.38
		).normalized()

		var particle_size: float = float(particle["size"]) * particle_scale
		var particle_alpha: float = float(particle["alpha"]) * (0.65 + ash_factor * 0.55)
		var ash_color: Color = Color(0.43, 0.43, 0.45, particle_alpha)

		draw_line(
			particle_position - tangent * particle_size * 1.2,
			particle_position + tangent * particle_size * 1.4,
			Color(ash_color.r, ash_color.g, ash_color.b, particle_alpha * 0.45),
			max(particle_size * 0.45, 0.35)
		)
		draw_circle(particle_position, particle_size, ash_color)
