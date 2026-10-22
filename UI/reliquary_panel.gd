class_name ReliquaryPanel
extends VBoxContainer

signal relics_changed
var state: GameState
var _rows: Dictionary = {}

func setup(game_state: GameState) -> void:
	state = game_state
	add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "THE RELIQUARY"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.38))
	add_child(title)
	var inventory_title := Label.new()
	inventory_title.name = "RelicInventoryLabel"
	add_child(inventory_title)
	var description := Label.new()
	description.text = "Equip one relic per unlocked generator slot. Effects that a generator cannot use remain inactive."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(description)
	for generator_id in state.generators.keys():
		var generator: Generator = state.get_generator(str(generator_id))
		var row := HBoxContainer.new()
		row.name = "RelicRow_" + str(generator_id)
		row.add_theme_constant_override("separation", 6)
		add_child(row)
		var name_label := Label.new()
		name_label.text = generator.definition.display_name
		name_label.custom_minimum_size = Vector2(140, 0)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var selector := OptionButton.new()
		selector.custom_minimum_size = Vector2(150, 0)
		selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(selector)
		var equip_button := Button.new()
		equip_button.text = "Equip"
		row.add_child(equip_button)
		equip_button.pressed.connect(_on_equip_pressed.bind(str(generator_id), selector))
		var status_label := Label.new()
		status_label.custom_minimum_size = Vector2(170, 0)
		status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(status_label)
		_rows[str(generator_id)] = {"row": row, "selector": selector, "status": status_label}
	refresh()

func refresh() -> void:
	if state == null:
		return
	var inventory_label := get_node_or_null("RelicInventoryLabel") as Label
	if inventory_label != null:
		var names: Array[String] = []
		for relic in state.relic_manager.get_inventory_options():
			names.append(str(relic.get("display_name", "Relic")))
		inventory_label.text = "Inventory (%d): %s" % [names.size(), ", ".join(PackedStringArray(names)) if not names.is_empty() else "No relics"]
	for generator_id in _rows:
		var row_data: Dictionary = _rows[generator_id]
		var selector: OptionButton = row_data["selector"]
		var status_label: Label = row_data["status"]
		var slots: int = state.eternal_flame_upgrade_manager.get_relic_slot_count(generator_id, state.eternal_flame_state)
		row_data["row"].visible = slots > 0
		if slots <= 0:
			continue
		selector.clear()
		selector.add_item("Empty")
		selector.set_item_metadata(0, "")
		var selected_index := 0
		var equipped_id := state.relic_manager.get_equipped_relic_id(generator_id)
		for relic in state.relic_manager.get_inventory_options():
			var instance_id := str(relic.get("instance_id", ""))
			selector.add_item(str(relic.get("display_name", "Relic")))
			selector.set_item_metadata(selector.item_count - 1, instance_id)
			if instance_id == equipped_id:
				selected_index = selector.item_count - 1
		selector.select(selected_index)
		if equipped_id == "":
			status_label.text = "Empty slot"
		else:
			var relic: Dictionary = state.relic_manager.get_relic(equipped_id)
			var definition_id := str(relic.get("definition_id", ""))
			var definition: Dictionary = state.relic_manager.get_definition(definition_id)
			status_label.text = state.relic_manager.get_effect_status(definition_id, generator_id, state) + " · " + str(definition.get("description", ""))

func _on_equip_pressed(generator_id: String, selector: OptionButton) -> void:
	if state == null or selector == null or selector.selected < 0:
		return
	var instance_id := str(selector.get_item_metadata(selector.selected))
	if instance_id == "":
		state.relic_manager.unequip_relic(generator_id)
	elif not state.relic_manager.equip_relic(generator_id, instance_id, state):
		return
	state.rebuild_relic_modifiers()
	refresh()
	relics_changed.emit()
