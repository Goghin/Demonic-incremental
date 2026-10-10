class_name LavaLake
extends Node2D


class LavaBurstOverlay extends Node2D:
	var surface_points: PackedVector2Array = PackedVector2Array()
	var burst_timer: float = 0.25
	var randomizer: RandomNumberGenerator = RandomNumberGenerator.new()
	var particles: Array[Dictionary] = []

	func _ready() -> void:
		randomizer.randomize()

	func set_surface_points(points: PackedVector2Array) -> void:
		surface_points = points
		if surface_points.size() >= 3 and particles.is_empty():
			_spawn_burst()
		queue_redraw()

	func _process(delta: float) -> void:
		burst_timer -= delta

		if burst_timer <= 0.0 and surface_points.size() >= 3:
			_spawn_burst()
			burst_timer = randomizer.randf_range(0.45, 1.0)

		for i in range(particles.size() - 1, -1, -1):
			var particle: Dictionary = particles[i]
			particle["life"] = float(particle["life"]) - delta
			particle["position"] = (
				particle["position"] as Vector2
				+ particle["velocity"] as Vector2 * delta
			)
			particle["velocity"] = (
				particle["velocity"] as Vector2
				+ Vector2(0.0, -22.0) * delta
			)

			if float(particle["life"]) <= 0.0:
				particles.remove_at(i)
			else:
				particles[i] = particle

		queue_redraw()

	func _spawn_burst() -> void:
		var center: Vector2 = Vector2.ZERO
		for point in surface_points:
			center += point
		center /= float(surface_points.size())

		# Pick a random point inside the lake's current lava surface.
		var edge_index: int = randomizer.randi_range(
			0,
			surface_points.size() - 1
		)
		var edge_point: Vector2 = surface_points[edge_index]
		var next_point: Vector2 = surface_points[
			(edge_index + 1) % surface_points.size()
		]
		var edge_position: Vector2 = edge_point.lerp(
			next_point,
			randomizer.randf()
		)
		var burst_position: Vector2 = center.lerp(
			edge_position,
			sqrt(randomizer.randf())
		)

		var particle_count: int = randomizer.randi_range(8, 14)
		for i in range(particle_count):
			var angle: float = randomizer.randf_range(
				-PI * 0.92,
				-PI * 0.08
			)
			var speed: float = randomizer.randf_range(35.0, 75.0)
			particles.append({
				"position": burst_position,
				"velocity": Vector2(cos(angle), sin(angle)) * speed,
				"life": randomizer.randf_range(0.7, 1.2),
				"max_life": 1.2,
				"size": randomizer.randf_range(5.0, 8.0)
			})

	func _draw() -> void:
		# Temporary diagnostics: draw each particle at a fixed, unmistakable
		# size and color so we can distinguish spawning from animation issues.
		if surface_points.size() >= 3:
			var debug_center: Vector2 = Vector2.ZERO
			for point in surface_points:
				debug_center += point
			debug_center /= float(surface_points.size())
			draw_circle(debug_center, 7.0, Color(1.0, 0.0, 1.0, 1.0))

		for particle in particles:
			var debug_position: Vector2 = particle["position"]
			draw_circle(debug_position, 10.0, Color(0.0, 1.0, 0.2, 1.0))
			var life: float = float(particle["life"])
			var alpha: float = clamp(life / float(particle["max_life"]), 0.0, 1.0)
			var particle_position: Vector2 = particle["position"]
			var particle_size: float = float(particle["size"])
			draw_circle(
				particle_position,
				particle_size,
				Color(1.0, 0.24, 0.025, alpha)
			)
			draw_circle(
				particle_position,
				particle_size * 0.55,
				Color(1.0, 0.9, 0.35, alpha)
			)


var edge_points: PackedVector2Array = PackedVector2Array()
var lake_rect: Rect2 = Rect2()
var normalized_edge_points: PackedVector2Array = PackedVector2Array()
var heat: float = 0.0
var heat_threshold: float = 100000.0

var fill: float = 0.02
var visual_fill: float = 0.02

const FILL_SMOOTH_SPEED: float = .1

var animation_time: float = 0.0
var lava_burst_overlay: LavaBurstOverlay

func setup(
	normalized_points: PackedVector2Array,
	island_rect: Rect2
) -> void:
	normalized_edge_points = normalized_points
	lake_rect = island_rect

	_reposition(island_rect)
	_update_fill()
	_ensure_lava_burst_overlay()
	_update_visuals()

func _ensure_lava_burst_overlay() -> void:
	if lava_burst_overlay != null:
		return

	lava_burst_overlay = LavaBurstOverlay.new()
	lava_burst_overlay.name = "LavaBurstOverlay"
	lava_burst_overlay.z_index = 100
	lava_burst_overlay.visible = true
	lava_burst_overlay.set_process(true)
	add_child(lava_burst_overlay)


