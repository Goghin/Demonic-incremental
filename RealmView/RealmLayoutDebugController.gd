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
		if braziers.has(stat_name) and layout.brazier_layout_positions.has(stat_name):
			print(
				"Brazier ",
				stat_name,
				" -> ",
				layout.brazier_layout_positions[stat_name]
			)
		elif braziers.has(stat_name):
			print(
				"Brazier ",
				stat_name,
				" -> <missing layout position>"
			)

	if not lava_lakes.is_empty():
		var main_lake: LavaLake = lava_lakes[0]
		print("MAIN LAKE FILL: ", main_lake.fill)

	print("====================")
	print("Shift + Left Click = print normalized position")

func print_layout_point(
	mouse_position: Vector2,
	island_rect: Rect2
) -> void:
	if island_rect.size.x <= 0.0 or island_rect.size.y <= 0.0:
		print("Cannot print layout point: island bounds are not ready.")
		return

	var normalized_position: Vector2 = (
		(mouse_position - island_rect.position) /
		island_rect.size
	)

	print(
		"CLICKED POINT"
	)

	print(
		"Normalized -> Vector2(",
		"%.6f" % normalized_position.x,
		", ",
		"%.6f" % normalized_position.y,
		")"
	)

	print(
		"Island local -> Vector2(",
		"%.2f" % (mouse_position.x - island_rect.position.x),
		", ",
		"%.2f" % (mouse_position.y - island_rect.position.y)
	)

	print(
		"Screen/local -> ",
		mouse_position
	)


