class_name GeneratorPanel
extends Control


var state: GameState
var input_handler: InputHandler
var generator_id: String
var current_illustration_path: String = ""
var _last_automation_style_enabled: bool = false
var _has_automation_style: bool = false
var _last_upgrade_automation_style_enabled: bool = false
var _has_upgrade_automation_style: bool = false
var _resource_icon_cache: Dictionary = {}
var _event_effects_button: Button
var _event_effects_popup: AcceptDialog
var _level_upgrade_button: Button
var _illustration: TextureRect
var _relic_slots_container: HBoxContainer
var _crafting_slots_container: HBoxContainer
var _crafting_slots_label: Label
var _crafting_slot_controls: Array[RelicSlotControl] = []
var _crafting_slot_count: int = -1
var _last_crafting_signature: String = ""
var _relic_slot_controls: Array[RelicSlotControl] = []
var _relic_slot_count: int = -1
var _last_relic_slot_signature: String = ""

signal upgrades_requested(generator_id: String)
signal selection_requested(generator_id: String)
signal details_requested(generator_id: String)
signal upgrade_automation_changed
signal generator_purchased
signal relics_changed


var _normal_panel_style: StyleBox
var is_new_unlock: bool = false
var reliquary_compact_mode: bool = false


func mark_new_unlock() -> void:
	is_new_unlock = true
	$HBoxContainer/VBoxContainer/Header/NewLabel.visible = true


func mark_seen() -> void:
	is_new_unlock = false
	$HBoxContainer/VBoxContainer/Header/NewLabel.visible = false


func _ready() -> void:
	_normal_panel_style = get_theme_stylebox("panel")
	_style_action_button($HBoxContainer/VBoxContainer/HBoxContainer/PauseButton)
	_style_action_button($HBoxContainer/VBoxContainer/BuyButtons/BuyButton)
	_style_action_button($HBoxContainer/VBoxContainer/BottomButtons/DetailsButton)
	_style_action_button($HBoxContainer/VBoxContainer/BuyButtons/AutomationButton)
	_style_action_button($HBoxContainer/VBoxContainer/BottomButtons/UpgradeAutomationButton)
	_style_operation_mode_dropdown()
	_setup_event_effects_ui()
	_setup_relic_slots_ui()
	_setup_level_upgrade_ui()
	if reliquary_compact_mode:
		_apply_reliquary_compact_layout()


func _apply_reliquary_compact_layout() -> void:
	custom_minimum_size = Vector2.ZERO
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var content: VBoxContainer = $HBoxContainer/VBoxContainer
	content.add_theme_constant_override("separation", 3)
	$HBoxContainer.add_theme_constant_override("separation", 6)
	$HBoxContainer/IllustrationPanel.custom_minimum_size = Vector2(44.0, 0.0)
	_illustration.custom_minimum_size = Vector2(0.0, 30.0)
	$HBoxContainer/VBoxContainer/Header/GeneratorLabel.add_theme_font_size_override("font_size", 12)
	$HBoxContainer/VBoxContainer/Header/LevelLabel.add_theme_font_size_override("font_size", 10)
	$HBoxContainer/VBoxContainer/OperationModeOptionButton.custom_minimum_size.y = 0.0
	$HBoxContainer/VBoxContainer/InputLabel.hide()
	$HBoxContainer/VBoxContainer/ProductionLabel.hide()
	$HBoxContainer/VBoxContainer/BuyButtons.add_theme_constant_override("separation", 4)
	$HBoxContainer/VBoxContainer/BuyButtons/BuyButton.add_theme_font_size_override("font_size", 10)
	$HBoxContainer/VBoxContainer/HBoxContainer/PauseButton.add_theme_font_size_override("font_size", 10)
	$HBoxContainer/VBoxContainer/ProgressBar.custom_minimum_size.y = 6.0
	$HBoxContainer/VBoxContainer/ContaminationLabel.add_theme_font_size_override("font_size", 9)
	$HBoxContainer/VBoxContainer/BottomButtons.hide()
	$HBoxContainer/VBoxContainer/CostLabel.hide()


func set_selected(is_selected: bool) -> void:
	if _normal_panel_style == null:
		_normal_panel_style = get_theme_stylebox("panel")

	if not is_selected:
		if _normal_panel_style != null:
			add_theme_stylebox_override("panel", _normal_panel_style)
		return

	var selected_style := StyleBoxFlat.new()
	if _normal_panel_style is StyleBoxFlat:
		selected_style = _normal_panel_style.duplicate() as StyleBoxFlat
	else:
		selected_style.bg_color = Color(0.12, 0.10, 0.09, 1.0)
	selected_style.set_border_width_all(2)
	selected_style.border_color = Color(0.95, 0.43, 0.17, 1.0)
	add_theme_stylebox_override("panel", selected_style)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			mark_seen()
			selection_requested.emit(generator_id)


func setup(
	game_state: GameState,
	game_input_handler: InputHandler,
	game_generator_id: String
	) -> void:
	
	state = game_state
	input_handler = game_input_handler
	generator_id = game_generator_id


