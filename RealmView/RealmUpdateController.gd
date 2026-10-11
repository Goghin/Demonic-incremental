class_name RealmUpdateController
extends RefCounted


func update(
	visual_parent: Control,
	state: GameState,
	animation_controller: GeneratorAnimationController,
	generator_layer: Node2D,
	generator_sprites: Dictionary,
	scene_visual_controller: RealmSceneVisualController,
	molecular_agitation_controller: MolecularAgitationParticleController,
	crystallized_flame_controller: CrystallizedFlameVisualController,
	forge_activity_controller: ForgeActivityVisualController,
	get_generator_position: Callable,
	queue_redraw: Callable,
	delta: float
) -> void:
	if state == null:
		return

	_update_persistent_visuals(
		visual_parent,
		state,
		crystallized_flame_controller,
		forge_activity_controller,
		delta
	)

	# Keep generator animation phases interleaved with realm updates.
	# Their order is intentional: early machine motion, realm visuals,
	# middle overlays, the independent agitation particles, then late motion.
	_update_early_animations(
		animation_controller,
		generator_layer,
		state,
		generator_sprites,
		delta
	)
	scene_visual_controller.update_from_view(visual_parent)
	_update_middle_animations(
		animation_controller,
		generator_layer,
		state,
		generator_sprites
	)
	_update_molecular_agitation(
		molecular_agitation_controller,
		state,
		get_generator_position.call("thermal_furnace")
	)
	_update_late_animations(
		animation_controller,
		state,
		generator_sprites,
		delta
	)

	queue_redraw.call()


func _update_persistent_visuals(
	visual_parent: Control,
	state: GameState,
	crystallized_flame_controller: CrystallizedFlameVisualController,
	forge_activity_controller: ForgeActivityVisualController,
	delta: float
) -> void:
	crystallized_flame_controller.update_if_needed(
		visual_parent,
		state
	)
	forge_activity_controller.advance(delta)


func _update_early_animations(
	animation_controller: GeneratorAnimationController,
	generator_layer: Node2D,
	state: GameState,
	generator_sprites: Dictionary,
	delta: float
) -> void:
	animation_controller.update_early(
		generator_layer,
		state,
		generator_sprites,
		delta
	)


func _update_middle_animations(
	animation_controller: GeneratorAnimationController,
	generator_layer: Node2D,
	state: GameState,
	generator_sprites: Dictionary
) -> void:
	animation_controller.update_middle(
		generator_layer,
		state,
		generator_sprites
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


func _update_late_animations(
	animation_controller: GeneratorAnimationController,
	state: GameState,
	generator_sprites: Dictionary,
	delta: float
) -> void:
	animation_controller.update_late(
		state,
		generator_sprites,
		delta
)
