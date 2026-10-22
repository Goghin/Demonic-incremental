class_name RelicSlotControl
extends Button

signal equipment_changed

const SLOT_SIZE := Vector2(34.0, 34.0)

var state: GameState
var slot_kind: String = "inventory"
var generator_id: String = ""
var slot_index: int = 0
var instance_id: String = ""


func configure(
	game_state: GameState,
	kind: String,
	relic_instance_id: String = "",
	target_generator_id: String = "",
	target_slot_index: int = 0
) -> void:
	state = game_state
	slot_kind = kind
	instance_id = relic_instance_id
	generator_id = target_generator_id
	slot_index = target_slot_index
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
		tooltip_text = (
			str(definition.get("display_name", "Relic")) + "\n" + str(definition.get("description", ""))
			if not relic.is_empty()
			else "Empty inventory slot"
		)
		style.bg_color = Color(0.19, 0.105, 0.075, 1.0) if not relic.is_empty() else Color(0.08, 0.07, 0.08, 1.0)
		style.border_color = Color(0.78, 0.38, 0.18, 1.0) if not relic.is_empty() else Color(0.28, 0.23, 0.25, 1.0)
	else:
		instance_id = state.relic_manager.get_equipped_relic_id(generator_id, slot_index)
		var relic: Dictionary = state.relic_manager.get_relic(instance_id)
		var definition: Dictionary = state.relic_manager.get_definition(
			str(relic.get("definition_id", ""))
		)
		text = _get_relic_glyph(str(definition.get("family", ""))) if not relic.is_empty() else "+"
		tooltip_text = (
			str(definition.get("display_name", "Relic")) + "\n" + str(definition.get("description", ""))
			if not relic.is_empty()
			else "Drop a relic here"
		)
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
	if slot_kind == "inventory":
		dragged_instance_id = state.relic_manager.get_inventory_relic_id_at_slot(slot_index)
	elif slot_kind == "generator":
		dragged_instance_id = state.relic_manager.get_equipped_relic_id(generator_id, slot_index)
	if dragged_instance_id == "":
		return null

	var relic: Dictionary = state.relic_manager.get_relic(dragged_instance_id)
	if relic.is_empty():
		return null

	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(42.0, 42.0)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	preview.top_level = true

	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.22, 0.12, 0.08, 0.96)
	preview_style.border_color = Color(1.0, 0.58, 0.25, 1.0)
	preview_style.set_border_width_all(2)
	preview_style.set_corner_radius_all(4)
	preview_style.shadow_color = Color(0.0, 0.0, 0.0, 0.85)
	preview_style.shadow_size = 6
	preview.add_theme_stylebox_override("panel", preview_style)

	var preview_glyph := Label.new()
	preview_glyph.text = _get_relic_glyph(str(state.relic_manager.get_definition(
		str(relic.get("definition_id", ""))
	).get("family", ""))
	preview_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_glyph.add_theme_font_size_override("font_size", 23)
	preview_glyph.add_theme_color_override("font_color", Color(1.0, 0.76, 0.43))
	preview.add_child(preview_glyph)
	set_drag_preview(preview)

	return {
		"type": "relic",
		"instance_id": dragged_instance_id,
		"source_kind": slot_kind,
		"source_generator_id": generator_id,
		"source_slot_index": slot_index
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
		var source_kind := str(data.get("source_kind", ""))
		if source_kind == "inventory":
			return true
		if source_kind == "generator":
			return state.relic_manager.get_inventory_relic_id_at_slot(slot_index) == ""
		return false
	return (
		state.get_generator(generator_id) != null
		and slot_index < state.eternal_flame_upgrade_manager.get_relic_slot_count(
			generator_id,
			state.eternal_flame_state
		)
	)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if state == null or not data is Dictionary:
		return

	var dragged_instance_id := str(data.get("instance_id", ""))
	var source_kind := str(data.get("source_kind", ""))
	var source_generator_id := str(data.get("source_generator_id", ""))
	var source_slot_index := int(data.get("source_slot_index", 0))

	if slot_kind == "inventory":
		if source_kind == "generator" and source_generator_id != "":
			if not state.relic_manager.move_relic_to_inventory(dragged_instance_id, slot_index):
				return
			state.relic_manager.unequip_relic(source_generator_id, source_slot_index)
		elif source_kind == "inventory":
			if not state.relic_manager.move_relic_to_inventory(dragged_instance_id, slot_index):
				return
	elif slot_kind == "generator":
		if dragged_instance_id == "":
			return
		if source_kind == "generator" and source_generator_id == generator_id and source_slot_index == slot_index:
			return

		var target_relic_id := state.relic_manager.get_equipped_relic_id(generator_id, slot_index)
		var is_generator_move := source_kind == "generator" and source_generator_id != ""
		if is_generator_move and target_relic_id != "":
			# Swapping occupied slots is supported both within and across generators.
			state.relic_manager.unequip_relic(source_generator_id, source_slot_index)
			state.relic_manager.unequip_relic(generator_id, slot_index)
			if not state.relic_manager.equip_relic(generator_id, dragged_instance_id, state, slot_index):
				state.relic_manager.equip_relic(source_generator_id, dragged_instance_id, state, source_slot_index)
				return
			if not state.relic_manager.equip_relic(source_generator_id, target_relic_id, state, source_slot_index):
				state.relic_manager.unequip_relic(generator_id, slot_index)
				state.relic_manager.equip_relic(source_generator_id, dragged_instance_id, state, source_slot_index)
				return
		elif not state.relic_manager.equip_relic(generator_id, dragged_instance_id, state, slot_index):
			return

	state.rebuild_relic_modifiers()
	equipment_changed.emit()
