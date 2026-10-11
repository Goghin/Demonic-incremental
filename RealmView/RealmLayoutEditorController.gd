class_name RealmLayoutEditorController
extends RefCounted


var layout_mode: bool = false
var drag_controller: RealmLayoutDragController = RealmLayoutDragController.new()


func handle_owner_input(event: InputEvent, owner: RealmView) -> void:
	if owner.state == null or owner.realm_layout == null:
		return

	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_F2:
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

	drag_controller.handle_mouse_input(event, owner)