func _process(_delta: float) -> void:
	if state == null:
		return
	
	var generator = state.get_generator(generator_id)
	
	if generator == null:
		return

	# A new-unlock tag is about the first level, not about viewing the panel.
	# Checking the live level also catches purchases made by the generator autobuyer.
	if is_new_unlock and generator.level > 0:
		mark_seen()
	
	var automation_manager = state.generator_automation_manager
	var automation_button: Button = $HBoxContainer/VBoxContainer/BuyButtons/AutomationButton

	var upgrade_automation_manager: UpgradeAutomationManager = state.upgrade_automation_manager
	var upgrade_automation_button: Button = $HBoxContainer/VBoxContainer/BottomButtons/UpgradeAutomationButton
	upgrade_automation_button.visible = upgrade_automation_manager.is_automation_unlocked(generator_id)
	if upgrade_automation_button.visible:
		var upgrade_auto_enabled: bool = upgrade_automation_manager.is_enabled(generator_id)
		upgrade_automation_button.text = (
			"UPGRADE AUTO: ON"
			if upgrade_auto_enabled
			else "UPGRADE AUTO: OFF"
		)
		if (
			not _has_upgrade_automation_style
			or upgrade_auto_enabled != _last_upgrade_automation_style_enabled
		):
			_update_upgrade_automation_button_style(upgrade_automation_button, upgrade_auto_enabled)
			_last_upgrade_automation_style_enabled = upgrade_auto_enabled
			_has_upgrade_automation_style = true

	automation_button.visible = (
		automation_manager.is_automation_unlocked(generator_id)
	)

	if automation_button.visible:
		var auto_enabled: bool = automation_manager.is_enabled(generator_id)
		automation_button.text = (
			"AUTO: ON"
			if auto_enabled
			else "AUTO: OFF"
		)
		if (
			not _has_automation_style
			or auto_enabled != _last_automation_style_enabled
		):
			_update_automation_button_style(automation_button, auto_enabled)
			_last_automation_style_enabled = auto_enabled
			_has_automation_style = true
	update_illustration(generator)
	_update_relic_slots_ui()
	_update_crafting_slots_ui(generator)
	update_operation_mode_ui(generator)
	_update_event_effects_ui(generator)
	_update_level_upgrade_ui(generator)

	if not generator.unlocked:
		$HBoxContainer/VBoxContainer/Header/LevelLabel.text = "Locked"
		$HBoxContainer/VBoxContainer/HBoxContainer/StatusLabel.text = ""
		$HBoxContainer/VBoxContainer/HBoxContainer/PauseButton.disabled = true
		$HBoxContainer/VBoxContainer/ProgressBar.visible = false
		_clear_resource_rows($HBoxContainer/VBoxContainer/InputLabel)
		_clear_resource_rows($HBoxContainer/VBoxContainer/ProductionLabel)
		_clear_resource_rows($HBoxContainer/VBoxContainer/CostLabel)
		$HBoxContainer/VBoxContainer/BuyButtons/BuyButton.disabled = true
		$HBoxContainer/VBoxContainer/BuyButtons/BuyButton.text = "LOCKED"
		return
	
	$HBoxContainer/VBoxContainer/Header/GeneratorLabel.text = (
		generator.definition.display_name
	)
	
	$HBoxContainer/VBoxContainer/Header/LevelLabel.text = (
		"Level: %d"
		% generator.level
	)
	
	var status = generator.get_status()
	
	$HBoxContainer/VBoxContainer/HBoxContainer/StatusLabel.text = (
		"Status: %s"
		% status
	)
	
	$HBoxContainer/VBoxContainer/HBoxContainer/PauseButton.text = (
		"Start"
		if generator.manually_paused
		else "Stop"
	)
	
	$HBoxContainer/VBoxContainer/HBoxContainer/PauseButton.disabled = (
		generator.level <= 0
	)
	
	if generator.definition.cycle_based:
		$HBoxContainer/VBoxContainer/ProgressBar.visible = true
		$HBoxContainer/VBoxContainer/ProgressBar.value = (
			generator.get_cycle_progress_percent()
		)
	else:
		$HBoxContainer/VBoxContainer/ProgressBar.visible = false
	
	var contamination_label: Label = $HBoxContainer/VBoxContainer/ContaminationLabel
	contamination_label.visible = false
	if generator_id == "infernal_forge":
		# Match Simulation's cycle progression by using the effective CYCLE_SPEED
		# modifiers instead of maintaining a second copy of their formulas here.
		var speed_multiplier := get_effective_cycle_speed_multiplier(state, generator)
		var ash_speed_multiplier := 1.0
		var has_ash_speed_modifier := false
		for modifier in generator.modifiers:
			if modifier.id != "ashen_contamination_cycle_speed":
				continue
			if not modifier.applies_to(ModifierTypes.CYCLE_SPEED):
				continue
			ash_speed_multiplier = modifier.get_effective_multiplier(state, generator)
			has_ash_speed_modifier = true
			break

		var contamination_upgrade = state.upgrades.get("ashen_contamination")
		var show_contamination_status: bool = (
			contamination_upgrade != null
			and contamination_upgrade.is_purchased()
			and has_ash_speed_modifier
		)
		var remaining_progress := maxf(generator.get_cycle_duration() - generator.cycle_progress, 0.0)
		var remaining_seconds := remaining_progress / maxf(speed_multiplier, 0.0001)
		var remaining_time_text := _format_duration(remaining_seconds)
		var cycle_time_suffix := " left" if generator.is_operating() else ""
		contamination_label.text = "Cycle: ~%s%s" % [remaining_time_text, cycle_time_suffix]
		if show_contamination_status:
			if ash_speed_multiplier < 0.9999:
				contamination_label.text += " · Ash: -%s%% speed (x%s)" % [
					NumberFormatter.format((1.0 - ash_speed_multiplier) * 100.0),
					NumberFormatter.format(ash_speed_multiplier),
				]
			else:
				contamination_label.text += " · Ash: no slowdown (x%s)" % NumberFormatter.format(ash_speed_multiplier)
		contamination_label.visible = true
	elif generator.definition.cycle_based:
		# All cycle generators show their duration, even when idle. Only show
		# "left" while the generator is actively processing its current cycle.
		var speed_multiplier := get_effective_cycle_speed_multiplier(state, generator)
		var remaining_progress := maxf(generator.get_cycle_duration() - generator.cycle_progress, 0.0)
		var remaining_seconds := remaining_progress / maxf(speed_multiplier, 0.0001)
		var cycle_time_suffix := " left" if generator.is_operating() else ""
		var reward_summary := ""
		var operation_mode := generator.get_operation_mode()
		if operation_mode != null and state.relic_manager != null:
			for item_output in operation_mode.completion_item_outputs:
				var item_id := str(item_output.get("item_id", ""))
				var item_definition := state.relic_manager.get_stackable_item_definition(item_id)
				if item_definition.is_empty():
					continue
				var reward_quantity := maxi(0, int(item_output.get("quantity", 0)))
				if bool(item_output.get("scale_with_generator_level", true)):
					reward_quantity *= maxi(generator.level, 1)
				if reward_quantity <= 0:
					continue
				reward_summary += " · +%s %s" % [
					NumberFormatter.format(reward_quantity),
					str(item_definition.get("display_name", item_id))
				]
		if operation_mode != null and operation_mode.completion_random_relic_tier > 0:
			reward_summary += " · +1 random Tier %d Relic" % operation_mode.completion_random_relic_tier
		contamination_label.text = "Cycle: ~%s%s%s" % [
			_format_duration(remaining_seconds),
			cycle_time_suffix,
			reward_summary
		]
		contamination_label.visible = true

	var operating = generator.is_operating()
	
	var input_rows: Array[Dictionary] = []
	for input in generator.get_active_inputs():
		var input_rate := 0.0
		if operating:
			input_rate = generator.get_input_consumption_per_second(input, state)
		input_rows.append({
			"resource_id": input.resource_id,
			"prefix": "Consumes:",
			"amount": "%s/s" % NumberFormatter.format(input_rate),
		})
	_update_resource_rows($HBoxContainer/VBoxContainer/InputLabel, input_rows)

	var production_rows: Array[Dictionary] = []
	for output in generator.get_production_per_second(state):
		var production := output.amount_per_second if operating else 0.0
		production_rows.append({
			"resource_id": output.resource_id,
			"prefix": "Produces:",
			"amount": "%s/s" % NumberFormatter.format(production),
		})
	_update_resource_rows($HBoxContainer/VBoxContainer/ProductionLabel, production_rows)

	var buy_button: Button = $HBoxContainer/VBoxContainer/BuyButtons/BuyButton
	var cost_resource_id: String = generator.definition.cost_resource_id
	var cost_text: String = "%s %s" % [
		NumberFormatter.format(generator.get_cost(state)),
		state.get_resource_display_name(cost_resource_id),
	]
	var action_label: String = "INITIATE" if generator.definition.cycle_based else "BUY"
	buy_button.text = "%s · %s" % [action_label, cost_text]
	buy_button.icon = _get_small_resource_icon(cost_resource_id)
	buy_button.expand_icon = false
	buy_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	$HBoxContainer/VBoxContainer/CostLabel.visible = false
	
	buy_button.disabled = (
		not input_handler.can_buy_generator(
			generator_id
		)
	)



