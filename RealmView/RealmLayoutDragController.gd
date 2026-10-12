class_name RealmLayoutDragController
extends RefCounted


var geometry_controller: RealmLayoutGeometryController = RealmLayoutGeometryController.new()


var dragging_object: String = ""
var selected_object: String = ""
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

			if event.ctrl_pressed and not _is_near_existing_geometry_handle(
				mouse_position,
				owner.realm_layout,
				island_rect
			):
				var inserted_object: String = _insert_flow_point_at_position(
					mouse_position,
					owner,
					island_rect
				)
				if inserted_object == "":
					inserted_object = _insert_lake_point_at_position(
						mouse_position,
						owner,
						island_rect
					)
				if inserted_object != "":
					selected_object = inserted_object
					dragging_object = ""
					drag_offset = Vector2.ZERO
					owner.queue_redraw()
					return
			var drag_result: Dictionary = find_drag_target(
				mouse_position,
				owner
			)
			dragging_object = drag_result["object"]
			selected_object = dragging_object
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


func _is_near_existing_geometry_handle(
	mouse_position: Vector2,
	layout: RealmLayout,
	island_rect: Rect2
) -> bool:
	if layout == null:
		return false

	# Existing handles take priority over insertion, even if another
	# nearby flow or lake segment would otherwise qualify.
	for flow_index in range(layout.lava_flow_definitions.size()):
		for point in _get_flow_points(layout, flow_index):
			var screen_point: Vector2 = geometry_controller.get_position_from_normalized(
				point,
				island_rect
			)
			if screen_point.distance_to(mouse_position) <= 12.0:
				return true

	var lake_count: int = 1 + layout.small_lake_definitions.size()
	for lake_index in range(lake_count):
		for point in _get_lake_points(layout, lake_index):
			var screen_point: Vector2 = geometry_controller.get_position_from_normalized(
				point,
				island_rect
			)
			if screen_point.distance_to(mouse_position) <= 12.0:
				return true

	return false


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

		points[point_index] = _clamp_normalized_position(
			geometry_controller.get_normalized_position(
				mouse_position - drag_offset,
				island_rect
			)
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

		var normalized_position: Vector2 = _clamp_normalized_position(
			geometry_controller.get_normalized_position(
				mouse_position - drag_offset,
				island_rect
			)
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
		var normalized_position: Vector2 = _clamp_normalized_position(
			geometry_controller.get_normalized_position(
				new_position,
				island_rect
			)
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
		var normalized_position: Vector2 = _clamp_normalized_position(
			geometry_controller.get_normalized_position(
				new_position,
				island_rect
			)
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


func nudge_selected(
	layout: RealmLayout,
	owner: RealmView,
	pixel_delta: Vector2,
	island_rect: Rect2
) -> bool:
	if layout == null or island_rect.size.x <= 0.0 or island_rect.size.y <= 0.0:
		return false
	if selected_object == "":
		return false

	var normalized_delta: Vector2 = Vector2(
		pixel_delta.x / island_rect.size.x,
		pixel_delta.y / island_rect.size.y
	)

	if selected_object.begins_with("lava_flow:"):
		var parts: PackedStringArray = selected_object.split(":")
		if parts.size() != 3:
			return false
		var flow_index: int = int(parts[1])
		var point_index: int = int(parts[2])
		var points: PackedVector2Array = _get_flow_points(layout, flow_index)
		if point_index < 0 or point_index >= points.size():
			return false
		points[point_index] = _clamp_normalized_position(points[point_index] + normalized_delta)
		_set_flow_points(layout, flow_index, points)
		owner.lava_realm_visual_controller.update_positions(layout, island_rect)
		return true

	if selected_object.begins_with("lake_edge:"):
		var parts: PackedStringArray = selected_object.split(":")
		if parts.size() != 3:
			return false
		var lake_index: int = int(parts[1])
		var point_index: int = int(parts[2])
		var points: PackedVector2Array = _get_lake_points(layout, lake_index)
		if point_index < 0 or point_index >= points.size():
			return false
		points[point_index] = _clamp_normalized_position(points[point_index] + normalized_delta)
		_set_lake_points(layout, lake_index, points)
		_refresh_lake_geometry(owner, lake_index, points, island_rect)
		return true

	if selected_object.begins_with("ash_pile:"):
		var pile_index: int = int(selected_object.substr(9))
		if pile_index < 0 or pile_index >= layout.ash_pile_layout_positions.size():
			return false
		layout.ash_pile_layout_positions[pile_index] = _clamp_normalized_position(
			layout.ash_pile_layout_positions[pile_index] + normalized_delta
		)
		owner._update_ash_piles(owner.state.get_resource_amount(ResourceIds.ASH))
		return true

	if selected_object.begins_with("brazier:"):
		var stat_name: String = selected_object.substr(8)
		if not layout.brazier_layout_positions.has(stat_name):
			return false
		var normalized_position: Vector2 = _clamp_normalized_position(
			layout.brazier_layout_positions[stat_name] + normalized_delta
		)
		layout.brazier_layout_positions[stat_name] = normalized_position
		if owner.braziers.has(stat_name) and is_instance_valid(owner.braziers[stat_name]):
			owner.braziers[stat_name].position = owner.realm_layout_geometry_controller.get_position_from_normalized(
				normalized_position,
				island_rect
			)
		return true

	if not layout.generator_layout_positions.has(selected_object):
		return false
	layout.generator_layout_positions[selected_object] = _clamp_normalized_position(
		layout.generator_layout_positions[selected_object] + normalized_delta
	)
	return true


func _clamp_normalized_position(position: Vector2) -> Vector2:
	return Vector2(
		clampf(position.x, 0.0, 1.0),
		clampf(position.y, 0.0, 1.0)
	)


func adjust_selected_flow_width(layout: RealmLayout, amount: float) -> bool:
	if layout == null or not selected_object.begins_with("lava_flow:"):
		return false
	var parts: PackedStringArray = selected_object.split(":")
	if parts.size() != 3:
		return false
	var flow_index: int = int(parts[1])
	var point_index: int = int(parts[2])
	if flow_index < 0 or flow_index >= layout.lava_flow_definitions.size():
		return false
	var definition: Dictionary = layout.lava_flow_definitions[flow_index]
	if not definition.has("widths"):
		return false
	var widths: PackedFloat32Array = definition["widths"]
	if point_index < 0 or point_index >= widths.size():
		return false
	widths[point_index] = maxf(0.0, widths[point_index] + amount)
	definition["widths"] = widths
	layout.lava_flow_definitions[flow_index] = definition
	return true


func adjust_selected_waterfall(layout: RealmLayout, width_delta: float, length_delta: float) -> bool:
	if layout == null or not selected_object.begins_with("lava_flow:"):
		return false

	var parts: PackedStringArray = selected_object.split(":")
	if parts.size() != 3:
		return false

	var flow_index: int = int(parts[1])
	var point_index: int = int(parts[2])
	if flow_index < 0 or flow_index >= layout.lava_flow_definitions.size():
		return false

	var definition: Dictionary = layout.lava_flow_definitions[flow_index]
	var points: PackedVector2Array = _get_flow_points(layout, flow_index)
	# The waterfall is attached to the final point of its lava flow.
	if points.is_empty() or point_index != points.size() - 1:
		return false

	var changed: bool = false
	if width_delta != 0.0:
		definition["fall_width"] = maxf(1.0, float(definition.get("fall_width", 4.0)) + width_delta)
		changed = true
	if length_delta != 0.0:
		definition["fall_length"] = maxf(8.0, float(definition.get("fall_length", 60.0)) + length_delta)
		changed = true

	if changed:
		layout.lava_flow_definitions[flow_index] = definition
	return changed


func _insert_flow_point_at_position(
	mouse_position: Vector2,
	owner: RealmView,
	island_rect: Rect2
) -> String:
	var layout: RealmLayout = owner.realm_layout
	if layout == null:
		return ""

	# Ctrl-clicking an existing handle should still allow normal selection.
	for flow_index in range(layout.lava_flow_definitions.size()):
		var points: PackedVector2Array = _get_flow_points(layout, flow_index)
		for point in points:
			var screen_point: Vector2 = geometry_controller.get_position_from_normalized(
				point,
				island_rect
			)
			if screen_point.distance_to(mouse_position) <= 12.0:
				return ""

	var best_flow_index: int = -1
	var best_segment_index: int = -1
	var best_position: Vector2 = Vector2.ZERO
	var best_distance: float = 10.0
	var best_ratio: float = 0.5

	for flow_index in range(layout.lava_flow_definitions.size()):
		var points: PackedVector2Array = _get_flow_points(layout, flow_index)
		if points.size() < 2:
			continue

		var screen_points := PackedVector2Array()
		for point in points:
			screen_points.append(geometry_controller.get_position_from_normalized(
				point,
				island_rect
			))

		for segment_index in range(screen_points.size() - 1):
			var start: Vector2 = screen_points[segment_index]
			var finish: Vector2 = screen_points[segment_index + 1]
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(
				mouse_position,
				start,
				finish
			)
			var distance: float = closest.distance_to(mouse_position)
			if distance >= best_distance:
				continue

			var segment: Vector2 = finish - start
			var segment_length_squared: float = segment.length_squared()
			if segment_length_squared <= 0.0001:
				continue

			best_distance = distance
			best_flow_index = flow_index
			best_segment_index = segment_index
			best_position = closest
			best_ratio = clampf((closest - start).dot(segment) / segment_length_squared, 0.0, 1.0)

	if best_flow_index < 0:
		return ""

	var definition: Dictionary = layout.lava_flow_definitions[best_flow_index]
	var points: PackedVector2Array = _get_flow_points(layout, best_flow_index)
	var widths: PackedFloat32Array = _get_aligned_flow_widths(
		definition,
		points.size()
	)
	var normalized_position: Vector2 = geometry_controller.get_normalized_position(
		best_position,
		island_rect
	)
	var inserted_width: float = lerpf(
		widths[best_segment_index],
		widths[best_segment_index + 1],
		best_ratio
	)

	points.insert(best_segment_index + 1, normalized_position)
	widths.insert(best_segment_index + 1, inserted_width)
	definition["points"] = points
	definition["widths"] = widths
	layout.lava_flow_definitions[best_flow_index] = definition
	owner.lava_realm_visual_controller.update_positions(layout, island_rect)
	return "lava_flow:%d:%d" % [best_flow_index, best_segment_index + 1]


func _get_aligned_flow_widths(
	definition: Dictionary,
	point_count: int
) -> PackedFloat32Array:
	var widths := PackedFloat32Array()
	if point_count <= 0:
		return widths

	var stored_widths: PackedFloat32Array = definition.get(
		"widths",
		PackedFloat32Array()
	)
	for i in range(point_count):
		if i < stored_widths.size():
			widths.append(maxf(0.0, stored_widths[i]))
		elif not widths.is_empty():
			# Extend malformed width data using the last known width.
			widths.append(widths[widths.size() - 1])
		else:
			# A missing width array gets a conservative, readable default.
			widths.append(3.0)

	return widths


func remove_selected_flow_point(layout: RealmLayout) -> bool:
	if layout == null or not selected_object.begins_with("lava_flow:"):
		return false

	var parts: PackedStringArray = selected_object.split(":")
	if parts.size() != 3:
		return false

	var flow_index: int = int(parts[1])
	var point_index: int = int(parts[2])
	if flow_index < 0 or flow_index >= layout.lava_flow_definitions.size():
		return false

	var definition: Dictionary = layout.lava_flow_definitions[flow_index]
	var points: PackedVector2Array = _get_flow_points(layout, flow_index)
	# A flow needs at least two points to define a segment.
	if points.size() <= 2 or point_index < 0 or point_index >= points.size():
		return false

	var widths: PackedFloat32Array = _get_aligned_flow_widths(
		definition,
		points.size()
	)

	points.remove_at(point_index)
	widths.remove_at(point_index)
	definition["points"] = points
	definition["widths"] = widths
	layout.lava_flow_definitions[flow_index] = definition
	var new_point_index: int = mini(point_index, points.size() - 1)
	selected_object = "lava_flow:%d:%d" % [flow_index, new_point_index]
	return true


func _insert_lake_point_at_position(
	mouse_position: Vector2,
	owner: RealmView,
	island_rect: Rect2
) -> String:
	var layout: RealmLayout = owner.realm_layout
	if layout == null:
		return ""

	# Do not insert a new point when Ctrl-clicking an existing flow or lake handle.
	for flow_index in range(layout.lava_flow_definitions.size()):
		for point in _get_flow_points(layout, flow_index):
			var flow_screen_point: Vector2 = geometry_controller.get_position_from_normalized(
				point,
				island_rect
			)
			if flow_screen_point.distance_to(mouse_position) <= 12.0:
				return ""

	var lake_count: int = 1 + layout.small_lake_definitions.size()
	for lake_index in range(lake_count):
		var points: PackedVector2Array = _get_lake_points(layout, lake_index)
		if points.size() < 3:
			continue
		var screen_points := PackedVector2Array()
		for point in points:
			screen_points.append(geometry_controller.get_position_from_normalized(
				point,
				island_rect
			))
		for point in screen_points:
			if point.distance_to(mouse_position) <= 12.0:
				return ""

	var best_lake_index: int = -1
	var best_segment_index: int = -1
	var best_position: Vector2 = Vector2.ZERO
	var best_distance: float = 10.0

	for lake_index in range(lake_count):
		var points: PackedVector2Array = _get_lake_points(layout, lake_index)
		if points.size() < 3:
			continue
		var screen_points := PackedVector2Array()
		for point in points:
			screen_points.append(geometry_controller.get_position_from_normalized(
				point,
				island_rect
			))
		# Lake outlines are closed, so include the final-to-first segment.
		for segment_index in range(screen_points.size()):
			var next_index: int = (segment_index + 1) % screen_points.size()
			var start: Vector2 = screen_points[segment_index]
			var finish: Vector2 = screen_points[next_index]
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(
				mouse_position,
				start,
				finish
			)
			var distance: float = closest.distance_to(mouse_position)
			if distance >= best_distance:
				continue
			best_distance = distance
			best_lake_index = lake_index
			best_segment_index = segment_index
			best_position = closest

	if best_lake_index < 0:
		return ""

	var points: PackedVector2Array = _get_lake_points(layout, best_lake_index)
	var normalized_position: Vector2 = geometry_controller.get_normalized_position(
		best_position,
		island_rect
	)
	var insert_index: int = best_segment_index + 1
	if best_segment_index == points.size() - 1:
		insert_index = points.size()
	points.insert(insert_index, normalized_position)
	_set_lake_points(layout, best_lake_index, points)
	_refresh_lake_geometry(owner, best_lake_index, points, island_rect)
	return "lake_edge:%d:%d" % [best_lake_index, insert_index]


func remove_selected_lake_point(
	layout: RealmLayout,
	owner: RealmView,
	island_rect: Rect2
) -> bool:
	if layout == null or not selected_object.begins_with("lake_edge:"):
		return false

	var parts: PackedStringArray = selected_object.split(":")
	if parts.size() != 3:
		return false

	var lake_index: int = int(parts[1])
	var point_index: int = int(parts[2])
	var points: PackedVector2Array = _get_lake_points(layout, lake_index)
	# Keep at least three points so the lake outline remains a valid polygon.
	if points.size() <= 3 or point_index < 0 or point_index >= points.size():
		return false

	points.remove_at(point_index)
	_set_lake_points(layout, lake_index, points)
	_refresh_lake_geometry(owner, lake_index, points, island_rect)
	var new_point_index: int = mini(point_index, points.size() - 1)
	selected_object = "lake_edge:%d:%d" % [lake_index, new_point_index]
	return true


func _refresh_lake_geometry(
	owner: RealmView,
	lake_index: int,
	points: PackedVector2Array,
	island_rect: Rect2
) -> void:
	var lakes: Array[LavaLake] = owner.lava_realm_visual_controller.lakes
	if lake_index < 0 or lake_index >= lakes.size():
		return
	var lake: LavaLake = lakes[lake_index]
	if is_instance_valid(lake):
		lake.setup(points, island_rect)


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
