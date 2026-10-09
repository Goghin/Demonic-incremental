
class_name UpgradePanel
extends Control


var state: GameState
var input_handler: InputHandler
var upgrade_id: String
var info_popup: UpgradeInfoPopup
var simulation: Simulation
var exclusive_preference_checkbox: CheckBox

signal exclusive_preference_changed

func _ready() -> void:
	_setup_button_style()
	mouse_entered.connect(_on_panel_mouse_entered)

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
	_update_exclusive_preference_checkbox(upgrade)
	
	if info_popup != null and info_popup.visible:
		info_popup.update_info()




func _update_exclusive_preference_checkbox(upgrade: Upgrade) -> void:
	var is_generator_upgrade: bool = upgrade.definition.generator_id != ""
	var is_exclusive: bool = upgrade.definition.exclusivity_group != ""
	var manager: UpgradeAutomationManager = state.upgrade_automation_manager
	var should_show: bool = (
		is_generator_upgrade
		and is_exclusive
		and manager.is_automation_unlocked(upgrade.definition.generator_id)
	)

	if not should_show:
		if exclusive_preference_checkbox != null:
			exclusive_preference_checkbox.visible = false
		return

	if exclusive_preference_checkbox == null:
		exclusive_preference_checkbox = CheckBox.new()
		exclusive_preference_checkbox.name = "ExclusivePreferenceCheckbox"
		exclusive_preference_checkbox.text = ""
		exclusive_preference_checkbox.tooltip_text = "Allow the upgrade autobuyer to buy this option. Only one option per exclusive group can be selected."
		exclusive_preference_checkbox.custom_minimum_size = Vector2(28, 28)
		exclusive_preference_checkbox.size = Vector2(28, 28)
		exclusive_preference_checkbox.position = Vector2(50, -8)
		exclusive_preference_checkbox.z_index = 5
		exclusive_preference_checkbox.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(exclusive_preference_checkbox)
		exclusive_preference_checkbox.toggled.connect(
			_on_exclusive_preference_checkbox_toggled
		)

	exclusive_preference_checkbox.visible = true

	var purchased_choice: Upgrade = _get_purchased_exclusive_choice(upgrade)
	if purchased_choice != null:
		# A manually purchased option becomes the permanent choice for this run.
		# Synchronize the autobuyer preference so it agrees with the actual purchase.
		if not manager.is_exclusive_preference_selected(purchased_choice.definition.id):
			manager.set_exclusive_preference(
				purchased_choice.definition.id,
				true
			)
			exclusive_preference_changed.emit()

		exclusive_preference_checkbox.set_pressed_no_signal(
			upgrade.definition.id == purchased_choice.definition.id
		)
		exclusive_preference_checkbox.disabled = (
			upgrade.definition.id != purchased_choice.definition.id
		)
	else:
		exclusive_preference_checkbox.disabled = false
		exclusive_preference_checkbox.set_pressed_no_signal(
			manager.is_exclusive_preference_selected(upgrade.definition.id)
		)

	# Make the unchecked indicator easier to see against the dark upgrade panel.
	exclusive_preference_checkbox.modulate = (
		Color(1.30, 1.30, 1.30, 1.0)
		if not exclusive_preference_checkbox.button_pressed
		else Color.WHITE
	)


func _get_purchased_exclusive_choice(upgrade: Upgrade) -> Upgrade:
	var group_id: String = upgrade.definition.exclusivity_group
	var generator_id: String = upgrade.definition.generator_id

	for other_value in state.upgrades.values():
		var other_upgrade: Upgrade = other_value
		if other_upgrade.definition.generator_id != generator_id:
			continue
		if other_upgrade.definition.exclusivity_group != group_id:
			continue
		if other_upgrade.is_purchased():
			return other_upgrade

	return null


func _on_exclusive_preference_checkbox_toggled(selected: bool) -> void:
	if state == null:
		return

	var upgrade: Upgrade = state.get_upgrade(upgrade_id)
	if upgrade == null:
		return

	# Ignore attempts to change the selection after any option in this group
	# has been purchased, including clicks dispatched before the UI refreshes.
	if _get_purchased_exclusive_choice(upgrade) != null:
		return

	state.upgrade_automation_manager.set_exclusive_preference(
		upgrade_id,
		selected
	)
	exclusive_preference_changed.emit()



func _update_button(upgrade: Upgrade) -> void:

	

	$UpgradeButton.text = ""

	$UpgradeButton/Icon.texture = null

	if not upgrade.definition.icon_path.is_empty():
		var icon := load(
			upgrade.definition.icon_path
		) as Texture2D

		if icon != null:
			$UpgradeButton/Icon.texture = icon

	if upgrade.definition.max_level > 1:
		$UpgradeButton/LevelLabel.text = "%d/%d" % [
			upgrade.level,
			upgrade.definition.max_level
		]
	else:
		$UpgradeButton/LevelLabel.text = ""

	if upgrade.is_maxed():
		if upgrade.definition.automatic:
			_set_button_state("active")
		else:
			_set_button_state("purchased")
		return

	var exclusive_upgrade = state.upgrade_system.get_exclusive_upgrade(
		upgrade
	)

	if exclusive_upgrade != null:
		_set_button_state("exclusive")
		return

	var next_cost = simulation.get_upgrade_cost(
		upgrade
	)

	var can_afford = (
		state.get_resource_amount(
			upgrade.definition.cost_resource_id
		) >= next_cost
	)

	var requirements_met = state.upgrade_system.requirements_met(
		upgrade.definition.requirements
	)

	if not requirements_met:
		_set_button_state("requirements")
		return

	if not can_afford:
		_set_button_state("cannot_afford")
		return

	_set_button_state("available")



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
	print(
	"BUTTON HOVER: ",
	upgrade_id,
	" | button_global=",
	$UpgradeButton.global_position,
	" | button_size=",
	$UpgradeButton.size
	)
	if info_popup == null:
		return

	info_popup.setup(
		state,
		simulation,
		upgrade_id
	)

	info_popup.visible = true

	# Wait for the popup containers and labels to
	# calculate their final size before positioning it.
	await get_tree().process_frame

	if not is_instance_valid(info_popup):
		return

	if not info_popup.visible:
		return

	_position_info_popup()


