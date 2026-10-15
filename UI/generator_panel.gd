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

signal upgrades_requested(generator_id: String)
signal selection_requested(generator_id: String)
signal upgrade_automation_changed
signal generator_purchased


var _normal_panel_style: StyleBox
var is_new_unlock: bool = false


func mark_new_unlock() -> void:
	is_new_unlock = true
	$HBoxContainer/VBoxContainer/Header/NewLabel.visible = true


func mark_seen() -> void:
	is_new_unlock = false
	$HBoxContainer/VBoxContainer/Header/NewLabel.visible = false


func _ready() -> void:
	_normal_panel_style = get_theme_stylebox("panel")


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
	selected_style.set_border_width_all(3)
	selected_style.border_color = Color(1.0, 0.48, 0.16, 1.0)
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
	update_operation_mode_ui(generator)
	
	if not generator.unlocked:
		$HBoxContainer/VBoxContainer/Header/LevelLabel.text = "Locked"
		$HBoxContainer/VBoxContainer/HBoxContainer/StatusLabel.text = ""
		$HBoxContainer/VBoxContainer/HBoxContainer/PauseButton.disabled = true
		$HBoxContainer/VBoxContainer/ProgressBar.visible = false
		_clear_resource_rows($HBoxContainer/VBoxContainer/InputLabel)
		_clear_resource_rows($HBoxContainer/VBoxContainer/ProductionLabel)
		_clear_resource_rows($HBoxContainer/VBoxContainer/CostLabel)
		$HBoxContainer/VBoxContainer/BuyButtons/BuyButton.disabled = true
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

	_update_resource_rows($HBoxContainer/VBoxContainer/CostLabel, [{
		"resource_id": generator.definition.cost_resource_id,
		"prefix": "Cost:",
		"amount": NumberFormatter.format(generator.get_cost(state)),
	}])
	
	$HBoxContainer/VBoxContainer/BuyButtons/BuyButton.disabled = (
		not input_handler.can_buy_generator(
			generator_id
		)
	)


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
	generator.set_operation_mode(mode_id)


func _on_buy_button_pressed() -> void:
	if input_handler == null:
		return

	if input_handler.buy_generator(generator_id):
		generator_purchased.emit()


func _on_pause_button_pressed() -> void:
	if input_handler == null:
		return
	
	input_handler.toggle_generator_pause(
		generator_id
	)

func _on_upgrades_button_pressed() -> void:
	upgrades_requested.emit(generator_id)

func update_illustration(
	generator: Generator
	) -> void:
	
	var illustration = $HBoxContainer/IllustrationPanel/Illustration
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


func _update_toggle_button_style(button: Button, enabled: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = (
		Color(0.18, 0.36, 0.22, 1.0)
		if enabled
		else Color(0.25, 0.20, 0.20, 1.0)
	)
	style.border_color = (
		Color(0.55, 0.90, 0.52, 1.0)
		if enabled
		else Color(0.90, 0.52, 0.42, 1.0)
	)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = style.bg_color.lightened(0.12)
	button.add_theme_stylebox_override("hover", hover_style)
	var pressed_style := style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = style.bg_color.darkened(0.10)
	button.add_theme_stylebox_override("pressed", pressed_style)



func _clear_resource_rows(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _update_resource_rows(container: Node, rows: Array[Dictionary]) -> void:
	_clear_resource_rows(container)

	for row_data in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(row)

		var prefix_label := Label.new()
		prefix_label.text = str(row_data.get("prefix", ""))
		prefix_label.add_theme_font_size_override("font_size", 11)
		row.add_child(prefix_label)

		var resource_id := str(row_data.get("resource_id", ""))
		var icon := ResourceIcon.new()
		icon.setup(resource_id, Vector2(14.0, 14.0))
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)

		var value_label := Label.new()
		value_label.text = "%s %s" % [
			str(row_data.get("amount", "")),
			state.get_resource_display_name(resource_id),
		]
		value_label.add_theme_font_size_override("font_size", 11)
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(value_label)
