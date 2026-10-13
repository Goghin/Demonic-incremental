class_name MatterPileRenderer
extends RefCounted


const MAX_CUBES_PER_PILE: int = 18
const BASE_WIDTH_RATIO: float = 0.018
const CUBE_HEIGHT_RATIO: float = 0.72
const MAX_SATURATED_SCALE_BONUS: float = 0.18
const SATURATION_SCALE_START_MAGNITUDE: float = 9.0
const SCALE_PER_EXTRA_MAGNITUDE: float = 0.025

const TOP_COLOR: Color = Color(0.73, 0.43, 0.95, 1.0)
const LEFT_COLOR: Color = Color(0.39, 0.20, 0.57, 1.0)
const RIGHT_COLOR: Color = Color(0.23, 0.12, 0.36, 1.0)
const OUTLINE_COLOR: Color = Color(0.12, 0.07, 0.19, 1.0)
const GLOW_COLOR: Color = Color(0.48, 0.17, 0.78, 0.10)
const SHADOW_COLOR: Color = Color(0.035, 0.015, 0.06, 0.58)
const RUBBLE_COLOR: Color = Color(0.34, 0.19, 0.48, 0.95)
const RUBBLE_HIGHLIGHT: Color = Color(0.58, 0.32, 0.72, 0.95)

# Each slot is (horizontal offset, stack layer, front/back depth).
# The base is broad and irregular; each higher layer narrows into a heap.
const CUBE_SLOTS: Array[Vector3] = [
	Vector3(-1.0, 0.0, 0.0),
	Vector3(0.0, 0.0, 0.0),
	Vector3(1.0, 0.0, 0.0),
	Vector3(-0.62, 0.0, 1.0),
	Vector3(0.38, 0.0, 1.0),
	Vector3(1.25, 0.0, 1.0),
	Vector3(-0.55, 1.0, 0.0),
	Vector3(0.48, 1.0, 0.0),
	Vector3(-0.28, 1.0, 1.0),
	Vector3(0.72, 1.0, 1.0),
	Vector3(-0.75, 2.0, 0.35),
	Vector3(0.25, 2.0, 0.0),
	Vector3(0.92, 2.0, 0.55),
	Vector3(-0.48, 3.0, 0.0),
	Vector3(0.52, 3.0, 0.45),
	Vector3(-0.24, 4.0, 0.2),
	Vector3(0.55, 4.0, 0.0),
	Vector3(0.12, 5.0, 0.15)
]


var _last_geometry_width: float = -1.0


func setup(
	view: Control,
	old_piles: Array[Node2D],
	layout: RealmLayout
) -> Array[Node2D]:
	for pile in old_piles:
		if is_instance_valid(pile):
			pile.queue_free()
	old_piles.clear()
	_last_geometry_width = -1.0

	if layout == null:
		return old_piles

	for i in range(layout.matter_pile_layout_positions.size()):
		var pile: Node2D = Node2D.new()
		pile.name = "MatterPile_%02d" % (i + 1)
		pile.z_index = 6
		pile.visible = false
		view.add_child(pile)

		_create_ground_visuals(pile)
		for cube_index in range(MAX_CUBES_PER_PILE):
			pile.add_child(_create_cube(cube_index))

		old_piles.append(pile)

	return old_piles


