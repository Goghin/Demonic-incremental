class_name RelicSlotControl
extends Button

signal equipment_changed

const SLOT_SIZE := Vector2(34.0, 34.0)

var state: GameState
var slot_kind: String = "inventory"
var generator_id: String = ""
var instance_id: String = ""


func configure(
	game_state: GameState,
	kind: String,
	relic_instance_id: String = "",
	target_generator_id: String = ""
) -> void:
	state = game_state
	slot_kind = kind
	instance_id = relic_instance_id
	generator_id = target_generator_id
	custom_minimum_size = SLOT_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	flat = false
	focus_mode = Control.FOCUS_NONE
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	_update_appearance()


func refresh_slot() -> void:
	_update_appearance()


func _update_appearance() -> void:
	if state == null:
		return

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.095, 0.11, 1.0)
	style.border_color = Color(0.34, 0.25, 0.27, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 2.0
	style.content_margin_top = 2.0
	style.content_margin_right = 2.0
	style.content_margin_bottom = 2.0

	if slot_kind == "inventory":
		var relic: Dictionary = state.relic_manager.get_relic(instance_id)
		var definition: Dictionary = state.relic_manager.get_definition(
			str(relic.get("definition_id", ""))
		)
		text = _get_relic_glyph(str(definition.get("family", ""))) if not relic.is_empty() else ""
		tooltip_text = str(definition.get("display_name", "Relic")) + "\n" + str(definition.get("description", "")) if not relic.is_empty() else "Empty inventory slot"
		disabled = false
		style.bg_color = Color(0.19, 0.105, 0.075, 1.0) if not relic.is_empty() else Color(0.08, 0.07, 0.08, 1.0)
		style.border_color = Color(0.78, 0.38, 0.18, 1.0) if not relic.is_empty() else Color(0.28, 0.23, 0.25, 1.0)
	else:
		var equipped_id := state.relic_manager.get_equipped_relic_id(generator_id)
		var relic: Dictionary = state.relic_manager.get_relic(equipped_id)
		var definition: Dictionary = state.relic_manager.get_definition(
			str(relic.get("definition_id", ""))
		)
		instance_id = equipped_id
		text = _get_relic_glyph(str(definition.get("family", ""))) if not relic.is_empty() else "+"
		tooltip_text = str(definition.get("display_name", "Relic")) + "\n" + str(definition.get("description", "")) if not relic.is_empty() else "Drop a relic here"
		disabled = false
		style.bg_color = Color(0.19, 0.105, 0.075, 1.0) if not relic.is_empty() else Color(0.08, 0.07, 0.08, 1.0)
		style.border_color = Color(0.78, 0.38, 0.18, 1.0) if not relic.is_empty() else Color(0.38, 0.29, 0.30, 1.0)

	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	add_theme_color_override("font_color", Color(1.0, 0.68, 0.36))
	add_theme_color_override("font_hover_color", Color(1.0, 0.86, 0.64))
	add_theme_font_size_override("font_size", 17)


func _get_relic_glyph(family: String) -> String:
	match family:
		"production":
			return "◆"
		"cycle_speed":
			return "◈"
		"input_efficiency":
			return "◇"
	return "✦"


func _get_drag_data(_at_position: Vector2) -> Variant:
	if state == null:
		return null

	var dragged_instance_id := instance_id
	if slot_kind == "generator":
		dragged_instance_id = state.relic_manager.get_equipped_relic_id(generator_id)
	if dragged_instance_id == "":
		return null

	var relic: Dictionary = state.relic_manager.get_relic(dragged_instance_id)
	if relic.is_empty():
		return null

	var preview := Label.new()
	preview.text = text
	preview.add_theme_font_size_override("font_size", 22)
	preview.add_theme_color_override("font_color", Color(1.0, 0.68, 0.36))
	preview.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	preview.add_theme_constant_override("shadow_offset_x", 1)
	preview.add_theme_constant_override("shadow_offset_y", 1)
	set_drag_preview(preview)

	return {
		"type": "relic",
		"instance_id": dragged_instance_id,
		"source_kind": slot_kind,
		"source_generator_id": generator_id
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if state == null or not data is Dictionary:
		return false
	if str(data.get("type", "")) != "relic":
		return false
	var dragged_instance_id := str(data.get("instance_id", ""))
	if state.relic_manager.get_relic(dragged_instance_id).is_empty():
		return false
	if slot_kind == "inventory":
		return true
	return state.eternal_flame_upgrade_manager.get_relic_slot_count(
		generator_id,
		state.eternal_flame_state
	) > 0


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if state == null or not data is Dictionary:
		return

	var dragged_instance_id := str(data.get("instance_id", ""))
	var source_kind := str(data.get("source_kind", ""))
	var source_generator_id := str(data.get("source_generator_id", ""))

	if slot_kind == "inventory":
		if source_kind == "generator" and source_generator_id != "":
			state.relic_manager.unequip_relic(source_generator_id)
	elif slot_kind == "generator":
		if dragged_instance_id == "":
			return
		# equip_relic moves a relic out of its previous generator and replaces
		# any relic in this slot, returning the displaced relic to inventory.
		if not state.relic_manager.equip_relic(generator_id, dragged_instance_id, state):
			return

	state.rebuild_relic_modifiers()
	equipment_changed.emit()
