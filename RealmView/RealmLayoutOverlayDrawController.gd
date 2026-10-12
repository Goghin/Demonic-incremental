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

	_draw_editor_help(owner, selected_object, realm_layout)
	_draw_flow_handles(owner, realm_layout, island_rect, selected_object)
	_draw_lake_edge_handles(owner, realm_layout, island_rect, selected_object)

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



func _draw_editor_help(owner: Control, selected_object: String, realm_layout: RealmLayout) -> void:
	var has_selection: bool = selected_object != ""
	var panel_alpha: float = 0.28 if has_selection else 1.0
	var panel_rect: Rect2 = Rect2(14.0, 14.0, 300.0, 160.0)
	owner.draw_rect(panel_rect, Color(0.04, 0.03, 0.02, 0.88 * panel_alpha), true)
	owner.draw_rect(panel_rect, Color(1.0, 0.75, 0.20, 0.9 * panel_alpha), false, 1.0)
	var lines: Array[String] = [
		"REALM LAYOUT EDITOR",
		"Drag machines, braziers, ash piles, flow or lake handles",
		"Select flow point, then +/- to change width",
		"Shift + click: print normalized point",
		"F2: close editor"
	]
	for i in range(lines.size()):
		owner.draw_string(
			ThemeDB.fallback_font,
			Vector2(24.0, 34.0 + i * 17.0),
			lines[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			13 if i == 0 else 11,
			Color(1.0, 0.88, 0.58, 1.0) if i == 0 else Color(0.92, 0.9, 0.84, 0.28 if has_selection else 1.0)
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
								Vector2(24.0, 158.0),
								"Width at point %d: %.1f" % [point_index + 1, widths[point_index]],
								HORIZONTAL_ALIGNMENT_LEFT,
								-1.0,
								12,
								Color(0.78, 0.68, 1.0, 1.0)
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
					Color(0.55, 0.45, 1.0, 0.08 if selected_object != "" else 0.8),
					2.0
				)

			var handle_id: String = "lava_flow:%d:%d" % [flow_index, point_index]
			var is_selected: bool = selected_object == handle_id
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
				_draw_flow_handle_circle(owner, current, false, selected_object == "")

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
			owner.draw_line(
				current,
				next,
				Color(1.0, 0.28, 0.035, 0.06 if selected_object != "" else 0.65),
				1.5
			)

			var handle_id: String = "lake_edge:%d:%d" % [lake_index, point_index]
			var is_selected: bool = selected_object == handle_id
			owner.draw_circle(
				current,
				7.0 if is_selected else 5.0,
				Color(1.0, 0.95, 0.55, 1.0) if is_selected else Color(1.0, 0.48, 0.08, 0.08 if selected_object != "" else 0.95)
			)
			owner.draw_circle(
				current,
				7.0 if is_selected else 5.0,
				Color(0.16, 0.045, 0.015, 1.0 if is_selected or selected_object == "" else 0.08),
				false,
				1.2
			)