func _position_info_popup() -> void:

	var viewport_size := get_viewport_rect().size

	var popup_size := info_popup.size

	var node_rect := Rect2(
		global_position,
		size
	)

	const GAP := 10.0
	const EDGE_MARGIN := 10.0

	# Vertically center the popup against the upgrade.
	var centered_y := (
		node_rect.position.y
		+ (node_rect.size.y - popup_size.y) / 2.0
	)

	# Preferred position: right side.
	var right_position := Vector2(
		node_rect.end.x + GAP,
		centered_y
	)

	# Alternative: left side.
	var left_position := Vector2(
		node_rect.position.x
			- popup_size.x
			- GAP,
		centered_y
	)

	var right_space := (
		viewport_size.x
		- node_rect.end.x
		- EDGE_MARGIN
	)

	var left_space := (
		node_rect.position.x
		- EDGE_MARGIN
	)

	var popup_position: Vector2

	# Prefer the right side when it fits.
	if right_space >= popup_size.x:

		popup_position = right_position

	# Otherwise use the left side if it fits.
	elif left_space >= popup_size.x:

		popup_position = left_position

	# If neither side has enough room, use whichever
	# side has more available space.
	elif right_space >= left_space:

		popup_position = right_position

	else:

		popup_position = left_position

	# Keep the popup vertically inside the viewport.
	popup_position.y = clamp(
		popup_position.y,
		EDGE_MARGIN,
		max(
			EDGE_MARGIN,
			viewport_size.y
			- popup_size.y
			- EDGE_MARGIN
		)
	)

	# Also prevent it from going off-screen horizontally.
	popup_position.x = clamp(
		popup_position.x,
		EDGE_MARGIN,
		max(
			EDGE_MARGIN,
			viewport_size.x
			- popup_size.x
			- EDGE_MARGIN
		)
	)

	info_popup.position = popup_position


func _on_upgrade_button_mouse_exited() -> void:

	if info_popup == null:
		return

	info_popup.visible = false



func _set_button_state(
	state_name: String
	) -> void:
	
	var button := $UpgradeButton

	match state_name:

		"active":
			button.disabled = true
			button.modulate = Color(
				1.0,
				1.0,
				1.0
			)

			var active_style := _create_state_style(
				Color(
					0.32,
					0.32,
					0.36,
					1.0
				),
				Color(
					0.65,
					0.65,
					0.70,
					1.0
				)
			)

			button.add_theme_stylebox_override(
				"normal",
				active_style
			)

			button.add_theme_stylebox_override(
				"disabled",
				active_style
			)

		"available":
			button.disabled = false
			button.modulate = Color(
				1.0,
				1.0,
				1.0
			)
			button.add_theme_stylebox_override(
				"normal",
				_create_state_style(
					Color(0.34, 0.34, 0.40),
					Color(0.75, 0.75, 0.85)
				)
			)
			button.add_theme_stylebox_override(
				"hover",
				_create_state_style(
					Color(0.45, 0.45, 0.52),
					Color(0.95, 0.95, 1.0)
				)
			)

		"cannot_afford":
			button.disabled = true
			button.modulate = Color(
				0.65,
				0.65,
				0.65
			)
			button.add_theme_stylebox_override(
				"disabled",
				_create_state_style(
					Color(0.27, 0.27, 0.30),
					Color(0.18, 0.18, 0.21)
				)
			)

		"requirements":
			button.disabled = true
			button.modulate = Color(
				0.50,
				0.50,
				0.50
			)
			button.add_theme_stylebox_override(
				"disabled",
				_create_state_style(
					Color(0.22, 0.22, 0.25),
					Color(0.14, 0.14, 0.17)
				)
			)

		"exclusive":
			button.disabled = true
			button.modulate = Color(
				0.35,
				0.35,
				0.35
			)
			button.add_theme_stylebox_override(
				"disabled",
				_create_state_style(
					Color(0.17, 0.17, 0.19),
					Color(0.10, 0.10, 0.12)
				)
			)

		"purchased":
			button.disabled = true
			button.modulate = Color(
				1.0,
				1.0,
				1.0
			)

			var purchased_style := _create_state_style(
				Color(
					0.381,
					0.62,
					0.24,
					1.0
				),
				Color(
					1.0,
					0.82,
					0.20,
					1.0
				)
			)

			button.add_theme_stylebox_override(
				"normal",
				purchased_style
			)

			button.add_theme_stylebox_override(
				"disabled",
				purchased_style
			)
	


func _create_state_style(
	background_color: Color,
	border_color: Color
	) -> StyleBoxFlat:

	var style := StyleBoxFlat.new()

	style.bg_color = background_color

	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2

	style.border_color = border_color

	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5

	return style



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

func _on_panel_mouse_entered() -> void:
	print(
		"PANEL HOVER: ",
		upgrade_id,
		" | global_position=",
		global_position,
		" | size=",
		size
	)
