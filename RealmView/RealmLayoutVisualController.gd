class_name RealmLayoutVisualController
extends RefCounted


func update_positions(
	owner: Control,
	island_rect: Rect2
) -> void:
	if owner.realm_layout == null:
		return

	# Keep layout-bound visuals aligned when the Control changes size.
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