static func get_effective_cycle_speed_multiplier(
	game_state: GameState,
	generator: Generator
) -> float:
	var multiplier := 1.0
	for modifier in generator.modifiers:
		if not modifier.applies_to(ModifierTypes.CYCLE_SPEED):
			continue
		multiplier *= modifier.get_effective_multiplier(game_state, generator)
	return maxf(multiplier, 0.0)


static func _format_duration(seconds: float) -> String:
	var total_seconds := maxi(0, int(ceil(seconds)))
	var hours := total_seconds / 3600
	var minutes := (total_seconds % 3600) / 60
	var remaining_seconds := total_seconds % 60

	if hours > 0:
		return "%dh %02dm %02ds" % [hours, minutes, remaining_seconds]
	if minutes > 0:
		return "%dm %02ds" % [minutes, remaining_seconds]
	return "%ds" % remaining_seconds


func _get_small_resource_icon(resource_id: String) -> Texture2D:
	if _resource_icon_cache.has(resource_id):
		return _resource_icon_cache[resource_id] as Texture2D

	var source_texture: Texture2D = ResourceIconRegistry.get_texture(resource_id)
	if source_texture == null:
		return null

	var image: Image = source_texture.get_image()
	if image == null or image.is_empty():
		return source_texture

	image.resize(14, 14, Image.INTERPOLATE_LANCZOS)
	var small_texture := ImageTexture.create_from_image(image)
	_resource_icon_cache[resource_id] = small_texture
	return small_texture

