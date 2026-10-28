extends RefCounted

# Supported native managers mutate configuration only through the audited
# Simulation purchase APIs. Those APIs append to the exact owned TickLog on
# success, after all effects. Checks, cooldowns and waiting-cache refreshes do
# not append. Automatic upgrades run at the separate pre-tick boundary.
# Arbitrary callbacks, replacement manager/simulation/logger scripts and clocks
# remain refused by Packet.build. This is not a generic external-event journal.


static func enabled(state: GameState) -> bool:
	for manager: Variant in [state.generator_automation_manager, state.upgrade_automation_manager]:
		for automation: Dictionary in manager.automation_states.values():
			if bool(automation["enabled"]):
				return true
	return false


static func mark(state: GameState) -> int:
	return state.gameplay_log.events.size()


static func changed(state: GameState, previous: int) -> bool:
	return state.gameplay_log.events.size() != previous
