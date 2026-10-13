class_name RealmLayoutEditorController
extends RefCounted


var layout_mode: bool = false
var drag_controller: RealmLayoutDragController = RealmLayoutDragController.new()
var held_fall_width_direction: float = 0.0
var held_fall_length_direction: float = 0.0

const FALL_WIDTH_CHANGE_PER_SECOND: float = 6.0
const FALL_LENGTH_CHANGE_PER_SECOND: float = 30.0


func handle_application_focus_lost() -> void:
	# Key-up and mouse-up events may not arrive if the application loses focus.
	held_fall_width_direction = 0.0
	held_fall_length_direction = 0.0
	drag_controller.cancel_drag()


func handle_owner_input(event: InputEvent, owner: RealmView) -> void:
	if owner.state == null or owner.realm_layout == null:
		return

	if event is InputEventKey:
		if not event.pressed:
			_release_waterfall_key(event.keycode)
			return
		if event.echo:
			return

		if event.keycode == KEY_ESCAPE and layout_mode:
			held_fall_width_direction = 0.0
			held_fall_length_direction = 0.0
			drag_controller.cancel_drag()
			drag_controller.selected_object = ""
			owner.queue_redraw()
			return

		if event.keycode == KEY_F2:
			held_fall_width_direction = 0.0
			held_fall_length_direction = 0.0
			layout_mode = not layout_mode
			drag_controller.cancel_drag()
			if layout_mode:
				owner.realm_layout_debug_controller.print_layout_details(
					owner.realm_layout,
					owner.braziers,
					owner.BRAZIER_STATS,
					owner.lava_realm_visual_controller.lakes
				)
			owner.queue_redraw()
			return

		if not layout_mode:
			return

		# Toggle the selected flow's waterfall between the two draw-order layers
		# used by the layouts: 4 (behind) and 7 (in front).
		if event.keycode == KEY_Z:
			_toggle_selected_fall_z(owner)
			return

		if event.ctrl_pressed and event.shift_pressed and event.keycode == KEY_S:
			RealmLayoutExportController.open_save_dialog(owner)
			return

		if event.ctrl_pressed and event.shift_pressed and event.keycode == KEY_I:
			RealmLayoutImageController.open_texture_dialog(owner)
			return

		if event.ctrl_pressed and event.shift_pressed and event.keycode == KEY_L:
			_cycle_layout(owner)
			return

		# Ctrl + Shift + arrows move the whole island layout in the view.
		if event.ctrl_pressed and event.shift_pressed and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			var offset_delta := Vector2.ZERO
			match event.keycode:
				KEY_LEFT:
					offset_delta.x = -0.01
				KEY_RIGHT:
					offset_delta.x = 0.01
				KEY_UP:
					offset_delta.y = -0.01
				KEY_DOWN:
					offset_delta.y = 0.01
			owner.realm_layout.island_view_offset += offset_delta
			_refresh_island_view(owner)
			return

		# Ctrl + plus/minus scales the island and all normalized layout elements.
		if event.ctrl_pressed and not event.shift_pressed and event.keycode in [KEY_EQUAL, KEY_KP_ADD, KEY_MINUS, KEY_KP_SUBTRACT]:
			var scale_delta := 0.05 if event.keycode in [KEY_EQUAL, KEY_KP_ADD] else -0.05
			owner.realm_layout.island_view_scale = clampf(
				owner.realm_layout.island_view_scale + scale_delta,
				0.5,
				2.0
			)
			_refresh_island_view(owner)
			return

		# Shift + arrows nudge the selected item without interfering with
		# the unmodified arrow keys used to adjust waterfall dimensions.
		if event.shift_pressed and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			var nudge: Vector2 = Vector2.ZERO
			match event.keycode:
				KEY_LEFT:
					nudge.x = -2.0
				KEY_RIGHT:
					nudge.x = 2.0
				KEY_UP:
					nudge.y = -2.0
				KEY_DOWN:
					nudge.y = 2.0
			drag_controller.nudge_selected(
				owner.realm_layout,
				owner,
				nudge,
				owner._get_island_rect()
			)
			owner.queue_redraw()
			return

		if event.keycode in [KEY_DELETE, KEY_BACKSPACE]:
			if event.ctrl_pressed:
				_remove_selected_flow(owner)
				return

			var removed_point: bool = drag_controller.remove_selected_flow_point(owner.realm_layout)
			if not removed_point:
				removed_point = drag_controller.remove_selected_lake_point(
					owner.realm_layout,
					owner,
					owner._get_island_rect()
				)
			if removed_point:
				owner.lava_realm_visual_controller.update_positions(
					owner.realm_layout,
					owner._get_island_rect()
				)
				owner.queue_redraw()
			return

		# Create a new editable flow near the mouse cursor.
		if event.keycode == KEY_N:
			_add_flow_at_cursor(owner)
			return

		# Toggle the waterfall attached to the selected flow endpoint.
		if event.keycode == KEY_F:
			_toggle_selected_waterfall(owner)
			return

		var width_change: float = 0.0
		if event.keycode in [KEY_PLUS, KEY_EQUAL, KEY_KP_ADD]:
			width_change = 0.5
		elif event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
			width_change = -0.5

		if width_change != 0.0 and drag_controller.adjust_selected_flow_width(owner.realm_layout, width_change):
			owner.lava_realm_visual_controller.update_positions(
				owner.realm_layout,
				owner._get_island_rect()
			)
			owner.queue_redraw()
			return

		match event.keycode:
			KEY_LEFT:
				held_fall_width_direction = -1.0
				return
			KEY_RIGHT:
				held_fall_width_direction = 1.0
				return
			KEY_UP:
				held_fall_length_direction = 1.0
				return
			KEY_DOWN:
				held_fall_length_direction = -1.0
				return

		return

	if not layout_mode:
		return

	drag_controller.handle_mouse_input(event, owner)



