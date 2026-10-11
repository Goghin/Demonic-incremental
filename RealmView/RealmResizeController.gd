class_name RealmResizeController
extends RefCounted


func handle_notification(owner: Control, what: int) -> void:
	if what != Control.NOTIFICATION_RESIZED:
		return

	owner.lava_realm_visual_controller.update_positions(
		owner.realm_layout,
		owner._get_island_rect()
	)
	owner.island_visual_controller.update(
		owner,
		owner.realm_layout,
		owner._get_island_rect()
	)
