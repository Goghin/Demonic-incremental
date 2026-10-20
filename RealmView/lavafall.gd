class_name LavaFall
extends Node2D

@onready var surface: Polygon2D = $Surface
@onready var rim: Polygon2D = $Rim

const FLOW_SHADER = preload("res://RealmView/lava_fall.gdshader")
const LAVA_TEXTURE = preload("res://RealmView/lava1.png")



var width: float = 4.0
var length: float = 60.0
var speed: float = 15.0

var progress: float = 0.0
var target_progress: float = 0.0

enum FallState {
	EMPTY,
	FILLING,
	FULL,
	DRAINING
}

var fall_state: FallState = FallState.EMPTY

const ANIMATION_SPEED: float = 0.6

var lava_palette: Dictionary = {}

var _is_front_layer: bool = false
var _front_layers: Array[LavaFall] = []
var _target_filled: bool = false
var _drain_after_fill: bool = false

func set_lava_palette(palette: Dictionary) -> void:
	lava_palette = palette.duplicate(true)
	if surface.material is ShaderMaterial:
		_apply_palette_to_material(surface.material as ShaderMaterial)
	# Falls should have no bright outline; keep the rim geometry hidden
	# so the animated lava surface meets the surrounding rock cleanly.
	rim.color = Color.TRANSPARENT

func _apply_palette_to_material(s_material: ShaderMaterial) -> void:
	for key in ["dark", "red", "orange", "bright", "glow"]:
		if lava_palette.has(key):
			var color: Color = lava_palette[key]
			s_material.set_shader_parameter(key + "_lava", Vector3(color.r, color.g, color.b))

	if lava_palette.has("dark"):
		var dark_color: Color = lava_palette["dark"]
		s_material.set_shader_parameter(
			"dark_blob_lava",
			Vector3(dark_color.r * 0.25, dark_color.g * 0.25, dark_color.b * 0.25)
		)

	if lava_palette.has("bright"):
		var bright_color: Color = lava_palette["bright"]
		s_material.set_shader_parameter(
			"bright_blob_lava",
			Vector3(
				minf(bright_color.r * 1.15, 1.2),
				minf(bright_color.g * 1.15, 1.0),
				minf(bright_color.b * 1.15, 1.0)
			)
		)


func setup(
	fall_width: float = 4.0,
	fall_length: float = 60.0,
	fall_speed: float = 15.0
) -> void:
	width = fall_width
	length = fall_length
	speed = fall_speed
	if not _is_front_layer:
		for layer in _front_layers:
			layer.queue_free()
		_front_layers.clear()
		_target_filled = false
	progress = 0.0
	target_progress = 0.0
	fall_state = FallState.EMPTY
	_drain_after_fill = false
	_setup_material()
	_update_polygon()


func _setup_material() -> void:
	var s_material := ShaderMaterial.new()

	s_material.shader = FLOW_SHADER

	s_material.set_shader_parameter(
		"lava_texture",
		LAVA_TEXTURE
	)

	s_material.set_shader_parameter(
		"flow_speed",
		speed
	)

	surface.material = s_material
	if not lava_palette.is_empty():
		_apply_palette_to_material(s_material)


func set_filled(filled: bool) -> void:
	if not _is_front_layer:
		if filled == _target_filled:
			return
		_target_filled = filled
		if filled:
			var layer := LavaFall.new()
			layer._is_front_layer = true
			layer.width = width
			layer.length = length
			layer.speed = speed
			layer.lava_palette = lava_palette.duplicate(true)
			var layer_surface := Polygon2D.new()
			layer_surface.name = "Surface"
			layer.add_child(layer_surface)
			var layer_rim := Polygon2D.new()
			layer_rim.name = "Rim"
			layer.add_child(layer_rim)
			add_child(layer)
			layer.setup(width, length, speed)
			if not lava_palette.is_empty():
				layer.set_lava_palette(lava_palette)
			_front_layers.append(layer)
			layer.set_filled(true)
		else:
			for layer in _front_layers:
				layer.set_filled(false)
		fall_state = FallState.FILLING if filled else FallState.DRAINING
		set_process(not _front_layers.is_empty())
		return

	if filled:
		if fall_state == FallState.FULL or fall_state == FallState.FILLING:
			return
		_drain_after_fill = false
		if fall_state == FallState.EMPTY:
			progress = 0.0
		fall_state = FallState.FILLING
		target_progress = 1.0
		set_process(true)
	else:
		if fall_state == FallState.EMPTY or fall_state == FallState.DRAINING:
			return
		if fall_state == FallState.FILLING:
			_drain_after_fill = true
			return
		_start_draining()


func _start_draining() -> void:
	progress = 0.0
	target_progress = 1.0
	fall_state = FallState.DRAINING
	_drain_after_fill = false
	_update_surface()
	set_process(true)


func _process(delta: float) -> void:
	if not _is_front_layer:
		for i in range(_front_layers.size() - 1, -1, -1):
			var layer := _front_layers[i]
			if not is_instance_valid(layer) or layer.fall_state == FallState.EMPTY:
				if is_instance_valid(layer):
					layer.queue_free()
				_front_layers.remove_at(i)
		if _front_layers.is_empty():
			fall_state = FallState.EMPTY
			set_process(false)
		else:
			var has_filling := false
			var has_full := false
			var has_draining := false
			for layer in _front_layers:
				has_filling = has_filling or layer.fall_state == FallState.FILLING
				has_full = has_full or layer.fall_state == FallState.FULL
				has_draining = has_draining or layer.fall_state == FallState.DRAINING
			if has_filling:
				fall_state = FallState.FILLING
			elif has_full:
				fall_state = FallState.FULL
			elif has_draining:
				fall_state = FallState.DRAINING
		return

	if fall_state == FallState.FULL or fall_state == FallState.EMPTY:
		set_process(false)
		return
	progress = move_toward(progress, target_progress, delta * ANIMATION_SPEED)
	_update_surface()
	if fall_state == FallState.FILLING and progress >= 1.0:
		progress = 1.0
		fall_state = FallState.FULL
		_update_surface()
		if _drain_after_fill:
			_start_draining()
		else:
			set_process(false)
	elif fall_state == FallState.DRAINING and progress >= 1.0:
		progress = 1.0
		fall_state = FallState.EMPTY
		_update_surface()
		set_process(false)