func update(
	piles: Array[Node2D],
	layout_positions: PackedVector2Array,
	island_rect: Rect2,
	matter: float
) -> void:
	if piles.is_empty() or layout_positions.is_empty():
		for pile in piles:
			if is_instance_valid(pile):
				pile.visible = false
		return

	var total_cubes: int = _get_total_cube_count(matter)
	var magnitude_scale: float = _get_magnitude_scale(matter)
	var cube_width: float = max(island_rect.size.x * BASE_WIDTH_RATIO, 4.0)
	cube_width *= magnitude_scale
	var cube_height: float = cube_width * CUBE_HEIGHT_RATIO
	var geometry_changed: bool = not is_equal_approx(
		cube_width,
		_last_geometry_width
	)

	for pile_index in range(piles.size()):
		var pile: Node2D = piles[pile_index]
		if not is_instance_valid(pile):
			continue
		if pile_index >= layout_positions.size():
			pile.visible = false
			continue

		var normalized_position: Vector2 = layout_positions[pile_index]
		pile.position = island_rect.position + Vector2(
			island_rect.size.x * normalized_position.x,
			island_rect.size.y * normalized_position.y
		)

		var pile_cube_count: int = clamp(
			int(ceil(float(total_cubes - pile_index) / float(piles.size()))),
			0,
			MAX_CUBES_PER_PILE
		)
		pile.visible = pile_cube_count > 0

		_update_ground_visuals(pile, cube_width, geometry_changed)

		for cube_index in range(MAX_CUBES_PER_PILE):
			var cube: Node2D = pile.get_node("Cube_%02d" % cube_index) as Node2D
			cube.visible = cube_index < pile_cube_count
			if geometry_changed:
				_update_cube_geometry(
					cube,
					cube_width,
					cube_height,
					cube_index,
					pile_index
				)
			_update_cube_position(
				cube,
				cube_width,
				cube_height,
				cube_index,
				pile_index
			)

	if geometry_changed:
		_last_geometry_width = cube_width


func _get_total_cube_count(matter: float) -> int:
	if matter <= 0.0:
		return 0
	# Each order of magnitude adds roughly six visible cubes, up to 54.
	# Once full, the heap grows slightly instead of becoming visually static.
	return clamp(
		int(ceil(log(1.0 + matter) / log(10.0) * 6.0)),
		1,
		MAX_CUBES_PER_PILE * 3
	)


func _get_magnitude_scale(matter: float) -> float:
	if matter <= 0.0:
		return 1.0
	var magnitude: float = log(matter) / log(10.0)
	var bonus: float = clamp(
		(magnitude - SATURATION_SCALE_START_MAGNITUDE)
		* SCALE_PER_EXTRA_MAGNITUDE,
		0.0,
		MAX_SATURATED_SCALE_BONUS
	)
	return 1.0 + bonus


func _create_ground_visuals(pile: Node2D) -> void:
	var glow: Polygon2D = Polygon2D.new()
	glow.name = "Glow"
	glow.color = GLOW_COLOR
	glow.antialiased = false
	pile.add_child(glow)

	var shadow: Polygon2D = Polygon2D.new()
	shadow.name = "GroundShadow"
	shadow.color = SHADOW_COLOR
	shadow.antialiased = false
	pile.add_child(shadow)

	for rubble_index in range(4):
		var rubble: Polygon2D = Polygon2D.new()
		rubble.name = "Rubble_%02d" % rubble_index
		rubble.antialiased = false
		rubble.color = RUBBLE_HIGHLIGHT if rubble_index % 2 == 0 else RUBBLE_COLOR
		pile.add_child(rubble)


func _update_ground_visuals(
	pile: Node2D,
	width: float,
	geometry_changed: bool
) -> void:
	if not geometry_changed:
		return

	var glow: Polygon2D = pile.get_node("Glow") as Polygon2D
	glow.polygon = _ellipse_polygon(
		Vector2(0.0, width * 0.20),
		width * 2.55,
		width * 0.78,
		12
	)

	var shadow: Polygon2D = pile.get_node("GroundShadow") as Polygon2D
	shadow.polygon = _ellipse_polygon(
		Vector2(0.0, width * 0.28),
		width * 1.95,
		width * 0.48,
		10
	)

	var rubble_positions: Array[Vector2] = [
		Vector2(-1.05, 0.15),
		Vector2(1.18, 0.25),
		Vector2(-0.65, 0.62),
		Vector2(0.78, 0.68)
	]
	var rubble_sizes: Array[Vector2] = [
		Vector2(0.25, 0.15),
		Vector2(0.20, 0.13),
		Vector2(0.16, 0.11),
		Vector2(0.22, 0.14)
	]
	for rubble_index in range(4):
		var rubble: Polygon2D = pile.get_node(
			"Rubble_%02d" % rubble_index
		) as Polygon2D
		var center: Vector2 = rubble_positions[rubble_index] * width
		var half_size: Vector2 = rubble_sizes[rubble_index] * width
		rubble.polygon = PackedVector2Array([
			center + Vector2(-half_size.x, 0.0),
			center + Vector2(0.0, -half_size.y),
			center + Vector2(half_size.x, half_size.y * 0.25),
			center + Vector2(half_size.x * 0.45, half_size.y),
			center + Vector2(-half_size.x * 0.45, half_size.y * 0.7)
		])


