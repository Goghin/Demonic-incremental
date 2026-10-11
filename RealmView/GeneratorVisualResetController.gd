class_name GeneratorVisualResetController
extends RefCounted


func reset(
	animation_controller: GeneratorAnimationController,
	forge_controller: ForgeActivityVisualController,
	molecular_particle_controller: MolecularAgitationParticleController,
	lava_mite_controller: LavaMiteVisualController,
	matter_furnace_controller: MatterFurnaceVisualController,
	visual_renderer: GeneratorVisualRenderer,
	generator_sprites: Dictionary,
	generator_hitboxes: Dictionary
) -> void:
	# Reset shared generator effects and animation state.
	animation_controller.reset()
	forge_controller.reset()
	molecular_particle_controller.reset()

	# Reset generator-specific animations.
	lava_mite_controller.reset(generator_sprites)
	matter_furnace_controller.reset(generator_sprites)

	# Clear rotation and drawing caches before rebuilding the layout.
	visual_renderer.reset_generator_rotations(generator_sprites)
	visual_renderer.clear_cache()
	generator_hitboxes.clear()
