class_name RealmLayoutEditorController
extends RefCounted


func find_drag_target(
	mouse_position: Vector2,
	ash_piles: Array[Sprite2D],
	braziers: Dictionary,
	brazier_stats: Array[String],
	generator_hitboxes: Dictionary,
	current_dragging_object: String,
	current_drag_offset: Vector2
) -> Dictionary:
	var result: Dictionary = {
		"object": current_dragging_object,
		"offset": current_drag_offset
	}

	# ------------------------------------------------------------
	# Ash piles
	# ------------------------------------------------------------

	for i in range(ash_piles.size()):
		var pile: Sprite2D = ash_piles[i]
		var pile_rect: Rect2 = Rect2(
			pile.position - Vector2(16.0, 16.0),
			Vector2(32.0, 32.0)
		)

		if pile_rect.has_point(mouse_position):
			result["object"] = "ash_pile:" + str(i)
			result["offset"] = mouse_position - pile.position
			return result

	# ------------------------------------------------------------
	# Braziers
	# ------------------------------------------------------------

	for stat_name in brazier_stats:
		if not braziers.has(stat_name):
			continue

		var brazier: Control = braziers[stat_name]

		var brazier_rect: Rect2 = Rect2(
			brazier.position - Vector2(32, 32),
			Vector2(64, 64)
		)

		if brazier_rect.has_point(mouse_position):
			result["object"] = "brazier:" + stat_name
			result["offset"] = (
				mouse_position -
				brazier.position
			)
			return result

	# ------------------------------------------------------------
	# Generators
	# ------------------------------------------------------------

	for generator_id in generator_hitboxes:
		var hitbox: Rect2 = generator_hitboxes[
			generator_id
		]

		if hitbox.has_point(mouse_position):
			result["object"] = generator_id

			var generator_position: Vector2 = (
				hitbox.position +
				hitbox.size * 0.5
			)

			result["offset"] = (
				mouse_position -
				generator_position
			)

			return result

	return result


func update_drag(
	mouse_position: Vector2,
	dragging_object: String,
	drag_offset: Vector2,
	realm_layout: Resource,
	braziers: Dictionary,
	island_rect: Rect2,
	ash_amount: float,
	update_ash_piles: Callable,
	request_redraw: Callable
) -> void:
	# ------------------------------------------------------------
	# Ash pile
	# ------------------------------------------------------------

	if dragging_object.begins_with("ash_pile:"):
		var pile_index: int = int(dragging_object.substr(9))
		if pile_index >= 0 and pile_index < realm_layout.ash_pile_layout_positions.size():
			var new_position: Vector2 = mouse_position - drag_offset
			var normalized_position: Vector2 = (
				(new_position - island_rect.position) /
				island_rect.size
			)
			normalized_position.x = clamp(normalized_position.x, 0.0, 1.0)
			normalized_position.y = clamp(normalized_position.y, 0.0, 1.0)
			realm_layout.ash_pile_layout_positions[pile_index] = normalized_position
			update_ash_piles.call(ash_amount)
			request_redraw.call()
		return

	# ------------------------------------------------------------
	# Brazier
	# ------------------------------------------------------------

	if dragging_object.begins_with("brazier:"):
		var stat_name: String = dragging_object.substr(8)
		if braziers.has(stat_name):
			var new_position: Vector2 = mouse_position - drag_offset
			var normalized_position: Vector2 = (
				(new_position - island_rect.position) /
				island_rect.size
			)
			normalized_position.x = clamp(normalized_position.x, 0.0, 1.0)
			normalized_position.y = clamp(normalized_position.y, 0.0, 1.0)
			realm_layout.brazier_layout_positions[stat_name] = normalized_position
			braziers[stat_name].position = (
				island_rect.position +
				island_rect.size * normalized_position
			)
			request_redraw.call()
			return

	# ------------------------------------------------------------
	# Generator
	# ------------------------------------------------------------

	if realm_layout.generator_layout_positions.has(dragging_object):
		var new_position: Vector2 = mouse_position - drag_offset
		var normalized_position: Vector2 = (
			(new_position - island_rect.position) /
			island_rect.size
		)
		normalized_position.x = clamp(normalized_position.x, 0.0, 1.0)
		normalized_position.y = clamp(normalized_position.y, 0.0, 1.0)
		realm_layout.generator_layout_positions[dragging_object] = normalized_position
		request_redraw.call()
