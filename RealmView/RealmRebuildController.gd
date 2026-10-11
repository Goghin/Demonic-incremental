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

	owner.generator_visual_reset_controller.reset(
		owner.generator_animation_controller,
		owner.forge_activity_visual_controller,
		owner.molecular_agitation_particle_controller,
		owner.lava_mite_visual_controller,
		owner.matter_furnace_visual_controller,
		owner.generator_visual_renderer,
		owner.generator_sprites,
		owner.generator_hitboxes
	)
	_build_realm_geometry(owner)
	_refresh_state_dependent_visuals(owner)

	owner.queue_redraw()


func _build_realm_geometry(owner) -> void:
	var island_rect: Rect2 = owner._get_island_rect()

	_setup_ash_visuals(owner)
	_build_lava_network(owner, island_rect)

	# Use the same layout-positioning path as window resizing so both lifecycle
	# paths keep generators, hitboxes, ash piles, lava, and braziers aligned.
	# This path also updates the island, so geometry is only placed once.
	owner.realm_layout_visual_controller.update_positions(
		owner,
		island_rect
	)


func _setup_ash_visuals(owner) -> void:
	owner.ash_visual_controller.setup(
		owner,
		owner.realm_layout
	)


func _build_lava_network(owner, island_rect: Rect2) -> void:
	owner.lava_realm_visual_controller.build_realm_visuals(
		owner,
		owner.state,
		owner.realm_layout,
		island_rect,
		owner.LAVA_FLOW_SCENE,
		owner.LAVA_FALL_SCENE,
		owner.LAVA_LAKE_SCENE
	)


func _refresh_state_dependent_visuals(owner) -> void:
	owner.realm_rebuild_state_controller.refresh(owner)
