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
	var has_selection: bool = selected_object != ""
	var inactive_alpha: float = 0.07 if has_selection else 1.0

	owner.draw_rect(
		Rect2(Vector2.ZERO, owner.size),
		Color(1.0, 0.75, 0.20, 0.08 if has_selection else 0.65),
		false,
		2.0
	)

	_draw_editor_help(owner, selected_object, realm_layout, island_rect)
	_draw_flow_handles(owner, realm_layout, island_rect, selected_object)
	_draw_lake_edge_handles(owner, realm_layout, island_rect, selected_object)
	_draw_main_lake_center_handle(owner, realm_layout, island_rect, selected_object)

	for generator_id in generator_hitboxes:
		var hitbox: Rect2 = generator_hitboxes[generator_id]
		var is_generator_selected: bool = selected_object == generator_id
		var outline_color: Color = Color(1.0, 0.95, 0.55, 1.0) if is_generator_selected else Color(1.0, 0.75, 0.20, 0.75 * inactive_alpha)
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

		var pile_id: String = "ash_pile:" + str(i)
		var is_pile_selected: bool = selected_object == pile_id
		owner.draw_circle(
			pile.position,
			12.0,
			Color(0.75, 0.75, 0.75, 0.2 * inactive_alpha)
		)
		owner.draw_circle(
			pile.position,
			14.0 if not is_pile_selected else 18.0,
			Color(1.0, 0.95, 0.55, 1.0) if is_pile_selected else Color(0.85, 0.75, 0.55, 0.85 * inactive_alpha),
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
			Color(1.0, 0.9, 0.7, 1.0 if is_pile_selected else inactive_alpha)
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
			Color(1.0, 0.75, 0.20, 0.15 * inactive_alpha)
		)
		var brazier_id: String = "brazier:" + stat_name
		var is_brazier_selected: bool = selected_object == brazier_id
		owner.draw_circle(
			brazier_position,
			32.0 if not is_brazier_selected else 38.0,
			Color(1.0, 0.95, 0.55, 1.0) if is_brazier_selected else Color(1.0, 0.75, 0.20, 0.75 * inactive_alpha),
			false,
			3.0 if is_brazier_selected else 2.0
		)
		owner.draw_line(
			brazier_position + Vector2(-42, 0),
			brazier_position + Vector2(42, 0),
			Color(1.0, 0.75, 0.20, 0.50 * inactive_alpha),
			1.0
		)
		owner.draw_line(
			brazier_position + Vector2(0, -42),
			brazier_position + Vector2(0, 42),
			Color(1.0, 0.75, 0.20, 0.50 * inactive_alpha),
			1.0
		)



