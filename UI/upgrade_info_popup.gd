
class_name UpgradeInfoPopup
extends PanelContainer


const MIN_WIDTH := 180.0
const MAX_WIDTH := 280.0


var state: GameState
var simulation: Simulation
var upgrade_id: String
var _last_maxed_upgrade_id: String = ""


func _ready() -> void:

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_setup_popup_style()

	for child in $MarginContainer.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE

	$MarginContainer/VBoxContainer.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	_replace_display_label_with_container("CostLabel")
	_replace_display_label_with_container("RequirementLabel")
	_setup_font_size()

func _setup_popup_style() -> void:

	var style := StyleBoxFlat.new()

	style.bg_color = Color(
		0.08,
		0.08,
		0.10,
		0.96
	)

	style.border_color = Color(
		0.35,
		0.35,
		0.40,
		1.0
	)

	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1

	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4

	add_theme_stylebox_override(
		"panel",
		style
	)


func setup(
	game_state: GameState,
	game_simulation: Simulation,
	game_upgrade_id: String
	) -> void:

	state = game_state
	simulation = game_simulation
	upgrade_id = game_upgrade_id

	update_info()



func update_info() -> void:

	if state == null:
		return

	if simulation == null:
		return

	var upgrade = state.get_upgrade(
		upgrade_id
	)

	if upgrade == null:
		return

	# Maxed upgrades have no changing costs or requirements. Avoid rebuilding
	# their labels every frame while the popup is visible; queue_free() is
	# deferred, so repeated rebuilding can temporarily inflate container size.
	if upgrade.is_maxed() and _last_maxed_upgrade_id == upgrade_id:
		return

	if upgrade.is_maxed():
		_last_maxed_upgrade_id = upgrade_id
	else:
		_last_maxed_upgrade_id = ""

	$MarginContainer/VBoxContainer/NameLabel.text = (
		upgrade.definition.display_name
	)

	$MarginContainer/VBoxContainer/DescriptionLabel.text = (
		upgrade.definition.description
	)

	if upgrade.definition.max_level > 1:
		if upgrade.is_maxed():
			_set_cost_display([
				"Level: %d / %d" % [upgrade.level, upgrade.definition.max_level],
			], "", "")
		else:
			var next_cost := simulation.get_upgrade_cost(upgrade)
			if next_cost <= 0.0:
				_set_cost_display([], "", "")
			else:
				_set_cost_display([
					"Level: %d / %d" % [upgrade.level, upgrade.definition.max_level],
					"Next level: %d" % (upgrade.level + 1),
				], upgrade.definition.cost_resource_id, NumberFormatter.format(next_cost))
	else:
		if upgrade.definition.cost <= 0.0:
			_set_cost_display([], "", "")
		else:
			_set_cost_display([], upgrade.definition.cost_resource_id, NumberFormatter.format(upgrade.definition.cost))

	var unmet_requirements: Array[Requirement] = []
	if upgrade.level == 0:
		for requirement in upgrade.definition.requirements:
			if not state.upgrade_system.requirement_met(requirement):
				unmet_requirements.append(requirement)
	_set_requirement_display(unmet_requirements)

	var status_text := ""

	if upgrade.is_maxed():

		if upgrade.definition.automatic:
			status_text = "ACTIVE"
		else:
			status_text = "MAX LEVEL"

	else:

		var exclusive_upgrade = (
			state.upgrade_system.get_exclusive_upgrade(
				upgrade
			)
		)

		if exclusive_upgrade != null:

			status_text = (
				"LOCKED\nConflicts with: %s"
				% exclusive_upgrade.definition.display_name
			)

		elif not state.upgrade_system.requirements_met(
			upgrade.definition.requirements
		):

			status_text = "Requirements not met"

		else:

			var next_cost = simulation.get_upgrade_cost(
				upgrade
			)

			var can_afford = (
				state.get_resource_amount(
					upgrade.definition.cost_resource_id
				) >= next_cost
			)

			if can_afford:
				status_text = "Available"
			else:
				status_text = "Cannot afford"

	$MarginContainer/VBoxContainer/StatusLabel.text = status_text

	_update_popup_width()



func _update_popup_width() -> void:

	custom_minimum_size.x = MIN_WIDTH

	size.x = MAX_WIDTH

	reset_size()

	size.x = clamp(
		size.x,
		MIN_WIDTH,
		MAX_WIDTH
	)


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


		return "Requires %s %s (%s / %s)" % [
			NumberFormatter.format(
				requirement.value
			),
			resource_name,
			_format_requirement_amount(
				current_amount
			),
			NumberFormatter.format(
				requirement.value
			)
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

func _format_requirement_amount(
	value: float
	) -> String:

	if value < 10.0:
		return "%.2f" % value

	if value < 100.0:
		return "%.1f" % value

	return "%.0f" % value


func _setup_font_size() -> void:

	var font_size := 11

	$MarginContainer/VBoxContainer/NameLabel.add_theme_font_size_override(
		"font_size",
		14
	)

	$MarginContainer/VBoxContainer/DescriptionLabel.add_theme_font_size_override(
		"font_size",
		font_size
	)



	$MarginContainer/VBoxContainer/StatusLabel.add_theme_font_size_override(
		"font_size",
		font_size
	)



func _replace_display_label_with_container(node_name: String) -> void:
	var parent := $MarginContainer/VBoxContainer
	var old_label := parent.get_node(node_name) as Label
	if old_label == null:
		return

	var index := old_label.get_index()
	var replacement := VBoxContainer.new()
	replacement.name = node_name
	replacement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.remove_child(old_label)
	parent.add_child(replacement)
	parent.move_child(replacement, index)
	old_label.queue_free()


func _clear_display_container(container: Node) -> void:
	container.visible = false
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _add_display_label(container: Node, text_value: String) -> void:
	if text_value.is_empty():
		return
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 11)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(label)
	container.visible = true


func _set_cost_display(info_lines: Array, resource_id: String, amount_text: String) -> void:
	var container := $MarginContainer/VBoxContainer/CostLabel as VBoxContainer
	_clear_display_container(container)

	for line in info_lines:
		_add_display_label(container, line)

	if resource_id.is_empty() or amount_text.is_empty():
		return

	container.visible = true
	var cost_row := HBoxContainer.new()
	cost_row.add_theme_constant_override("separation", 4)
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(cost_row)

	var cost_prefix := Label.new()
	cost_prefix.text = "Cost:"
	cost_prefix.add_theme_font_size_override("font_size", 11)
	cost_row.add_child(cost_prefix)

	var icon := ResourceIcon.new()
	icon.setup(resource_id, Vector2(15.0, 15.0))
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cost_row.add_child(icon)

	var cost_value := Label.new()
	cost_value.text = "%s %s" % [
		amount_text,
		state.get_resource_display_name(resource_id),
	]
	cost_value.add_theme_font_size_override("font_size", 11)
	cost_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_row.add_child(cost_value)


func _set_requirement_display(requirements: Array[Requirement]) -> void:
	var container := $MarginContainer/VBoxContainer/RequirementLabel as VBoxContainer
	_clear_display_container(container)
	if requirements.is_empty():
		return

	_add_display_label(container, "Requirements:")
	for requirement in requirements:
		if requirement.type == RequirementTypes.RESOURCE:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 4)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(row)

			var icon := ResourceIcon.new()
			icon.setup(requirement.target_id, Vector2(15.0, 15.0))
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(icon)

			var label := Label.new()
			label.text = get_requirement_text(requirement)
			label.add_theme_font_size_override("font_size", 11)
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)
		else:
			_add_display_label(container, get_requirement_text(requirement))