func _add_flow_at_cursor(owner: RealmView) -> void:
	var layout: RealmLayout = owner.realm_layout
	if layout == null:
		return

	var island_rect: Rect2 = owner._get_island_rect()
	if island_rect.size.x <= 0.0 or island_rect.size.y <= 0.0:
		return

	var start: Vector2 = owner.get_local_mouse_position()
	var normalized_start: Vector2 = owner.realm_layout_geometry_controller.get_normalized_position(
		start,
		island_rect
	)
	var normalized_end: Vector2 = owner.realm_layout_geometry_controller.get_normalized_position(
		start + Vector2(28.0, 28.0),
		island_rect
	)
	if normalized_start.distance_to(normalized_end) < 0.005:
		normalized_end = Vector2(
			clampf(normalized_start.x + 0.025, 0.0, 1.0),
			clampf(normalized_start.y + 0.025, 0.0, 1.0)
		)

	var definition: Dictionary = {
		"points": PackedVector2Array([normalized_start, normalized_end]),
		"widths": PackedFloat32Array([3.0, 3.0]),
		"speed": 25.0,
		"thickness": 1.0,
		"flow_z": 6,
		"start_fill": 0.5,
		"stop_fill": 0.45,
		"has_fall": false,
		"fall_width": 4.0,
		"fall_length": 60.0,
		"fall_speed": 100.0,
		"fall_z": 7
	}
	layout.lava_flow_definitions.append(definition)
	var flow_index: int = layout.lava_flow_definitions.size() - 1
	_rebuild_lava_visuals(owner)
	drag_controller.selected_object = "lava_flow:%d:1" % flow_index
	owner.queue_redraw()
	print("Added lava flow ", flow_index, ". Drag either endpoint to shape it.")


func _remove_selected_flow(owner: RealmView) -> void:
	var layout: RealmLayout = owner.realm_layout
	if layout == null or not drag_controller.selected_object.begins_with("lava_flow:"):
		return

	var parts: PackedStringArray = drag_controller.selected_object.split(":")
	if parts.size() != 3:
		return

	var flow_index: int = int(parts[1])
	if flow_index < 0 or flow_index >= layout.lava_flow_definitions.size():
		return

	# Keep an empty slot instead of erasing the definition: other flows can
	# refer to this flow by index through their "requires_flow" setting.
	var definition: Dictionary = layout.lava_flow_definitions[flow_index]
	definition["points"] = PackedVector2Array()
	definition["widths"] = PackedFloat32Array()
	definition["has_fall"] = false
	layout.lava_flow_definitions[flow_index] = definition

	drag_controller.cancel_drag()
	drag_controller.selected_object = ""
	_rebuild_lava_visuals(owner)
	owner.queue_redraw()
	print("Removed lava flow ", flow_index, ".")


