class_name ReliquaryPanel
extends VBoxContainer

signal relics_changed

const DISPLAY_INVENTORY_ONLY := "inventory"
const DISPLAY_INVENTORY_AND_GENERATORS := "inventory_and_generators"
const DISPLAY_GENERATOR_ONLY := "generator"
const DISPLAY_FOCUSED_GENERATOR_RELICS := "focused_generator_relics"

var state: GameState
var display_mode: String = DISPLAY_INVENTORY_AND_GENERATORS
var focused_generator_id: String = ""
var inventory_grid: GridContainer
var inventory_scroll: ScrollContainer
var inventory_title: Label
var generator_list: GridContainer
var generator_list_scroll: ScrollContainer
var generator_navigation: HBoxContainer
var generators_button: Button
var crafting_button: Button
var crafting_section: VBoxContainer
var crafting_generator_panel: GeneratorPanel
var craft_t3_relic_button: Button
var input_handler: InputHandler
var inventory_section: VBoxContainer
var generator_section: VBoxContainer
var right_view: String = "generators"
var _last_equipment_signature: String = ""


func setup(
	game_state: GameState,
	requested_display_mode: String = DISPLAY_INVENTORY_AND_GENERATORS,
	target_generator_id: String = "",
	game_input_handler: InputHandler = null
) -> void:
	state = game_state
	input_handler = game_input_handler
	display_mode = requested_display_mode
	focused_generator_id = target_generator_id
	add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = "GENERATOR RELICS" if display_mode == DISPLAY_FOCUSED_GENERATOR_RELICS else "THE RELIQUARY"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.38))
	add_child(title)

	var sections := HBoxContainer.new()
	sections.name = "ReliquarySections"
	sections.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sections.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sections.add_theme_constant_override("separation", 4)
	add_child(sections)

	inventory_section = VBoxContainer.new()
	inventory_section.name = "InventorySection"
	inventory_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_section.custom_minimum_size.x = 220.0
	inventory_section.add_theme_constant_override("separation", 5)
	sections.add_child(inventory_section)

	inventory_title = Label.new()
	inventory_title.name = "RelicInventoryLabel"
	inventory_title.add_theme_font_size_override("font_size", 12)
	inventory_title.add_theme_color_override("font_color", Color(0.94, 0.82, 0.68))
	inventory_section.add_child(inventory_title)

	inventory_scroll = ScrollContainer.new()
	inventory_scroll.name = "RelicInventoryScroll"
	inventory_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_scroll.custom_minimum_size.y = 0.0
	inventory_section.add_child(inventory_scroll)

	inventory_grid = GridContainer.new()
	inventory_grid.name = "RelicInventoryGrid"
	inventory_grid.columns = 5
	inventory_grid.add_theme_constant_override("h_separation", 5)
	inventory_grid.add_theme_constant_override("v_separation", 5)
	inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_scroll.add_child(inventory_grid)
	inventory_scroll.resized.connect(_update_responsive_grid_columns)

	generator_section = VBoxContainer.new()
	generator_section.name = "GeneratorEquipmentSection"
	generator_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generator_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	generator_section.custom_minimum_size.x = 0.0
	generator_section.add_theme_constant_override("separation", 5)
	sections.add_child(generator_section)

	generator_navigation = HBoxContainer.new()
	generator_navigation.name = "ReliquaryNavigation"
	generator_navigation.add_theme_constant_override("separation", 4)
	generator_section.add_child(generator_navigation)

	generators_button = Button.new()
	generators_button.name = "GeneratorsButton"
	generators_button.text = "GENERATORS"
	generators_button.toggle_mode = true
	generators_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generators_button.pressed.connect(_on_generators_button_pressed)
	generator_navigation.add_child(generators_button)

	crafting_button = Button.new()
	crafting_button.name = "CraftingButton"
	crafting_button.text = "CRAFTING"
	crafting_button.toggle_mode = true
	crafting_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crafting_button.pressed.connect(_on_crafting_button_pressed)
	generator_navigation.add_child(crafting_button)

	generator_list_scroll = ScrollContainer.new()
	generator_list_scroll.name = "GeneratorEquipmentScroll"
	generator_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generator_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	generator_section.add_child(generator_list_scroll)

	generator_list = GridContainer.new()
	generator_list.name = "GeneratorEquipmentList"
	generator_list.columns = 3
	generator_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generator_list.add_theme_constant_override("h_separation", 5)
	generator_list.add_theme_constant_override("v_separation", 5)
	generator_list_scroll.add_child(generator_list)
	generator_list_scroll.resized.connect(_update_responsive_grid_columns)

	crafting_section = VBoxContainer.new()
	crafting_section.name = "ReliquaryCraftingSection"
	crafting_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crafting_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	crafting_section.add_theme_constant_override("separation", 5)
	generator_section.add_child(crafting_section)

	var crafting_title := Label.new()
	crafting_title.text = "RELIC CRAFTING"
	crafting_title.add_theme_font_size_override("font_size", 12)
	crafting_title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.38))
	crafting_section.add_child(crafting_title)

	crafting_generator_panel = preload("res://UI/generator_panel.tscn").instantiate() as GeneratorPanel
	crafting_generator_panel.name = "RelicShardExtractorPanel"
	crafting_generator_panel.reliquary_compact_mode = true
	crafting_generator_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crafting_generator_panel.custom_minimum_size.x = 0.0
	crafting_generator_panel.setup(state, input_handler, "relic_shard_extractor")
	crafting_section.add_child(crafting_generator_panel)

	craft_t3_relic_button = Button.new()
	craft_t3_relic_button.name = "CraftT3RelicButton"
	craft_t3_relic_button.text = "FORGE T3 RELIC · 1 RELIC SHARD"
	craft_t3_relic_button.custom_minimum_size.y = 30.0
	craft_t3_relic_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	craft_t3_relic_button.pressed.connect(_on_forge_t3_relic_pressed)
	crafting_section.add_child(craft_t3_relic_button)

	# Crafting uses shared generator state. Keep purchase controls so the
	# player can buy the first level here; hide unrelated upgrade navigation.
	crafting_generator_panel.relics_changed.connect(_on_equipment_changed)
	var bottom_buttons := crafting_generator_panel.get_node_or_null("HBoxContainer/VBoxContainer/BottomButtons")
	if bottom_buttons != null:
		bottom_buttons.hide()
	var cost_label := crafting_generator_panel.get_node_or_null("HBoxContainer/VBoxContainer/CostLabel")
	if cost_label != null:
		cost_label.hide()

	_set_right_view("generators")
	refresh()


