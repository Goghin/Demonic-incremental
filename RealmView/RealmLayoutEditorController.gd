class_name RealmLayoutEditorController
extends RefCounted


var layout_mode: bool = false
var drag_controller: RealmLayoutDragController = RealmLayoutDragController.new()


func handle_owner_input(event: InputEvent, owner: RealmView) -> void:
	if owner.state == null or owner.realm_layout == null:
		return

	if event is InputEventKey:
		if not event.pressed or event.echo:
			return

		if event.keycode == KEY_F2:
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

		if event.keycode in [KEY_DELETE, KEY_BACKSPACE]:
			if drag_controller.remove_selected_flow_point(owner.realm_layout):
				owner.lava_realm_visual_controller.update_positions(
					owner.realm_layout,
					owner._get_island_rect()
				)
				owner.queue_redraw()
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

	if not layout_mode:
		return

	drag_controller.handle_mouse_input(event, owner)