func _toggle_selected_waterfall(owner: RealmView) -> void:
	var layout: RealmLayout = owner.realm_layout
	if layout == null or not drag_controller.selected_object.begins_with("lava_flow:"):
		return

	var parts: PackedStringArray = drag_controller.selected_object.split(":")
	if parts.size() != 3:
		return

	var flow_index: int = int(parts[1])
	var point_index: int = int(parts[2])
	if flow_index < 0 or flow_index >= layout.lava_flow_definitions.size():
		return

	var definition: Dictionary = layout.lava_flow_definitions[flow_index]
	var points: PackedVector2Array = definition.get("points", PackedVector2Array())
	if points.is_empty() or point_index != points.size() - 1:
		return

	var has_fall: bool = bool(definition.get("has_fall", true))
	definition["has_fall"] = not has_fall
	layout.lava_flow_definitions[flow_index] = definition
	_rebuild_lava_visuals(owner)
	drag_controller.selected_object = "lava_flow:%d:%d" % [flow_index, point_index]
	owner.queue_redraw()
	print("Waterfall ", "enabled" if not has_fall else "removed", " for lava flow ", flow_index, ".")


func _rebuild_lava_visuals(owner: RealmView) -> void:
	owner.lava_realm_visual_controller.build_realm_visuals(
		owner,
		owner.state,
		owner.realm_layout,
		owner._get_island_rect(),
		owner.LAVA_FLOW_SCENE,
		owner.LAVA_FALL_SCENE,
		owner.LAVA_LAKE_SCENE
	)


func _toggle_selected_fall_z(owner: RealmView) -> void:
	if not drag_controller.selected_object.begins_with("lava_flow:"):
		return

	var parts: PackedStringArray = drag_controller.selected_object.split(":")
	if parts.size() < 2:
		return

	var flow_index: int = int(parts[1])
	if flow_index < 0 or flow_index >= owner.realm_layout.lava_flow_definitions.size():
		return

	var definition: Dictionary = owner.realm_layout.lava_flow_definitions[flow_index]
	var current_z: int = int(definition.get("fall_z", 7))
	var next_z: int = 4 if current_z == 7 else 7
	definition["fall_z"] = next_z

	if flow_index < owner.lava_realm_visual_controller.falls.size():
		var fall: LavaFall = owner.lava_realm_visual_controller.falls[flow_index]
		if is_instance_valid(fall):
			fall.z_index = next_z

	print("Waterfall ", flow_index, " draw order set to Z ", next_z)
	owner.queue_redraw()


func _cycle_layout(owner: RealmView) -> void:
	var layout_ids: Array[String] = RealmLayoutRegistry.get_layout_ids()
	if layout_ids.is_empty():
		return

	var current_index: int = layout_ids.find(owner.state.realm_layout_id)
	var next_index: int = (current_index + 1) % layout_ids.size()
	var next_layout_id: String = layout_ids[next_index]

	owner.state.realm_layout_id = next_layout_id
	owner.state.realm_layout = RealmLayoutRegistry.create_layout(next_layout_id)
	owner.rebuild_realm(owner.state.realm_layout)
	owner.realm_layout_debug_controller.print_layout_details(
		owner.realm_layout,
		owner.braziers,
		owner.BRAZIER_STATS,
		owner.lava_realm_visual_controller.lakes
	)
	print("Switched realm layout to: ", next_layout_id)


func _refresh_island_view(owner: RealmView) -> void:
	var island_rect: Rect2 = owner._get_island_rect()
	owner.realm_layout_visual_controller.update_positions(owner, island_rect)
	owner.queue_redraw()


func _release_waterfall_key(keycode: int) -> void:
	match keycode:
		KEY_LEFT, KEY_RIGHT:
			held_fall_width_direction = 0.0
		KEY_UP, KEY_DOWN:
			held_fall_length_direction = 0.0


func update(owner: RealmView, delta: float) -> void:
	if not layout_mode or owner.state == null or owner.realm_layout == null:
		held_fall_width_direction = 0.0
		held_fall_length_direction = 0.0
		return

	if held_fall_width_direction == 0.0 and held_fall_length_direction == 0.0:
		return

	var changed: bool = drag_controller.adjust_selected_waterfall(
		owner.realm_layout,
		held_fall_width_direction * FALL_WIDTH_CHANGE_PER_SECOND * delta,
		held_fall_length_direction * FALL_LENGTH_CHANGE_PER_SECOND * delta
	)
	if changed:
		owner.lava_realm_visual_controller.update_positions(
			owner.realm_layout,
			owner._get_island_rect()
		)
		owner.queue_redraw()
