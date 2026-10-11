class_name RealmLayoutEditorController
extends RefCounted


var layout_mode: bool = false
var drag_controller: RealmLayoutDragController = RealmLayoutDragController.new()


func handle_owner_input(event: InputEvent, owner: Control) -> void:
	if owner.state == null or owner.realm_layout == null:
		return

	handle_input(
		event,
		owner,
		owner.realm_layout,
		owner.ash_visual_controller.piles,
		owner.braziers,
		owner.BRAZIER_STATS,
		owner.generator_hitboxes,
		owner._get_island_rect(),
		owner.state.get_resource_amount(ResourceIds.ASH),
		Callable(owner, "_update_ash_piles"),
		Callable(owner, "queue_redraw"),
		owner.realm_layout_debug_controller,
		owner.lava_realm_visual_controller.lakes
	)


func handle_input(
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
	debug_controller: RealmLayoutDebugController,
	lava_lakes: Array[LavaLake]
) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode == KEY_F2:
			layout_mode = not layout_mode
			drag_controller.cancel_drag()

			if layout_mode:
				debug_controller.print_layout_details(
					realm_layout,
					braziers,
					brazier_stats,
					lava_lakes
				)

			request_redraw.call()
			return

	if not layout_mode:
		return

	drag_controller.handle_mouse_input(
		event,
		owner,
		realm_layout,
		ash_piles,
		braziers,
		brazier_stats,
		generator_hitboxes,
		island_rect,
		ash_amount,
		update_ash_piles,
		request_redraw,
		debug_controller
	)
