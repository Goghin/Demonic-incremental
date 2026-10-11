class_name RealmLayoutOverlayDrawController
extends RefCounted


func draw_overlay(
	owner: Control,
	generator_hitboxes: Dictionary,
	ash_piles: Array[Sprite2D],
	braziers: Dictionary,
	brazier_stats: Array[String],
	selected_object: String
) -> void:
	owner.draw_rect(
		Rect2(Vector2.ZERO, owner.size),
		Color(1.0, 0.75, 0.20, 0.65),
		false,
		2.0
	)

	_draw_editor_help(owner, selected_object)

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
			Color(1.0, 0.95, 0.55, 1.0) if is_generator_selected else Color(1.0, 0.75, 0.20, 0.75),
			false,
			3.0 if is_pile_selected else 2.0
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
		"Drag a machine, brazier or ash pile",
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