func set_display_mode(requested_display_mode: String, target_generator_id: String = "") -> void:
	display_mode = requested_display_mode
	focused_generator_id = target_generator_id
	refresh()


func _apply_display_mode() -> void:
	if inventory_section != null:
		inventory_section.visible = display_mode != DISPLAY_GENERATOR_ONLY
	if generator_section != null:
		generator_section.visible = display_mode not in [DISPLAY_INVENTORY_ONLY, DISPLAY_FOCUSED_GENERATOR_RELICS]
	if generator_navigation != null:
		generator_navigation.visible = display_mode != DISPLAY_FOCUSED_GENERATOR_RELICS
	if display_mode == DISPLAY_FOCUSED_GENERATOR_RELICS:
		right_view = "generators"
		if crafting_section != null:
			crafting_section.hide()
	_update_right_view_visibility()


func _on_generators_button_pressed() -> void:
	_set_right_view("generators")


func _on_crafting_button_pressed() -> void:
	_set_right_view("crafting")


func _set_right_view(view_name: String) -> void:
	right_view = "crafting" if view_name == "crafting" else "generators"
	_update_right_view_visibility()


func _update_right_view_visibility() -> void:
	if generator_list_scroll != null:
		generator_list_scroll.visible = right_view == "generators"
	if crafting_section != null:
		crafting_section.visible = right_view == "crafting"
	_update_navigation_button_styles()


