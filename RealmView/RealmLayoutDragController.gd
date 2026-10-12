class_name RealmLayoutDragController
extends RefCounted


var geometry_controller: RealmLayoutGeometryController = RealmLayoutGeometryController.new()


var dragging_object: String = ""
var drag_offset: Vector2 = Vector2.ZERO


func cancel_drag() -> void:
	dragging_object = ""
	drag_offset = Vector2.ZERO


func handle_mouse_input(event: InputEvent, owner: RealmView) -> void:
	var island_rect: Rect2 = owner._get_island_rect()

	if event is InputEventMouseButton or event is InputEventMouseMotion:
		if island_rect.size.x <= 0.0 or island_rect.size.y <= 0.0:
			cancel_drag()
			return

	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		if event.pressed:
			var mouse_position: Vector2 = owner.get_local_mouse_position()

			if event.shift_pressed:
				owner.realm_layout_debug_controller.print_layout_point(
					mouse_position,
					island_rect
				)
				return

			var drag_result: Dictionary = find_drag_target(
				mouse_position,
				owner
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
			owner,
			island_rect
		)


func find_drag_target(
	mouse_position: Vector2,
	owner: RealmView
) -> Dictionary:
	var realm_layout: RealmLayout = owner.realm_layout
	var island_rect: Rect2 = owner._get_island_rect()
	var lakes: Array[LavaLake] = owner.lava_realm_visual_controller.lakes

	for flow_index in range(realm_layout.lava_flow_definitions.size()):
		var flow_points: PackedVector2Array = _get_flow_points(realm_layout, flow_index)
		for point_index in range(flow_points.size()):
			var point_position: Vector2 = geometry_controller.get_position_from_normalized(
				flow_points[point_index],
				island_rect
			)
			if point_position.distance_to(mouse_position) <= 11.0:
				return {
					"object": "lava_flow:%d:%d" % [flow_index, point_index],
					"offset": mouse_position - point_position
				}

	for lake_index in range(lakes.size()):
		var points: PackedVector2Array = _get_lake_points(realm_layout, lake_index)
		for point_index in range(points.size()):
			var point_position: Vector2 = geometry_controller.get_position_from_normalized(
				points[point_index],
				island_rect
			)
			if point_position.distance_to(mouse_position) <= 11.0:
				return {
					"object": "lake_edge:%d:%d" % [lake_index, point_index],
					"offset": mouse_position - point_position
				}

	for i in range(owner.ash_visual_controller.piles.size()):
		var pile: Sprite2D = owner.ash_visual_controller.piles[i]
		if not is_instance_valid(pile):
			continue

		var pile_rect: Rect2 = Rect2(
			pile.position - Vector2(16.0, 16.0),
			Vector2(32.0, 32.0)
		)

		if pile_rect.has_point(mouse_position):
			return {
				"object": "ash_pile:" + str(i),
				"offset": mouse_position - pile.position
			}

	for stat_name in owner.BRAZIER_STATS:
		if not owner.braziers.has(stat_name):
			continue

		var brazier: Control = owner.braziers[stat_name]
		if not is_instance_valid(brazier):
			continue

		var brazier_rect: Rect2 = Rect2(
			brazier.position - Vector2(32, 32),
			Vector2(64, 64)
		)

		if brazier_rect.has_point(mouse_position):
			return {
				"object": "brazier:" + stat_name,
				"offset": mouse_position - brazier.position
			}

	for generator_id in owner.generator_hitboxes:
		var hitbox: Rect2 = owner.generator_hitboxes[generator_id]
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
	owner: RealmView,
	island_rect: Rect2
) -> void:
	if island_rect.size.x <= 0.0 or island_rect.size.y <= 0.0:
		cancel_drag()
		return

	var realm_layout: RealmLayout = owner.realm_layout
	if realm_layout == null:
		cancel_drag()
		return

	if dragging_object.begins_with("lava_flow:"):
		var parts: PackedStringArray = dragging_object.split(":")
		if parts.size() != 3:
			cancel_drag()
			return

		var flow_index: int = int(parts[1])
		var point_index: int = int(parts[2])
		var points: PackedVector2Array = _get_flow_points(realm_layout, flow_index)
		if point_index < 0 or point_index >= points.size():
			cancel_drag()
			return

		points[point_index] = geometry_controller.get_normalized_position(
			mouse_position - drag_offset,
			island_rect
		)
		_set_flow_points(realm_layout, flow_index, points)
		owner.lava_realm_visual_controller.update_positions(realm_layout, island_rect)
		owner.queue_redraw()
		return

	if dragging_object.begins_with("lake_edge:"):
		var parts: PackedStringArray = dragging_object.split(":")
		if parts.size() != 3:
			cancel_drag()
			return

		var lake_index: int = int(parts[1])
		var point_index: int = int(parts[2])
		var points: PackedVector2Array = _get_lake_points(realm_layout, lake_index)
		if point_index < 0 or point_index >= points.size():
			cancel_drag()
			return

		var normalized_position: Vector2 = geometry_controller.get_normalized_position(
			mouse_position - drag_offset,
			island_rect
		)
		points[point_index] = normalized_position
		_set_lake_points(realm_layout, lake_index, points)

		var lakes: Array[LavaLake] = owner.lava_realm_visual_controller.lakes
		if lake_index >= 0 and lake_index < lakes.size():
			var lake: LavaLake = lakes[lake_index]
			if is_instance_valid(lake):
				lake.setup(points, island_rect)

		owner.queue_redraw()
		return

	if dragging_object.begins_with("ash_pile:"):
		var pile_index: int = int(dragging_object.substr(9))
		if pile_index < 0 or pile_index >= realm_layout.ash_pile_layout_positions.size():
			cancel_drag()
			return

		var new_position: Vector2 = mouse_position - drag_offset
		var normalized_position: Vector2 = geometry_controller.get_normalized_position(
			new_position,
			island_rect
		)
		realm_layout.ash_pile_layout_positions[pile_index] = normalized_position
		owner._update_ash_piles(
			owner.state.get_resource_amount(ResourceIds.ASH)
		)
		owner.queue_redraw()
		return

	if dragging_object.begins_with("brazier:"):
		var stat_name: String = dragging_object.substr(8)
		if not owner.braziers.has(stat_name) or not is_instance_valid(owner.braziers[stat_name]):
			cancel_drag()
			return
		if not realm_layout.brazier_layout_positions.has(stat_name):
			cancel_drag()
			return

		var new_position: Vector2 = mouse_position - drag_offset
		var normalized_position: Vector2 = geometry_controller.get_normalized_position(
			new_position,
			island_rect
		)
		realm_layout.brazier_layout_positions[stat_name] = normalized_position
		owner.braziers[stat_name].position = geometry_controller.get_position_from_normalized(
			normalized_position,
			island_rect
		)
		owner.queue_redraw()
		return

	if not realm_layout.generator_layout_positions.has(dragging_object):
		cancel_drag()
		return

	var new_position: Vector2 = mouse_position - drag_offset
	var normalized_position: Vector2 = geometry_controller.get_normalized_position(
		new_position,
		island_rect
	)
	realm_layout.generator_layout_positions[dragging_object] = normalized_position
	owner.queue_redraw()



