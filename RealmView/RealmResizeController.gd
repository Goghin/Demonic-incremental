class_name RealmResizeController
extends RefCounted


func handle_notification(owner: Control, what: int) -> void:
	if what != Control.NOTIFICATION_RESIZED:
		return
	if owner.realm_layout == null:
		return

	var island_rect: Rect2 = owner._get_island_rect()
	_update_layout_dependent_visuals(owner, island_rect)


func _update_layout_dependent_visuals(
	owner: Control,
	island_rect: Rect2
) -> void:
	# Keep every visual tied to normalized realm layout positions aligned.
	owner.lava_realm_visual_controller.update_positions(
		owner.realm_layout,
		island_rect
	)
	owner.island_visual_controller.update(
		owner,
		owner.realm_layout,
		island_rect
	)
	owner.brazier_visual_controller.position_braziers(
		owner.braziers,
		owner.BRAZIER_STATS,
		owner.realm_layout,
		island_rect
	)
	owner.crystallized_flame_visual_controller.reposition(owner)
