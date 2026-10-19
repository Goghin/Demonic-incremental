class_name LavaLake
extends Node2D


class LavaBurstOverlay extends Node2D:
	var surface_points: PackedVector2Array = PackedVector2Array()
	var burst_timer: float = 0.8
	var randomizer: RandomNumberGenerator = RandomNumberGenerator.new()
	var lake_area_factor: float = 1.0
	var effect_quality: int = 2
	var particles: Array[Dictionary] = []
	var outer_spark_color: Color = Color(0.72, 0.045, 0.008, 0.92)
	var core_spark_color: Color = Color(1.0, 0.24, 0.035, 0.95)

	func _ready() -> void:
		randomizer.randomize()

	func set_lava_spark_colors(outer_color: Color, core_color: Color) -> void:
		outer_spark_color = outer_color
		core_spark_color = core_color
		for particle in particles:
			var node: Node2D = particle["node"]
			var outer := node.get_node_or_null("OuterGlow") as Polygon2D
			var core := node.get_node_or_null("HotCore") as Polygon2D
			if outer != null:
				outer.color = outer_spark_color
			if core != null:
				core.color = core_spark_color

	func set_visual_effect_quality(quality: int) -> void:
		var normalized_quality: int = clampi(quality, 0, 3)
		if effect_quality == normalized_quality:
			return
		effect_quality = normalized_quality
		if effect_quality == 0:
			for particle in particles:
				var node: Node2D = particle["node"]
				if is_instance_valid(node):
					node.queue_free()
			particles.clear()
		set_process(effect_quality > 0 or not particles.is_empty())

	func set_surface_points(points: PackedVector2Array) -> void:
		# The points are in LavaLake-local coordinates. This overlay is a
		# child of LavaLake, so particle child nodes use those same coordinates.
		surface_points = points
		lake_area_factor = _calculate_area_factor(surface_points)
		if effect_quality > 0 and surface_points.size() >= 3 and particles.is_empty():
			_spawn_burst()
		set_process(effect_quality > 0 or not particles.is_empty())

	func _process(delta: float) -> void:
		if effect_quality > 0:
			burst_timer -= delta
			if burst_timer <= 0.0 and surface_points.size() >= 3:
				_spawn_burst()
				var rate_multiplier: float = [0.0, 0.5, 1.0, 1.5][effect_quality]
				burst_timer = randomizer.randf_range(0.9, 1.5) / (lake_area_factor * rate_multiplier)

		for i in range(particles.size() - 1, -1, -1):
			var particle: Dictionary = particles[i]
			var particle_node: Node2D = particle["node"]
			var life: float = float(particle["life"]) - delta
			var velocity: Vector2 = particle["velocity"]
			velocity += Vector2(0.0, 22.0) * delta
			velocity.x = move_toward(velocity.x, 0.0, 1.2 * delta)
			particle_node.rotation = velocity.angle() + PI * 0.5
			particle_node.position += velocity * delta

			if life <= 0.0:
				particle_node.queue_free()
				particles.remove_at(i)
			else:
				particle["life"] = life
				particle["velocity"] = velocity
				var life_ratio: float = clamp(life / float(particle["max_life"]), 0.0, 1.0)
				particle_node.modulate.a = life_ratio
				var burst_scale: float = float(particle.get("burst_scale", 1.0))
				particle_node.scale = Vector2(lerp(0.45, 1.0, life_ratio), lerp(0.9, 1.35, life_ratio)) * burst_scale
				particles[i] = particle
		set_process(effect_quality > 0 or not particles.is_empty())

	func _spawn_burst() -> void:
		var center: Vector2 = Vector2.ZERO
		for point in surface_points:
			center += point
		center /= float(surface_points.size())

		var edge_index: int = randomizer.randi_range(0, surface_points.size() - 1)
		var edge_point: Vector2 = surface_points[edge_index]
		var next_point: Vector2 = surface_points[(edge_index + 1) % surface_points.size()]
		var edge_position: Vector2 = edge_point.lerp(next_point, randomizer.randf())
		var burst_position: Vector2 = center.lerp(edge_position, sqrt(randomizer.randf()))

		var burst_roll: float = randomizer.randf()
		var burst_scale: float = 1.0
		if burst_roll < 0.85:
			burst_scale = 1.0
		elif burst_roll < 0.98:
			burst_scale = randomizer.randf_range(1.8, 2.5)
		else:
			burst_scale = 3.0

		var base_particle_count: int = randomizer.randi_range(3, 6)
		var quality_multiplier: float = [0.0, 0.5, 1.0, 1.5][effect_quality]
		var burst_count_multiplier: float = 1.0 if burst_scale == 1.0 else (1.25 if burst_scale < 3.0 else 1.5)
		var particle_count: int = maxi(1, roundi(float(base_particle_count) * lake_area_factor * burst_count_multiplier * quality_multiplier))
		for i in range(particle_count):
			var particle_node := Node2D.new()
			particle_node.name = "LavaBurstParticle"
			particle_node.position = burst_position
			particle_node.z_index = 1
			add_child(particle_node)

			var particle_size: float = randomizer.randf_range(1.8, 3.2)
			var outer := Polygon2D.new()
			outer.name = "OuterGlow"
			outer.polygon = _make_spark(particle_size * randomizer.randf_range(0.7, 1.0), randomizer.randf_range(1.2, 2.0))
			outer.color = outer_spark_color
			particle_node.add_child(outer)

			var core := Polygon2D.new()
			core.name = "HotCore"
			core.polygon = _make_spark(particle_size * 0.42, 0.65)
			core.color = core_spark_color
			particle_node.add_child(core)

			var angle: float = randomizer.randf_range(-PI * 0.88, -PI * 0.12)
			var speed: float = randomizer.randf_range(22.0, 48.0) * sqrt(burst_scale)
			var particle_life: float = randomizer.randf_range(0.45, 0.8) * (1.0 + (burst_scale - 1.0) * 0.12)
			particles.append({
				"node": particle_node,
				"velocity": Vector2(cos(angle), sin(angle)) * speed,
				"life": particle_life,
				"max_life": particle_life,
				"burst_scale": burst_scale
			})

	func _calculate_area_factor(points: PackedVector2Array) -> float:
		if points.size() < 3:
			return 0.1

		var twice_area: float = 0.0
		for i in range(points.size()):
			var a: Vector2 = points[i]
			var b: Vector2 = points[(i + 1) % points.size()]
			twice_area += a.x * b.y - b.x * a.y

		var area: float = absf(twice_area) * 0.5
		# Normalize against a typical large lake. Small lakes produce fewer
		# and less frequent bursts; large lakes approach the full effect rate.
		return clamp(area / 5000.0, 0.12, 1.0)

	func _make_spark(length: float, width: float) -> PackedVector2Array:
		return PackedVector2Array([
			Vector2(0.0, -length),
			Vector2(width, 0.0),
			Vector2(0.0, length * 0.45),
			Vector2(-width, 0.0)
		])

	func _make_circle(radius: float, segments: int) -> PackedVector2Array:
		var points := PackedVector2Array()
		for i in range(segments):
			var angle: float = TAU * float(i) / float(segments)
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		return points


