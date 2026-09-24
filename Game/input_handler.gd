class_name InputHandler
extends RefCounted


var simulation: Simulation


func _init(game_simulation: Simulation) -> void:
	simulation = game_simulation



func buy_generator(generator_id: String) -> bool:
	return simulation.buy_generator(generator_id)


func can_buy_generator(generator_id: String) -> bool:
	return simulation.can_buy_generator(generator_id)


func buy_upgrade(upgrade_id: String) -> bool:
	return simulation.buy_upgrade(upgrade_id)


func toggle_generator_pause(
	generator_id: String
	) -> void:
	
	simulation.toggle_generator_pause(
		generator_id
	)
