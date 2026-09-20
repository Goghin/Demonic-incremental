
class_name UpgradePanel
extends Control


var state: GameState
var input_handler: InputHandler
var upgrade_id: String
var info_popup: UpgradeInfoPopup
var simulation: Simulation

func _ready() -> void:
	_setup_button_style()


func setup(
	game_state: GameState,
	game_simulation: Simulation,
	game_input_handler: InputHandler,
	game_upgrade_id: String,
	game_info_popup: UpgradeInfoPopup
	) -> void:
	
	state = game_state
	simulation = game_simulation
	input_handler = game_input_handler
	upgrade_id = game_upgrade_id
	info_popup = game_info_popup
	
	$UpgradeButton.mouse_entered.connect(
		_on_upgrade_button_mouse_entered
	)
	
	$UpgradeButton.mouse_exited.connect(
		_on_upgrade_button_mouse_exited
	)



func _process(_delta: float) -> void:
	if state == null:
		return
	
	var upgrade = state.get_upgrade(
		upgrade_id
	)
	
	if upgrade == null:
		return
	
	_update_button(
		upgrade
	)
	
	if info_popup != null and info_popup.visible:
		info_popup.update_info()



func _update_button(upgrade: Upgrade) -> void:
	var display_name = upgrade.definition.display_name
	
	$UpgradeButton.text = get_button_text(
		display_name,
		upgrade
	)
	
	if upgrade.is_maxed():
		if upgrade.definition.automatic:
			_set_button_state(
				"active"
			)
		else:
			_set_button_state(
				"purchased"
			)
		
		return
	
	var exclusive_upgrade = state.get_exclusive_upgrade(
		upgrade
	)
	
	if exclusive_upgrade != null:
		_set_button_state(
			"exclusive"
		)
		
		return
	
	var next_cost = simulation.get_upgrade_cost(
		upgrade	
		)
	
	var can_afford = (
		state.get_resource_amount(
			upgrade.definition.cost_resource_id
		) >= next_cost
	)
	
	var requirements_met = state.requirements_met(
		upgrade.definition.requirements
	)
	
	if not requirements_met:
		_set_button_state(
			"requirements"
		)
		
		return
	
	if not can_afford:
		_set_button_state(
			"cannot_afford"
		)
		
		return
	
	_set_button_state(
		"available"
	)


func get_button_text(
	display_name: String,
	upgrade: Upgrade
	) -> String:
	
	var initials = get_initials(
		display_name
	)
	
	if upgrade.definition.max_level <= 1:
		return initials
	
	return "%s\n%d/%d" % [
		initials,
		upgrade.level,
		upgrade.definition.max_level
	]





func get_initials(display_name: String) -> String:
	var words = display_name.split(
		" ",
		false
	)
	
	if words.size() == 1:
		return words[0].left(2).to_upper()
	
	var initials = ""
	
	for word in words:
		if word.is_empty():
			continue
		
		initials += word[0].to_upper()
		
		if initials.length() >= 3:
			break
	
	return initials


func get_requirement_text(
	requirement: Requirement
	) -> String:
	
	if requirement.type == RequirementTypes.RESOURCE:
		var resource_name = (
			state.get_resource_display_name(
				requirement.target_id
			)
		)
		
		var current_amount = (
			state.get_resource_amount(
				requirement.target_id
			)
		)
		
		return "Requires %.0f %s (%.0f / %.0f)" % [
			requirement.value,
			resource_name,
			current_amount,
			requirement.value
		]
	
	if requirement.type == RequirementTypes.GENERATOR_LEVEL:
		var generator = state.get_generator(
			requirement.target_id
		)
		
		if generator == null:
			return "Requires unknown generator."
		
		return "Requires %s level %d (current: %d)" % [
			generator.definition.display_name,
			int(requirement.value),
			generator.level
		]
	
	if requirement.type == RequirementTypes.UPGRADE_PURCHASED:
		var required_upgrade = state.get_upgrade(
			requirement.target_id
		)
		
		if required_upgrade == null:
			return "Requires unknown upgrade."
		
		return "Requires: %s" % (
			required_upgrade.definition.display_name
		)
	
	if requirement.type == RequirementTypes.UPGRADE_LEVEL:
		var required_upgrade = state.get_upgrade(
			requirement.target_id
		)
		
		if required_upgrade == null:
			return "Requires unknown upgrade."
		
		return "Requires %s level %d (current: %d)" % [
			required_upgrade.definition.display_name,
			int(requirement.value),
			required_upgrade.level
		]
	
	return "Unknown requirement."