func _update_polygon() -> void:
	_update_surface()



func _update_surface() -> void:
	if fall_state == FallState.EMPTY:
		surface.polygon = PackedVector2Array()
		rim.polygon = PackedVector2Array()
		return

	if fall_state == FallState.FULL:
		_build_full_surface()
		return

	var points := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(0.0, length * 0.18),
		Vector2(0.0, length * 0.42),
		Vector2(0.0, length * 0.68),
		Vector2(0.0, length)
	])

	var width_factors := PackedFloat32Array([
		1.0,
		0.92,
		0.82,
		0.58,
		0.25
	])

	var edge_y: float = length * progress

	var edge_width_factor: float = _get_width_factor(
		points,
		width_factors,
		edge_y
	)

	var edge_half_width: float = width * edge_width_factor * 0.5

	var left := PackedVector2Array()
	var right := PackedVector2Array()

	if fall_state == FallState.FILLING:
		# Filling reveals lava from the top down to the moving leading edge.
		left.append(Vector2(-width * 0.5, 0.0))
		right.append(Vector2(width * 0.5, 0.0))

		for i in range(1, points.size()):
			if points[i].y < edge_y:
				var half_width := width * width_factors[i] * 0.5
				left.append(Vector2(-half_width, points[i].y))
				right.append(Vector2(half_width, points[i].y))

		left.append(Vector2(-edge_half_width, edge_y))
		right.append(Vector2(edge_half_width, edge_y))
	else:
		# Draining removes lava from the top down. The section below the
		# moving trailing edge remains visible until the edge reaches the bottom.
		left.append(Vector2(-edge_half_width, edge_y))
		right.append(Vector2(edge_half_width, edge_y))

		for i in range(1, points.size()):
			if points[i].y > edge_y:
				var half_width := width * width_factors[i] * 0.5
				left.append(Vector2(-half_width, points[i].y))
				right.append(Vector2(half_width, points[i].y))

		if edge_y < length:
			var bottom_half_width: float = width * width_factors[width_factors.size() - 1] * 0.5
			left.append(Vector2(-bottom_half_width, length))
			right.append(Vector2(bottom_half_width, length))

	_set_surface_polygon(left, right)

func _get_width_factor(
	points: PackedVector2Array,
	width_factors: PackedFloat32Array,
	y: float
) -> float:
	for i in range(points.size() - 1):
		if y <= points[i + 1].y:
			var segment_length := (
				points[i + 1].y -
				points[i].y
			)

			if segment_length <= 0.0:
				return width_factors[i]

			var t := (
				y -
				points[i].y
			) / segment_length

			return lerp(
				width_factors[i],
				width_factors[i + 1],
				t
			)

	return width_factors[
		width_factors.size() - 1
	]


func _set_surface_polygon(
	left: PackedVector2Array,
	right: PackedVector2Array
) -> void:
	# --------------------------------------------------------
	# Surface
	# --------------------------------------------------------

	var surface_polygon := PackedVector2Array()

	for point in left:
		surface_polygon.append(point)

	for i in range(
		right.size() - 1,
		-1,
		-1
	):
		surface_polygon.append(
			right[i]
		)

	surface.polygon = surface_polygon

	# --------------------------------------------------------
	# Rim
	#
	# Use the same geometry, but expand it slightly.
	# This guarantees that the rim follows the lava surface.
	# --------------------------------------------------------

	const RIM_WIDTH_MULTIPLIER: float = 1.12

	var rim_left := PackedVector2Array()
	var rim_right := PackedVector2Array()

	for i in range(left.size()):
		var left_point: Vector2 = left[i]
		var right_point: Vector2 = right[i]

		var center_x: float = (
			left_point.x +
			right_point.x
		) * 0.5

		var half_width: float = (
			right_point.x -
			left_point.x
		) * 0.5

		var rim_half_width: float = (
			half_width *
			RIM_WIDTH_MULTIPLIER
		)

		rim_left.append(
			Vector2(
				center_x - rim_half_width,
				left_point.y
			)
		)

		rim_right.append(
			Vector2(
				center_x + rim_half_width,
				right_point.y
			)
		)

	var rim_polygon := PackedVector2Array()

	for point in rim_left:
		rim_polygon.append(point)

	for i in range(
		rim_right.size() - 1,
		-1,
		-1
	):
		rim_polygon.append(
			rim_right[i]
		)

	rim.polygon = rim_polygon
	rim.color = Color.TRANSPARENT
func _build_full_surface() -> void:
	var points := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(0.0, length * 0.18),
		Vector2(0.0, length * 0.42),
		Vector2(0.0, length * 0.68),
		Vector2(0.0, length)
	])

	var width_factors := PackedFloat32Array([
		1.0,
		0.92,
		0.82,
		0.58,
		0.25
	])

	var left := PackedVector2Array()
	var right := PackedVector2Array()

	for i in range(points.size()):
		var half_width := (
			width *
			width_factors[i] *
			0.5
		)

		left.append(
			points[i] +
			Vector2(-half_width, 0.0)
		)

		right.append(
			points[i] +
			Vector2(half_width, 0.0)
		)

	_set_surface_polygon(
		left,
		right
	)
