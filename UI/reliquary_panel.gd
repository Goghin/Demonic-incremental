class_name ReliquaryPanel
extends VBoxContainer

signal relics_changed

const DISPLAY_INVENTORY_ONLY := "inventory"
const DISPLAY_INVENTORY_AND_GENERATORS := "inventory_and_generators"
const DISPLAY_GENERATOR_ONLY := "generator"

var state: GameState
var display_mode: String = DISPLAY_INVENTORY_AND_GENERATORS
var focused_generator_id: String = ""
var inventory_grid: GridContainer
var inventory_title: Label
var status_label: Label
var generator_list: VBoxContainer
var generator_list_scroll: ScrollContainer
var inventory_section: VBoxContainer
var generator_section: VBoxContainer
var _last_equipment_signature: String = ""


func setup(
	game_state: GameState,
	requested_display_mode: String = DISPLAY_INVENTORY_AND_GENERATORS,
	target_generator_id: String = ""
) -> void:
	state = game_state
	display_mode = requested_display_mode
	focused_generator_id = target_generator_id
	add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "THE RELIQUARY"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.38))
	add_child(title)

	var sections := HBoxContainer.new()
	sections.name = "ReliquarySections"
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sections.add_theme_constant_override("separation", 14)
	add_child(sections)

	inventory_section = VBoxContainer.new()
	inventory_section.name = "InventorySection"
	inventory_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_section.custom_minimum_size.x = 250.0
	inventory_section.add_theme_constant_override("separation", 6)
	sections.add_child(inventory_section)

	inventory_title = Label.new()
	inventory_title.name = "RelicInventoryLabel"
	inventory_section.add_child(inventory_title)

	var description := Label.new()
	description.text = "Drag relics onto generator slots. Drag equipped relics back here to unequip them."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inventory_section.add_child(description)

	inventory_grid = GridContainer.new()
	inventory_grid.name = "RelicInventoryGrid"
	inventory_grid.columns = 6
	inventory_grid.add_theme_constant_override("h_separation", 5)
	inventory_grid.add_theme_constant_override("v_separation", 5)
	inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_section.add_child(inventory_grid)

	status_label = Label.new()
	status_label.name = "RelicInventoryStatus"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color(0.72, 0.67, 0.65))
	inventory_section.add_child(status_label)

	generator_section = VBoxContainer.new()
	generator_section.name = "GeneratorEquipmentSection"
	generator_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generator_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	generator_section.custom_minimum_size.x = 260.0
	generator_section.add_theme_constant_override("separation", 6)
	sections.add_child(generator_section)

	var generator_title := Label.new()
	generator_title.text = "GENERATOR SLOTS"
	generator_title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.38))
	generator_section.add_child(generator_title)

	generator_list_scroll = ScrollContainer.new()
	generator_list_scroll.name = "GeneratorEquipmentScroll"
	generator_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generator_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	generator_section.add_child(generator_list_scroll)

	generator_list = VBoxContainer.new()
	generator_list.name = "GeneratorEquipmentList"
	generator_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generator_list.add_theme_constant_override("separation", 8)
	generator_list_scroll.add_child(generator_list)

	_apply_display_mode()
	refresh()


func set_display_mode(requested_display_mode: String, target_generator_id: String = "") -> void:
	display_mode = requested_display_mode
	focused_generator_id = target_generator_id
	_apply_display_mode()
	refresh()


func _apply_display_mode() -> void:
	if inventory_section != null:
		inventory_section.visible = display_mode != DISPLAY_GENERATOR_ONLY
	if generator_section != null:
		generator_section.visible = display_mode != DISPLAY_INVENTORY_ONLY


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
		"slots": _get_slot_counts(),
		"mode": display_mode,
		"focused": focused_generator_id
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
	if state == null or inventory_grid == null or generator_list == null:
		return

	_last_equipment_signature = _get_equipment_signature()
	_apply_display_mode()
	_refresh_inventory()
	_refresh_generator_list()


func _refresh_inventory() -> void:
	for child in inventory_grid.get_children():
		inventory_grid.remove_child(child)
		child.queue_free()

	var equipped_ids: Dictionary = {}
	for generator_id_variant in state.relic_manager.equipped.keys():
		for instance_id in state.relic_manager.get_equipped_relic_ids(str(generator_id_variant)):
			equipped_ids[instance_id] = true

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

	# Keep empty square slots visible and usable as drop targets.
	var visible_slot_count := maxi(8, int(ceil(float(available_relics.size()) / 6.0)) * 6)
	while inventory_grid.get_child_count() < visible_slot_count:
		var empty_slot := RelicSlotControl.new()
		empty_slot.configure(state, "inventory", "")
		empty_slot.equipment_changed.connect(_on_equipment_changed)
		inventory_grid.add_child(empty_slot)

	status_label.text = (
		"Drag an item to equip it. Drop an equipped item into an empty inventory square to unequip it."
		if not available_relics.is_empty()
		else "No unequipped relics. Empty squares can receive relics dragged from generator slots."
	)


func _refresh_generator_list() -> void:
	for child in generator_list.get_children():
		generator_list.remove_child(child)
		child.queue_free()

	for generator_id_variant in state.generators.keys():
		var generator_id := str(generator_id_variant)
		if display_mode == DISPLAY_GENERATOR_ONLY and generator_id != focused_generator_id:
			continue
		var generator: Generator = state.get_generator(generator_id)
		if generator == null or not generator.unlocked:
			continue

		var row := VBoxContainer.new()
		row.name = "Generator_" + generator_id
		row.add_theme_constant_override("separation", 3)
		generator_list.add_child(row)

		var name_label := Label.new()
		name_label.text = str(generator.definition.display_name)
		name_label.add_theme_color_override("font_color", Color(0.88, 0.82, 0.77))
		row.add_child(name_label)

		var slot_count: int = state.eternal_flame_upgrade_manager.get_relic_slot_count(
			generator_id,
			state.eternal_flame_state
		)
		if slot_count <= 0:
			var locked_label := Label.new()
			locked_label.text = "No relic slots unlocked"
			locked_label.add_theme_color_override("font_color", Color(0.55, 0.51, 0.50))
			row.add_child(locked_label)
		else:
			var slots_row := HBoxContainer.new()
			slots_row.add_theme_constant_override("separation", 3)
			row.add_child(slots_row)
			for slot_index in range(slot_count):
				var slot := RelicSlotControl.new()
				slot.configure(state, "generator", "", generator_id, slot_index)
				slot.equipment_changed.connect(_on_equipment_changed)
				slots_row.add_child(slot)

		var separator := HSeparator.new()
		separator.add_theme_constant_override("separation", 2)
		row.add_child(separator)


func _on_equipment_changed() -> void:
	if state == null:
		return
	state.rebuild_relic_modifiers()
	_last_equipment_signature = ""
	refresh()
	relics_changed.emit()
