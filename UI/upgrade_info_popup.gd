
class_name UpgradeInfoPopup
extends PanelContainer


const MIN_WIDTH := 180.0
const MAX_WIDTH := 280.0


var state: GameState
var simulation: Simulation
var upgrade_id: String


func _ready() -> void:

	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_setup_popup_style()

	for child in $MarginContainer.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE

	$MarginContainer/VBoxContainer.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


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

	$MarginContainer/VBoxContainer/NameLabel.text = (
		upgrade.definition.display_name
	)

	$MarginContainer/VBoxContainer/DescriptionLabel.text = (
		upgrade.definition.description
	)

	if upgrade.definition.max_level > 1:

		if upgrade.is_maxed():

			$MarginContainer/VBoxContainer/CostLabel.text = (
				"Level: %d / %d\nMAX LEVEL"
				% [
					upgrade.level,
					upgrade.definition.max_level
				]
			)

		else:

			var cost_name = (
				state.get_resource_display_name(
					upgrade.definition.cost_resource_id
				)
			)

			var next_cost = simulation.get_upgrade_cost(
				upgrade
			)

			if next_cost <= 0.0:

				$MarginContainer/VBoxContainer/CostLabel.text = ""

			else:

				$MarginContainer/VBoxContainer/CostLabel.text = (
					"Level: %d / %d\nNext level: %d\nCost: %s %s"
					% [
						upgrade.level,
						upgrade.definition.max_level,
						upgrade.level + 1,
						NumberFormatter.format(
							next_cost
						),
						cost_name
					]
				)

	else:

		var cost_name = (
			state.get_resource_display_name(
				upgrade.definition.cost_resource_id
			)
		)

		if upgrade.definition.cost <= 0.0:

			$MarginContainer/VBoxContainer/CostLabel.text = ""

		else:

			$MarginContainer/VBoxContainer/CostLabel.text = (
				"Cost: %s %s"
				% [
					NumberFormatter.format(
						upgrade.definition.cost
					),
					cost_name
				]
			)

	var requirement_text := ""

	for requirement in upgrade.definition.requirements:

		if state.upgrade_system.requirement_met(
			requirement
		):
			continue

		if requirement_text != "":
			requirement_text += "\n"

		requirement_text += (
			get_requirement_text(
				requirement
			)
		)

	if requirement_text == "":

		$MarginContainer/VBoxContainer/RequirementLabel.text = ""

	else:

		$MarginContainer/VBoxContainer/RequirementLabel.text = (
			"Requirements:\n%s"
			% requirement_text
		)

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
			NumberFormatter.format(
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
