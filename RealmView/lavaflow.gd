class_name LavaFlow
extends Node2D


@onready var surface: Node2D = $Surface
@onready var rim: Line2D = $Rim
@onready var channel: Polygon2D = $Channel

const FLOW_SHADER = preload("res://RealmView/lava_flow.gdshader")
const LAVA_TEXTURE = preload("res://RealmView/lava1.png")

var points: PackedVector2Array = PackedVector2Array()
var widths: PackedFloat32Array = PackedFloat32Array()

var speed: float = 25.0
var intensity: float = 1.0

var start_ratio: float = 0.10
var stop_ratio: float = 0.07

var active_length: float = 0.0
var animation_speed: float = 0.12
var cooling_length: float = 0.0

var fill_speed_multiplier: float = 1.0
var drain_speed_multiplier: float = 1.0

const SEGMENT_OVERLAP: float = 1.2


enum FlowState {
	INACTIVE,
	STARTING,
	FLOWING,
	STOPPING
}


var flow_state: FlowState = FlowState.INACTIVE
var target_active: bool = false

var surface_segments: Array[Polygon2D] = []
var surface_corners: Array[Polygon2D] = []
var surface_material: ShaderMaterial


func setup(
	flow_points: PackedVector2Array,
	flow_widths: PackedFloat32Array,
	flow_speed: float = 25.0,
	flow_intensity: float = 1.0,
	flow_start_ratio: float = 0.10,
	flow_stop_ratio: float = 0.07
) -> void:

	if flow_points.size() < 2:
		return

	if flow_widths.size() != flow_points.size():
		return

	speed = flow_speed
	intensity = flow_intensity
	start_ratio = flow_start_ratio
	stop_ratio = flow_stop_ratio

	position = flow_points[0]

	points.clear()
	widths.clear()

	for i in range(flow_points.size()):
		points.append(flow_points[i] - position)
		widths.append(flow_widths[i])

	_setup_material()

	flow_state = FlowState.INACTIVE
	target_active = false
	active_length = 0.0
	cooling_length = 0.0

	_clear_flow_polygons()



func set_active(active: bool) -> void:
	target_active = active

	if active:
		if flow_state == FlowState.INACTIVE:
			flow_state = FlowState.STARTING
		elif flow_state == FlowState.STOPPING:
			# Finish the stopping animation before restarting.
			return
	else:
		if flow_state == FlowState.FLOWING:
			flow_state = FlowState.STOPPING
		elif flow_state == FlowState.STARTING:
			flow_state = FlowState.STOPPING

func reposition_from_points(
	flow_points: PackedVector2Array
) -> void:

	if flow_points.size() < 2:
		return

	position = flow_points[0]

	points.clear()

	for point in flow_points:
		points.append(point - position)

	_update_surface()


func _setup_material() -> void:
	surface_material = ShaderMaterial.new()
	surface_material.shader = FLOW_SHADER

	surface_material.set_shader_parameter(
		"lava_texture",
		LAVA_TEXTURE
	)

	surface_material.set_shader_parameter(
		"flow_speed",
		speed
	)



func _process(delta: float) -> void:
	match flow_state:
		FlowState.STARTING:
			active_length += (
				delta
				* animation_speed
				* fill_speed_multiplier
			)

			if active_length >= 1.0:
				active_length = 1.0
				cooling_length = 0.0
				flow_state = FlowState.FLOWING

			_update_surface()

		FlowState.FLOWING:
			active_length = 1.0
			cooling_length = 0.0

		FlowState.STOPPING:
			cooling_length += (delta 
			* animation_speed
			* fill_speed_multiplier)

			if cooling_length >= 1.0:
				cooling_length = 1.0
				active_length = 0.0
				cooling_length = 0.0
				flow_state = FlowState.INACTIVE

			_update_surface()

		FlowState.INACTIVE:
			active_length = 0.0
			cooling_length = 0.0
			_update_surface()

