class_name LavaLake
extends Node2D

var edge_points: PackedVector2Array = PackedVector2Array()
var lake_rect: Rect2 = Rect2()
var normalized_edge_points: PackedVector2Array = PackedVector2Array()
var heat: float = 0.0
var heat_threshold: float = 100000.0

var fill: float = 0.02
var visual_fill: float = 0.02

const FILL_SMOOTH_SPEED: float = .1

var animation_time: float = 0.0

func setup(
	normalized_points: PackedVector2Array,
	island_rect: Rect2
) -> void:
	normalized_edge_points = normalized_points
	lake_rect = island_rect

	_reposition(island_rect)
	_update_fill()
	_update_visuals()

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
		0.02 +
		1.10 *
		log(1.0 + heat_ratio) /
		log(500.0),
		0.01,
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
