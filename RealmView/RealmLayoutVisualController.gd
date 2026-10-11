class_name RealmLayoutVisualController
extends RefCounted


func update_positions(
	visual_parent: Control,
	state: GameState,
	realm_layout: RealmLayout,
	island_rect: Rect2,
	lava_controller: LavaRealmVisualController,
	island_controller: IslandVisualController,
	draw_generators: Callable,
	ash_controller: AshVisualController,
	brazier_controller: BrazierVisualController,
	braziers: Dictionary,
	brazier_stats: Array[String],
	crystal_controller: CrystallizedFlameVisualController
) -> void:
	if realm_layout == null:
		return

	# Keep layout-bound visuals aligned across rebuilds and window resizes.
	lava_controller.update_positions(realm_layout, island_rect)
	island_controller.update(visual_parent, realm_layout, island_rect)

	# Generator sprites and hitboxes use absolute Control coordinates.
	draw_generators.call()

	# Ash piles must follow the island even if the resource amount is unchanged.
	if state != null:
		ash_controller.update_piles(
			realm_layout,
			island_rect,
			state.get_resource_amount(ResourceIds.ASH)
		)

	brazier_controller.position_braziers(
		braziers,
		brazier_stats,
		realm_layout,
		island_rect
	)
	crystal_controller.reposition(visual_parent)
