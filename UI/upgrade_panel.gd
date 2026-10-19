class_name UpgradePanel
extends Control


signal exclusive_preference_changed
signal purchase_succeeded


const EXCLUSIVE_CHECKBOX_SIZE := Vector2(13, 13)
const EXCLUSIVE_CHECKBOX_POSITION := Vector2(32, -6)
const EXCLUSIVE_CHECKBOX_TOOLTIP := "Allow the upgrade autobuyer to buy this option. Only one option per exclusive group can be selected."


var state: GameState
var input_handler: InputHandler
var upgrade_id: String
var info_popup: UpgradeInfoPopup
var simulation: Simulation

var exclusive_preference_checkbox: Button
var _exclusive_checkbox_style_state: String = ""


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
	if not purchase_succeeded.is_connected(_on_purchase_succeeded):
		purchase_succeeded.connect(_on_purchase_succeeded)


func _process(_delta: float) -> void:
	if state == null:
		return

	var upgrade: Upgrade = state.get_upgrade(upgrade_id)
	if upgrade == null:
		return

	_update_button(upgrade)
	_update_exclusive_preference_checkbox(upgrade)



# -------------------------------------------------------------------
# Exclusive upgrade preference checkbox
# -------------------------------------------------------------------

func _update_exclusive_preference_checkbox(upgrade: Upgrade) -> void:
	var generator_id: String = upgrade.definition.generator_id
	var is_generator_upgrade: bool = generator_id != ""
	var is_exclusive: bool = upgrade.definition.exclusivity_group != ""
	var manager: UpgradeAutomationManager = state.upgrade_automation_manager

	var should_show: bool = (
		is_generator_upgrade
		and is_exclusive
		and manager.is_automation_unlocked(generator_id)
	)

	if not should_show:
		if exclusive_preference_checkbox != null:
			exclusive_preference_checkbox.visible = false
		return

	if exclusive_preference_checkbox == null:
		_create_exclusive_preference_checkbox()

	exclusive_preference_checkbox.visible = true

	var purchased_choice: Upgrade = _get_purchased_exclusive_choice(upgrade)

	if purchased_choice != null:
		# Keep the preference synchronized with the purchased choice.
		if not manager.is_exclusive_preference_selected(
			purchased_choice.definition.id
		):
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
			manager.is_exclusive_preference_selected(
				upgrade.definition.id
			)
		)

	_update_exclusive_preference_button_appearance()


func _create_exclusive_preference_checkbox() -> void:
	exclusive_preference_checkbox = Button.new()
	exclusive_preference_checkbox.name = "ExclusivePreferenceCheckbox"
	exclusive_preference_checkbox.toggle_mode = true
	exclusive_preference_checkbox.text = ""
	exclusive_preference_checkbox.tooltip_text = EXCLUSIVE_CHECKBOX_TOOLTIP
	exclusive_preference_checkbox.position = EXCLUSIVE_CHECKBOX_POSITION
	exclusive_preference_checkbox.z_index = 5
	exclusive_preference_checkbox.mouse_filter = Control.MOUSE_FILTER_STOP
	exclusive_preference_checkbox.focus_mode = Control.FOCUS_NONE

	exclusive_preference_checkbox.add_theme_constant_override(
		"h_separation",
		0
	)
	exclusive_preference_checkbox.add_theme_font_size_override(
		"font_size",
		10
	)

	add_child(exclusive_preference_checkbox)

	# Apply the size after adding the button to its parent.
	exclusive_preference_checkbox.custom_minimum_size = EXCLUSIVE_CHECKBOX_SIZE
	exclusive_preference_checkbox.reset_size()
	exclusive_preference_checkbox.size = EXCLUSIVE_CHECKBOX_SIZE

	exclusive_preference_checkbox.toggled.connect(
		_on_exclusive_preference_checkbox_toggled
	)


