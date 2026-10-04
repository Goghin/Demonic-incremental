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


func setup(
	fall_width: float = 4.0,
	fall_length: float = 60.0,
	fall_speed: float = 15.0
) -> void:
	width = fall_width
	length = fall_length
	speed = fall_speed

	progress = 0.0
	target_progress = 0.0
	fall_state = FallState.EMPTY

	_setup_material()
	_update_polygon()


func _setup_material() -> void:
	var material := ShaderMaterial.new()

	material.shader = FLOW_SHADER

	material.set_shader_parameter(
		"lava_texture",
		LAVA_TEXTURE
	)

	material.set_shader_parameter(
		"flow_speed",
		speed
	)

	surface.material = material


func set_filled(filled: bool) -> void:
	if filled:
		if fall_state == FallState.FULL:
			return

		# Never interrupt a draining waterfall.
		if fall_state == FallState.DRAINING:
			return

		if fall_state == FallState.FILLING:
			return

		if fall_state == FallState.EMPTY:
			progress = 0.0

		fall_state = FallState.FILLING
		target_progress = 1.0
		set_process(true)

	else:
		if fall_state == FallState.EMPTY:
			return

		if fall_state == FallState.DRAINING:
			return

		progress = 0.0
		fall_state = FallState.DRAINING
		target_progress = 1.0
		set_process(true)

func _process(delta: float) -> void:
	if fall_state == FallState.FULL:
		set_process(false)
		return

	if fall_state == FallState.EMPTY:
		set_process(false)
		return

	progress = move_toward(
		progress,
		target_progress,
		delta * ANIMATION_SPEED
	)

	_update_surface()

	if progress >= 1.0:
		progress = 1.0

		if fall_state == FallState.FILLING:
			fall_state = FallState.FULL

		elif fall_state == FallState.DRAINING:
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
		left.append(Vector2(-edge_half_width, edge_y))
		right.append(Vector2(edge_half_width, edge_y))

		for i in range(1, points.size()):
			if points[i].y > edge_y:
				var half_width := width * width_factors[i] * 0.5
				left.append(Vector2(-half_width, points[i].y))
				right.append(Vector2(half_width, points[i].y))

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
	rim.color = Color(
		1.0,
		0.08,
		0.005,
		0.75
	)
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
