class_name GeneratorPanel
extends Control


var state: GameState
var input_handler: InputHandler
var generator_id: String
var current_illustration_path: String = ""

signal upgrades_requested(generator_id: String)
signal upgrade_automation_changed


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
	
	var automation_manager = state.generator_automation_manager
	var automation_button = (
		$HBoxContainer/VBoxContainer/HBoxContainer/AutomationButton
	)

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
		_update_upgrade_automation_button_style(upgrade_automation_button, upgrade_auto_enabled)

	automation_button.visible = (
		automation_manager.is_automation_unlocked(generator_id)
	)

	if automation_button.visible:
		automation_button.text = (
			"AUTO: ON"
			if automation_manager.is_enabled(generator_id)
			else "AUTO: OFF"
		)	
	
	update_illustration(generator)
	update_operation_mode_ui(generator)
	
	if not generator.unlocked:
		$HBoxContainer/VBoxContainer/LevelLabel.text = "Locked"
		$HBoxContainer/VBoxContainer/HBoxContainer/StatusLabel.text = ""
		$HBoxContainer/VBoxContainer/HBoxContainer/PauseButton.disabled = true
		$HBoxContainer/VBoxContainer/ProgressBar.visible = false
		$HBoxContainer/VBoxContainer/InputLabel.text = ""
		$HBoxContainer/VBoxContainer/ProductionLabel.text = ""
		$HBoxContainer/VBoxContainer/CostLabel.text = ""
		$HBoxContainer/VBoxContainer/BuyButton.disabled = true
		return
	
	$HBoxContainer/VBoxContainer/GeneratorLabel.text = (
		generator.definition.display_name
	)
	
	$HBoxContainer/VBoxContainer/LevelLabel.text = (
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
	
	var input_text = ""
	
	for input in generator.get_active_inputs():
		var input_rate = 0.0
		
		if operating:
			input_rate = generator.get_input_consumption_per_second(
				input,
				state
			)
		
		var input_name = state.get_resource_display_name(
			input.resource_id
		)
		
		if input_text != "":
			input_text += "\n"
		
		input_text += "Consumes: %s %s/s" % [
			NumberFormatter.format(input_rate),
			input_name
		]
	
	$HBoxContainer/VBoxContainer/InputLabel.text = input_text
	
	var production_outputs = (
		generator.get_production_per_second(state)
	)
	
	var production_text = ""
	
	for output in production_outputs:
		var production = 0.0
		
		if operating:
			production = output.amount_per_second
		
		var output_name = state.get_resource_display_name(
			output.resource_id
		)
		
		if production_text != "":
			production_text += "\n"
		
		production_text += "Production: %s %s/s" % [
			NumberFormatter.format(production),
			output_name
		]
	
	$HBoxContainer/VBoxContainer/ProductionLabel.text = production_text
	
	var cost_name = state.get_resource_display_name(
		generator.definition.cost_resource_id
	)
	
	$HBoxContainer/VBoxContainer/CostLabel.text = "Cost: %s %s" % [
		NumberFormatter.format(
			generator.get_cost(state)
		),
		cost_name
	]
	
	$HBoxContainer/VBoxContainer/BuyButton.disabled = (
		not input_handler.can_buy_generator(
			generator_id
		)
	)


func update_operation_mode_ui(
	generator: Generator
	) -> void:
	
	var option_button = (
		$HBoxContainer/VBoxContainer/OperationModeOptionButton
	)
	
	var modes = generator.definition.operation_modes
	
	if modes.size() <= 1:
		option_button.visible = false
		return
	
	option_button.visible = true
	
	var selected_index = 0
	
	if option_button.item_count != modes.size():
		option_button.clear()
		
		for i in range(modes.size()):
			var mode = modes[i]
			
			option_button.add_item(
				mode.display_name
			)
			
			if mode.id == generator.operation_mode_id:
				selected_index = i
		
		option_button.select(selected_index)
	else:
		for i in range(modes.size()):
			if modes[i].id == generator.operation_mode_id:
				selected_index = i
				break
		
		if option_button.selected != selected_index:
			option_button.select(selected_index)
	
	option_button.disabled = (
		not generator.can_change_operation_mode()
	)


func _on_operation_mode_option_button_item_selected(
	index: int
	) -> void:
	
	if state == null:
		return
	
	var generator = state.get_generator(generator_id)
	
	if generator == null:
		return
	
	var modes = generator.definition.operation_modes
	
	if index < 0 or index >= modes.size():
		return
	
	generator.set_operation_mode(
		modes[index].id
	)


func _on_buy_button_pressed() -> void:
	if input_handler == null:
		return
	
	input_handler.buy_generator(generator_id)


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


func _update_upgrade_automation_button_style(button: Button, enabled: bool) -> void:
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
