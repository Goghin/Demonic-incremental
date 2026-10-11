class_name RealmLayoutDragController
extends RefCounted


var dragging_object: String = ""
var drag_offset: Vector2 = Vector2.ZERO


func cancel_drag() -> void:
	dragging_object = ""
	drag_offset = Vector2.ZERO


func handle_mouse_input(
	event: InputEvent,
	owner: Control,
	realm_layout: RealmLayout,
	ash_piles: Array[Sprite2D],
	braziers: Dictionary,
	brazier_stats: Array[String],
	generator_hitboxes: Dictionary,
	island_rect: Rect2,
	ash_amount: float,
	update_ash_piles: Callable,
	request_redraw: Callable,
	debug_controller: RealmLayoutDebugController
) -> void:
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		if event.pressed:
			var mouse_position: Vector2 = owner.get_local_mouse_position()

			if event.shift_pressed:
				debug_controller.print_layout_point(
					mouse_position,
					island_rect
				)
				return

			var drag_result: Dictionary = find_drag_target(
				mouse_position,
				ash_piles,
				braziers,
				brazier_stats,
				generator_hitboxes
			)
			dragging_object = drag_result["object"]
			drag_offset = drag_result["offset"]
		else:
			cancel_drag()

	elif event is InputEventMouseMotion:
		if dragging_object == "":
			return

		update_drag(
			owner.get_local_mouse_position(),
			realm_layout,
			braziers,
			island_rect,
			ash_amount,
			update_ash_piles,
			request_redraw
		)


func find_drag_target(
	mouse_position: Vector2,
	ash_piles: Array[Sprite2D],
	braziers: Dictionary,
	brazier_stats: Array[String],
	generator_hitboxes: Dictionary
) -> Dictionary:
	for i in range(ash_piles.size()):
		var pile: Sprite2D = ash_piles[i]
		var pile_rect: Rect2 = Rect2(
			pile.position - Vector2(16.0, 16.0),
			Vector2(32.0, 32.0)
		)

		if pile_rect.has_point(mouse_position):
			return {
				"object": "ash_pile:" + str(i),
				"offset": mouse_position - pile.position
			}

	for stat_name in brazier_stats:
		if not braziers.has(stat_name):
			continue

		var brazier: Control = braziers[stat_name]
		var brazier_rect: Rect2 = Rect2(
			brazier.position - Vector2(32, 32),
			Vector2(64, 64)
		)

		if brazier_rect.has_point(mouse_position):
			return {
				"object": "brazier:" + stat_name,
				"offset": mouse_position - brazier.position
			}

	for generator_id in generator_hitboxes:
		var hitbox: Rect2 = generator_hitboxes[generator_id]
		if hitbox.has_point(mouse_position):
			var generator_position: Vector2 = (
				hitbox.position +
				hitbox.size * 0.5
			)
			return {
				"object": generator_id,
				"offset": mouse_position - generator_position
			}

	return {
		"object": "",
		"offset": Vector2.ZERO
	}


func update_drag(
	mouse_position: Vector2,
	realm_layout: RealmLayout,
	braziers: Dictionary,
	island_rect: Rect2,
	ash_amount: float,
	update_ash_piles: Callable,
	request_redraw: Callable
) -> void:
	if dragging_object.begins_with("ash_pile:"):
		var pile_index: int = int(dragging_object.substr(9))
		if pile_index >= 0 and pile_index < realm_layout.ash_pile_layout_positions.size():
			var new_position: Vector2 = mouse_position - drag_offset
			var normalized_position: Vector2 = _normalize_position(
				new_position,
				island_rect
			)
			realm_layout.ash_pile_layout_positions[pile_index] = normalized_position
			update_ash_piles.call(ash_amount)
			request_redraw.call()
		return

	if dragging_object.begins_with("brazier:"):
		var stat_name: String = dragging_object.substr(8)
		if braziers.has(stat_name):
			var new_position: Vector2 = mouse_position - drag_offset
			var normalized_position: Vector2 = _normalize_position(
				new_position,
				island_rect
			)
			realm_layout.brazier_layout_positions[stat_name] = normalized_position
			braziers[stat_name].position = (
				island_rect.position +
				island_rect.size * normalized_position
			)
			request_redraw.call()
			return

	if realm_layout.generator_layout_positions.has(dragging_object):
		var new_position: Vector2 = mouse_position - drag_offset
		var normalized_position: Vector2 = _normalize_position(
			new_position,
			island_rect
		)
		realm_layout.generator_layout_positions[dragging_object] = normalized_position
		request_redraw.call()


func _normalize_position(
	position: Vector2,
	island_rect: Rect2
) -> Vector2:
	var geometry_controller: RealmLayoutGeometryController = RealmLayoutGeometryController.new()
	return geometry_controller.get_normalized_position(
		position,
		island_rect
	)
