class_name MatterPileRenderer
extends RefCounted


const MAX_CUBES_PER_PILE: int = 18
const BASE_WIDTH_RATIO: float = 0.018
const CUBE_HEIGHT_RATIO: float = 0.72

const TOP_COLOR: Color = Color(0.73, 0.43, 0.95, 1.0)
const LEFT_COLOR: Color = Color(0.39, 0.20, 0.57, 1.0)
const RIGHT_COLOR: Color = Color(0.23, 0.12, 0.36, 1.0)
const OUTLINE_COLOR: Color = Color(0.12, 0.07, 0.19, 1.0)


func setup(
	view: Control,
	old_piles: Array[Node2D],
	layout: RealmLayout
) -> Array[Node2D]:
	for pile in old_piles:
		if is_instance_valid(pile):
			pile.queue_free()
	old_piles.clear()

	if layout == null:
		return old_piles

	for i in range(layout.matter_pile_layout_positions.size()):
		var pile: Node2D = Node2D.new()
		pile.name = "MatterPile_%02d" % (i + 1)
		pile.z_index = 6
		pile.visible = false
		view.add_child(pile)
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
	var cube_width: float = max(island_rect.size.x * BASE_WIDTH_RATIO, 4.0)
	var cube_height: float = cube_width * CUBE_HEIGHT_RATIO

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

		for cube_index in range(pile.get_child_count()):
			var cube: Node2D = pile.get_child(cube_index) as Node2D
			if cube == null:
				continue
			cube.visible = cube_index < pile_cube_count
			if not cube.visible:
				continue

			var column: int = cube_index % 3
			var row: int = cube_index / 3
			var stagger: float = float((row + pile_index) % 2) * cube_width * 0.12
			cube.position = Vector2(
				(float(column) - 1.0) * cube_width * 0.52 + stagger,
				-float(row) * cube_height * 0.55
			)
			_update_cube_geometry(cube, cube_width, cube_height)


func _get_total_cube_count(matter: float) -> int:
	if matter <= 0.0:
		return 0
	# Each order of magnitude adds roughly six visible cubes, up to the
	# fixed visual budget. This keeps enormous resource values inexpensive.
	return clamp(
		int(ceil(log(1.0 + matter) / log(10.0) * 6.0)),
		1,
		MAX_CUBES_PER_PILE * 3
	)


func _create_cube(_cube_index: int) -> Node2D:
	var cube: Node2D = Node2D.new()
	cube.name = "Cube"
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


func _update_cube_geometry(cube: Node2D, width: float, height: float) -> void:
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
	left_face.color = LEFT_COLOR
	right_face.color = RIGHT_COLOR
	top_face.color = TOP_COLOR


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