func _update_exclusive_preference_button_appearance() -> void:
	if exclusive_preference_checkbox == null:
		return

	var selected: bool = exclusive_preference_checkbox.button_pressed
	exclusive_preference_checkbox.text = "✓" if selected else ""

	var style_state: String = "selected" if selected else "unselected"
	if exclusive_preference_checkbox.disabled:
		style_state += "_disabled"

	if _exclusive_checkbox_style_state == style_state:
		return

	_exclusive_checkbox_style_state = style_state

	var background: Color = (
		Color(0.34, 0.22, 0.10, 1.0)
		if selected
		else Color(0.10, 0.10, 0.12, 1.0)
	)
	var border: Color = (
		Color(1.0, 0.72, 0.28, 1.0)
		if selected
		else Color(0.95, 0.78, 0.48, 1.0)
	)
	var font_color: Color = (
		Color(1.0, 0.90, 0.62, 1.0)
		if selected
		else Color(1.0, 0.90, 0.70, 1.0)
	)

	exclusive_preference_checkbox.add_theme_stylebox_override(
		"normal",
		_create_exclusive_preference_style(background, border)
	)
	exclusive_preference_checkbox.add_theme_stylebox_override(
		"hover",
		_create_exclusive_preference_style(
			background.lightened(0.18),
			border.lightened(0.10)
		)
	)
	exclusive_preference_checkbox.add_theme_stylebox_override(
		"pressed",
		_create_exclusive_preference_style(
			background.darkened(0.10),
			border
		)
	)
	exclusive_preference_checkbox.add_theme_stylebox_override(
		"disabled",
		_create_exclusive_preference_style(
			background.darkened(0.12),
			border.darkened(0.15)
		)
	)

	exclusive_preference_checkbox.add_theme_color_override(
		"font_color",
		font_color
	)
	exclusive_preference_checkbox.add_theme_color_override(
		"font_hover_color",
		Color.WHITE
	)
	exclusive_preference_checkbox.add_theme_color_override(
		"font_pressed_color",
		font_color
	)
	exclusive_preference_checkbox.add_theme_color_override(
		"font_disabled_color",
		font_color
	)