func _update_surface() -> void:
	if not is_instance_valid(surface):
		return

	if points.size() < 2:
		return

	var distances := PackedFloat32Array()
	var total_distance: float = 0.0

	distances.append(0.0)

	for i in range(1, points.size()):
		total_distance += (
			points[i].distance_to(points[i - 1])
		)

		distances.append(total_distance)

	if total_distance <= 0.0:
		return

	var start_distance: float = 0.0
	var end_distance: float = total_distance

	match flow_state:
		FlowState.INACTIVE:
			_clear_flow_polygons()
			return

		FlowState.STARTING:
			end_distance = total_distance * active_length

		FlowState.FLOWING:
			end_distance = total_distance

		FlowState.STOPPING:
			start_distance = total_distance * cooling_length
			end_distance = total_distance

	if end_distance <= start_distance:
		_clear_flow_polygons()
		return

	# --------------------------------------------------
	# Build the visible path
	# --------------------------------------------------

	var active_points := PackedVector2Array()
	var active_widths := PackedFloat32Array()
	var active_distances := PackedFloat32Array()

	var sample_spacing: float = 2.0

	var distance: float = start_distance

	while distance < end_distance:
		var point_data := _get_visual_point_at_distance(
			distances,
			distance
		)

		active_points.append(point_data.position)
		active_widths.append(point_data.width)
		active_distances.append(distance)

		distance += sample_spacing

	# Always include the actual leading edge.
	var end_data := _get_visual_point_at_distance(
		distances,
		end_distance
	)

	if active_points.is_empty():
		active_points.append(end_data.position)
		active_widths.append(end_data.width)
		active_distances.append(end_distance)

	elif active_points[-1].distance_to(
		end_data.position
	) > 0.01:

		active_points.append(end_data.position)
		active_widths.append(end_data.width)
		active_distances.append(end_distance)

	if active_points.size() < 2:
		_clear_flow_polygons()
		return

	# --------------------------------------------------
	# Surface segments
	# --------------------------------------------------

	_ensure_surface_segments(
		active_points.size() - 1
	)

	for i in range(active_points.size() - 1):
		var point_a: Vector2 = active_points[i]
		var point_b: Vector2 = active_points[i + 1]

		var direction := point_b - point_a

		if direction.length_squared() <= 0.000001:
			surface_segments[i].polygon = PackedVector2Array()
			surface_segments[i].visible = false
			continue

		direction = direction.normalized()

		var normal := Vector2(
			-direction.y,
			direction.x
		)

		var half_width_a: float = (
			active_widths[i] * 0.5
		)

		var half_width_b: float = (
			active_widths[i + 1] * 0.5
		)

		var extended_a := (
			point_a -
			direction * SEGMENT_OVERLAP
		)

		var extended_b := (
			point_b +
			direction * SEGMENT_OVERLAP
		)

		var left_a := (
			extended_a +
			normal * half_width_a
		)

		var right_a := (
			extended_a -
			normal * half_width_a
		)

		var left_b := (
			extended_b +
			normal * half_width_b
		)

		var right_b := (
			extended_b -
			normal * half_width_b
		)

		surface_segments[i].polygon = PackedVector2Array([
			left_a,
			left_b,
			right_b,
			right_a
		])

		var uv_a: float = (
			active_distances[i] /
			total_distance
		)

		var uv_b: float = (
			active_distances[i + 1] /
			total_distance
		)

		surface_segments[i].uv = PackedVector2Array([
			Vector2(0.0, uv_a),
			Vector2(0.0, uv_b),
			Vector2(1.0, uv_b),
			Vector2(1.0, uv_a)
		])

		surface_segments[i].visible = true

	# --------------------------------------------------
	# Hide unused segments
	# --------------------------------------------------

	for i in range(
		active_points.size() - 1,
		surface_segments.size()
	):
		surface_segments[i].visible = false
		surface_segments[i].polygon = PackedVector2Array()

	# --------------------------------------------------
	# Corner polygons
	# --------------------------------------------------

	_ensure_surface_corners(
		max(active_points.size() - 2, 0)
	)

	for i in range(active_points.size() - 2):
		var corner: Vector2 = active_points[i + 1]

		var radius: float = (
			active_widths[i + 1] * 0.8
		)

		_create_corner_polygon(
			surface_corners[i],
			corner,
			radius
		)

	for i in range(
		active_points.size() - 2,
		surface_corners.size()
	):
		surface_corners[i].visible = false
		surface_corners[i].polygon = PackedVector2Array()

	# --------------------------------------------------
	# Rim
	# --------------------------------------------------

	var rim_points := PackedVector2Array()

	for point in active_points:
		rim_points.append(point)

	rim.points = rim_points

	const RIM_WIDTH_MULTIPLIER: float = 1.12

	rim.width = (
		active_widths[0] *
		RIM_WIDTH_MULTIPLIER
	)

	rim.default_color = Color(
		1.0,
		0.10,
		0.008,
		0.80
	)

	rim.z_index = -1


