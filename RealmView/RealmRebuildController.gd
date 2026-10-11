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

	owner.generator_visual_reset_controller.reset(owner)
	_build_realm_geometry(owner)
	_refresh_state_dependent_visuals(owner)

	owner.queue_redraw()


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
	owner.lava_realm_visual_controller.build_realm_visuals(
		owner,
		owner.state,
		owner.realm_layout,
		island_rect,
		owner.LAVA_FLOW_SCENE,
		owner.LAVA_FALL_SCENE,
		owner.LAVA_LAKE_SCENE
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

	# Initialize lake fill before evaluating dependent flow states.
	owner.lava_realm_visual_controller.update_dynamic_states(
		owner.state,
		owner.realm_layout
	)