var edge_points: PackedVector2Array = PackedVector2Array()
var lake_rect: Rect2 = Rect2()
var normalized_edge_points: PackedVector2Array = PackedVector2Array()
var normalized_center_position: Vector2 = Vector2(-1.0, -1.0)
var heat: float = 0.0
var heat_threshold: float = 100000.0

var fill: float = 0.02
var visual_fill: float = 0.02

const FILL_SMOOTH_SPEED: float = .1
const GLOW_ALPHAS: Array[float] = [
	0.13, 0.22, 0.15, 0.25, 0.16, 0.23, 0.14, 0.13
]

var animation_time: float = 0.0
var lava_burst_overlay: LavaBurstOverlay
var edge_glow: Line2D
var edge_glow_gradient: Gradient
var lava_palette: Dictionary = {}
var visual_effect_quality: int = 2
var _visuals_dirty: bool = true
var _last_rendered_visual_fill: float = -1.0
var _last_rendered_animation_time: float = -1.0

func setup(
	normalized_points: PackedVector2Array,
	island_rect: Rect2,
	normalized_center: Vector2 = Vector2(-1.0, -1.0)
) -> void:
	normalized_edge_points = normalized_points
	normalized_center_position = normalized_center
	lake_rect = island_rect

	_reposition(island_rect)
	_update_fill()
	_ensure_edge_glow()
	_ensure_lava_burst_overlay()
	lava_burst_overlay.set_visual_effect_quality(visual_effect_quality)
	_update_visuals()

func set_visual_effect_quality(quality: int) -> void:
	var normalized_quality: int = clampi(quality, 0, 3)
	if visual_effect_quality == normalized_quality:
		return
	visual_effect_quality = normalized_quality
	if is_instance_valid(lava_burst_overlay):
		lava_burst_overlay.set_visual_effect_quality(visual_effect_quality)

func set_lava_palette(palette: Dictionary) -> void:
	lava_palette = palette.duplicate(true)
	_visuals_dirty = true

	var surface_node := get_node_or_null("Surface") as Polygon2D
	if surface_node != null and surface_node.material is ShaderMaterial:
		var node_material := surface_node.material as ShaderMaterial
		for key in ["dark", "red", "orange", "bright"]:
			if lava_palette.has(key):
				var color: Color = lava_palette[key]
				node_material.set_shader_parameter(
					key + "_lava",
					Vector3(color.r, color.g, color.b)
				)

	if is_instance_valid(lava_burst_overlay):
		lava_burst_overlay.set_lava_spark_colors(lava_palette.get("red", Color(0.72, 0.045, 0.008, 0.92)), lava_palette.get("bright", Color(1.0, 0.24, 0.035, 0.95)))
	_update_visuals()

