class_name MatterPileRenderer
extends RefCounted


const MAX_CUBES_PER_PILE: int = 18
const BASE_WIDTH_RATIO: float = 0.011
const CUBE_HEIGHT_RATIO: float = 0.72
const MAX_SATURATED_SCALE_BONUS: float = 0.12
const SATURATION_SCALE_START_MAGNITUDE: float = 9.0
const SCALE_PER_EXTRA_MAGNITUDE: float = 0.02

const TOP_COLOR: Color = Color(0.73, 0.43, 0.95, 1.0)
const LEFT_COLOR: Color = Color(0.39, 0.20, 0.57, 1.0)
const RIGHT_COLOR: Color = Color(0.23, 0.12, 0.36, 1.0)
const OUTLINE_COLOR: Color = Color(0.12, 0.07, 0.19, 1.0)
const GLOW_COLOR: Color = Color(0.48, 0.17, 0.78, 0.075)
const SHADOW_COLOR: Color = Color(0.035, 0.015, 0.06, 0.48)
const RUBBLE_COLOR: Color = Color(0.34, 0.19, 0.48, 0.85)
const RUBBLE_HIGHLIGHT: Color = Color(0.58, 0.32, 0.72, 0.85)

# Each slot is (horizontal offset, vertical layer, front/back depth).
# This is a scatter of fragments rather than a neat stack.
const CUBE_SLOTS: Array[Vector3] = [
	Vector3(-1.35, 0.0, 0.0),
	Vector3(-0.45, 0.0, 0.4),
	Vector3(0.48, 0.0, 0.0),
	Vector3(1.28, 0.0, 0.5),
	Vector3(-1.02, 0.55, 0.7),
	Vector3(0.08, 0.65, 0.0),
	Vector3(0.92, 0.5, 0.7),
	Vector3(-0.62, 1.05, 0.0),
	Vector3(0.48, 1.15, 0.5),
	Vector3(1.45, 0.95, 0.0),
	Vector3(-1.38, 1.0, 0.5),
	Vector3(-0.05, 1.55, 0.2),
	Vector3(0.95, 1.65, 0.0),
	Vector3(-0.92, 1.9, 0.5),
	Vector3(0.28, 2.15, 0.0),
	Vector3(1.18, 2.05, 0.4),
	Vector3(-0.42, 2.55, 0.0),
	Vector3(0.55, 2.85, 0.3)
]


var _last_geometry_width: float = -1.0
var _last_growth_stage: int = -1


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
	_last_growth_stage = -1

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
	var growth_stage: int = _get_growth_stage(matter)
	var geometry_changed: bool = (
		not is_equal_approx(cube_width, _last_geometry_width)
		or growth_stage != _last_growth_stage
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
		_update_ground_visuals(pile, cube_width, geometry_changed, pile_cube_count)

		for cube_index in range(MAX_CUBES_PER_PILE):
			var cube: Node2D = pile.get_node("Cube_%02d" % cube_index) as Node2D
			cube.visible = cube_index < pile_cube_count
			var size_factor: float = _get_fragment_size(cube_index, growth_stage)
			if geometry_changed:
				_update_cube_geometry(cube, cube_width, cube_height, cube_index, pile_index)
			_update_cube_position(
				cube, cube_width, cube_height, cube_index, pile_index, size_factor
			)

	if geometry_changed:
		_last_geometry_width = cube_width
		_last_growth_stage = growth_stage


func _get_total_cube_count(matter: float) -> int:
	if matter <= 0.0:
		return 0
	return clamp(
		int(ceil(log(1.0 + matter) / log(10.0) * 6.0)),
		1,
		MAX_CUBES_PER_PILE * 3
	)


func _get_growth_stage(matter: float) -> int:
	if matter <= 0.0:
		return 0
	return max(0, int(floor(log(1.0 + matter) / log(10.0))))


func _get_fragment_size(cube_index: int, growth_stage: int) -> float:
	# Older fragments grow in stages. New fragments remain tiny, keeping
	# the overall pile varied even at high resource amounts.
	var fragment_group: int = int(cube_index / 3)
	var growth_steps: int = max(0, growth_stage - fragment_group - 1)
	var size_factor: float = 0.48 + float(growth_steps) * 0.23
	var stable_variation: float = float((cube_index * 7) % 4) * 0.035
	return clamp(size_factor + stable_variation, 0.42, 1.75)


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
	geometry_changed: bool,
	cube_count: int
) -> void:
	var glow: Polygon2D = pile.get_node("Glow") as Polygon2D
	var shadow: Polygon2D = pile.get_node("GroundShadow") as Polygon2D
	var growth_alpha: float = clamp(float(cube_count) / 18.0, 0.12, 1.0)
	glow.color = Color(GLOW_COLOR.r, GLOW_COLOR.g, GLOW_COLOR.b, GLOW_COLOR.a * growth_alpha)
	shadow.color = Color(SHADOW_COLOR.r, SHADOW_COLOR.g, SHADOW_COLOR.b, SHADOW_COLOR.a * growth_alpha)
	if not geometry_changed:
		return

	glow.polygon = _ellipse_polygon(Vector2(0.0, width * 0.22), width * 1.95, width * 0.52, 12)
	shadow.polygon = _ellipse_polygon(Vector2(0.0, width * 0.28), width * 1.42, width * 0.34, 10)

	var rubble_positions: Array[Vector2] = [
		Vector2(-1.45, 0.22), Vector2(1.48, 0.28),
		Vector2(-0.88, 0.72), Vector2(0.96, 0.78)
	]
	var rubble_sizes: Array[Vector2] = [
		Vector2(0.16, 0.10), Vector2(0.13, 0.09),
		Vector2(0.12, 0.08), Vector2(0.15, 0.09)
	]
	for rubble_index in range(4):
		var rubble: Polygon2D = pile.get_node("Rubble_%02d" % rubble_index) as Polygon2D
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
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
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
	pile_index: int,
	size_factor: float
) -> void:
	var slot: Vector3 = CUBE_SLOTS[cube_index]
	var variation: float = float((cube_index * 13 + pile_index * 7) % 5)
	var jitter_x: float = (variation - 2.0) * width * 0.025
	var jitter_y: float = float((cube_index + pile_index * 3) % 3 - 1) * height * 0.035
	cube.position = Vector2(
		slot.x * width * 0.46 + jitter_x,
		-slot.y * height * 0.60 + slot.z * height * 0.20 + jitter_y
	)
	cube.scale = Vector2.ONE * size_factor


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
	var outline: float = max(width * 0.085, 0.45)
	var top: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(half_width, quarter_height),
		Vector2(0.0, height), Vector2(-half_width, quarter_height)
	])
	var left: PackedVector2Array = PackedVector2Array([
		Vector2(-half_width, quarter_height), Vector2(0.0, height),
		Vector2(0.0, height + face_depth), Vector2(-half_width, quarter_height + face_depth)
	])
	var right: PackedVector2Array = PackedVector2Array([
		Vector2(half_width, quarter_height), Vector2(0.0, height),
		Vector2(0.0, height + face_depth), Vector2(half_width, quarter_height + face_depth)
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
		expanded.append(point + (point - center).normalized() * outline)
	return expanded
