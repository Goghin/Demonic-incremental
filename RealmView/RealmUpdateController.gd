class_name RealmUpdateController
extends RefCounted


func update(owner: Control, delta: float) -> void:
	if owner.state == null:
		return

	_update_persistent_visuals(owner, delta)

	# Keep generator animation phases interleaved with realm updates.
	# Their order is intentional: early machine motion, realm visuals,
	# middle overlays, the independent agitation particles, then late motion.
	_update_early_animations(owner, delta)
	owner.realm_scene_visual_controller.update(owner)
	_update_middle_animations(owner)
	_update_molecular_agitation(
		owner.molecular_agitation_particle_controller,
		owner.state,
		owner._get_generator_position("thermal_furnace")
	)
	_update_late_animations(owner, delta)

	owner.queue_redraw()


func _update_persistent_visuals(owner: Control, delta: float) -> void:
	owner.crystallized_flame_visual_controller.update_if_needed(
		owner,
		owner.state
	)
	owner.forge_activity_visual_controller.advance(delta)


func _update_early_animations(owner: Control, delta: float) -> void:
	owner.generator_animation_controller.update_early(
		owner,
		owner.state,
		owner.generator_sprites,
		delta
	)


func _update_middle_animations(owner: Control) -> void:
	owner.generator_animation_controller.update_middle(
		owner,
		owner.state,
		owner.generator_sprites
	)


func _update_molecular_agitation(
	particle_controller: MolecularAgitationParticleController,
	state: GameState,
	generator_position: Vector2
) -> void:
	particle_controller.update(
		state.generators.get("thermal_furnace"),
		generator_position
	)

func _update_late_animations(owner: Control, delta: float) -> void:
	owner.generator_animation_controller.update_late(
		owner.state,
		owner.generator_sprites,
		delta
	)