func _update_navigation_button_styles() -> void:
	_style_reliquary_tab(generators_button, right_view == "generators")
	_style_reliquary_tab(crafting_button, right_view == "crafting")


func _style_reliquary_tab(button: Button, selected: bool) -> void:
	if button == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.19, 0.105, 0.075, 1.0) if selected else Color(0.075, 0.06, 0.075, 0.98)
	normal.border_color = Color(0.85, 0.43, 0.20, 1.0) if selected else Color(0.28, 0.2, 0.19, 1.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 6.0
	normal.content_margin_right = 6.0
	normal.content_margin_top = 3.0
	normal.content_margin_bottom = 3.0
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_color_override("font_color", Color(1.0, 0.82, 0.67) if selected else Color(0.88, 0.80, 0.70))
	button.add_theme_color_override("font_disabled_color", Color(0.61, 0.55, 0.52))
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.24, 0.13, 0.10, 1.0)
	hover.border_color = Color(0.62, 0.34, 0.22, 1.0)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.28, 0.14, 0.095, 1.0)
	button.add_theme_stylebox_override("pressed", pressed)


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
		"inventory_positions": state.relic_manager.inventory_positions,
		"equipped": state.relic_manager.equipped,
		"slots": _get_slot_counts(),
		"machine_slots": state.relic_manager.machine_slots,
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


# Keep slot and card dimensions unchanged so drag-and-drop hit targets remain stable.
# Reserve room for the vertical scrollbar when calculating available width.
func _update_responsive_grid_columns() -> void:
	if inventory_grid != null and inventory_scroll != null:
		var inventory_width: float = maxf(0.0, inventory_scroll.size.x - 16.0)
		var inventory_columns: int = clampi(int(floor((inventory_width + 5.0) / 39.0)), 1, 5)
		if inventory_grid.columns != inventory_columns:
			inventory_grid.columns = inventory_columns
	if generator_list != null and generator_list_scroll != null:
		var equipment_width: float = maxf(0.0, generator_list_scroll.size.x - 16.0)
		var equipment_columns: int = clampi(int(floor((equipment_width + 5.0) / 100.0)), 1, 3)
		if generator_list.columns != equipment_columns:
			generator_list.columns = equipment_columns


func refresh() -> void:
	if state == null or inventory_grid == null or generator_list == null:
		return

	_last_equipment_signature = _get_equipment_signature()
	_apply_display_mode()
	_refresh_inventory()
	_refresh_generator_list()
	_update_t3_craft_button()
	_update_responsive_grid_columns()


func _refresh_inventory() -> void:
	for child in inventory_grid.get_children():
		inventory_grid.remove_child(child)
		child.queue_free()

	var equipped_ids: Dictionary = {}
	for generator_id_variant in state.relic_manager.equipped.keys():
		for instance_id in state.relic_manager.get_equipped_relic_ids(str(generator_id_variant)):
			equipped_ids[instance_id] = true

	inventory_title.text = "RELIQUARY"
	var visible_slot_count: int = maxi(
		RelicManager.INVENTORY_SLOT_COUNT,
		state.relic_manager.get_inventory_slot_count()
	)
	for slot_index in range(visible_slot_count):
		var slot := RelicSlotControl.new()
		slot.configure(state, "inventory", "", "", slot_index)
		slot.equipment_changed.connect(_on_equipment_changed)
		inventory_grid.add_child(slot)


