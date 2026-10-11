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

	# Generator sprites and hitboxes use absolute Control coordinates, so they
	# must be recalculated whenever the layout's island rectangle changes.
	owner._draw_generators()

	# Ash piles are layout-bound too; refresh their position and scale alongside
	# the island instead of waiting for the next resource update.
	if owner.state != null:
		owner._update_ash_piles(
			owner.state.get_resource_amount(ResourceIds.ASH)
		)

	position_braziers(owner, island_rect)
	owner.crystallized_flame_visual_controller.reposition(owner)


func position_braziers(
	owner: Control,
	island_rect: Rect2
) -> void:
	if owner.realm_layout == null:
		return

	owner.brazier_visual_controller.position_braziers(
		owner.braziers,
		owner.BRAZIER_STATS,
		owner.realm_layout,
		island_rect
	)
