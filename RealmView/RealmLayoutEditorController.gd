class_name RealmLayoutEditorController
extends RefCounted


var layout_mode: bool = false
var drag_controller: RealmLayoutDragController = RealmLayoutDragController.new()
var held_fall_width_direction: float = 0.0
var held_fall_length_direction: float = 0.0

const FALL_WIDTH_CHANGE_PER_SECOND: float = 6.0
const FALL_LENGTH_CHANGE_PER_SECOND: float = 30.0


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
