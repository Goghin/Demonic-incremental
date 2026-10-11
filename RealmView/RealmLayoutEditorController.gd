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