func _ellipse_polygon(
	center: Vector2,
	radius_x: float,
	radius_y: float,
	segments: int
) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		points.append(center + Vector2(
			cos(angle) * radius_x,
			sin(angle) * radius_y
		))
	return points


func _create_cube(cube_index: int) -> Node2D:
	var cube: Node2D = Node2D.new()
	cube.name = "Cube_%02d" % cube_index
	for face_name in [
		"LeftOutline", "RightOutline", "TopOutline",
		"LeftFace", "RightFace", "TopFace"
	]:
		var face: Polygon2D = Polygon2D.new()
		face.name = face_name
		face.antialiased = false
		face.color = OUTLINE_COLOR
		cube.add_child(face)
	return cube


func _update_cube_position(
	cube: Node2D,
	width: float,
	height: float,
	cube_index: int,
	pile_index: int
) -> void:
	var slot: Vector3 = CUBE_SLOTS[cube_index]
	var variation: float = float((cube_index * 13 + pile_index * 7) % 5)
	var jitter_x: float = (variation - 2.0) * width * 0.035
	var jitter_y: float = float((cube_index + pile_index * 3) % 3 - 1) * height * 0.045
	cube.position = Vector2(
		slot.x * width * 0.52 + jitter_x,
		-slot.y * height * 0.84 + slot.z * height * 0.28 + jitter_y
	)
	var size_variant: float = 0.88 + float(
		(cube_index * 11 + pile_index * 3) % 5
	) * 0.035
	cube.scale = Vector2.ONE * size_variant


func _update_cube_geometry(
	cube: Node2D,
	width: float,
	height: float,
	cube_index: int,
	pile_index: int
) -> void:
	var half_width: float = width * 0.5
	var quarter_height: float = height * 0.5
	var face_depth: float = height * 0.68
	var outline: float = max(width * 0.09, 0.6)

	var top: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(half_width, quarter_height),
		Vector2(0.0, height),
		Vector2(-half_width, quarter_height)
	])
	var left: PackedVector2Array = PackedVector2Array([
		Vector2(-half_width, quarter_height),
		Vector2(0.0, height),
		Vector2(0.0, height + face_depth),
		Vector2(-half_width, quarter_height + face_depth)
	])
	var right: PackedVector2Array = PackedVector2Array([
		Vector2(half_width, quarter_height),
		Vector2(0.0, height),
		Vector2(0.0, height + face_depth),
		Vector2(half_width, quarter_height + face_depth)
	])

	var left_outline: Polygon2D = cube.get_node("LeftOutline") as Polygon2D
	var right_outline: Polygon2D = cube.get_node("RightOutline") as Polygon2D
	var top_outline: Polygon2D = cube.get_node("TopOutline") as Polygon2D
	var left_face: Polygon2D = cube.get_node("LeftFace") as Polygon2D
	var right_face: Polygon2D = cube.get_node("RightFace") as Polygon2D
	var top_face: Polygon2D = cube.get_node("TopFace") as Polygon2D

	left_outline.polygon = _outline_polygon(left, outline)
	right_outline.polygon = _outline_polygon(right, outline)
	top_outline.polygon = _outline_polygon(top, outline)
	left_outline.color = OUTLINE_COLOR
	right_outline.color = OUTLINE_COLOR
	top_outline.color = OUTLINE_COLOR

	left_face.polygon = left
	right_face.polygon = right
	top_face.polygon = top
	left_face.color = LEFT_COLOR.darkened(float((cube_index + pile_index) % 3) * 0.035)
	right_face.color = RIGHT_COLOR.lightened(float((cube_index * 2 + pile_index) % 3) * 0.025)
	top_face.color = TOP_COLOR.darkened(float((cube_index * 3 + pile_index) % 5) * 0.025)


func _outline_polygon(points: PackedVector2Array, outline: float) -> PackedVector2Array:
	var expanded: PackedVector2Array = PackedVector2Array()
	var center: Vector2 = Vector2.ZERO
	for point in points:
		center += point
	center /= float(points.size())
	for point in points:
		var direction: Vector2 = (point - center).normalized()
		expanded.append(point + direction * outline)
	return expanded
