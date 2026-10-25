class_name RelicSlotControl
extends Button

signal equipment_changed

const SLOT_SIZE := Vector2(34.0, 34.0)

var state: GameState
var slot_kind: String = "inventory"
var generator_id: String = ""
var slot_index: int = 0
var instance_id: String = ""
var crafting_requirement: Dictionary = {}


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


# Use Godot's native tooltip sizing. The slot's tooltip_text is already populated
# with the relic name and current rolled description in _update_appearance().
func _make_custom_tooltip(_for_text: String) -> Object:
	if state == null:
		return null

	var relic: Dictionary = {}
	if slot_kind == "inventory":
		relic = state.relic_manager.get_inventory_entry_at_slot(slot_index)
	elif slot_kind == "crafting":
		relic = state.relic_manager.get_machine_entry_at_slot(generator_id, slot_index)
	elif slot_kind == "generator":
		relic = state.relic_manager.get_relic(
			state.relic_manager.get_equipped_relic_id(generator_id, slot_index)
		)
	if state.relic_manager.get_inventory_entry_type(relic) != "relic":
		return null

	var definition: Dictionary = state.relic_manager.get_relic_definition(relic)
	if definition.is_empty():
		return null

	var tier := int(definition.get("tier", 0))
	var rarity_name := str(definition.get("rarity_name", "Uncommon" if tier >= 2 else "Common" if tier == 1 else "Legacy"))
	var rarity_color := Color.from_string(str(definition.get("rarity_color", "")), _get_rarity_color(tier))
	var description := state.relic_manager.get_relic_description(relic)

	# Use a plain Control as the root so child label minimum sizes cannot
	# force Godot's tooltip popup to expand vertically. All layout is bounded
	# by this root; unlike the old version, there is no scroll container.
	var tooltip := Control.new()
	tooltip.name = "RelicTooltip"
	tooltip.custom_minimum_size = Vector2(280.0, 90.0)
	tooltip.size = tooltip.custom_minimum_size
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background := Panel.new()
	background.name = "Background"
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.045, 0.06, 0.98)
	panel_style.border_color = rarity_color.darkened(0.2)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(5)
	panel_style.content_margin_left = 10.0
	panel_style.content_margin_right = 10.0
	panel_style.content_margin_top = 8.0
	panel_style.content_margin_bottom = 8.0
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	panel_style.shadow_size = 5
	background.add_theme_stylebox_override("panel", panel_style)
	tooltip.add_child(background)

	var rarity_label := Label.new()
	rarity_label.text = rarity_name.to_upper()
	rarity_label.position = Vector2(10.0, 7.0)
	rarity_label.size = Vector2(258.0, 13.0)
	rarity_label.add_theme_font_size_override("font_size", 9)
	rarity_label.add_theme_color_override("font_color", rarity_color)
	rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.add_child(rarity_label)

	var title_label := Label.new()
	title_label.text = str(definition.get("display_name", "Relic"))
	title_label.position = Vector2(10.0, 21.0)
	title_label.size = Vector2(258.0, 21.0)
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", rarity_color)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.add_child(title_label)

	var separator := HSeparator.new()
	separator.position = Vector2(10.0, 45.0)
	separator.size = Vector2(258.0, 2.0)
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.add_child(separator)

	var description_label := RichTextLabel.new()
	description_label.text = description
	description_label.position = Vector2(10.0, 52.0)
	# Keep the label constrained to the tooltip's inner width. fit_content=true
	# lets RichTextLabel expand horizontally to its unwrapped text width.
	description_label.custom_minimum_size = Vector2(258.0, 0.0)
	description_label.size = Vector2(258.0, 0.0)
	description_label.fit_content = false
	description_label.scroll_active = false
	description_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	description_label.add_theme_font_size_override("normal_font_size", 11)
	description_label.add_theme_color_override("default_color", Color(0.86, 0.82, 0.78))
	description_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.add_child(description_label)

	# Let RichTextLabel lay out the description and use its actual content
	# height directly. No estimated line counts or arbitrary maximum height.
	var description_height := maxf(18.0, description_label.get_content_height() + 6.0)
	description_label.custom_minimum_size.y = description_height
	description_label.size.y = description_height
	var tooltip_height := 62.0 + description_height
	tooltip.custom_minimum_size = Vector2(280.0, tooltip_height)
	tooltip.size = tooltip.custom_minimum_size
	return tooltip


