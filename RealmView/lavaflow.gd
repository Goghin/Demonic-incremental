class_name LavaFlow
extends Node2D


class LavaFlowSparkOverlay extends Node2D:
	var flow_points: PackedVector2Array = PackedVector2Array()
	var flow_widths: PackedFloat32Array = PackedFloat32Array()
	var burst_timer: float = 0.25
	var activity_factor: float = 1.0
	var randomizer: RandomNumberGenerator = RandomNumberGenerator.new()
	var particles: Array[Dictionary] = []

	func _ready() -> void:
		randomizer.randomize()

	func set_flow_shape(new_points: PackedVector2Array, new_widths: PackedFloat32Array) -> void:
		flow_points = new_points
		flow_widths = new_widths
		var total_length: float = 0.0
		for i in range(1, flow_points.size()):
			total_length += flow_points[i].distance_to(flow_points[i - 1])
		activity_factor = clamp(total_length / 180.0, 0.15, 1.0)

	func _process(delta: float) -> void:
		if flow_points.size() < 2 or flow_widths.size() != flow_points.size():
			return

		burst_timer -= delta
		if burst_timer <= 0.0:
			_spawn_burst()
			burst_timer = randomizer.randf_range(0.55, 1.05) / activity_factor

		for i in range(particles.size() - 1, -1, -1):
			var particle: Dictionary = particles[i]
			var node: Node2D = particle["node"]
			var life: float = float(particle["life"]) - delta
			var velocity: Vector2 = particle["velocity"]
			velocity += Vector2(0.0, -8.0) * delta
			velocity = velocity.move_toward(Vector2.ZERO, 5.0 * delta)
			node.position += velocity * delta
			node.rotation = velocity.angle() + PI * 0.5

			if life <= 0.0:
				node.queue_free()
				particles.remove_at(i)
			else:
				particle["life"] = life
				particle["velocity"] = velocity
				var ratio: float = clamp(life / float(particle["max_life"]), 0.0, 1.0)
				node.modulate.a = ratio
				node.scale = Vector2(lerp(0.45, 1.0, ratio), lerp(0.85, 1.15, ratio))
				particles[i] = particle

	func _spawn_burst() -> void:
		var distance_segments := PackedFloat32Array([0.0])
		var total_length: float = 0.0
		for i in range(1, flow_points.size()):
			total_length += flow_points[i].distance_to(flow_points[i - 1])
			distance_segments.append(total_length)
		if total_length <= 0.0:
			return

		# Pick a burst location only where the interpolated flow width is visible.
		var target_distance: float = 0.0
		var segment_index: int = 0
		var ratio: float = 0.0
		var origin: Vector2 = Vector2.ZERO
		var width: float = 0.0
		var found_valid_location: bool = false

		for attempt in range(20):
			target_distance = randomizer.randf() * total_length
			segment_index = 0
			while segment_index < distance_segments.size() - 2 and target_distance > distance_segments[segment_index + 1]:
				segment_index += 1
			var segment_length: float = distance_segments[segment_index + 1] - distance_segments[segment_index]
			ratio = 0.0 if segment_length <= 0.0 else (target_distance - distance_segments[segment_index]) / segment_length
			width = lerp(flow_widths[segment_index], flow_widths[segment_index + 1], ratio)
			if width > 0.1:
				origin = flow_points[segment_index].lerp(flow_points[segment_index + 1], ratio)
				found_valid_location = true
				break

		if not found_valid_location:
			return

		origin += Vector2(randomizer.randf_range(-0.25, 0.25) * width, randomizer.randf_range(-0.2, 0.2) * width)

		var count: int = maxi(1, roundi(randomizer.randi_range(3, 5) * activity_factor))
		for j in range(count):
			var spread_distance: float = randomizer.randf_range(-14.0, 14.0)
			var particle_distance: float = clamp(target_distance + spread_distance, 0.0, total_length)
			var particle_segment: int = 0
			while particle_segment < distance_segments.size() - 2 and particle_distance > distance_segments[particle_segment + 1]:
				particle_segment += 1
			var particle_segment_length: float = distance_segments[particle_segment + 1] - distance_segments[particle_segment]
			var particle_ratio: float = 0.0 if particle_segment_length <= 0.0 else (particle_distance - distance_segments[particle_segment]) / particle_segment_length
			var particle_width: float = lerp(flow_widths[particle_segment], flow_widths[particle_segment + 1], particle_ratio)

			# The spread can cross into a hidden/zero-width section, so reject it.
			if particle_width <= 0.1:
				continue

			var particle_origin: Vector2 = flow_points[particle_segment].lerp(flow_points[particle_segment + 1], particle_ratio)
			particle_origin += Vector2(randomizer.randf_range(-0.35, 0.35) * particle_width, randomizer.randf_range(-0.25, 0.25) * particle_width)
			var node := Node2D.new()
			node.name = "LavaFlowSpark"
			node.position = particle_origin
			node.z_index = 2
			add_child(node)

			var size: float = randomizer.randf_range(1.9, 3.1)
			var outer := Polygon2D.new()
			outer.polygon = _make_spark(size, randomizer.randf_range(0.7, 1.2))
			outer.color = Color(0.72, 0.045, 0.008, 0.9)
			node.add_child(outer)

			var core := Polygon2D.new()
			core.polygon = _make_spark(size * 0.42, 0.45)
			core.color = Color(1.0, 0.24, 0.035, 0.92)
			node.add_child(core)

			var angle: float = randomizer.randf_range(-PI * 0.85, -PI * 0.15)
			var speed: float = randomizer.randf_range(14.0, 32.0)
			var life: float = randomizer.randf_range(0.5, 0.95)
			particles.append({
				"node": node,
				"velocity": Vector2(cos(angle), sin(angle)) * speed,
				"life": life,
				"max_life": life
			})
	func _make_spark(length: float, width: float) -> PackedVector2Array:
		return PackedVector2Array([
			Vector2(0.0, -length),
			Vector2(width, 0.0),
			Vector2(0.0, length * 0.45),
			Vector2(-width, 0.0)
		])


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
var spark_overlay: LavaFlowSparkOverlay


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
	_ensure_spark_overlay()


func _ensure_spark_overlay() -> void:
	if is_instance_valid(spark_overlay):
		return
	spark_overlay = LavaFlowSparkOverlay.new()
	spark_overlay.name = "LavaFlowSparkOverlay"
	spark_overlay.z_index = 3
	add_child(spark_overlay)


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
		if is_instance_valid(spark_overlay):
			spark_overlay.set_flow_shape(PackedVector2Array(), PackedFloat32Array())
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
		if is_instance_valid(spark_overlay):
			spark_overlay.set_flow_shape(PackedVector2Array(), PackedFloat32Array())
		return

	_ensure_spark_overlay()
	spark_overlay.set_flow_shape(active_points, active_widths)

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
