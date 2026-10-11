class_name GeneratorVisualResetController
extends RefCounted


func reset(owner: RealmView) -> void:
	# Reset shared generator effects and animation state.
	owner.generator_animation_controller.reset()
	owner.forge_activity_visual_controller.reset()
	owner.molecular_agitation_particle_controller.reset()

	# Reset generator-specific animations.
	owner.lava_mite_visual_controller.reset(owner.generator_sprites)
	owner.matter_furnace_visual_controller.reset(owner.generator_sprites)

	# Clear rotation and drawing caches before rebuilding the layout.
	owner.generator_visual_renderer.reset_generator_rotations(
		owner.generator_sprites
	)
	owner.generator_visual_renderer.clear_cache()
	owner.generator_hitboxes.clear()
