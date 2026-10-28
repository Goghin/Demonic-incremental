extends RefCounted

const GeneratorProbe = preload("res://tests/experimental/automation_generator_probe.gd")
const UpgradeProbe = preload("res://tests/experimental/automation_upgrade_probe.gd")


static func install(state: GameState) -> void:
	var generator: GeneratorAutomationManager = state.generator_automation_manager
	var upgrade: UpgradeAutomationManager = state.upgrade_automation_manager
	var measured_generator := GeneratorProbe.new(state)
	var measured_upgrade := UpgradeProbe.new(state)
	measured_generator._state_ref = generator._state_ref
	measured_generator.automation_states = generator.automation_states
	measured_generator._offline_enabled_ids = generator._offline_enabled_ids
	measured_generator._offline_index_dirty = generator._offline_index_dirty
	measured_upgrade._state_ref = upgrade._state_ref
	measured_upgrade.automation_states = upgrade.automation_states
	measured_upgrade._offline_enabled_ids = upgrade._offline_enabled_ids
	measured_upgrade._offline_index_dirty = upgrade._offline_index_dirty
	measured_upgrade.exclusive_preferences = upgrade.exclusive_preferences
	state.generator_automation_manager = measured_generator
	state.upgrade_automation_manager = measured_upgrade
