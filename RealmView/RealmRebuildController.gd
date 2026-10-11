class_name RealmRebuildController
extends RefCounted


func rebuild(owner: RealmView, new_layout: RealmLayout) -> void:
	if owner.state == null:
		return

	if new_layout == null:
		push_warning(
			"RealmView: Cannot rebuild realm without a RealmLayout."
		)
		return

	owner.realm_layout = new_layout

	owner.generator_visual_reset_controller.reset(owner)
	_build_realm_geometry(owner)
	_refresh_state_dependent_visuals(owner)

	owner.queue_redraw()


func _build_realm_geometry(owner: RealmView) -> void:
	var island_rect: Rect2 = owner._get_island_rect()

	_setup_ash_visuals(owner)
	_build_lava_network(owner, island_rect)

	# Rebuilds and resizes share one positioning path, preventing duplicate
	# placement and keeping all layout-bound visuals aligned.
	owner.realm_layout_visual_controller.update_positions(
		owner,
		island_rect
	)


func _setup_ash_visuals(owner: RealmView) -> void:
	owner.ash_visual_controller.setup(
		owner,
		owner.realm_layout
	)


func _build_lava_network(owner: RealmView, island_rect: Rect2) -> void:
	owner.lava_realm_visual_controller.build_realm_visuals(
		owner,
		owner.state,
		owner.realm_layout,
		island_rect,
		owner.LAVA_FLOW_SCENE,
		owner.LAVA_FALL_SCENE,
		owner.LAVA_LAKE_SCENE
	)


func _refresh_state_dependent_visuals(owner: RealmView) -> void:
	owner.realm_rebuild_state_controller.refresh(owner)