func _get_flow_points(layout: RealmLayout, flow_index: int) -> PackedVector2Array:
	if layout == null or flow_index < 0 or flow_index >= layout.lava_flow_definitions.size():
		return PackedVector2Array()
	var definition: Dictionary = layout.lava_flow_definitions[flow_index]
	if not definition.has("points"):
		return PackedVector2Array()
	return definition["points"]


func _set_flow_points(
	layout: RealmLayout,
	flow_index: int,
	points: PackedVector2Array
) -> void:
	if layout == null or flow_index < 0 or flow_index >= layout.lava_flow_definitions.size():
		return
	var definition: Dictionary = layout.lava_flow_definitions[flow_index]
	definition["points"] = points
	layout.lava_flow_definitions[flow_index] = definition


func _get_lake_points(layout: RealmLayout, lake_index: int) -> PackedVector2Array:
	if layout == null:
		return PackedVector2Array()
	if lake_index == 0:
		return layout.main_lake_edge_points
	var definition_index: int = lake_index - 1
	if definition_index < 0 or definition_index >= layout.small_lake_definitions.size():
		return PackedVector2Array()
	var definition: Dictionary = layout.small_lake_definitions[definition_index]
	if not definition.has("points"):
		return PackedVector2Array()
	return definition["points"]


func _set_lake_points(
	layout: RealmLayout,
	lake_index: int,
	points: PackedVector2Array
) -> void:
	if lake_index == 0:
		layout.main_lake_edge_points = points
		return
	var definition_index: int = lake_index - 1
	if definition_index < 0 or definition_index >= layout.small_lake_definitions.size():
		return
	var definition: Dictionary = layout.small_lake_definitions[definition_index]
	definition["points"] = points
	layout.small_lake_definitions[definition_index] = definition