func _ensure_edge_glow() -> void:
	if is_instance_valid(edge_glow):
		return

	edge_glow = Line2D.new()
	edge_glow.name = "LavaEdgeGlow"
	edge_glow.z_index = 0
	edge_glow.width = 5.5
	edge_glow.closed = true
	edge_glow.antialiased = false

	# Vary the glow thickness around the shoreline instead of making it a
	# perfectly uniform outline. The curve is subtle so the edge still reads
	# as one continuous pool of light.
	var glow_width_curve := Curve.new()
	glow_width_curve.add_point(Vector2(0.0, 0.78))
	glow_width_curve.add_point(Vector2(0.14, 1.0))
	glow_width_curve.add_point(Vector2(0.29, 0.72))
	glow_width_curve.add_point(Vector2(0.44, 1.12))
	glow_width_curve.add_point(Vector2(0.60, 0.82))
	glow_width_curve.add_point(Vector2(0.76, 1.08))
	glow_width_curve.add_point(Vector2(0.90, 0.70))
	glow_width_curve.add_point(Vector2(1.0, 0.78))
	edge_glow.width_curve = glow_width_curve

	# Reuse one gradient rather than allocating a new resource every frame.
	edge_glow_gradient = Gradient.new()
	edge_glow_gradient.offsets = PackedFloat32Array([
		0.0, 0.13, 0.28, 0.43, 0.60, 0.77, 0.91, 1.0
	])
	edge_glow_gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.13),
		Color(1.0, 1.0, 1.0, 0.22),
		Color(1.0, 1.0, 1.0, 0.15),
		Color(1.0, 1.0, 1.0, 0.25),
		Color(1.0, 1.0, 1.0, 0.16),
		Color(1.0, 1.0, 1.0, 0.23),
		Color(1.0, 1.0, 1.0, 0.14),
		Color(1.0, 1.0, 1.0, 0.13)
	])
	edge_glow.gradient = edge_glow_gradient

	add_child(edge_glow)


func _ensure_lava_burst_overlay() -> void:
	if lava_burst_overlay != null:
		return

	lava_burst_overlay = LavaBurstOverlay.new()
	lava_burst_overlay.name = "LavaBurstOverlay"
	lava_burst_overlay.z_index = 4
	lava_burst_overlay.visible = true
	lava_burst_overlay.set_visual_effect_quality(visual_effect_quality)
	add_child(lava_burst_overlay)
	if not lava_palette.is_empty():
		lava_burst_overlay.set_lava_spark_colors(lava_palette.get("red", Color(0.72, 0.045, 0.008, 0.92)), lava_palette.get("bright", Color(1.0, 0.24, 0.035, 0.95)))


func _reposition(island_rect: Rect2) -> void:
	_visuals_dirty = true
	lake_rect = island_rect

	edge_points.clear()

	for normalized_point in normalized_edge_points:
		edge_points.append(
			island_rect.position +
			island_rect.size * normalized_point
		)
		
func _process(delta: float) -> void:
	if visual_effect_quality > 0:
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
	if (
		not _visuals_dirty
		and is_equal_approx(visual_fill, _last_rendered_visual_fill)
		and is_equal_approx(animation_time, _last_rendered_animation_time)
	):
		return

	var center: Vector2 = Vector2.ZERO

	for point in edge_points:
		center += point

	center /= edge_points.size()
	if normalized_center_position.x >= 0.0 and normalized_center_position.y >= 0.0:
		center = lake_rect.position + lake_rect.size * normalized_center_position

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

	_ensure_edge_glow()
	edge_glow.points = rim_points
	var glow_color: Color = lava_palette.get("orange", Color(1.0, 0.12, 0.01, 1.0))
	var glow_pulse: float = 0.5 + 0.5 * sin(animation_time * 0.72) if visual_effect_quality > 0 else 0.5
	var glow_intensity: float = lerp(0.88, 1.12, glow_pulse)
	for i in range(GLOW_ALPHAS.size()):
		edge_glow_gradient.set_color(i, Color(
			glow_color.r,
			glow_color.g,
			glow_color.b,
			GLOW_ALPHAS[i] * glow_intensity
		))
	edge_glow.width = 5.2 + glow_pulse * 0.6

	var rim: Polygon2D = $Rim

	rim.polygon = rim_points
	rim.color = lava_palette.get("dark", Color(0.32, 0.022, 0.005, 0.55))

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
	surface.color = lava_palette.get("orange", Color(0.65, 0.055, 0.008, 0.9))
	# ---------------------------------------------------------
	# BRIGHT INNER EDGE
	# ---------------------------------------------------------

	var inner_edge: Line2D = $InnerEdge

	inner_edge.points = lake_points

	inner_edge.width = 0.8 + glow_pulse * 0.12

	var inner_edge_color: Color = lava_palette.get(
		"bright",
		Color(1.0, 0.16, 0.025, 0.75)
	)
	inner_edge_color.a *= 0.88 + glow_pulse * 0.18
	inner_edge.default_color = inner_edge_color

	inner_edge.closed = true

	_visuals_dirty = false
	_last_rendered_visual_fill = visual_fill
	_last_rendered_animation_time = animation_time


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