func update_operation_mode_ui(
	generator: Generator
	) -> void:
	
	var option_button: OptionButton = (
		$HBoxContainer/VBoxContainer/OperationModeOptionButton
	)
	
	var modes = generator.definition.operation_modes
	var unlocked_modes: Array[GeneratorOperationMode] = []
	
	for mode in modes:
		if mode.unlocked:
			unlocked_modes.append(mode)
	
	if unlocked_modes.size() <= 1:
		option_button.visible = false
		return
	
	option_button.visible = true
	option_button.disabled = (
		not generator.can_change_operation_mode()
	)
	
	var selected_index := 0
	
	if option_button.item_count != unlocked_modes.size():
		option_button.clear()
		
		for i in range(unlocked_modes.size()):
			option_button.add_item(
				unlocked_modes[i].display_name
			)
			option_button.set_item_metadata(
				i,
				unlocked_modes[i].id
			)
			if unlocked_modes[i].id == generator.operation_mode_id:
				selected_index = i
		
		option_button.select(selected_index)
	else:
		for i in range(unlocked_modes.size()):
			option_button.set_item_metadata(
				i,
				unlocked_modes[i].id
			)
			if unlocked_modes[i].id == generator.operation_mode_id:
				selected_index = i
		
		if option_button.selected != selected_index:
			option_button.select(selected_index)


func _on_operation_mode_option_button_item_selected(
	index: int
	) -> void:
	
	if state == null:
		return
	
	var generator = state.get_generator(generator_id)
	
	if generator == null:
		return
	
	var option_button: OptionButton = (
		$HBoxContainer/VBoxContainer/OperationModeOptionButton
	)
	
	if index < 0 or index >= option_button.item_count:
		return
	
	var mode_id = str(option_button.get_item_metadata(index))
	if not generator.set_operation_mode(mode_id):
		return
	var selected_mode := generator.get_operation_mode()
	var visible_slots := selected_mode.crafting_input_requirements.size() if selected_mode != null else 0
	state.relic_manager.resize_machine_slots(generator_id, visible_slots)
	_last_crafting_signature = ""
	_update_crafting_slots_ui(generator)
	relics_changed.emit()


func _update_crafting_slots_ui(generator: Generator) -> void:
	if state == null or _crafting_slots_container == null:
		return
	var mode := generator.get_operation_mode()
	var requirements: Array[Dictionary] = mode.crafting_input_requirements if mode != null else []
	var slot_count := requirements.size()
	_crafting_slots_label.visible = slot_count > 0
	_crafting_slots_container.visible = slot_count > 0
	var slots: Dictionary = state.relic_manager.machine_slots.get(generator_id, {})
	var signature := "%s:%s" % [generator.operation_mode_id, JSON.stringify(slots)]
	if signature == _last_crafting_signature and slot_count == _crafting_slot_count:
		for slot in _crafting_slot_controls:
			slot.refresh_slot()
		return
	_last_crafting_signature = signature
	if slot_count != _crafting_slot_count:
		for child in _crafting_slots_container.get_children():
			_crafting_slots_container.remove_child(child)
			child.queue_free()
		_crafting_slot_controls.clear()
		_crafting_slot_count = slot_count
		for slot_index in range(slot_count):
			var slot := RelicSlotControl.new()
			slot.configure(state, "crafting", "", generator_id, slot_index)
			slot.equipment_changed.connect(_on_crafting_slot_changed)
			_crafting_slots_container.add_child(slot)
			_crafting_slot_controls.append(slot)
	for slot_index in range(_crafting_slot_controls.size()):
		_crafting_slot_controls[slot_index].crafting_requirement = requirements[slot_index]
		_crafting_slot_controls[slot_index].refresh_slot()


func _on_crafting_slot_changed() -> void:
	_last_crafting_signature = ""
	if state != null:
		var generator: Generator = state.get_generator(generator_id)
		if generator != null:
			_update_crafting_slots_ui(generator)
		_update_relic_slots_ui()
		relics_changed.emit()


func _on_buy_button_pressed() -> void:
	if input_handler == null:
		return

	if input_handler.buy_generator(generator_id):
		generator_purchased.emit()