func _on_buy_button_pressed() -> void:
	if input_handler == null:
		return
	
	input_handler.buy_upgrade(
		upgrade_id
	)


func _on_upgrade_button_mouse_entered() -> void:
	if info_popup == null:
		return
	
	info_popup.setup(
	state,
	simulation,
	upgrade_id
	)
	
	var popup_position = (
		global_position
		+ Vector2(
			size.x + 10.0,
			0.0
		)
	)
	
	var viewport_size = (
		get_viewport_rect().size
	)
	
	var popup_size = (
		info_popup.size
	)
	
	if popup_position.x + popup_size.x > viewport_size.x:
		popup_position.x = (
			global_position.x
			- popup_size.x
			- 10.0
		)
	
	if popup_position.y + popup_size.y > viewport_size.y:
		popup_position.y = (
			viewport_size.y
			- popup_size.y
			- 10.0
		)
	
	popup_position.x = max(
		popup_position.x,
		10.0
	)
	
	popup_position.y = max(
		popup_position.y,
		10.0
	)
	
	info_popup.position = popup_position
	info_popup.visible = true


func _on_upgrade_button_mouse_exited() -> void:
	if info_popup == null:
		return
	
	info_popup.visible = false


func _set_button_state(
	state_name: String
	) -> void:
	
	match state_name:
		"active":
			$UpgradeButton.disabled = true
			$UpgradeButton.modulate = Color(
				0.6,
				1.0,
				0.6
			)
			
		"available":
			$UpgradeButton.disabled = false
			$UpgradeButton.modulate = Color(
				1.0,
				1.0,
				1.0
			)
		
		"cannot_afford":
			$UpgradeButton.disabled = true
			$UpgradeButton.modulate = Color(
				0.65,
				0.65,
				0.65
			)
		
		"requirements":
			$UpgradeButton.disabled = true
			$UpgradeButton.modulate = Color(
				0.45,
				0.45,
				0.45
			)
		
		"exclusive":
			$UpgradeButton.disabled = true
			$UpgradeButton.modulate = Color(
				0.35,
				0.35,
				0.35
			)
		
		"purchased":
			$UpgradeButton.disabled = true
			$UpgradeButton.modulate = Color(
				0.6,
				1.0,
				0.6
			)


func _setup_button_style() -> void:
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(
		0.30,
		0.30,
		0.34
	)
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(
		0.10,
		0.10,
		0.12
	)
	normal_style.corner_radius_top_left = 5
	normal_style.corner_radius_top_right = 5
	normal_style.corner_radius_bottom_left = 5
	normal_style.corner_radius_bottom_right = 5
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(
		0.38,
		0.38,
		0.43
	)
	hover_style.border_width_left = 2
	hover_style.border_width_top = 2
	hover_style.border_width_right = 2
	hover_style.border_width_bottom = 2
	hover_style.border_color = Color(
		0.10,
		0.10,
		0.12
	)
	hover_style.corner_radius_top_left = 5
	hover_style.corner_radius_top_right = 5
	hover_style.corner_radius_bottom_left = 5
	hover_style.corner_radius_bottom_right = 5
	
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(
		0.25,
		0.25,
		0.28
	)
	pressed_style.border_width_left = 2
	pressed_style.border_width_top = 2
	pressed_style.border_width_right = 2
	pressed_style.border_width_bottom = 2
	pressed_style.border_color = Color(
		0.10,
		0.10,
		0.12
	)
	pressed_style.corner_radius_top_left = 5
	pressed_style.corner_radius_top_right = 5
	pressed_style.corner_radius_bottom_left = 5
	pressed_style.corner_radius_bottom_right = 5
	
	var disabled_style = StyleBoxFlat.new()
	disabled_style.bg_color = Color(
		0.27,
		0.27,
		0.30
	)
	disabled_style.border_width_left = 2
	disabled_style.border_width_top = 2
	disabled_style.border_width_right = 2
	disabled_style.border_width_bottom = 2
	disabled_style.border_color = Color(
		0.10,
		0.10,
		0.12
	)
	disabled_style.corner_radius_top_left = 5
	disabled_style.corner_radius_top_right = 5
	disabled_style.corner_radius_bottom_left = 5
	disabled_style.corner_radius_bottom_right = 5
	
	$UpgradeButton.add_theme_stylebox_override(
		"normal",
		normal_style
	)
	
	$UpgradeButton.add_theme_stylebox_override(
		"hover",
		hover_style
	)
	
	$UpgradeButton.add_theme_stylebox_override(
		"pressed",
		pressed_style
	)
	
	$UpgradeButton.add_theme_stylebox_override(
		"disabled",
		disabled_style
	)
