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

		# Tab cycles through editable objects under the cursor when hit areas overlap.
		if event.keycode == KEY_TAB:
			drag_controller.cycle_overlapping_target(
				owner.get_local_mouse_position(),
				owner
			)
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
			if drag_controller.selected_object.begins_with("smoke_emitter:"):
				_remove_selected_flow(owner)
				return
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

		# Create a new editable Matter pile at the mouse cursor.
		if event.keycode == KEY_M:
			_add_matter_pile_at_cursor(owner)
			return

		# Add a placeable smoke emitter at the cursor. Shift+A creates an animated column.
		if event.keycode == KEY_A:
			_add_smoke_emitter_at_cursor(owner, event.shift_pressed)
			return

		# Cycle through the five animated smoke column variants on the selected emitter.
		if event.keycode == KEY_V and drag_controller.selected_object.begins_with("smoke_emitter:"):
			_cycle_selected_smoke_variant(owner)
			return

		# Create a new editable flow near the mouse cursor.
		if event.keycode == KEY_N:
			_add_flow_at_cursor(owner)
			return

		# Toggle the waterfall attached to the selected flow endpoint.
		if event.keycode == KEY_F:
			_toggle_selected_waterfall(owner)
			return

		if drag_controller.selected_object.begins_with("matter_pile:") and event.keycode in [KEY_PLUS, KEY_EQUAL, KEY_KP_ADD, KEY_MINUS, KEY_KP_SUBTRACT]:
			var rotation_delta: float = 5.0 if event.keycode in [KEY_PLUS, KEY_EQUAL, KEY_KP_ADD] else -5.0
			_rotate_selected_matter_pile(owner, rotation_delta)
			return

		var width_change: float = 0.0
		if event.keycode in [KEY_PLUS, KEY_EQUAL, KEY_KP_ADD]:
			width_change = 0.5
		elif event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
			width_change = -0.5

		if width_change != 0.0 and drag_controller.selected_object.begins_with("smoke_emitter:"):
			_adjust_selected_smoke_size(owner, signf(width_change) * 0.25)
			return

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



func _add_matter_pile_at_cursor(owner: RealmView) -> void:
	var layout: RealmLayout = owner.realm_layout
	if layout == null:
		return

	var island_rect: Rect2 = owner._get_island_rect()
	if island_rect.size.x <= 0.0 or island_rect.size.y <= 0.0:
		return

	var normalized_position: Vector2 = owner.realm_layout_geometry_controller.get_normalized_position(
		owner.get_local_mouse_position(),
		island_rect
	)
	layout.matter_pile_layout_positions.append(Vector2(
		clampf(normalized_position.x, 0.0, 1.0),
		clampf(normalized_position.y, 0.0, 1.0)
	))
	_ensure_matter_pile_rotations(layout)
	layout.matter_pile_layout_rotations.append(0.0)
	owner.matter_pile_visual_controller.setup(owner, layout)
	owner.matter_pile_visual_controller.update_piles(
		layout,
		island_rect,
		owner.state.get_resource_amount(ResourceIds.MATTER)
	)
	var pile_index: int = layout.matter_pile_layout_positions.size() - 1
	drag_controller.selected_object = "matter_pile:%d" % pile_index
	owner.queue_redraw()
	print("Added Matter pile ", pile_index + 1, ". Drag it to position it.")


func _ensure_matter_pile_rotations(layout: RealmLayout) -> void:
	while layout.matter_pile_layout_rotations.size() < layout.matter_pile_layout_positions.size():
		layout.matter_pile_layout_rotations.append(0.0)


func _rotate_selected_matter_pile(owner: RealmView, amount: float) -> void:
	var layout: RealmLayout = owner.realm_layout
	if layout == null or not drag_controller.selected_object.begins_with("matter_pile:"):
		return
	var pile_index: int = int(drag_controller.selected_object.substr(12))
	if pile_index < 0 or pile_index >= layout.matter_pile_layout_positions.size():
		return
	_ensure_matter_pile_rotations(layout)
	layout.matter_pile_layout_rotations[pile_index] = wrapf(
		layout.matter_pile_layout_rotations[pile_index] + amount,
		-180.0,
		180.0
	)
	owner.matter_pile_visual_controller.update_piles(
		layout,
		owner._get_island_rect(),
		owner.state.get_resource_amount(ResourceIds.MATTER)
	)
	owner.queue_redraw()
	print("Matter pile ", pile_index + 1, " rotation: ", layout.matter_pile_layout_rotations[pile_index], " degrees")