func _setup_level_upgrade_ui() -> void:
	var generator_content: VBoxContainer = $HBoxContainer/VBoxContainer
	_level_upgrade_button = Button.new()
	_level_upgrade_button.name = "LevelUpgradeButton"
	_level_upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_level_upgrade_button.visible = false
	_style_action_button(_level_upgrade_button)
	_level_upgrade_button.pressed.connect(_on_level_upgrade_button_pressed)
	generator_content.add_child(_level_upgrade_button)
	generator_content.move_child(
		_level_upgrade_button,
		generator_content.get_node("BuyButtons").get_index()
	)


func _update_level_upgrade_ui(generator: Generator) -> void:
	if _level_upgrade_button == null:
		return
	var definition: GeneratorDefinition = generator.definition
	_level_upgrade_button.visible = definition.level_upgrade_enabled and generator.unlocked
	if not _level_upgrade_button.visible:
		return
	var resource_id := definition.level_upgrade_resource_id
	var resource_name := state.get_resource_display_name(resource_id)
	var current_chance := 0.0
	var next_chance := 0.0
	for mode in definition.operation_modes:
		if mode.completion_random_relic_tier <= 0:
			continue
		current_chance = input_handler.simulation.get_effective_relic_critical_chance(generator, mode)
		next_chance = current_chance
		if generator.level < definition.level_upgrade_max_level:
			next_chance = minf(
				current_chance + definition.level_critical_chance_bonus,
				definition.level_critical_chance_cap
			)
		break
	if definition.level_upgrade_max_level > 0 and generator.level >= definition.level_upgrade_max_level:
		_level_upgrade_button.text = "MAX LEVEL · %s%% CRIT" % NumberFormatter.format(current_chance * 100.0)
		_level_upgrade_button.tooltip_text = "The Relic Crucible has reached its maximum level."
		_level_upgrade_button.disabled = true
		return
	var cost := input_handler.simulation.get_generator_level_upgrade_cost(generator)
	_level_upgrade_button.text = "UPGRADE · L%d → %d · %s %s" % [
		generator.level,
		generator.level + 1,
		NumberFormatter.format(cost),
		resource_name
	]
	_level_upgrade_button.tooltip_text = "Critical chance: %s%% → %s%%" % [
		NumberFormatter.format(current_chance * 100.0),
		NumberFormatter.format(next_chance * 100.0)
	]
	_level_upgrade_button.disabled = not input_handler.can_buy_generator_level(generator_id)


func _on_level_upgrade_button_pressed() -> void:
	if input_handler == null:
		return
	if input_handler.buy_generator_level(generator_id):
		generator_purchased.emit()


func _on_pause_button_pressed() -> void:
	if input_handler == null:
		return
	
	input_handler.toggle_generator_pause(
		generator_id
	)

func _on_details_button_pressed() -> void:
	details_requested.emit(generator_id)


func _setup_relic_slots_ui() -> void:
	var illustration_panel: PanelContainer = $HBoxContainer/IllustrationPanel
	_illustration = illustration_panel.get_node_or_null("Illustration") as TextureRect
	if _illustration == null:
		return

	illustration_panel.custom_minimum_size.x = 78.0
	illustration_panel.remove_child(_illustration)

	var content := VBoxContainer.new()
	content.name = "IllustrationContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 3)
	illustration_panel.add_child(content)

	_illustration.custom_minimum_size = Vector2(0.0, 48.0)
	_illustration.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_illustration.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_illustration)

	_relic_slots_container = HBoxContainer.new()
	_relic_slots_container.name = "RelicSlots"
	_relic_slots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_relic_slots_container.add_theme_constant_override("separation", 2)
	content.add_child(_relic_slots_container)
	_relic_slots_container.hide()

	_crafting_slots_label = Label.new()
	_crafting_slots_label.name = "CraftingInputsLabel"
	_crafting_slots_label.text = "Ingredients"
	_crafting_slots_label.add_theme_font_size_override("font_size", 10)
	_crafting_slots_label.add_theme_color_override("font_color", Color(0.72, 0.61, 0.56))
	var generator_content: VBoxContainer = $HBoxContainer/VBoxContainer
	generator_content.add_child(_crafting_slots_label)
	_crafting_slots_container = HBoxContainer.new()
	_crafting_slots_container.name = "CraftingInputSlots"
	_crafting_slots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_crafting_slots_container.add_theme_constant_override("separation", 2)
	generator_content.add_child(_crafting_slots_container)
	_crafting_slots_label.hide()
	_crafting_slots_container.hide()


