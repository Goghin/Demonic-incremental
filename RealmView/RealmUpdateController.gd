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
	_update_realm_environment(owner)
	_update_realm_scene_visuals(owner)
	_update_middle_animations(owner)
	_update_molecular_agitation(owner)
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


func _update_realm_environment(owner: Control) -> void:
	if owner.realm_layout == null:
		return

	owner.lava_realm_visual_controller.update_lakes(
		owner.state,
		owner.realm_layout
	)
	owner.lava_realm_visual_controller.update_flow_states(
		owner.state,
		owner.realm_layout
	)


func _update_realm_scene_visuals(owner: Control) -> void:
	if owner.realm_layout == null:
		return

	var island_rect: Rect2 = owner._get_island_rect()

	_update_ash_visuals(owner, island_rect)
	_update_braziers(owner, island_rect)
	_update_forge_visuals(owner)
	_update_ash_contamination(owner)


func _update_ash_visuals(
	owner: Control,
	island_rect: Rect2
) -> void:
	var ash: float = owner.state.get_resource_amount(
		ResourceIds.ASH
	)

	owner.ash_visual_controller.update_piles(
		owner.realm_layout,
		island_rect,
		ash
	)


func _update_braziers(
	owner: Control,
	island_rect: Rect2
) -> void:
	owner.brazier_visual_controller.update_stat_values(
		owner.braziers,
		owner.BRAZIER_STATS,
		owner.state.realm_configuration
	)

	owner.brazier_visual_controller.position_braziers(
		owner.braziers,
		owner.BRAZIER_STATS,
		owner.realm_layout,
		island_rect
	)


func _update_forge_visuals(owner: Control) -> void:
	owner.forge_activity_visual_controller.update(
		owner,
		owner.state.generators.get("infernal_forge"),
		owner._get_generator_position("infernal_forge")
	)


func _update_ash_contamination(owner: Control) -> void:
	var ash: float = owner.state.get_resource_amount(
		ResourceIds.ASH
	)

	var center: Vector2 = owner.size * owner.ISLAND_CENTER_RATIO

	owner.ash_visual_controller.update_contamination(
		owner,
		center,
		owner.ASH_VISUAL_RADIUS,
		ash
	)


func _update_middle_animations(owner: Control) -> void:
	owner.generator_animation_controller.update_middle(
		owner,
		owner.state,
		owner.generator_sprites
	)


func _update_molecular_agitation(owner: Control) -> void:
	owner.molecular_agitation_particle_controller.update(
		owner.state.generators.get("thermal_furnace"),
		owner._get_generator_position("thermal_furnace")
	)


func _update_late_animations(owner: Control, delta: float) -> void:
	owner.generator_animation_controller.update_late(
		owner.state,
		owner.generator_sprites,
		delta
	)
