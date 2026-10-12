class_name RealmLayoutOverlayDrawController
extends RefCounted


func draw_overlay(
	owner: Control,
	generator_hitboxes: Dictionary,
	ash_piles: Array[Sprite2D],
	braziers: Dictionary,
	brazier_stats: Array[String],
	selected_object: String,
	realm_layout: RealmLayout,
	island_rect: Rect2
) -> void:
	owner.draw_rect(
		Rect2(Vector2.ZERO, owner.size),
		Color(1.0, 0.75, 0.20, 0.65),
		false,
		2.0
	)

	_draw_editor_help(owner, selected_object)
	_draw_flow_handles(owner, realm_layout, island_rect, selected_object)
	_draw_lake_edge_handles(owner, realm_layout, island_rect, selected_object)

	for generator_id in generator_hitboxes:
		var hitbox: Rect2 = generator_hitboxes[generator_id]
		var is_generator_selected: bool = selected_object == generator_id
		var outline_color: Color = Color(1.0, 0.95, 0.55, 1.0) if is_generator_selected else Color(1.0, 0.75, 0.20, 0.75)
		owner.draw_rect(
			hitbox.grow(5.0 if is_generator_selected else 3.0),
			outline_color,
			false,
			2.0 if is_generator_selected else 1.0
		)

	for i in range(ash_piles.size()):
		var pile: Sprite2D = ash_piles[i]
		if not is_instance_valid(pile):
			continue

		owner.draw_circle(
			pile.position,
			12.0,
			Color(0.75, 0.75, 0.75, 0.2)
		)
		var pile_id: String = "ash_pile:" + str(i)
		var is_pile_selected: bool = selected_object == pile_id
		owner.draw_circle(
			pile.position,
			14.0 if not is_pile_selected else 18.0,
			Color(1.0, 0.95, 0.55, 1.0) if is_pile_selected else Color(0.85, 0.75, 0.55, 0.85),
			false,
			3.0 if is_pile_selected else 2.0
		)
		owner.draw_string(
			ThemeDB.fallback_font,
			pile.position + Vector2(4.0, -7.0),
			"A%d" % (i + 1),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			12,
			Color(1.0, 0.9, 0.7, 1.0)
		)

	for stat_name in brazier_stats:
		if not braziers.has(stat_name):
			continue

		var brazier: Control = braziers[stat_name]
		if not is_instance_valid(brazier):
			continue

		var brazier_position: Vector2 = brazier.position

		owner.draw_circle(
			brazier_position,
			30.0,
			Color(1.0, 0.75, 0.20, 0.15)
		)
		var brazier_id: String = "brazier:" + stat_name
		var is_brazier_selected: bool = selected_object == brazier_id
		owner.draw_circle(
			brazier_position,
			32.0 if not is_brazier_selected else 38.0,
			Color(1.0, 0.95, 0.55, 1.0) if is_brazier_selected else Color(1.0, 0.75, 0.20, 0.75),
			false,
			3.0 if is_brazier_selected else 2.0
		)
		owner.draw_line(
			brazier_position + Vector2(-42, 0),
			brazier_position + Vector2(42, 0),
			Color(1.0, 0.75, 0.20, 0.50),
			1.0
		)
		owner.draw_line(
			brazier_position + Vector2(0, -42),
			brazier_position + Vector2(0, 42),
			Color(1.0, 0.75, 0.20, 0.50),
			1.0
		)



func _draw_editor_help(owner: Control, selected_object: String) -> void:
	var panel_rect: Rect2 = Rect2(14.0, 14.0, 270.0, 104.0)
	owner.draw_rect(panel_rect, Color(0.04, 0.03, 0.02, 0.88), true)
	owner.draw_rect(panel_rect, Color(1.0, 0.75, 0.20, 0.9), false, 1.0)
	var lines: Array[String] = [
		"REALM LAYOUT EDITOR",
		"Drag machines, braziers, ash piles, flow or lake handles",
		"Shift + click: print normalized point",
		"F2: close editor"
	]
	for i in range(lines.size()):
		owner.draw_string(
			ThemeDB.fallback_font,
			Vector2(24.0, 34.0 + i * 20.0),
			lines[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			13 if i == 0 else 11,
			Color(1.0, 0.88, 0.58, 1.0) if i == 0 else Color(0.92, 0.9, 0.84, 1.0)
		)
	if selected_object != "":
		owner.draw_string(
			ThemeDB.fallback_font,
			Vector2(24.0, 137.0),
			"Moving: " + selected_object,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			12,
			Color(1.0, 0.95, 0.55, 1.0)
		)



func _draw_flow_handles(
	owner: Control,
	realm_layout: RealmLayout,
	island_rect: Rect2,
	selected_object: String
) -> void:
	if realm_layout == null or island_rect.size.x <= 0.0 or island_rect.size.y <= 0.0:
		return

	for flow_index in range(realm_layout.lava_flow_definitions.size()):
		var definition: Dictionary = realm_layout.lava_flow_definitions[flow_index]
		if not definition.has("points"):
			continue
		var points: PackedVector2Array = definition["points"]
		if points.is_empty():
			continue

		var screen_points := PackedVector2Array()
		for normalized_point in points:
			screen_points.append(island_rect.position + island_rect.size * normalized_point)

		for point_index in range(screen_points.size()):
			var current: Vector2 = screen_points[point_index]
			if point_index > 0:
				owner.draw_line(
					screen_points[point_index - 1],
					current,
					Color(0.55, 0.45, 1.0, 0.8),
					2.0
				)

			var handle_id: String = "lava_flow:%d:%d" % [flow_index, point_index]
			var is_selected: bool = selected_object == handle_id
			owner.draw_circle(
				current,
				7.0 if is_selected else 5.0,
				Color(1.0, 0.95, 0.55, 1.0) if is_selected else Color(0.62, 0.48, 1.0, 1.0)
			)
			owner.draw_circle(
				current,
				7.0 if is_selected else 5.0,
				Color(0.08, 0.035, 0.16, 1.0),
				false,
				1.2
			)

func _draw_lake_edge_handles(
	owner: Control,
	realm_layout: RealmLayout,
	island_rect: Rect2,
	selected_object: String
) -> void:
	if realm_layout == null or island_rect.size.x <= 0.0 or island_rect.size.y <= 0.0:
		return

	var lake_count: int = 1 + realm_layout.small_lake_definitions.size()
	for lake_index in range(lake_count):
		var points: PackedVector2Array
		if lake_index == 0:
			points = realm_layout.main_lake_edge_points
		else:
			var definition: Dictionary = realm_layout.small_lake_definitions[lake_index - 1]
			if not definition.has("points"):
				continue
			points = definition["points"]

		if points.size() < 2:
			continue

		var screen_points := PackedVector2Array()
		for normalized_point in points:
			screen_points.append(island_rect.position + island_rect.size * normalized_point)

		for point_index in range(screen_points.size()):
			var current: Vector2 = screen_points[point_index]
			var next: Vector2 = screen_points[(point_index + 1) % screen_points.size()]
			owner.draw_line(current, next, Color(1.0, 0.28, 0.035, 0.65), 1.5)

			var handle_id: String = "lake_edge:%d:%d" % [lake_index, point_index]
			var is_selected: bool = selected_object == handle_id
			owner.draw_circle(
				current,
				7.0 if is_selected else 5.0,
				Color(1.0, 0.95, 0.55, 1.0) if is_selected else Color(1.0, 0.48, 0.08, 0.95)
			)
			owner.draw_circle(
				current,
				7.0 if is_selected else 5.0,
				Color(0.16, 0.045, 0.015, 1.0),
				false,
				1.2
			)
