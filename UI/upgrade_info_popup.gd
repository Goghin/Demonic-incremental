
class_name UpgradeInfoPopup
extends PanelContainer


var state: GameState
var simulation: Simulation
var upgrade_id: String


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	for child in $MarginContainer.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE


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
	
	$MarginContainer/NameLabel.text = (
		upgrade.definition.display_name
	)
	
	$MarginContainer/DescriptionLabel.text = (
		upgrade.definition.description
	)
	
	if upgrade.definition.max_level > 1:
		if upgrade.is_maxed():
			$MarginContainer/CostLabel.text = (
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
			
			$MarginContainer/CostLabel.text = (
				"Level: %d / %d\nNext level: %d\nCost: %.2f %s"
				% [
					upgrade.level,
					upgrade.definition.max_level,
					upgrade.level + 1,
					next_cost,
					cost_name
				]
			)
	else:
		var cost_name = (
			state.get_resource_display_name(
				upgrade.definition.cost_resource_id
			)
		)
		
		$MarginContainer/CostLabel.text = (
			"Cost: %.2f %s"
			% [
				upgrade.definition.cost,
				cost_name
			]
		)
	
	var requirement_text = ""
	
	for requirement in upgrade.definition.requirements:
		if state.requirement_met(
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
		$MarginContainer/RequirementLabel.text = ""
	else:
		$MarginContainer/RequirementLabel.text = (
			"Requirements:\n%s"
			% requirement_text
		)
	
	var status_text = ""
	
	if upgrade.is_maxed():
		if upgrade.definition.automatic:
			status_text = "ACTIVE"
		else:
			status_text = "MAX LEVEL"
	else:
		var exclusive_upgrade = (
			state.get_exclusive_upgrade(
				upgrade
			)
		)
		
		if exclusive_upgrade != null:
			status_text = (
				"LOCKED\nConflicts with: %s"
				% exclusive_upgrade.definition.display_name
			)
		elif not state.requirements_met(
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
	
	$MarginContainer/StatusLabel.text = status_text


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
