class_name ReliquaryPanel
extends VBoxContainer

signal relics_changed

var state: GameState
var inventory_grid: GridContainer
var inventory_title: Label
var status_label: Label
var _last_equipment_signature: String = ""


func setup(game_state: GameState) -> void:
	state = game_state
	add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "THE RELIQUARY"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.38))
	add_child(title)

	inventory_title = Label.new()
	inventory_title.name = "RelicInventoryLabel"
	add_child(inventory_title)

	var description := Label.new()
	description.text = "Drag relics onto unlocked generator slots. Drag an equipped relic back here to unequip it."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(description)

	inventory_grid = GridContainer.new()
	inventory_grid.name = "RelicInventoryGrid"
	inventory_grid.columns = 6
	inventory_grid.add_theme_constant_override("h_separation", 5)
	inventory_grid.add_theme_constant_override("v_separation", 5)
	inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(inventory_grid)

	status_label = Label.new()
	status_label.name = "RelicInventoryStatus"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color(0.72, 0.67, 0.65))
	add_child(status_label)

	refresh()


func _process(_delta: float) -> void:
	if state == null:
		return
	var signature := _get_equipment_signature()
	if signature != _last_equipment_signature:
		refresh()


func _get_equipment_signature() -> String:
	if state == null or state.relic_manager == null:
		return ""
	return JSON.stringify({
		"inventory": state.relic_manager.inventory,
		"equipped": state.relic_manager.equipped,
		"slots": _get_slot_counts()
	})


func _get_slot_counts() -> Dictionary:
	var counts: Dictionary = {}
	if state == null:
		return counts
	for generator_id in state.generators:
		counts[str(generator_id)] = state.eternal_flame_upgrade_manager.get_relic_slot_count(
			str(generator_id),
			state.eternal_flame_state
		)
	return counts


func refresh() -> void:
	if state == null or inventory_grid == null:
		return

	_last_equipment_signature = _get_equipment_signature()
	for child in inventory_grid.get_children():
		inventory_grid.remove_child(child)
		child.queue_free()

	var equipped_ids: Dictionary = {}
	for generator_id in state.relic_manager.equipped:
		equipped_ids[str(state.relic_manager.equipped[generator_id])] = true

	var available_relics: Array[Dictionary] = []
	for relic in state.relic_manager.get_inventory_options():
		var instance_id := str(relic.get("instance_id", ""))
		if instance_id == "" or equipped_ids.has(instance_id):
			continue
		available_relics.append(relic)

	inventory_title.text = "RELIC INVENTORY · %d available" % available_relics.size()
	for relic in available_relics:
		var slot := RelicSlotControl.new()
		slot.configure(state, "inventory", str(relic.get("instance_id", "")))
		slot.equipment_changed.connect(_on_equipment_changed)
		inventory_grid.add_child(slot)

	# Keep empty square slots visible and available as drop targets.
	var visible_slot_count := maxi(8, int(ceil(float(available_relics.size()) / 6.0)) * 6)
	while inventory_grid.get_child_count() < visible_slot_count:
		var empty_slot := RelicSlotControl.new()
		empty_slot.configure(state, "inventory", "")
		empty_slot.equipment_changed.connect(_on_equipment_changed)
		inventory_grid.add_child(empty_slot)

	status_label.text = (
		"Drag an item to equip it. Drop an equipped item into any empty inventory square to unequip it."
		if not available_relics.is_empty()
		else "No unequipped relics. Empty squares can receive relics dragged from generator slots."
	)


func _on_equipment_changed() -> void:
	if state == null:
		return
	state.rebuild_relic_modifiers()
	_last_equipment_signature = ""
	refresh()
	relics_changed.emit()