func _get_rarity_color(tier: int) -> Color:
	if tier >= 2:
		return Color(0.38, 0.70, 1.0)
	if tier == 1:
		return Color(0.38, 0.85, 0.48)
	return Color(1.0, 0.68, 0.36)


func _update_appearance() -> void:
	if state == null:
		return

	# Inventory slots are positional, so resolve their current relic from the slot index.
	# configure() intentionally does not receive a relic ID for these fixed squares.
	var inventory_entry: Dictionary = {}
	if slot_kind == "inventory":
		inventory_entry = state.relic_manager.get_inventory_entry_at_slot(slot_index)
		instance_id = str(inventory_entry.get("instance_id", ""))
	elif slot_kind == "crafting":
		inventory_entry = state.relic_manager.get_machine_entry_at_slot(generator_id, slot_index)
		instance_id = str(inventory_entry.get("instance_id", ""))

	var slot_font_size := 17
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.095, 0.11, 1.0)
	style.border_color = Color(0.34, 0.25, 0.27, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 2.0
	style.content_margin_top = 2.0
	style.content_margin_right = 2.0
	style.content_margin_bottom = 2.0

	if slot_kind == "inventory" or slot_kind == "crafting":
		var entry_type := state.relic_manager.get_inventory_entry_type(inventory_entry)
		if entry_type == "relic":
			var definition: Dictionary = state.relic_manager.get_relic_definition(inventory_entry)
			text = _get_relic_glyph(str(definition.get("family", "")))
			tooltip_text = str(definition.get("display_name", "Relic")) + "\n" + state.relic_manager.get_relic_description(inventory_entry)
		elif entry_type == "stackable":
			var item_definition: Dictionary = state.relic_manager.get_stackable_item_definition(
				str(inventory_entry.get("item_id", ""))
			)
			text = str(item_definition.get("glyph", "◆")) + "\n" + str(inventory_entry.get("quantity", 0))
			slot_font_size = 10
			tooltip_text = (
				str(item_definition.get("display_name", "Item"))
				+ " ×"
				+ str(inventory_entry.get("quantity", 0))
				+ "\n"
				+ str(item_definition.get("description", ""))
			)
		else:
			text = ""
			tooltip_text = "Empty inventory slot"
		var occupied := entry_type != ""
		if slot_kind == "crafting":
			tooltip_text = ("Crafting input: " + tooltip_text) if occupied else "Drop an ingredient here"
			var required_item_id := str(crafting_requirement.get("item_id", ""))
			var required_type := str(crafting_requirement.get("item_type", ""))
			var required_name := "Relic" if required_type == "relic" else "Ingredient"
			if required_item_id != "":
				var stack_definition := state.relic_manager.get_stackable_item_definition(required_item_id)
				var relic_definition := state.relic_manager.get_definition(required_item_id)
				if not stack_definition.is_empty():
					required_name = str(stack_definition.get("display_name", required_item_id))
				elif not relic_definition.is_empty():
					required_name = str(relic_definition.get("display_name", required_item_id))
			var required_quantity := maxi(1, int(crafting_requirement.get("quantity", 1)))
			tooltip_text += "\nRecipe: %s ×%d" % [required_name, required_quantity]
		style.bg_color = Color(0.19, 0.105, 0.075, 1.0) if occupied else Color(0.08, 0.07, 0.08, 1.0)
		style.border_color = Color(0.78, 0.38, 0.18, 1.0) if occupied else Color(0.28, 0.23, 0.25, 1.0)
	else:
		instance_id = state.relic_manager.get_equipped_relic_id(generator_id, slot_index)
		var relic: Dictionary = state.relic_manager.get_relic(instance_id)
		var definition: Dictionary = state.relic_manager.get_relic_definition(relic)
		text = _get_relic_glyph(str(definition.get("family", ""))) if not relic.is_empty() else "+"
		tooltip_text = (
			str(definition.get("display_name", "Relic")) + "\n" + state.relic_manager.get_relic_description(relic)
			if not relic.is_empty()
			else "Drop a relic here"
		)
		var equipment_locked := _is_generator_equipment_locked()
		if equipment_locked:
			text = "×" if relic.is_empty() else text
			tooltip_text = "Relic equipment is locked until this cycle completes.\n" + tooltip_text
			style.bg_color = Color(0.10, 0.085, 0.09, 1.0)
			style.border_color = Color(0.32, 0.27, 0.29, 1.0)
		else:
			style.bg_color = Color(0.19, 0.105, 0.075, 1.0) if not relic.is_empty() else Color(0.08, 0.07, 0.08, 1.0)
			style.border_color = Color(0.78, 0.38, 0.18, 1.0) if not relic.is_empty() else Color(0.38, 0.29, 0.30, 1.0)

	add_theme_stylebox_override("normal", style)
	add_theme_stylebox_override("hover", style)
	add_theme_stylebox_override("pressed", style)
	var rarity := ""
	var rarity_definition: Dictionary = {}
	var relic_for_rarity: Dictionary = inventory_entry
	if slot_kind != "inventory" and slot_kind != "crafting":
		relic_for_rarity = state.relic_manager.get_relic(instance_id)
	if not relic_for_rarity.is_empty():
		rarity_definition = state.relic_manager.get_relic_definition(relic_for_rarity)
		var rarity_tier := int(rarity_definition.get("tier", 0))
		rarity = str(rarity_definition.get("rarity_name", "common" if rarity_tier == 1 else "uncommon" if rarity_tier >= 2 else "")).to_lower()
	var rarity_color := Color(1.0, 0.68, 0.36)
	if not rarity_definition.is_empty():
		rarity_color = Color.from_string(str(rarity_definition.get("rarity_color", "")), _get_rarity_color(int(rarity_definition.get("tier", 0))))
	if rarity != "" and not relic_for_rarity.is_empty():
		style.border_color = rarity_color
		add_theme_stylebox_override("normal", style)
		add_theme_stylebox_override("hover", style)
		add_theme_stylebox_override("pressed", style)
	add_theme_color_override("font_color", rarity_color if rarity != "" else Color(1.0, 0.68, 0.36))
	add_theme_color_override("font_hover_color", Color(1.0, 0.86, 0.64))
	add_theme_font_size_override("font_size", slot_font_size)


func _is_generator_equipment_locked() -> bool:
	if state == null or slot_kind != "generator":
		return false
	var generator: Generator = state.get_generator(generator_id)
	return generator != null and generator.definition.cycle_based and generator.cycle_active


func _get_relic_glyph(family: String) -> String:
	match family:
		"production":
			return "◆"
		"cycle_speed":
			return "◈"
		"input_efficiency":
			return "◇"
		"event_chance":
			return "✦"
		"sensitivity":
			return "◉"
	return "✦"


func _get_drag_data(_at_position: Vector2) -> Variant:
	if state == null:
		return null
	if slot_kind == "generator" and _is_generator_equipment_locked():
		return null

	var dragged_instance_id := instance_id
	var dragged_entry: Dictionary = {}
	if slot_kind == "inventory":
		dragged_entry = state.relic_manager.get_inventory_entry_at_slot(slot_index)
		dragged_instance_id = str(dragged_entry.get("instance_id", ""))
	elif slot_kind == "crafting":
		dragged_entry = state.relic_manager.get_machine_entry_at_slot(generator_id, slot_index)
		dragged_instance_id = str(dragged_entry.get("instance_id", ""))
	elif slot_kind == "generator":
		dragged_instance_id = state.relic_manager.get_equipped_relic_id(generator_id, slot_index)
		dragged_entry = state.relic_manager.get_relic(dragged_instance_id)
	if dragged_instance_id == "" or dragged_entry.is_empty():
		return null

	var entry_type := state.relic_manager.get_inventory_entry_type(dragged_entry)
	if slot_kind == "generator":
		entry_type = "relic"

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
	if entry_type == "stackable":
		preview_glyph.text = str(state.relic_manager.get_stackable_item_definition(
			str(dragged_entry.get("item_id", ""))
		).get("glyph", "◆"))
	else:
		preview_glyph.text = _get_relic_glyph(str(state.relic_manager.get_relic_definition(dragged_entry).get("family", "")))
	preview_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview_glyph.add_theme_font_size_override("font_size", 23)
	preview_glyph.add_theme_color_override("font_color", Color(1.0, 0.76, 0.43))
	preview.add_child(preview_glyph)
	set_drag_preview(preview)

	return {
		"type": "reliquary_item",
		"item_type": entry_type,
		"instance_id": dragged_instance_id,
		"source_kind": slot_kind,
		"source_generator_id": generator_id,
		"source_slot_index": slot_index
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if state == null or not data is Dictionary:
		return false
	if str(data.get("type", "")) != "reliquary_item":
		return false
	if slot_kind == "generator" and _is_generator_equipment_locked():
		return false
	if str(data.get("source_kind", "")) == "generator":
		var source_generator: Generator = state.get_generator(str(data.get("source_generator_id", "")))
		if source_generator != null and source_generator.definition.cycle_based and source_generator.cycle_active:
			return false
	var dragged_instance_id := str(data.get("instance_id", ""))
	var item_type := str(data.get("item_type", ""))
	if state.relic_manager.get_inventory_entry_by_instance_id(dragged_instance_id).is_empty():
		return false
	if slot_kind == "inventory":
		var source_kind := str(data.get("source_kind", ""))
		if source_kind == "inventory":
			return true
		if source_kind == "crafting":
			return true
		if source_kind == "generator":
			return (
				item_type == "relic"
				and state.relic_manager.get_inventory_entry_at_slot(slot_index).is_empty()
			)
		return false
	if slot_kind == "crafting":
		return (
			state.get_generator(generator_id) != null
			and state.relic_manager.get_inventory_entry_by_instance_id(dragged_instance_id).size() > 0
			and str(data.get("source_kind", "")) != "generator"
		)
	if item_type != "relic":
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
		if source_kind == "crafting" and source_generator_id != "":
			if not state.relic_manager.move_machine_entry_to_inventory(source_generator_id, source_slot_index):
				return
			if not state.relic_manager.move_inventory_entry_to_slot(dragged_instance_id, slot_index):
				return
		elif source_kind == "generator" and source_generator_id != "":
			if not state.relic_manager.move_relic_to_inventory(dragged_instance_id, slot_index):
				return
			state.relic_manager.unequip_relic(source_generator_id, source_slot_index)
		elif source_kind == "inventory":
			if not state.relic_manager.move_inventory_entry_to_slot(dragged_instance_id, slot_index):
				return
	elif slot_kind == "crafting":
		if dragged_instance_id == "":
			return
		if source_kind == "crafting":
			if source_generator_id == generator_id and source_slot_index == slot_index:
				return
			if not state.relic_manager.move_machine_entry_to_inventory(source_generator_id, source_slot_index):
				return
		if not state.relic_manager.move_inventory_entry_to_machine_slot(dragged_instance_id, generator_id, slot_index):
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
		else:
			# If the incoming relic is in a crafting slot, first give it an inventory
			# square. The displaced equipped relic can then take that exact square.
			if source_kind == "crafting":
				if not state.relic_manager.move_machine_entry_to_inventory(source_generator_id, source_slot_index):
					return

			var incoming_inventory_slot := int(
				state.relic_manager.inventory_positions.get(dragged_instance_id, -1)
			)
			if target_relic_id != "":
				# Do not overwrite an occupied slot: unequip first, equip the incoming
				# relic, then return the displaced relic to the incoming relic's square.
				if incoming_inventory_slot < 0:
					return
				state.relic_manager.unequip_relic(generator_id, slot_index)

			if not state.relic_manager.equip_relic(generator_id, dragged_instance_id, state, slot_index):
				if target_relic_id != "":
					state.relic_manager.equip_relic(generator_id, target_relic_id, state, slot_index)
				return

			if target_relic_id != "":
				state.relic_manager.inventory_positions[target_relic_id] = incoming_inventory_slot

	state.rebuild_relic_modifiers()
	equipment_changed.emit()
