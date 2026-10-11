class_name RealmLayoutGeometryController
extends RefCounted


func get_island_rect(
	view_size: Vector2,
	center_ratio: Vector2,
	base_size: Vector2,
	island_scale: float
) -> Rect2:
	var center: Vector2 = view_size * center_ratio
	var island_size: Vector2 = base_size * island_scale
	return Rect2(
		center - island_size * 0.5,
		island_size
	)


func get_position_from_normalized(
	normalized_position: Vector2,
	island_rect: Rect2
) -> Vector2:
	if island_rect.size.x <= 0.0 or island_rect.size.y <= 0.0:
		return island_rect.position

	return island_rect.position + island_rect.size * normalized_position


func get_normalized_position(
	position: Vector2,
	island_rect: Rect2
) -> Vector2:
	if island_rect.size.x <= 0.0 or island_rect.size.y <= 0.0:
		return Vector2.ZERO

	var normalized_position: Vector2 = (
		position - island_rect.position
	) / island_rect.size
	normalized_position.x = clamp(normalized_position.x, 0.0, 1.0)
	normalized_position.y = clamp(normalized_position.y, 0.0, 1.0)
	return normalized_position


func get_generator_position(
	generator_id: String,
	layout_positions: Dictionary,
	view_size: Vector2,
	island_rect: Rect2
) -> Vector2:
	if not layout_positions.has(generator_id):
		return view_size * 0.5

	return get_position_from_normalized(
		layout_positions[generator_id],
		island_rect
	)