func _draw_editor_help(
	owner: Control,
	selected_object: String,
	realm_layout: RealmLayout,
	island_rect: Rect2
) -> void:
	# Keep the instructions readable while object overlays are dimmed.
	var panel_alpha: float = 1.0
	var panel_rect: Rect2 = Rect2(14.0, 14.0, 450.0, 360.0)
	owner.draw_rect(panel_rect, Color(0.04, 0.03, 0.02, 0.88 * panel_alpha), true)
	owner.draw_rect(panel_rect, Color(1.0, 0.75, 0.20, 0.9 * panel_alpha), false, 1.0)
	var lines: Array[String] = [
		"REALM LAYOUT EDITOR",
		"Drag machines, braziers, ash piles, flow or lake handles",
		"Drag the gold diamond to move the main lake origin",
		"Select a flow point, then +/- to change its width",
		"Ctrl + click flow/lake edge: insert a point",
		"Delete / Backspace: remove selected flow/lake point",
		"Selected flow endpoint: edit waterfall",
		"Hold Left/Right: adjust waterfall width",
		"Hold Up/Down: adjust waterfall length",
		"Shift + arrows: nudge selected item by 2 px",
		"Shift + click: print normalized position",
		"Ctrl + Shift + I: load an island image",
		"Ctrl + Shift + L: cycle available layouts",
		"Ctrl + +/-: scale island and layout",
		"Ctrl + Shift + arrows: move island and layout",
		"Ctrl + Shift + S: save/export layout source",
		"Game save: Options > Save Game; loads on startup",
		"F2: close editor; Esc: clear selection"
	]
	for i in range(lines.size()):
		owner.draw_string(
			ThemeDB.fallback_font,
			Vector2(24.0, 32.0 + i * 13.0),
			lines[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			13 if i == 0 else 11,
			Color(1.0, 0.88, 0.58, 1.0) if i == 0 else Color(0.92, 0.9, 0.84, 1.0)
		)
	if selected_object != "":
		owner.draw_string(
			ThemeDB.fallback_font,
			Vector2(24.0, 260.0),
			"Moving: " + selected_object,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			12,
			Color(1.0, 0.95, 0.55, 1.0)
		)
		if selected_object.begins_with("lava_flow:"):
			var parts: PackedStringArray = selected_object.split(":")
			if parts.size() == 3:
				var flow_index: int = int(parts[1])
				var point_index: int = int(parts[2])
				if flow_index >= 0 and flow_index < realm_layout.lava_flow_definitions.size():
					var definition: Dictionary = realm_layout.lava_flow_definitions[flow_index]
					if definition.has("widths"):
						var widths: PackedFloat32Array = definition["widths"]
						if point_index >= 0 and point_index < widths.size():
							owner.draw_string(
								ThemeDB.fallback_font,
								Vector2(24.0, 280.0),
								"Width at point %d: %.1f" % [point_index + 1, widths[point_index]],
								HORIZONTAL_ALIGNMENT_LEFT,
								-1.0,
								12,
								Color(0.78, 0.68, 1.0, 1.0)
							)

						var points: PackedVector2Array = definition.get("points", PackedVector2Array())
						if point_index == points.size() - 1 and point_index >= 0:
							var fall_width: float = float(definition.get("fall_width", 4.0))
							var fall_length: float = float(definition.get("fall_length", 60.0))
							owner.draw_string(
								ThemeDB.fallback_font,
								Vector2(24.0, 298.0),
								"Fall width: %.1f   length: %.1f" % [fall_width, fall_length],
								HORIZONTAL_ALIGNMENT_LEFT,
								-1.0,
								12,
								Color(1.0, 0.58, 0.28, 1.0)
							)
		elif selected_object.begins_with("lake_edge:"):
			var lake_parts: PackedStringArray = selected_object.split(":")
			if lake_parts.size() == 3:
				var lake_index: int = int(lake_parts[1])
				var point_index: int = int(lake_parts[2])
				var lake_points: PackedVector2Array = PackedVector2Array()
				var lake_name: String = "Main lake"
				if lake_index == 0:
					lake_points = realm_layout.main_lake_edge_points
				elif lake_index > 0 and lake_index <= realm_layout.small_lake_definitions.size():
					var definition: Dictionary = realm_layout.small_lake_definitions[lake_index - 1]
					lake_name = "Small lake %d" % lake_index
					lake_points = definition.get("points", PackedVector2Array())
				if point_index >= 0 and point_index < lake_points.size():
					owner.draw_string(
						ThemeDB.fallback_font,
						Vector2(24.0, 186.0),
						"%s - point %d of %d" % [lake_name, point_index + 1, lake_points.size()],
						HORIZONTAL_ALIGNMENT_LEFT,
						-1.0,
						12,
						Color(1.0, 0.82, 0.32, 1.0)
					)
					owner.draw_string(
						ThemeDB.fallback_font,
						Vector2(24.0, 207.0),
						"Delete keeps at least 3 outline points",
						HORIZONTAL_ALIGNMENT_LEFT,
						-1.0,
						12,
						Color(0.92, 0.9, 0.84, 1.0)
					)



		var normalized_position: Vector2 = _get_selected_normalized_position(
			selected_object,
			realm_layout
		)
		if normalized_position != Vector2(-1.0, -1.0) and island_rect.size.x > 0.0 and island_rect.size.y > 0.0:
			owner.draw_string(
				ThemeDB.fallback_font,
				Vector2(24.0, 322.0),
				"Normalized: (%.4f, %.4f)" % [normalized_position.x, normalized_position.y],
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				12,
				Color(0.72, 0.92, 1.0, 1.0)
			)
		elif selected_object != "":
			owner.draw_string(
				ThemeDB.fallback_font,
				Vector2(24.0, 227.0),
				"Normalized position unavailable",
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				11,
				Color(0.75, 0.72, 0.68, 1.0)
			)


func _get_selected_normalized_position(
	selected_object: String,
	realm_layout: RealmLayout
) -> Vector2:
	if realm_layout == null or selected_object == "":
		return Vector2(-1.0, -1.0)

	if selected_object == "lake_center":
		return _get_main_lake_center(realm_layout)

	if selected_object.begins_with("lava_flow:"):
		var parts: PackedStringArray = selected_object.split(":")
		if parts.size() != 3:
			return Vector2(-1.0, -1.0)
		var flow_index: int = int(parts[1])
		var point_index: int = int(parts[2])
		if flow_index < 0 or flow_index >= realm_layout.lava_flow_definitions.size():
			return Vector2(-1.0, -1.0)
		var points: PackedVector2Array = realm_layout.lava_flow_definitions[flow_index].get("points", PackedVector2Array())
		if point_index < 0 or point_index >= points.size():
			return Vector2(-1.0, -1.0)
		return points[point_index]

	if selected_object.begins_with("lake_edge:"):
		var parts: PackedStringArray = selected_object.split(":")
		if parts.size() != 3:
			return Vector2(-1.0, -1.0)
		var lake_index: int = int(parts[1])
		var point_index: int = int(parts[2])
		var points: PackedVector2Array
		if lake_index == 0:
			points = realm_layout.main_lake_edge_points
		else:
			var definition_index: int = lake_index - 1
			if definition_index < 0 or definition_index >= realm_layout.small_lake_definitions.size():
				return Vector2(-1.0, -1.0)
			points = realm_layout.small_lake_definitions[definition_index].get("points", PackedVector2Array())
		if point_index < 0 or point_index >= points.size():
			return Vector2(-1.0, -1.0)
		return points[point_index]

	if selected_object.begins_with("ash_pile:"):
		var pile_index: int = int(selected_object.substr(9))
		if pile_index < 0 or pile_index >= realm_layout.ash_pile_layout_positions.size():
			return Vector2(-1.0, -1.0)
		return realm_layout.ash_pile_layout_positions[pile_index]

	if selected_object.begins_with("brazier:"):
		var stat_name: String = selected_object.substr(8)
		if not realm_layout.brazier_layout_positions.has(stat_name):
			return Vector2(-1.0, -1.0)
		return realm_layout.brazier_layout_positions[stat_name]

	if realm_layout.generator_layout_positions.has(selected_object):
		return realm_layout.generator_layout_positions[selected_object]

	return Vector2(-1.0, -1.0)



func _draw_flow_handles(
	owner: Control,
	realm_layout: RealmLayout,
	island_rect: Rect2,
	selected_object: String
) -> void:
	if realm_layout == null or island_rect.size.x <= 0.0 or island_rect.size.y <= 0.0:
		return

	var selected_flow_index: int = -1
	if selected_object.begins_with("lava_flow:"):
		var selected_parts: PackedStringArray = selected_object.split(":")
		if selected_parts.size() == 3:
			selected_flow_index = int(selected_parts[1])

	for flow_index in range(realm_layout.lava_flow_definitions.size()):
		var definition: Dictionary = realm_layout.lava_flow_definitions[flow_index]
		if not definition.has("points"):
			continue
		var points: PackedVector2Array = definition["points"]
		if points.is_empty():
			continue

		var is_selected_flow: bool = selected_flow_index == flow_index
		var screen_points := PackedVector2Array()
		for normalized_point in points:
			screen_points.append(island_rect.position + island_rect.size * normalized_point)

		for point_index in range(screen_points.size()):
			var current: Vector2 = screen_points[point_index]
			if point_index > 0:
				var line_color: Color
				var line_width: float
				if is_selected_flow:
					line_color = Color(0.82, 0.68, 1.0, 1.0)
					line_width = 3.0
				else:
					line_color = Color(0.55, 0.45, 1.0, 0.08 if selected_object != "" else 0.8)
					line_width = 2.0
				owner.draw_line(
					screen_points[point_index - 1],
					current,
					line_color,
					line_width
				)

			var handle_id: String = "lava_flow:%d:%d" % [flow_index, point_index]
			var is_selected: bool = selected_object == handle_id
			if is_selected and point_index == screen_points.size() - 1:
				var fall_length: float = float(definition.get("fall_length", 60.0))
				var fall_width: float = float(definition.get("fall_width", 4.0))
				var fall_end: Vector2 = current + Vector2(0.0, fall_length)
				owner.draw_line(current, fall_end, Color(0.04, 0.015, 0.005, 0.95), maxf(6.0, fall_width + 4.0), true)
				owner.draw_line(current, fall_end, Color(1.0, 0.25, 0.035, 0.9), maxf(2.0, fall_width), true)
				owner.draw_circle(fall_end, 4.0, Color(1.0, 0.9, 0.55, 1.0))
			if is_selected and definition.has("widths"):
				var widths: PackedFloat32Array = definition["widths"]
				if widths.size() == screen_points.size():
					# The width cross-section replaces the usual selection circle.
					_draw_selected_flow_width_preview(owner, screen_points, widths, point_index)
				else:
					_draw_flow_handle_circle(owner, current, true)
			elif is_selected:
				_draw_flow_handle_circle(owner, current, true)
			else:
				_draw_flow_handle_circle(
					owner,
					current,
					false,
					selected_object == "" or is_selected_flow
				)

func _draw_flow_handle_circle(
	owner: Control,
	position: Vector2,
	is_selected: bool,
	fully_visible: bool = true
) -> void:
	var alpha: float = 1.0 if is_selected or fully_visible else 0.08
	owner.draw_circle(position, 5.0, Color(0.62, 0.48, 1.0, alpha))
	owner.draw_circle(position, 5.0, Color(0.08, 0.035, 0.16, alpha), false, 1.2)

func _draw_selected_flow_width_preview(
	owner: Control,
	screen_points: PackedVector2Array,
	widths: PackedFloat32Array,
	point_index: int
) -> void:
	if point_index < 0 or point_index >= screen_points.size() or point_index >= widths.size():
		return
	if screen_points.size() < 2:
		return

	var tangent: Vector2
	if point_index == 0:
		tangent = screen_points[1] - screen_points[0]
	elif point_index == screen_points.size() - 1:
		tangent = screen_points[point_index] - screen_points[point_index - 1]
	else:
		var incoming: Vector2 = (screen_points[point_index] - screen_points[point_index - 1]).normalized()
		var outgoing: Vector2 = (screen_points[point_index + 1] - screen_points[point_index]).normalized()
		tangent = incoming + outgoing
		if tangent.length_squared() <= 0.0001:
			tangent = outgoing

	if tangent.length_squared() <= 0.0001:
		return

	var normal: Vector2 = Vector2(-tangent.normalized().y, tangent.normalized().x)
	var center: Vector2 = screen_points[point_index]
	var half_width: float = maxf(2.0, widths[point_index] * 0.5)
	var start: Vector2 = center - normal * half_width
	var finish: Vector2 = center + normal * half_width

	# Dark backing keeps the width preview readable over lava and island art.
	owner.draw_line(start, finish, Color(0.025, 0.01, 0.06, 0.95), 7.0, true)
	owner.draw_line(start, finish, Color(0.72, 0.52, 1.0, 0.98), 3.0, true)
	owner.draw_circle(start, 3.0, Color(1.0, 0.91, 0.58, 1.0))
	owner.draw_circle(finish, 3.0, Color(1.0, 0.91, 0.58, 1.0))
	owner.draw_circle(center, 2.0, Color(0.08, 0.035, 0.16, 1.0))

func _draw_lake_edge_handles(
	owner: Control,
	realm_layout: RealmLayout,
	island_rect: Rect2,
	selected_object: String
) -> void:
	if realm_layout == null or island_rect.size.x <= 0.0 or island_rect.size.y <= 0.0:
		return

	var selected_lake_index: int = -1
	if selected_object.begins_with("lake_edge:"):
		var selected_parts: PackedStringArray = selected_object.split(":")
		if selected_parts.size() == 3:
			selected_lake_index = int(selected_parts[1])

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

		var is_selected_lake: bool = lake_index == selected_lake_index
		var inactive_alpha: float = 0.08 if selected_object != "" and not is_selected_lake else 1.0
		var outline_color: Color = (
			Color(1.0, 0.82, 0.32, 1.0)
			if is_selected_lake
			else Color(1.0, 0.28, 0.035, 0.65 * inactive_alpha)
		)
		var outline_width: float = 3.0 if is_selected_lake else 1.5
		var screen_points := PackedVector2Array()
		for normalized_point in points:
			screen_points.append(island_rect.position + island_rect.size * normalized_point)

		for point_index in range(screen_points.size()):
			var current: Vector2 = screen_points[point_index]
			var next: Vector2 = screen_points[(point_index + 1) % screen_points.size()]
			owner.draw_line(
				current,
				next,
				outline_color,
				outline_width
			)

			var handle_id: String = "lake_edge:%d:%d" % [lake_index, point_index]
			var is_selected: bool = selected_object == handle_id
			var handle_alpha: float = 1.0 if is_selected or is_selected_lake or selected_object == "" else 0.08
			owner.draw_circle(
				current,
				7.0 if is_selected else 5.0,
				Color(1.0, 0.95, 0.55, 1.0) if is_selected else Color(1.0, 0.48, 0.08, 0.95 * handle_alpha)
			)
			owner.draw_circle(
				current,
				7.0 if is_selected else 5.0,
				Color(0.16, 0.045, 0.015, handle_alpha),
				false,
				1.2
			)



func _draw_main_lake_center_handle(
	owner: Control,
	realm_layout: RealmLayout,
	island_rect: Rect2,
	selected_object: String
) -> void:
	if realm_layout == null or island_rect.size.x <= 0.0 or island_rect.size.y <= 0.0:
		return
	var normalized_center: Vector2 = _get_main_lake_center(realm_layout)
	var center: Vector2 = island_rect.position + island_rect.size * normalized_center
	var selected: bool = selected_object == "lake_center"
	var alpha: float = 1.0 if selected or selected_object == "" else 0.18
	var diamond := PackedVector2Array([
		center + Vector2(0.0, -9.0),
		center + Vector2(9.0, 0.0),
		center + Vector2(0.0, 9.0),
		center + Vector2(-9.0, 0.0)
	])
	owner.draw_colored_polygon(diamond, Color(1.0, 0.82, 0.18, alpha))
	for i in range(diamond.size()):
		owner.draw_line(diamond[i], diamond[(i + 1) % diamond.size()], Color(0.08, 0.035, 0.01, alpha), 1.5)
	if selected:
		owner.draw_string(
			ThemeDB.fallback_font,
			center + Vector2(12.0, -10.0),
			"LAKE ORIGIN",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			12,
			Color(1.0, 0.92, 0.55, 1.0)
		)


func _get_main_lake_center(realm_layout: RealmLayout) -> Vector2:
	if realm_layout.main_lake_center_position.x >= 0.0 and realm_layout.main_lake_center_position.y >= 0.0:
		return realm_layout.main_lake_center_position
	var center: Vector2 = Vector2.ZERO
	if realm_layout.main_lake_edge_points.is_empty():
		return Vector2(0.5, 0.5)
	for point in realm_layout.main_lake_edge_points:
		center += point
	return center / float(realm_layout.main_lake_edge_points.size())
