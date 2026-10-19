class_name RealmUpdateController
extends RefCounted


func update(owner: RealmView, delta: float) -> void:
	var visual_parent: Control = owner
	var state: GameState = owner.state
	if state == null:
		return

	owner.realm_background_renderer.advance(delta)

	var animation_controller: GeneratorAnimationController = owner.generator_animation_controller
	var generator_layer: Node2D = owner.generator_layer
	var generator_sprites: Dictionary = owner.generator_sprites
	var molecular_agitation_controller: MolecularAgitationParticleController = owner.molecular_agitation_particle_controller
	var crystallized_flame_controller: CrystallizedFlameVisualController = owner.crystallized_flame_visual_controller
	var forge_activity_controller: ForgeActivityVisualController = owner.forge_activity_visual_controller
	var island_rect: Rect2 = owner._get_island_rect()
	owner.smoke_visual_controller.update(owner, island_rect)
	owner.generator_ash_smoke_controller.update(owner, island_rect)
	var thermal_furnace_position: Vector2 = owner._get_generator_position_in_rect(
		"thermal_furnace",
		island_rect
	)
	_update_persistent_visuals(
		visual_parent,
		state,
		crystallized_flame_controller,
		forge_activity_controller,
		delta
	)

	# Keep static realm visuals current even when animated effects are disabled.
	if not owner.visual_effects_enabled:
		owner.realm_scene_visual_controller.update(owner, island_rect)
		visual_parent.queue_redraw()
		return

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
	owner.realm_scene_visual_controller.update(owner, island_rect)
	_update_middle_animations(
		animation_controller,
		generator_layer,
		state,
		generator_sprites,
		owner.visual_effect_quality
	)
	_update_molecular_agitation(
		molecular_agitation_controller,
		state,
		thermal_furnace_position,
		owner.visual_effect_quality
	)
	_update_late_animations(
		animation_controller,
		state,
		generator_sprites,
		delta
	)

	visual_parent.queue_redraw()


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
	generator_sprites: Dictionary,
	effect_quality: int
) -> void:
	animation_controller.update_middle(
		generator_layer,
		state,
		generator_sprites,
		effect_quality
	)


func _update_molecular_agitation(
	particle_controller: MolecularAgitationParticleController,
	state: GameState,
	generator_position: Vector2,
	effect_quality: int
) -> void:
	particle_controller.update(
		state.generators.get("thermal_furnace"),
		generator_position,
		effect_quality
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