func _create_exclusive_preference_style(
	background_color: Color,
	border_color: Color
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style


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

	# A purchased choice cannot be changed during the current run.
	if _get_purchased_exclusive_choice(upgrade) != null:
		return

	state.upgrade_automation_manager.set_exclusive_preference(
		upgrade_id,
		selected
	)
	exclusive_preference_changed.emit()


# -------------------------------------------------------------------
# Upgrade button state and display
# -------------------------------------------------------------------

func _update_button(upgrade: Upgrade) -> void:
	$UpgradeButton.text = ""
	$UpgradeButton/Icon.texture = null

	var generator_unlock_texture := _get_generator_unlock_texture(upgrade)
	if generator_unlock_texture != null:
		$UpgradeButton/Icon.texture = generator_unlock_texture
	elif not upgrade.definition.icon_path.is_empty():
		var icon := load(upgrade.definition.icon_path) as Texture2D
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

	var next_cost = simulation.get_upgrade_cost(upgrade)
	var can_afford: bool = (
		state.get_resource_amount(
			upgrade.definition.cost_resource_id
		) >= next_cost
	)
	var requirements_met: bool = state.upgrade_system.requirements_met(
		upgrade.definition.requirements
	)

	if not requirements_met:
		_set_button_state("requirements")
		return

	if not can_afford:
		_set_button_state("cannot_afford")
		return

	_set_button_state("available")


func _get_generator_unlock_texture(upgrade: Upgrade) -> Texture2D:
	# Generator unlock buttons use the same illustration as the RealmView
	# machine, making the newly unlocked generator immediately recognizable.
	var generator_id := ""
	match upgrade.definition.id:
		"molecular_agitation":
			generator_id = "molecular_agitation"
		"matter_furnace_unlock":
			generator_id = "matter_furnace"
		"lava_mite_colony_unlock":
			generator_id = "lava_mite_colony"
		"unlock_infernal_condensation":
			generator_id = "thermal_furnace"
		"thermal_compressor_unlock":
			generator_id = "thermal_compressor"
		"infernal_forge_unlock":
			generator_id = "infernal_forge"
		_:
			return null

	var generator: Generator = state.get_generator(generator_id)
	if generator == null or generator.definition.illustration_path.is_empty():
		return null

	return load(generator.definition.illustration_path) as Texture2D


func get_requirement_text(requirement: Requirement) -> String:
	if requirement.type == RequirementTypes.RESOURCE:
		var resource_name = state.get_resource_display_name(
			requirement.target_id
		)
		var current_amount = state.get_resource_amount(
			requirement.target_id
		)

		return "Requires %.0f %s (%.0f / %.0f)" % [
			requirement.value,
			resource_name,
			current_amount,
			requirement.value
		]

	if requirement.type == RequirementTypes.GENERATOR_LEVEL:
		var generator = state.get_generator(requirement.target_id)
		if generator == null:
			return "Requires unknown generator."

		return "Requires %s level %d (current: %d)" % [
			generator.definition.display_name,
			int(requirement.value),
			generator.level
		]

	if requirement.type == RequirementTypes.UPGRADE_PURCHASED:
		var required_upgrade = state.get_upgrade(requirement.target_id)
		if required_upgrade == null:
			return "Requires unknown upgrade."

		return "Requires: %s" % (
			required_upgrade.definition.display_name
		)

	if requirement.type == RequirementTypes.UPGRADE_LEVEL:
		var required_upgrade = state.get_upgrade(requirement.target_id)
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

	if input_handler.buy_upgrade(upgrade_id):
		purchase_succeeded.emit()


# -------------------------------------------------------------------
# Upgrade information popup
# -------------------------------------------------------------------

func _on_upgrade_button_mouse_entered() -> void:
	if info_popup == null:
		return

	# The popup is shared by general upgrades and generator trees. Reset its
	# layout before measuring so a previous full-height layout cannot persist.
	info_popup.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	info_popup.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	info_popup.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	info_popup.setup(state, simulation, upgrade_id)
	info_popup.visible = true

	# Let the labels and their containers calculate their minimum sizes first.
	await get_tree().process_frame

	if not is_instance_valid(info_popup) or not info_popup.visible:
		return

	info_popup.reset_size()
	info_popup.size.y = info_popup.get_combined_minimum_size().y
	_position_info_popup()


func _position_info_popup() -> void:
	var viewport_size := get_viewport_rect().size
	var popup_size := info_popup.size
	var node_rect := Rect2(global_position, size)

	const GAP := 10.0
	const EDGE_MARGIN := 10.0

	var centered_y: float = (
		node_rect.position.y
		+ (node_rect.size.y - popup_size.y) / 2.0
	)

	var right_position := Vector2(
		node_rect.end.x + GAP,
		centered_y
	)
	var left_position := Vector2(
		node_rect.position.x - popup_size.x - GAP,
		centered_y
	)

	var right_space: float = (
		viewport_size.x - node_rect.end.x - EDGE_MARGIN
	)
	var left_space: float = node_rect.position.x - EDGE_MARGIN

	var popup_position: Vector2

	if right_space >= popup_size.x:
		popup_position = right_position
	elif left_space >= popup_size.x:
		popup_position = left_position
	elif right_space >= left_space:
		popup_position = right_position
	else:
		popup_position = left_position

	popup_position.y = clamp(
		popup_position.y,
		EDGE_MARGIN,
		max(
			EDGE_MARGIN,
			viewport_size.y - popup_size.y - EDGE_MARGIN
		)
	)
	popup_position.x = clamp(
		popup_position.x,
		EDGE_MARGIN,
		max(
			EDGE_MARGIN,
			viewport_size.x - popup_size.x - EDGE_MARGIN
		)
	)

	info_popup.position = popup_position


func _on_upgrade_button_mouse_exited() -> void:
	if info_popup == null:
		return

	info_popup.visible = false


func _on_purchase_succeeded() -> void:
	if info_popup == null or not info_popup.visible:
		return
	if info_popup.upgrade_id != upgrade_id:
		return

	info_popup.update_info()

	# Re-measure after the labels have been rebuilt so level/cost changes do
	# not leave the visible popup with stale dimensions.
	await get_tree().process_frame
	if not is_instance_valid(info_popup) or not info_popup.visible:
		return

	info_popup.reset_size()
	info_popup.size.y = info_popup.get_combined_minimum_size().y
	_position_info_popup()


# -------------------------------------------------------------------
# Upgrade button styling
# -------------------------------------------------------------------

func _set_button_state(state_name: String) -> void:
	var button := $UpgradeButton
	var background := Color(0.095, 0.075, 0.085, 1.0)
	var border := Color(0.30, 0.22, 0.21, 1.0)
	var hover_background := Color(0.16, 0.095, 0.075, 1.0)
	var hover_border := Color(0.70, 0.36, 0.20, 1.0)
	var font_color := Color(0.90, 0.82, 0.76, 1.0)
	var disabled := false
	var icon_tint := Color.WHITE

	match state_name:
		"active":
			disabled = true
			background = Color(0.22, 0.15, 0.12, 1.0)
			border = Color(0.68, 0.43, 0.27, 1.0)
			hover_background = background.lightened(0.08)
			hover_border = border.lightened(0.08)
			font_color = Color(1.0, 0.86, 0.67, 1.0)
		"available":
			background = Color(0.12, 0.085, 0.08, 1.0)
			border = Color(0.54, 0.32, 0.23, 1.0)
			hover_background = Color(0.22, 0.12, 0.08, 1.0)
			hover_border = Color(0.98, 0.53, 0.25, 1.0)
			font_color = Color(1.0, 0.88, 0.74, 1.0)
		"cannot_afford":
			disabled = true
			background = Color(0.10, 0.075, 0.08, 1.0)
			border = Color(0.22, 0.17, 0.18, 1.0)
			font_color = Color(0.48, 0.42, 0.41, 1.0)
			icon_tint = Color(0.62, 0.57, 0.57, 1.0)
		"requirements":
			disabled = true
			background = Color(0.085, 0.065, 0.075, 1.0)
			border = Color(0.18, 0.14, 0.16, 1.0)
			font_color = Color(0.40, 0.36, 0.38, 1.0)
			icon_tint = Color(0.52, 0.48, 0.50, 1.0)
		"exclusive":
			disabled = true
			background = Color(0.12, 0.065, 0.075, 1.0)
			border = Color(0.36, 0.16, 0.18, 1.0)
			font_color = Color(0.58, 0.40, 0.41, 1.0)
			icon_tint = Color(0.65, 0.48, 0.48, 1.0)
		"purchased":
			disabled = true
			background = Color(0.20, 0.19, 0.11, 1.0)
			border = Color(0.91, 0.65, 0.25, 1.0)
			hover_background = background.lightened(0.08)
			hover_border = border.lightened(0.08)
			font_color = Color(1.0, 0.90, 0.60, 1.0)

	button.disabled = disabled
	button.modulate = icon_tint
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_disabled_color", font_color)
	button.add_theme_stylebox_override(
		"normal", _create_state_style(background, border)
	)
	button.add_theme_stylebox_override(
		"hover", _create_state_style(hover_background, hover_border)
	)
	button.add_theme_stylebox_override(
		"pressed", _create_state_style(
			background.darkened(0.12), border.lightened(0.05)
		)
	)
	button.add_theme_stylebox_override(
		"disabled", _create_state_style(background, border)
	)

func _create_state_style(
	background_color: Color,
	border_color: Color
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	return style


func _setup_button_style() -> void:
	var normal_style := _create_state_style(
		Color(0.30, 0.30, 0.34),
		Color(0.10, 0.10, 0.12)
	)
	var hover_style := _create_state_style(
		Color(0.38, 0.38, 0.43),
		Color(0.10, 0.10, 0.12)
	)
	var pressed_style := _create_state_style(
		Color(0.25, 0.25, 0.28),
		Color(0.10, 0.10, 0.12)
	)
	var disabled_style := _create_state_style(
		Color(0.27, 0.27, 0.30),
		Color(0.10, 0.10, 0.12)
	)

	$UpgradeButton.add_theme_stylebox_override("normal", normal_style)
	$UpgradeButton.add_theme_stylebox_override("hover", hover_style)
	$UpgradeButton.add_theme_stylebox_override("pressed", pressed_style)
	$UpgradeButton.add_theme_stylebox_override("disabled", disabled_style)
