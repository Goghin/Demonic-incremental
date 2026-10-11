class_name RealmResizeController
extends RefCounted


func handle_notification(owner: Control, what: int) -> void:
	if what != Control.NOTIFICATION_RESIZED:
		return

	var island_rect: Rect2 = owner._get_island_rect()
	_update_lava_positions(owner, island_rect)
	_update_island_visual(owner, island_rect)
	_update_crystal_positions(owner)


func _update_lava_positions(owner: Control, island_rect: Rect2) -> void:
	owner.lava_realm_visual_controller.update_positions(
		owner.realm_layout,
		island_rect
	)


func _update_crystal_positions(owner: Control) -> void:
	if owner.realm_layout == null:
		return

	owner.crystallized_flame_visual_controller.reposition(owner)


func _update_island_visual(owner: Control, island_rect: Rect2) -> void:
	owner.island_visual_controller.update(
		owner,
		owner.realm_layout,
		island_rect
	)