func _get_visual_point_at_distance(
	distances: PackedFloat32Array,
	distance: float
) -> Dictionary:

	return {
		"position": _get_point_at_distance(
			distances,
			distance
		),
		"width": _get_width_at_distance(
			distances,
			distance
		)
	}


func _ensure_surface_segments(count: int) -> void:
	while surface_segments.size() < count:
		var polygon := Polygon2D.new()

		polygon.material = surface_material
		polygon.z_index = 0

		surface.add_child(polygon)
		surface_segments.append(polygon)


func _ensure_surface_corners(count: int) -> void:
	while surface_corners.size() < count:
		var polygon := Polygon2D.new()

		polygon.material = surface_material
		polygon.z_index = 0

		surface.add_child(polygon)
		surface_corners.append(polygon)


func _create_corner_polygon(
	polygon: Polygon2D,
	center: Vector2,
	radius: float
) -> void:

	const CORNER_POINTS: int = 8

	var polygon_points := PackedVector2Array()
	var polygon_uv := PackedVector2Array()

	for i in range(CORNER_POINTS):
		var angle: float = (
			float(i) /
			float(CORNER_POINTS)
		) * TAU

		var point := center + Vector2(
			cos(angle),
			sin(angle)
		) * radius

		polygon_points.append(point)

		polygon_uv.append(
			Vector2(
				0.5 + cos(angle) * 0.5,
				0.5 + sin(angle) * 0.5
			)
		)

	polygon.polygon = polygon_points
	polygon.uv = polygon_uv
	polygon.visible = true


func _clear_flow_polygons() -> void:
	for polygon in surface_segments:
		polygon.visible = false
		polygon.polygon = PackedVector2Array()

	for polygon in surface_corners:
		polygon.visible = false
		polygon.polygon = PackedVector2Array()

	rim.points = PackedVector2Array()


func _get_point_at_distance(
	distances: PackedFloat32Array,
	distance: float
) -> Vector2:

	for i in range(distances.size() - 1):
		if distance <= distances[i + 1]:
			var segment_length := (
				distances[i + 1] -
				distances[i]
			)

			if segment_length <= 0.0:
				return points[i]

			var t := (
				distance - distances[i]
			) / segment_length

			return points[i].lerp(
				points[i + 1],
				t
			)

	return points[points.size() - 1]


func _get_width_at_distance(
	distances: PackedFloat32Array,
	distance: float
) -> float:

	for i in range(distances.size() - 1):
		if distance <= distances[i + 1]:
			var segment_length := (
				distances[i + 1] -
				distances[i]
			)

			if segment_length <= 0.0:
				return widths[i]

			var t := (
				distance - distances[i]
			) / segment_length

			return lerp(
				widths[i],
				widths[i + 1],
				t
			)

	return widths[widths.size() - 1]
	

func is_fully_filled() -> bool:
	return flow_state == FlowState.FLOWING
