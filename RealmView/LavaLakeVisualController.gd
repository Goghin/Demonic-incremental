class_name LavaLakeVisualController
extends RefCounted


func create_lakes(
	owner: Node,
	state: GameState,
	realm_layout: RealmLayout,
	island_rect: Rect2,
	lake_scene: PackedScene,
	lava_lakes: Array[LavaLake]
) -> void:
	for lake in lava_lakes:
		if is_instance_valid(lake):
			lake.queue_free()

	lava_lakes.clear()

	var main_lake: LavaLake = lake_scene.instantiate()
	owner.add_child(main_lake)
	main_lake.z_index = 6

	main_lake.setup(
		realm_layout.main_lake_edge_points,
		island_rect
	)

	var overflow: float = (
		state.get_heat_leak_per_second() *
		state.get_overflow_crystallization_multiplier()
	)

	var threshold: float = state.realm_effects.heat_leak_threshold

	main_lake.set_heat(
		overflow,
		threshold
	)

	lava_lakes.append(main_lake)

	for definition in realm_layout.small_lake_definitions:
		var lake: LavaLake = lake_scene.instantiate()
		owner.add_child(lake)
		lake.z_index = 6

		lake.setup(
			definition["points"],
			island_rect
		)

		lake.set_fill(0.01)
		lava_lakes.append(lake)


func update_positions(
	island_rect: Rect2,
	lava_lakes: Array[LavaLake]
) -> void:
	for lake in lava_lakes:
		if not is_instance_valid(lake):
			continue

		lake.reposition(island_rect)
