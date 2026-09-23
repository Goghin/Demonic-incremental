class_name GeneratorPanel
extends Control


var state: GameState
var input_handler: InputHandler
var generator_id: String
var current_illustration_path: String = ""

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
	
	update_illustration(generator)
	
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
		"Play"
		if generator.manually_paused
		else "Pause"
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
	
	for input in generator.definition.inputs:
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
