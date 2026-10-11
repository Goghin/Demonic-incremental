class_name RealmResizeController
extends RefCounted


func handle_notification(owner: Control, what: int) -> void:
	if what != Control.NOTIFICATION_RESIZED:
		return
	if owner.realm_layout == null:
		return

	var island_rect: Rect2 = owner._get_island_rect()
	owner.realm_layout_visual_controller.update_positions(
		owner,
		owner.state,
		owner.realm_layout,
		island_rect,
		owner.lava_realm_visual_controller,
		owner.island_visual_controller,
		Callable(owner, "_draw_generators"),
		owner.ash_visual_controller,
		owner.brazier_visual_controller,
		owner.braziers,
		owner.BRAZIER_STATS,
		owner.crystallized_flame_visual_controller
	)
