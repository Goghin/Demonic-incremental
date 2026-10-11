class_name RealmUpdateController
extends RefCounted


func update(owner: Control, delta: float) -> void:
	if owner.state == null:
		return

	_update_persistent_visuals(owner, delta)
	_update_early_animations(owner, delta)
	_update_realm_environment(owner)
	_update_middle_animations(owner, delta)
	_update_molecular_agitation(owner)
	_update_late_animations(owner, delta)

	owner.queue_redraw()


func _update_persistent_visuals(owner: Control, delta: float) -> void:
	owner.crystallized_flame_visual_controller.update_if_needed(
		owner,
		owner.state
	)
	owner.forge_activity_visual_controller.advance(delta)


func _update_early_animations(owner: Control, delta: float) -> void:
	_update_generator_animation_phase(owner, &"early", delta)


func _update_realm_environment(owner: Control) -> void:
	owner.lava_realm_visual_controller.update_lakes(
		owner.state,
		owner.realm_layout
	)
	owner.lava_realm_visual_controller.update_flow_states(
		owner.state,
		owner.realm_layout
	)


func _update_middle_animations(owner: Control, delta: float) -> void:
	_update_generator_animation_phase(owner, &"middle", delta)


func _update_molecular_agitation(owner: Control) -> void:
	owner.molecular_agitation_particle_controller.update(
		owner.state.generators.get("thermal_furnace"),
		owner._get_generator_position("thermal_furnace")
	)


func _update_late_animations(owner: Control, delta: float) -> void:
	_update_generator_animation_phase(owner, &"late", delta)


func _update_generator_animation_phase(
	owner: Control,
	phase: StringName,
	delta: float
) -> void:
	owner.generator_animation_controller.update_phase(
		phase,
		owner,
		owner.state,
		owner.generator_sprites,
		delta
	)
