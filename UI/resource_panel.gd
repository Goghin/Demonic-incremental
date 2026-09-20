class_name ResourcePanel
extends Control


var state: GameState
var resource_labels: Dictionary = {}


func setup(game_state: GameState) -> void:
	state = game_state
	
	for resource in state.get_resources().values():
		var definition = resource.definition
		
		var label = Label.new()
		label.text = definition.display_name
		label.custom_minimum_size = Vector2( 150, 0 )
		
		$ResourceContainer.add_child(label)
		resource_labels[definition.id] = label


func _process(_delta: float) -> void:
	if state == null:
		return
	
	for resource_id in resource_labels:
		var label = resource_labels[resource_id]
		var amount = state.get_resource_amount(resource_id)
		
		label.text = "%s: %s" % [
			state.get_resource_display_name(resource_id),
			NumberFormatter.format(amount)
		]
