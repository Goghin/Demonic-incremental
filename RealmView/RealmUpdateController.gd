class_name RealmUpdateController
extends RefCounted


func update(owner: Control, delta: float) -> void:
	if owner.state == null:
		return

	owner.crystallized_flame_visual_controller.update_if_needed(
		owner,
		owner.state
	)

	owner.forge_activity_visual_controller.advance(delta)

	owner.generator_animation_controller.update_phase(
		&"early",
		owner,
		owner.state,
		owner.generator_sprites,
		delta
	)

	owner.lava_realm_visual_controller.update_lakes(
		owner.state,
		owner.realm_layout
	)
	owner.lava_realm_visual_controller.update_flow_states(
		owner.state,
		owner.realm_layout
	)

	owner.generator_animation_controller.update_phase(
		&"middle",
		owner,
		owner.state,
		owner.generator_sprites,
		delta
	)

	owner.molecular_agitation_particle_controller.update(
		owner.state.generators.get("thermal_furnace"),
		owner._get_generator_position("thermal_furnace")
	)

	owner.generator_animation_controller.update_phase(
		&"late",
		owner,
		owner.state,
		owner.generator_sprites,
		delta
	)

	owner.queue_redraw()