func _reposition(island_rect: Rect2) -> void:
	lake_rect = island_rect

	edge_points.clear()

	for normalized_point in normalized_edge_points:
		edge_points.append(
			island_rect.position +
			island_rect.size * normalized_point
		)
		
func _process(delta: float) -> void:
	animation_time += delta

	visual_fill = move_toward(
		visual_fill,
		fill,
		FILL_SMOOTH_SPEED * delta
	)

	_update_visuals()
	
func _update_fill() -> void:
	var heat_ratio: float = (
		heat /
		max(heat_threshold, 1.0)
	)

	fill = clamp(
		0.12 +
		1.10 *
		log(1.0 + heat_ratio) /
		log(500.0),
		0.12,
		1.1
	)
	
func _update_visuals() -> void:
	if edge_points.is_empty():
		return

	var center: Vector2 = Vector2.ZERO

	for point in edge_points:
		center += point

	center /= edge_points.size()

	# ---------------------------------------------------------
	# LAKE BOUNDARY
	# ---------------------------------------------------------

	var lake_points := PackedVector2Array()

	for i in range(edge_points.size()):
		var point: Vector2 = edge_points[i]

		var direction: Vector2 = point - center
		var distance: float = direction.length()

		if distance <= 0.001:
			lake_points.append(center)
			continue

		var normalized_direction: Vector2 = (
			direction / distance
		)

		var wave_a: float = sin(
			animation_time * 1.15 +
			float(i) * 1.73
		)

		var wave_b: float = sin(
			animation_time * 0.63 +
			float(i) * 2.41 +
			1.7
		)

		var wave_c: float = sin(
			animation_time * 1.87 +
			float(i) * 0.91 +
			3.4
		)

		var wobble: float = (
			wave_a * 0.55 +
			wave_b * 0.30 +
			wave_c * 0.15
		)

		var irregularity: float = (
			1.0 +
			wobble * 0.035
		)

		var edge_scale: float = (
			visual_fill * irregularity
		)

		lake_points.append(
			center +
			normalized_direction *
			distance *
			edge_scale
		)

	# ---------------------------------------------------------
	# BACKGROUND
	# ---------------------------------------------------------

	var background: Polygon2D = $Background

	background.polygon = lake_points
	background.color = Color(
		0.008,
		0.006,
		0.008,
		0.92
	)

	# ---------------------------------------------------------
	# HOT RIM
	# ---------------------------------------------------------

	var rim_points := PackedVector2Array()

	var rim_expansion: float = 0.025

	for point in lake_points:
		var direction: Vector2 = point - center
		var distance: float = direction.length()

		if distance <= 0.001:
			rim_points.append(center)
			continue

		var normalized_direction: Vector2 = (
			direction / distance
		)

		var expanded_distance: float = (
			distance +
			(distance / max(visual_fill, 0.001)) *
			rim_expansion
		)

		rim_points.append(
			center +
			normalized_direction *
			expanded_distance
		)

	var rim: Polygon2D = $Rim

	rim.polygon = rim_points
	rim.color = Color(
		0.32,
		0.022,
		0.005,
		0.55
	)

	# ---------------------------------------------------------
	# LAVA SURFACE
	# ---------------------------------------------------------

	var surface_points := PackedVector2Array()

	var surface_scale: float = visual_fill

	for point in edge_points:
		var direction: Vector2 = point - center
		var distance: float = direction.length()

		if distance <= 0.001:
			surface_points.append(center)
			continue

		var normalized_direction: Vector2 = (
			direction / distance
		)

		surface_points.append(
			center +
			normalized_direction *
			distance *
			surface_scale
		)

	var surface: Polygon2D = $Surface

	surface.polygon = surface_points
	_ensure_lava_burst_overlay()
	lava_burst_overlay.set_surface_points(surface_points)
	surface.color = Color(
		0.65,
		0.055,
		0.008,
		0.9
	)
	# ---------------------------------------------------------
	# BRIGHT INNER EDGE
	# ---------------------------------------------------------

	var inner_edge: Line2D = $InnerEdge

	inner_edge.points = lake_points

	inner_edge.width = .8

	inner_edge.default_color = Color(
		1.0,
		0.16,
		0.025,
		0.75
	)

	inner_edge.closed = true
	

	
func reposition(island_rect: Rect2) -> void:
	_reposition(island_rect)
	_update_visuals()



func set_heat(current_heat: float, current_threshold: float) -> void:
	heat = current_heat
	heat_threshold = current_threshold

	var heat_ratio: float = heat / max(heat_threshold, 1.0)

	var calculated_fill: float = clamp(
		0.02 +
		1.10 * log(1.0 + heat_ratio) / log(2.0),
		0.01,
		1.1
	)

	set_fill(calculated_fill)


func set_fill(new_fill: float) -> void:
	fill = clamp(new_fill, 0.01, 1.1)
	_update_visuals()
