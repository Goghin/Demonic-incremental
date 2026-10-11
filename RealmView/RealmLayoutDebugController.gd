class_name RealmLayoutDebugController
extends RefCounted


func print_layout_details(
	layout,
	braziers: Dictionary,
	brazier_stats: Array[String],
	lava_lakes: Array[LavaLake]
) -> void:
	print("=== REALM LAYOUT ===")

	print("--- Generators ---")

	for generator_id in layout.generator_layout_positions:
		print(
			"Generator ",
			generator_id,
			" -> ",
			layout.generator_layout_positions[generator_id]
		)

	print("--- Ash Piles ---")

	for i in range(layout.ash_pile_layout_positions.size()):
		print(
			"Ash pile ",
			i + 1,
			" -> ",
			layout.ash_pile_layout_positions[i]
		)

	print("--- Braziers ---")

	for stat_name in brazier_stats:
		if braziers.has(stat_name):
			print(
				"Brazier ",
				stat_name,
				" -> ",
				layout.brazier_layout_positions[stat_name]
			)

	if not lava_lakes.is_empty():
		var main_lake: LavaLake = lava_lakes[0]
		print("MAIN LAKE FILL: ", main_lake.fill)

	print("====================")
	print("Shift + Left Click = print normalized position")