func _refresh_generator_list() -> void:
	for child in generator_list.get_children():
		generator_list.remove_child(child)
		child.queue_free()

	for generator_id_variant in state.generators.keys():
		var generator_id := str(generator_id_variant)
		if display_mode in [DISPLAY_GENERATOR_ONLY, DISPLAY_FOCUSED_GENERATOR_RELICS] and generator_id != focused_generator_id:
			continue
		var generator: Generator = state.get_generator(generator_id)
		if generator == null or not generator.unlocked:
			continue

		var card := PanelContainer.new()
		card.name = "Generator_" + generator_id
		# Three compact cards fit across the generator area without stretching.
		card.custom_minimum_size = Vector2(95.0, 112.0)
		card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.075, 0.065, 0.075, 0.96)
		card_style.border_color = Color(0.29, 0.21, 0.20, 1.0)
		card_style.set_border_width_all(1)
		card_style.set_corner_radius_all(4)
		card_style.content_margin_left = 5.0
		card_style.content_margin_top = 6.0
		card_style.content_margin_right = 5.0
		card_style.content_margin_bottom = 7.0
		card.add_theme_stylebox_override("panel", card_style)
		generator_list.add_child(card)

		var card_content := VBoxContainer.new()
		card_content.add_theme_constant_override("separation", 4)
		card.add_child(card_content)

		var name_label := Label.new()
		name_label.text = str(generator.definition.display_name)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_color", Color(0.88, 0.76, 0.68))
		name_label.add_theme_font_size_override("font_size", 10)
		card_content.add_child(name_label)

		var illustration_container := CenterContainer.new()
		illustration_container.name = "GeneratorIllustrationContainer"
		illustration_container.custom_minimum_size = Vector2(0.0, 48.0)
		card_content.add_child(illustration_container)

		# Use a compact 48 px square image area for the denser Reliquary grid.
		var illustration_panel := PanelContainer.new()
		illustration_panel.name = "IllustrationPanel"
		illustration_panel.custom_minimum_size = Vector2(44.0, 44.0)
		var illustration_style := StyleBoxFlat.new()
		illustration_style.bg_color = Color(0.09, 0.065, 0.075, 1.0)
		illustration_style.border_color = Color(0.22, 0.15, 0.15, 1.0)
		illustration_style.set_border_width_all(1)
		illustration_style.set_corner_radius_all(3)
		illustration_panel.add_theme_stylebox_override("panel", illustration_style)
		illustration_container.add_child(illustration_panel)

		var illustration := TextureRect.new()
		illustration.name = "GeneratorIllustration"
		illustration.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		illustration.size_flags_vertical = Control.SIZE_EXPAND_FILL
		illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var illustration_path := str(generator.definition.illustration_path)
		if illustration_path != "":
			var texture = load(illustration_path)
			if texture is Texture2D:
				illustration.texture = texture
		illustration_panel.add_child(illustration)

		var slot_count: int = state.eternal_flame_upgrade_manager.get_relic_slot_count(
			generator_id,
			state.eternal_flame_state
		)
		if slot_count > 0:
			var slots_row := HBoxContainer.new()
			slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
			slots_row.add_theme_constant_override("separation", 2)
			card_content.add_child(slots_row)
			for slot_index in range(slot_count):
				var slot := RelicSlotControl.new()
				slot.configure(state, "generator", "", generator_id, slot_index)
				slot.equipment_changed.connect(_on_equipment_changed)
				slots_row.add_child(slot)


func _update_t3_craft_button() -> void:
	if craft_t3_relic_button == null or state == null or state.relic_manager == null:
		return
	craft_t3_relic_button.disabled = (
		state.relic_manager.get_stackable_item_quantity("relic_shard") < 1
	)


func _on_forge_t3_relic_pressed() -> void:
	if state == null or state.relic_manager == null:
		return
	if not state.relic_manager.consume_stackable_item("relic_shard", 1):
		_update_t3_craft_button()
		return

	var relic_instance_id := state.relic_manager.add_random_relic_for_tier(3)
	if relic_instance_id == "":
		# Refund the input if generation fails, so a failed craft never destroys items.
		state.relic_manager.add_stackable_item("relic_shard", 1)
		refresh()
		return

	refresh()
	relics_changed.emit()


func _on_equipment_changed() -> void:
	if state == null:
		return
	state.rebuild_relic_modifiers()
	_last_equipment_signature = ""
	refresh()
	relics_changed.emit()

