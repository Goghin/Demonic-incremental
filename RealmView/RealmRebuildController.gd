class_name RealmRebuildController
extends RefCounted


func rebuild(owner, new_layout: RealmLayout) -> void:
	if owner.state == null:
		return

	if new_layout == null:
		push_warning(
			"RealmView: Cannot rebuild realm without a RealmLayout."
		)
		return

	owner.realm_layout = new_layout

	# Reset generator visual effects.
	owner.generator_animation_controller.reset()
	owner.forge_activity_visual_controller.reset()
	owner.molecular_agitation_particle_controller.reset()

	# Reset generator-specific animations.
	owner.lava_mite_visual_controller.reset(owner.generator_sprites)
	owner.matter_furnace_visual_controller.reset(owner.generator_sprites)

	# Reset generator rotations and cached drawing data.
	owner.generator_visual_renderer.reset_generator_rotations(
		owner.generator_sprites
	)
	owner.generator_visual_renderer.clear_cache()

	# Build the realm's static visual elements.
	owner.island_visual_controller.update(
		owner,
		owner.realm_layout,
		owner._get_island_rect()
	)
	owner.ash_visual_controller.setup(owner, owner.realm_layout)

	owner.lava_realm_visual_controller.create_network(
		owner,
		owner.realm_layout,
		owner._get_island_rect(),
		owner.LAVA_FLOW_SCENE,
		owner.LAVA_FALL_SCENE
	)
	owner.lava_realm_visual_controller.create_lakes(
		owner,
		owner.state,
		owner.realm_layout,
		owner._get_island_rect(),
		owner.LAVA_LAKE_SCENE
	)
	owner.lava_realm_visual_controller.update_positions(
		owner.realm_layout,
		owner._get_island_rect()
	)

	owner._draw_generators()

	# Force brazier positions to update immediately.
	owner.brazier_visual_controller.position_braziers(
		owner.braziers,
		owner.BRAZIER_STATS,
		owner.realm_layout,
		owner._get_island_rect()
	)

	# Rebuild crystallized flame visuals after the realm is ready.
	owner.crystallized_flame_visual_controller.reset_and_update(
		owner,
		owner.state
	)

	# Initialize the lava visuals from the current game state.
	owner.lava_realm_visual_controller.update_flow_states(
		owner.state,
		owner.realm_layout
	)

	owner.queue_redraw()
