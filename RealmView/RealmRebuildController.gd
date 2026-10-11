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

	_reset_visual_state(owner)
	_build_realm_geometry(owner)
	_refresh_state_dependent_visuals(owner)

	owner.queue_redraw()


func _reset_visual_state(owner) -> void:
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



func _build_realm_geometry(owner) -> void:
	var island_rect: Rect2 = owner._get_island_rect()

	_build_island_and_ash(owner, island_rect)
	_build_lava_network(owner, island_rect)
	_place_generators_and_braziers(owner, island_rect)


func _build_island_and_ash(owner, island_rect: Rect2) -> void:
	owner.island_visual_controller.update(
		owner,
		owner.realm_layout,
		island_rect
	)
	owner.ash_visual_controller.setup(owner, owner.realm_layout)


func _build_lava_network(owner, island_rect: Rect2) -> void:
	owner.lava_realm_visual_controller.create_network(
		owner,
		owner.realm_layout,
		island_rect,
		owner.LAVA_FLOW_SCENE,
		owner.LAVA_FALL_SCENE
	)
	owner.lava_realm_visual_controller.create_lakes(
		owner,
		owner.state,
		owner.realm_layout,
		island_rect,
		owner.LAVA_LAKE_SCENE
	)
	owner.lava_realm_visual_controller.update_positions(
		owner.realm_layout,
		island_rect
	)


func _place_generators_and_braziers(
	owner,
	island_rect: Rect2
) -> void:
	owner._draw_generators()
	_position_braziers(owner, island_rect)


func _position_braziers(owner, island_rect: Rect2) -> void:
	# Force brazier positions to update immediately after a layout rebuild.
	owner.brazier_visual_controller.position_braziers(
		owner.braziers,
		owner.BRAZIER_STATS,
		owner.realm_layout,
		island_rect
	)


func _refresh_state_dependent_visuals(owner) -> void:
	# Rebuild crystallized flame visuals after the realm is ready.
	owner.crystallized_flame_visual_controller.reset_and_update(
		owner,
		owner.state
	)

	# Initialize lava visuals from the current game state.
	owner.lava_realm_visual_controller.update_flow_states(
		owner.state,
		owner.realm_layout
	)