func _update_relic_slots_ui() -> void:
	if state == null or _relic_slots_container == null:
		return

	var unlocked_slots: int = state.eternal_flame_upgrade_manager.get_relic_slot_count(
		generator_id,
		state.eternal_flame_state
	)
	_relic_slots_container.visible = unlocked_slots > 0
	var equipped_ids := state.relic_manager.get_equipped_relic_ids(generator_id)
	var generator: Generator = state.get_generator(generator_id)
	var cycle_locked := generator != null and generator.definition.cycle_based and generator.cycle_active
	var signature := "%d:%s:%s" % [unlocked_slots, JSON.stringify(equipped_ids), str(cycle_locked)]
	if signature == _last_relic_slot_signature:
		return
	_last_relic_slot_signature = signature

	if unlocked_slots != _relic_slot_count:
		for child in _relic_slots_container.get_children():
			_relic_slots_container.remove_child(child)
			child.queue_free()
		_relic_slot_controls.clear()
		_relic_slot_count = unlocked_slots

		for slot_index in range(unlocked_slots):
			var slot := RelicSlotControl.new()
			slot.configure(state, "generator", "", generator_id, slot_index)
			slot.equipment_changed.connect(_on_relic_slot_equipment_changed)
			_relic_slots_container.add_child(slot)
			_relic_slot_controls.append(slot)

	for slot in _relic_slot_controls:
		slot.refresh_slot()


func _on_relic_slot_equipment_changed() -> void:
	if state == null:
		return
	state.rebuild_relic_modifiers()
	_update_relic_slots_ui()
	relics_changed.emit()


func update_illustration(
	generator: Generator
	) -> void:
	
	var illustration: TextureRect = _illustration
	if illustration == null:
		illustration = $HBoxContainer/IllustrationPanel/Illustration as TextureRect
	var illustration_path = generator.definition.illustration_path
	
	if illustration_path == current_illustration_path:
		return
	
	current_illustration_path = illustration_path
	
	if illustration_path == "":
		illustration.texture = null
		return
	
	var texture = load(
		illustration_path
	)
	
	if texture is Texture2D:
		illustration.texture = texture
	else:
		illustration.texture = null

func _on_automation_button_pressed() -> void:
	if state == null:
		return

	state.generator_automation_manager.toggle(generator_id)



func _on_upgrade_automation_button_pressed() -> void:
	if state == null:
		return

	var manager: UpgradeAutomationManager = state.upgrade_automation_manager
	if not manager.is_automation_unlocked(generator_id):
		return

	if manager.set_enabled(generator_id, not manager.is_enabled(generator_id)):
		upgrade_automation_changed.emit()


func _update_automation_button_style(button: Button, enabled: bool) -> void:
	_update_toggle_button_style(button, enabled)


func _update_upgrade_automation_button_style(button: Button, enabled: bool) -> void:
	_update_toggle_button_style(button, enabled)


func _style_action_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.085, 0.095, 1.0)
	normal.border_color = Color(0.32, 0.22, 0.20, 0.95)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 5.0
	normal.content_margin_right = 5.0
	normal.content_margin_top = 3.0
	normal.content_margin_bottom = 3.0
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_color_override("font_color", Color(0.88, 0.80, 0.70))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.75))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.88, 0.75))
	button.add_theme_color_override("font_disabled_color", Color(0.43, 0.38, 0.38))
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.20, 0.12, 0.105, 1.0)
	hover.border_color = Color(0.62, 0.34, 0.22, 1.0)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.28, 0.14, 0.095, 1.0)
	pressed.border_color = Color(0.82, 0.40, 0.22, 1.0)
	button.add_theme_stylebox_override("pressed", pressed)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.085, 0.07, 0.08, 1.0)
	disabled.border_color = Color(0.20, 0.16, 0.16, 1.0)
	button.add_theme_stylebox_override("disabled", disabled)


func _style_operation_mode_dropdown() -> void:
	var option_button: OptionButton = $HBoxContainer/VBoxContainer/OperationModeOptionButton
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.085, 0.095, 1.0)
	normal.border_color = Color(0.32, 0.22, 0.20, 0.95)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 6.0
	normal.content_margin_right = 6.0
	normal.content_margin_top = 3.0
	normal.content_margin_bottom = 3.0
	option_button.add_theme_stylebox_override("normal", normal)
	option_button.add_theme_color_override("font_color", Color(0.88, 0.80, 0.70))
	option_button.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.75))
	option_button.add_theme_color_override("font_disabled_color", Color(0.43, 0.38, 0.38))
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.20, 0.12, 0.105, 1.0)
	hover.border_color = Color(0.62, 0.34, 0.22, 1.0)
	option_button.add_theme_stylebox_override("hover", hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.28, 0.14, 0.095, 1.0)
	pressed.border_color = Color(0.82, 0.40, 0.22, 1.0)
	option_button.add_theme_stylebox_override("pressed", pressed)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.085, 0.07, 0.08, 1.0)
	disabled.border_color = Color(0.20, 0.16, 0.16, 1.0)
	option_button.add_theme_stylebox_override("disabled", disabled)

	var popup: PopupMenu = option_button.get_popup()
	var popup_panel := StyleBoxFlat.new()
	popup_panel.bg_color = Color(0.055, 0.045, 0.055, 0.99)
	popup_panel.border_color = Color(0.32, 0.22, 0.20, 1.0)
	popup_panel.set_border_width_all(1)
	popup_panel.set_corner_radius_all(4)
	popup_panel.content_margin_left = 4.0
	popup_panel.content_margin_right = 4.0
	popup_panel.content_margin_top = 4.0
	popup_panel.content_margin_bottom = 4.0
	popup.add_theme_stylebox_override("panel", popup_panel)
	var popup_hover := StyleBoxFlat.new()
	popup_hover.bg_color = Color(0.24, 0.13, 0.10, 1.0)
	popup_hover.set_corner_radius_all(3)
	popup.add_theme_stylebox_override("hover", popup_hover)
	popup.add_theme_color_override("font_color", Color(0.88, 0.80, 0.70))
	popup.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.75))
	popup.add_theme_color_override("font_disabled_color", Color(0.43, 0.38, 0.38))
	popup.add_theme_color_override("font_accelerator_color", Color(0.66, 0.59, 0.57))
	popup.add_theme_color_override("font_separator_color", Color(0.32, 0.22, 0.20))


