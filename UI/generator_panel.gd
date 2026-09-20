
class_name GeneratorPanel
extends Control


var state: GameState
var input_handler: InputHandler
var generator_id: String


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
	
	if not generator.unlocked:
		$VBoxContainer/LevelLabel.text = "Locked"
		$VBoxContainer/HBoxContainer/StatusLabel.text = ""
		$VBoxContainer/HBoxContainer/PauseButton.disabled = true
		$VBoxContainer/ProgressBar.visible = false
		$VBoxContainer/InputLabel.text = ""
		$VBoxContainer/ProductionLabel.text = ""
		$VBoxContainer/CostLabel.text = ""
		$VBoxContainer/BuyButton.disabled = true
		return
	
	$VBoxContainer/GeneratorLabel.text = (
		generator.definition.display_name
	)
	
	$VBoxContainer/LevelLabel.text = (
		"Level: %d"
		% generator.level
	)
	
	var status = generator.get_status()
	
	$VBoxContainer/HBoxContainer/StatusLabel.text = (
		"Status: %s"
		% status
	)
	
	$VBoxContainer/HBoxContainer/PauseButton.text = (
		"Play"
		if generator.manually_paused
		else "Pause"
	)
	
	$VBoxContainer/HBoxContainer/PauseButton.disabled = (
		generator.level <= 0
	)
	
	if generator.definition.cycle_based:
		$VBoxContainer/ProgressBar.visible = true
		$VBoxContainer/ProgressBar.value = (
			generator.get_cycle_progress_percent()
		)
	else:
		$VBoxContainer/ProgressBar.visible = false
	
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
	
	$VBoxContainer/InputLabel.text = input_text
	
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
	
	$VBoxContainer/ProductionLabel.text = production_text
	
	var cost_name = state.get_resource_display_name(
		generator.definition.cost_resource_id
	)
	
	$VBoxContainer/CostLabel.text = "Cost: %s %s" % [
		NumberFormatter.format(
			generator.get_cost(state)
		),
		cost_name
	]
	
	$VBoxContainer/BuyButton.disabled = (
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
