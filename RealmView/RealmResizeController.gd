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
		island_rect
	)
