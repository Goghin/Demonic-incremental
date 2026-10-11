class_name RealmLayoutVisualController
extends RefCounted


func update_positions(owner: RealmView, island_rect: Rect2) -> void:
	if owner.realm_layout == null:
		return

	# Keep layout-bound visuals aligned across rebuilds and window resizes.
	owner.lava_realm_visual_controller.update_positions(
		owner.realm_layout,
		island_rect
	)
	owner.island_visual_controller.update(
		owner,
		owner.realm_layout,
		island_rect
	)

	# Generator sprites and hitboxes use absolute Control coordinates.
	owner._draw_generators(island_rect)

	# Ash piles must follow the island even if the resource amount is unchanged.
	if owner.state != null:
		owner.ash_visual_controller.update_piles(
			owner.realm_layout,
			island_rect,
			owner.state.get_resource_amount(ResourceIds.ASH)
		)

	owner.brazier_visual_controller.position_braziers(
		owner.braziers,
		owner.BRAZIER_STATS,
		owner.realm_layout,
		island_rect
	)
	owner.crystallized_flame_visual_controller.reposition(owner)
