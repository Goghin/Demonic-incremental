class_name PrestigePanel
extends Control


var state: GameState
var prestige_system: PrestigeSystem
var save_manager: SaveManager
var time_manager: TimeManager

@onready var crystallized_flame_label: Label = $VBoxContainer/CrystallizedFlameLabel
@onready var eternal_flame_label: Label = $VBoxContainer/EternalFlameLabel
@onready var gain_label: Label = $VBoxContainer/GainLabel
@onready var smash_button: Button = $VBoxContainer/SmashButton


func setup(
	game_state: GameState,
	game_save_manager: SaveManager,
	game_time_manager: TimeManager
	) -> void:
	
	state = game_state
	save_manager = game_save_manager
	time_manager = game_time_manager
	prestige_system = PrestigeSystem.new()
	
	refresh()


func refresh() -> void:
	if state == null:
		return
	
	var crystallized_flame = state.get_resource_amount(
		ResourceIds.CRYSTALIZED_FLAME
	)
	
	var eternal_flame = (
		state.eternal_flame_state.eternal_flame
	)
	
	var eternal_flame_gain = (
		prestige_system.calculate_eternal_flame_gain(
			state
		)
	)
	
	crystallized_flame_label.text = (
		"Crystallized Flame: %.0f"
		% crystallized_flame
	)
	
	eternal_flame_label.text = (
		"Eternal Flame: %.0f"
		% eternal_flame
	)
	
	gain_label.text = (
		"Eternal Flame on Smash: +%.0f"
		% eternal_flame_gain
	)
	
	smash_button.disabled = eternal_flame_gain <= 0.0


func _on_smash_button_pressed() -> void:
	if state == null:
		return
	
	var eternal_flame_gain = (
		prestige_system.smash(
			state
		)
	)
	
	print(
		"Smash! Gained ",
		eternal_flame_gain,
		" Eternal Flame."
	)
	
	refresh()
	
	save_manager.save_game(
		state,
		time_manager
	)

func _process(_delta: float) -> void:
	if not visible:
		return
	
	refresh()