func _update_toggle_button_style(button: Button, enabled: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = (
		Color(0.105, 0.19, 0.12, 1.0)
		if enabled
		else Color(0.12, 0.085, 0.095, 1.0)
	)
	style.border_color = (
		Color(0.34, 0.52, 0.34, 1.0)
		if enabled
		else Color(0.32, 0.22, 0.20, 0.95)
	)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_color_override(
		"font_color",
		Color(0.68, 0.83, 0.67) if enabled else Color(0.88, 0.80, 0.70)
	)
	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = style.bg_color.lightened(0.08)
	hover_style.border_color = style.border_color.lightened(0.08)
	button.add_theme_stylebox_override("hover", hover_style)
	var pressed_style := style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = style.bg_color.darkened(0.08)
	button.add_theme_stylebox_override("pressed", pressed_style)
	var disabled_style := style.duplicate() as StyleBoxFlat
	disabled_style.bg_color = Color(0.085, 0.07, 0.08, 1.0)
	disabled_style.border_color = Color(0.20, 0.16, 0.16, 1.0)
	button.add_theme_stylebox_override("disabled", disabled_style)




func _clear_resource_rows(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _update_resource_rows(container: Node, rows: Array[Dictionary]) -> void:
	var rebuild := container.get_child_count() != rows.size()
	if not rebuild:
		for i in range(rows.size()):
			var existing_row := container.get_child(i) as HBoxContainer
			if (
				existing_row == null
				or str(existing_row.get_meta("resource_id", "")) != str(rows[i].get("resource_id", ""))
			):
				rebuild = true
				break

	if rebuild:
		_clear_resource_rows(container)
		for row_data in rows:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.set_meta("resource_id", str(row_data.get("resource_id", "")))
			container.add_child(row)

			var prefix_label := Label.new()
			prefix_label.name = "PrefixLabel"
			prefix_label.add_theme_font_size_override("font_size", 11)
			row.add_child(prefix_label)

			var icon := ResourceIcon.new()
			icon.name = "ResourceIcon"
			icon.setup(str(row_data.get("resource_id", "")), Vector2(14.0, 14.0))
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(icon)

			var value_label := Label.new()
			value_label.name = "ValueLabel"
			value_label.add_theme_font_size_override("font_size", 11)
			value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(value_label)

	for i in range(rows.size()):
		var row_data: Dictionary = rows[i]
		var row := container.get_child(i) as HBoxContainer
		var prefix_label := row.get_node("PrefixLabel") as Label
		prefix_label.text = str(row_data.get("prefix", ""))
		prefix_label.add_theme_color_override("font_color", Color(0.66, 0.59, 0.57))
		var value_label := row.get_node("ValueLabel") as Label
		value_label.text = "%s %s" % [
			str(row_data.get("amount", "")),
			state.get_resource_display_name(str(row_data.get("resource_id", ""))),
		]
		var prefix := str(row_data.get("prefix", ""))
		var resource_id := str(row_data.get("resource_id", ""))
		var is_ash := resource_id == "ash"

		if prefix == "Produces:":
			value_label.add_theme_color_override(
				"font_color",
				Color(0.88, 0.57, 0.50) if is_ash else Color(0.55, 0.85, 0.58)
			)
		elif prefix == "Consumes:":
			value_label.add_theme_color_override(
				"font_color",
				Color(0.55, 0.85, 0.58) if is_ash else Color(0.88, 0.57, 0.50)
			)
		else:
			value_label.add_theme_color_override("font_color", Color(0.88, 0.80, 0.70))


# Event effects are kept behind a small optional button so the generator card
# remains compact until the player wants the detailed chance/effect breakdown.
func _setup_event_effects_ui() -> void:
	var generator_content: VBoxContainer = $HBoxContainer/VBoxContainer

	_event_effects_button = Button.new()
	_event_effects_button.name = "EventEffectsButton"
	_event_effects_button.text = "Cycle Effects  ·  INFO"
	_event_effects_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_event_effects_button.visible = false
	_style_action_button(_event_effects_button)
	_event_effects_button.pressed.connect(_on_event_effects_button_pressed)
	generator_content.add_child(_event_effects_button)

	_event_effects_popup = AcceptDialog.new()
	_event_effects_popup.name = "EventEffectsPopup"
	_event_effects_popup.title = "Generator Effects"
	_event_effects_popup.dialog_text = ""
	_event_effects_popup.min_size = Vector2i(320, 180)
	add_child(_event_effects_popup)


func _update_event_effects_ui(generator: Generator) -> void:
	if _event_effects_button == null:
		return

	var has_event_effects := false
	for effect in generator.event_effects:
		if state.get_upgrade(effect.event_source_upgrade_id) != null:
			has_event_effects = true
			break

	_event_effects_button.visible = generator.unlocked and has_event_effects
	_event_effects_button.text = "Cycle Effects  ·  INFO"
	_event_effects_button.tooltip_text = (
		"View event chances, effects, and operation-mode restrictions."
	)


func _on_event_effects_button_pressed() -> void:
	if state == null or _event_effects_popup == null:
		return
	var generator: Generator = state.get_generator(generator_id)
	if generator == null:
		return

	_event_effects_popup.title = "%s — Effects" % generator.definition.display_name
	_event_effects_popup.dialog_text = _build_event_effects_text(generator)
	_event_effects_popup.popup_centered()


func _build_event_effects_text(generator: Generator) -> String:
	var lines: PackedStringArray = []
	var current_mode_name := generator.operation_mode_id
	var current_mode := generator.get_operation_mode()
	if current_mode != null:
		current_mode_name = current_mode.display_name

	lines.append("Current mode: %s" % current_mode_name)
	lines.append("Chance values include the levels you have purchased.")
	lines.append("")

	var found_effect := false
	for effect in generator.event_effects:
		var source_upgrade: Upgrade = state.get_upgrade(effect.event_source_upgrade_id)
		if source_upgrade == null or source_upgrade.level <= 0:
			continue

		found_effect = true
		var mode_restricted := not effect.operation_mode_ids.is_empty()
		var applies_now := (
			not mode_restricted
			or effect.operation_mode_ids.has(generator.operation_mode_id)
		)
		var mode_text := "All modes" if not mode_restricted else _get_event_effect_mode_names(generator, effect.operation_mode_ids)
		lines.append("%s%s" % [
			"✓ " if applies_now else "— ",
			source_upgrade.definition.display_name
		])
		lines.append("  " + _describe_event_effect(effect, source_upgrade))
		lines.append("  Modes: %s%s" % [
			mode_text,
			"" if applies_now else " (inactive in current mode)"
		])
		lines.append("")

	if not found_effect:
		lines.append("No purchased event effects are currently registered.")

	return "\n".join(lines).strip_edges()


func _describe_event_effect(effect: UpgradeEffect, source_upgrade: Upgrade) -> String:
	var effect_level: int = maxi(source_upgrade.level, 0)
	match effect.event_action:
		UpgradeEffectTypes.EVENT_ACTION_TRIGGER:
			var chance := clampf(effect.event_chance * effect_level, 0.0, 1.0)
			return "Chance: %s%% per completed cycle to trigger %s." % [
				NumberFormatter.format(chance * 100.0),
				_get_event_display_name(effect.event_id)
			]
		UpgradeEffectTypes.EVENT_ACTION_MULTIPLY_COMPLETION_OUTPUT:
			var bonus := effect.event_value * effect_level * 100.0
			var resource_name := state.get_resource_display_name(effect.event_resource_id) if effect.event_resource_id != "" else "completion output"
			var condition_text := ""
			if effect.event_condition_id != "":
				condition_text = " when %s triggers" % _get_event_display_name(effect.event_condition_id)
			return "Bonus: +%s%% %s%s." % [
				NumberFormatter.format(bonus),
				resource_name,
				condition_text
			]
		UpgradeEffectTypes.EVENT_ACTION_DECREASE_GENERATOR_LEVEL:
			var chance := clampf(effect.event_chance * effect_level, 0.0, 1.0)
			var levels_lost := maxi(roundi(effect.event_value), 1)
			return "Chance: %s%% per completed cycle to lose %d generator level(s)." % [
				NumberFormatter.format(chance * 100.0),
				levels_lost
			]
		_:
			return "Event action: %s." % effect.event_action.replace("_", " ")


func _get_event_display_name(event_id: String) -> String:
	if event_id == UpgradeEffectTypes.EVENT_CYCLE_COMPLETED:
		return "cycle completion"
	for effect in state.get_generator(generator_id).event_effects:
		if effect.event_id != event_id:
			continue
		var source_upgrade: Upgrade = state.get_upgrade(effect.event_source_upgrade_id)
		if source_upgrade != null:
			return source_upgrade.definition.display_name
	return event_id.replace("_", " ")


func _get_event_effect_mode_names(generator: Generator, mode_ids: Array[String]) -> String:
	var names: Array[String] = []
	for mode_id in mode_ids:
		var found := false
		for mode in generator.definition.operation_modes:
			if mode.id != mode_id:
				continue
			names.append(mode.display_name)
			found = true
			break
		if not found:
			names.append(mode_id.replace("_", " ").capitalize())
	return ", ".join(names)


func _on_stats_button_pressed() -> void:
	if generator_id.is_empty():
		return
	stats_requested.emit(generator_id)
