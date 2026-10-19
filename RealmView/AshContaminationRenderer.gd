class_name AshContaminationRenderer
extends Node2D


var effect_center: Vector2 = Vector2.ZERO
var realm_width: float = 0.0
var ash_amount: float = 0.0
const QUALITY_OFF: int = 0
const QUALITY_LOW: int = 1
const QUALITY_MEDIUM: int = 2
const QUALITY_HIGH: int = 3

var elapsed_time: float = 0.0
var effect_quality: int = QUALITY_MEDIUM
var active: bool = true

var randomizer: RandomNumberGenerator = RandomNumberGenerator.new()
var airborne_particles: Array[Dictionary] = []


func attach_to(view: Node) -> void:
	name = "AshContaminationRenderer"
	z_index = 10
	view.add_child(self)


func _ready() -> void:
	randomizer.randomize()


func _process(delta: float) -> void:
	if not active:
		return

	if ash_amount <= 0.0:
		if not airborne_particles.is_empty():
			airborne_particles.clear()
			queue_redraw()
		return

	elapsed_time += delta

	var target_count: int = _get_target_particle_count()

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
	var normalized_width: float = max(width, 1.0)
	var normalized_ash: float = max(ash, 0.0)
	if (
		effect_center == center
		and is_equal_approx(realm_width, normalized_width)
		and is_equal_approx(ash_amount, normalized_ash)
	):
		return

	effect_center = center
	realm_width = normalized_width
	ash_amount = normalized_ash
	# While active with Ash present, _process() already redraws every frame.
	# Only request an immediate redraw here when empty Ash needs to clear the effect.
	if active and ash_amount <= 0.0:
		queue_redraw()


func set_effect_quality(quality: int) -> void:
	var normalized_quality: int = clampi(
		quality,
		QUALITY_OFF,
		QUALITY_HIGH
	)
	var enabled: bool = normalized_quality > QUALITY_OFF
	if effect_quality == normalized_quality and active == enabled:
		return

	effect_quality = normalized_quality
	active = enabled
	visible = enabled
	set_process(enabled)
	if enabled:
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
		"size": randomizer.randf_range(0.75, 2.1),
		"alpha": randomizer.randf_range(0.16, 0.46),
		"variant": randomizer.randi_range(0, 3),
		"shape_angle": randomizer.randf_range(0.0, TAU),
		"warmth": randomizer.randf_range(0.0, 1.0),
		"vertical_offset": randomizer.randf_range(-75.0, 15.0)
	}


func _draw() -> void:
	if not active or ash_amount <= 0.0:
		return

	var ash_factor: float = _get_ash_factor()
	var particle_scale: float = 0.8 + ash_factor * 0.25

	for particle in airborne_particles:
		var angle: float = float(particle["angle"])
		var radius: float = float(particle["radius"]) * realm_width * 1.25
		var phase: float = float(particle["phase"])
		var vertical_offset: float = float(particle["vertical_offset"])

		var swirl_radius: float = radius + sin(phase) * realm_width * 0.035
		var particle_position: Vector2 = effect_center + Vector2(
			cos(angle) * swirl_radius,
			sin(angle) * swirl_radius * 0.38 + vertical_offset + sin(phase * 0.7) * 5.0
		)

		var particle_size: float = float(particle["size"]) * particle_scale
		var particle_alpha: float = minf(float(particle["alpha"]) * (0.75 + ash_factor * 0.60), 1.0)
		var variant: int = int(particle["variant"])
		var shape_angle: float = float(particle["shape_angle"]) + angle * 0.15
		var warmth: float = float(particle["warmth"])
		var soot_color: Color = Color(0.36, 0.36, 0.39, particle_alpha)
		var flake_color: Color = Color(0.58, 0.57, 0.55, particle_alpha * 0.9)
		var ember_color: Color = Color(0.95, 0.30 + warmth * 0.25, 0.08, particle_alpha * 0.72)

		match variant:
			0:
				# Thin, irregular soot sliver.
				var direction := Vector2(cos(shape_angle), sin(shape_angle))
				var side := Vector2(-direction.y, direction.x)
				var length: float = particle_size * 2.2
				var width: float = max(particle_size * 0.48, 0.35)
				draw_colored_polygon(PackedVector2Array([
					particle_position - direction * length,
					particle_position - direction * length * 0.15 - side * width,
					particle_position + direction * length,
					particle_position + direction * length * 0.1 + side * width * 0.65
				]), soot_color)
			1:
				# Chunky ash flake with a chipped silhouette.
				var points := PackedVector2Array()
				for point_data in [
					Vector2(-0.8, -0.25), Vector2(-0.2, -0.85),
					Vector2(0.45, -0.55), Vector2(0.9, 0.0),
					Vector2(0.25, 0.65), Vector2(-0.35, 0.8),
					Vector2(-0.65, 0.25)
				]:
					var point: Vector2 = point_data
					points.append(particle_position + point.rotated(shape_angle) * particle_size)
				draw_colored_polygon(points, flake_color)
			2:
				# A curled fragment, kept dim so it reads as ash rather than a spark.
				draw_arc(
					particle_position, particle_size * 0.9,
					shape_angle, shape_angle + PI * 1.45,
					6, Color(0.62, 0.48, 0.38, particle_alpha * 0.75),
					max(particle_size * 0.35, 0.4), true
				)
			3:
				# Rare warm ember among the otherwise cool grey ash.
				draw_circle(particle_position, particle_size * 0.75, ember_color)
				if warmth > 0.72:
					draw_circle(particle_position, particle_size * 1.8, Color(1.0, 0.24, 0.04, particle_alpha * 0.12))


func _get_target_particle_count() -> int:
	if ash_amount <= 0.0:
		return 0

	var quality_multiplier: float = 1.0
	match effect_quality:
		QUALITY_LOW:
			quality_multiplier = 0.35
		QUALITY_MEDIUM:
			quality_multiplier = 1.0
		QUALITY_HIGH:
			quality_multiplier = 1.5
		_:
			return 0

	return int(floor(
		280.0 * quality_multiplier * pow(
			ash_amount / (ash_amount + 3000.0),
			0.65
		)
	))
