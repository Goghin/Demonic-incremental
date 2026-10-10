class_name LavaLakeStateController
extends RefCounted


func update(
	state: GameState,
	realm_layout: RealmLayout,
	lava_lakes: Array[LavaLake]
) -> void:
	if state == null or realm_layout == null:
		return

	if lava_lakes.is_empty():
		return

	var main_lake: LavaLake = lava_lakes[0]

	if not is_instance_valid(main_lake):
		return

	var overflow_rate: float = (
		state.get_heat_leak_per_second() *
		state.get_overflow_crystallization_multiplier()
	)

	main_lake.set_heat(
		overflow_rate,
		state.realm_effects.heat_leak_threshold
	)

	var main_fill: float = main_lake.fill

	for i in range(realm_layout.small_lake_definitions.size()):
		var lake_index: int = i + 1

		if lake_index >= lava_lakes.size():
			break

		var lake: LavaLake = lava_lakes[lake_index]

		if not is_instance_valid(lake):
			continue

		var definition: Dictionary = realm_layout.small_lake_definitions[i]

		var start_fill: float = definition["start_fill"]
		var full_fill: float = definition["full_fill"]

		var small_fill: float = 0.01

		if main_fill > start_fill:
			var fill_range: float = max(
				full_fill - start_fill,
				0.001
			)

			var progress: float = clamp(
				(main_fill - start_fill) / fill_range,
				0.0,
				1.0
			)

			small_fill = lerp(
				0.01,
				1.0,
				progress
			)

		lake.set_fill(small_fill)