func _add_smoke_emitter_at_cursor(owner: RealmView, animated_column: bool = false) -> void:
	var layout: RealmLayout = owner.realm_layout
	if layout == null:
		return
	var island_rect: Rect2 = owner._get_island_rect()
	if island_rect.size.x <= 0.0 or island_rect.size.y <= 0.0:
		return
	var normalized_position: Vector2 = owner.realm_layout_geometry_controller.get_normalized_position(
		owner.get_local_mouse_position(), island_rect
	)
	var definition: Dictionary = {
		"position": normalized_position,
		"size": 1.0,
		"emission_rate": 1.0,
		"opacity": 0.7,
		"style": "column" if animated_column else "puff",
		"variant": randi_range(1, 5) if animated_column else 1
	}
	layout.smoke_emitter_definitions.append(definition)
	var smoke_index: int = layout.smoke_emitter_definitions.size() - 1
	drag_controller.selected_object = "smoke_emitter:%d" % smoke_index
	owner.queue_redraw()
	if animated_column:
		print("Added animated smoke column ", smoke_index + 1, " (variant ", definition["variant"], "). Drag to position it; +/- changes size; V cycles variants.")
	else:
		print("Added smoke puff emitter ", smoke_index + 1, ". Drag to position it; +/- changes size.")


func _cycle_selected_smoke_variant(owner: RealmView) -> void:
	var layout: RealmLayout = owner.realm_layout
	if layout == null or not drag_controller.selected_object.begins_with("smoke_emitter:"):
		return
	var smoke_index: int = int(drag_controller.selected_object.substr(14))
	if smoke_index < 0 or smoke_index >= layout.smoke_emitter_definitions.size():
		return
	var definition: Dictionary = layout.smoke_emitter_definitions[smoke_index]
	definition["style"] = "column"
	definition["variant"] = int(definition.get("variant", 1)) % 5 + 1
	layout.smoke_emitter_definitions[smoke_index] = definition
	owner.queue_redraw()
	print("Smoke emitter ", smoke_index + 1, " animation variant: ", definition["variant"])


func _adjust_selected_smoke_size(owner: RealmView, amount: float) -> void:
	var layout: RealmLayout = owner.realm_layout
	if layout == null or not drag_controller.selected_object.begins_with("smoke_emitter:"):
		return
	var smoke_index: int = int(drag_controller.selected_object.substr(14))
	if smoke_index < 0 or smoke_index >= layout.smoke_emitter_definitions.size():
		return
	var definition: Dictionary = layout.smoke_emitter_definitions[smoke_index]
	definition["size"] = clampf(float(definition.get("size", 1.0)) + amount, 0.25, 3.0)
	layout.smoke_emitter_definitions[smoke_index] = definition
	owner.queue_redraw()
	print("Smoke emitter ", smoke_index + 1, " size: ", definition["size"], "x")


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
	if layout == null:
		return

	if drag_controller.selected_object.begins_with("smoke_emitter:"):
		var smoke_index: int = int(drag_controller.selected_object.substr(14))
		if smoke_index < 0 or smoke_index >= layout.smoke_emitter_definitions.size():
			return
		layout.smoke_emitter_definitions.remove_at(smoke_index)
		drag_controller.cancel_drag()
		drag_controller.selected_object = ""
		owner.queue_redraw()
		print("Removed smoke emitter ", smoke_index + 1, ".")
		return

	if drag_controller.selected_object.begins_with("matter_pile:"):
		var pile_index: int = int(drag_controller.selected_object.substr(12))
		if pile_index < 0 or pile_index >= layout.matter_pile_layout_positions.size():
			return
		layout.matter_pile_layout_positions.remove_at(pile_index)
		if pile_index < layout.matter_pile_layout_rotations.size():
			layout.matter_pile_layout_rotations.remove_at(pile_index)
		drag_controller.cancel_drag()
		drag_controller.selected_object = ""
		owner.matter_pile_visual_controller.setup(owner, layout)
		owner.matter_pile_visual_controller.update_piles(
			layout,
			owner._get_island_rect(),
			owner.state.get_resource_amount(ResourceIds.MATTER)
		)
		owner.queue_redraw()
		print("Removed Matter pile ", pile_index + 1, ".")
		return

	if not drag_controller.selected_object.begins_with("lava_flow:"):
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
	owner.realm_layout_overlay_renderer.update_overlay(
		layout_mode and owner.state != null and owner.realm_layout != null,
		owner.generator_hitboxes,
		owner.ash_visual_controller.piles,
		owner.braziers,
		owner.BRAZIER_STATS,
		drag_controller.selected_object,
		owner.realm_layout,
		owner._get_island_rect()
	)

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
