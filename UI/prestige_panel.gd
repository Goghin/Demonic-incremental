class_name PrestigePanel
extends Control


var state: GameState
var prestige_system: PrestigeSystem
var save_manager: SaveManager
var time_manager: TimeManager

var realm_container: VBoxContainer
var realm_available_label: Label
var realm_assigned_label: Label

var realm_rows: Dictionary = {}

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
	
	_create_realm_ui()
	refresh()


func _create_realm_ui() -> void:
	if realm_container != null:
		return
	
	realm_container = VBoxContainer.new()
	realm_container.name = "RealmContainer"
	
	realm_container.add_theme_constant_override(
		"separation",
		6
	)
	
	$VBoxContainer.add_child(
		realm_container
	)
	
	var title = Label.new()
	title.text = "REALM"
	title.custom_minimum_size = Vector2(0, 30)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	realm_container.add_child(title)
	
	realm_available_label = Label.new()
	realm_container.add_child(realm_available_label)
	
	realm_assigned_label = Label.new()
	realm_container.add_child(realm_assigned_label)
	
	_create_realm_stat_row(
		"stability",
		"Stability"
	)
	
	_create_realm_stat_row(
		"intensity",
		"Intensity"
	)
	
	_create_realm_stat_row(
		"density",
		"Density"
	)
	
	_create_realm_stat_row(
		"resonance",
		"Resonance"
	)


func _create_realm_stat_row(
	stat_name: String,
	display_name: String
	) -> void:
	
	var row = HBoxContainer.new()
	row.name = "%sRow" % stat_name
	
	row.add_theme_constant_override(
		"separation",
		6
	)
	
	realm_container.add_child(row)
	
	var label = Label.new()
	label.text = display_name
	label.custom_minimum_size = Vector2(100, 0)
	
	row.add_child(label)
	
	var minus_button = Button.new()
	minus_button.text = "-"
	minus_button.custom_minimum_size = Vector2(35, 30)
	
	row.add_child(minus_button)
	
	var value_label = Label.new()
	value_label.text = "0"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.custom_minimum_size = Vector2(40, 30)
	
	row.add_child(value_label)
	
	var plus_button = Button.new()
	plus_button.text = "+"
	plus_button.custom_minimum_size = Vector2(35, 30)
	
	row.add_child(plus_button)
	
	minus_button.pressed.connect(
		func():
			_on_realm_minus_pressed(stat_name)
	)
	
	plus_button.pressed.connect(
		func():
			_on_realm_plus_pressed(stat_name)
	)
	
	realm_rows[stat_name] = {
		"value_label": value_label,
		"minus_button": minus_button,
		"plus_button": plus_button
	}


func _on_realm_plus_pressed(stat_name: String) -> void:
	if state == null:
		return
	
	var eternal_flame_state = state.eternal_flame_state
	
	if eternal_flame_state.assign_flame(stat_name):
		state.realm_effects.rebuild(
			eternal_flame_state,
			state.heat_leak_threshold
		)
		
		refresh()
		save_manager.save_game(
			state,
			time_manager
		)


func _on_realm_minus_pressed(stat_name: String) -> void:
	if state == null:
		return
	
	var eternal_flame_state = state.eternal_flame_state
	
	if eternal_flame_state.remove_flame(stat_name):
		state.realm_effects.rebuild(
			eternal_flame_state,
			state.heat_leak_threshold
		)
		
		refresh()
		save_manager.save_game(
			state,
			time_manager
		)


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
	
	_refresh_realm_ui()


func _refresh_realm_ui() -> void:
	if realm_container == null:
		return
	
	var eternal_flame_state = state.eternal_flame_state
	
	var assigned = (
		eternal_flame_state.get_assigned_flames()
	)
	
	var available = (
		eternal_flame_state.get_unassigned_flames()
	)
	
	realm_available_label.text = (
		"Unassigned Eternal Flames: %d"
		% available
	)
	
	realm_assigned_label.text = (
		"Assigned to Realm: %d / %d"
		% [
			assigned,
			int(eternal_flame_state.eternal_flame)
		]
	)
	
	for stat_name in realm_rows:
		var value = (
			eternal_flame_state.get_stat_value(
				stat_name
			)
		)
		
		var row = realm_rows[stat_name]
		
		row["value_label"].text = str(value)
		row["minus_button"].disabled = value <= 0
		row["plus_button"].disabled = available <= 0


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
