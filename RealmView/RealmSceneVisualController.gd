class_name RealmSceneVisualController
extends RefCounted


func update(owner: Control) -> void:
	if owner.state == null or owner.realm_layout == null:
		return

	# Keep lava state updates before the other scene visuals, matching the
	# previous RealmUpdateController order.
	owner.lava_realm_visual_controller.update_lakes(
		owner.state,
		owner.realm_layout
	)
	owner.lava_realm_visual_controller.update_flow_states(
		owner.state,
		owner.realm_layout
	)

	var island_rect: Rect2 = owner._get_island_rect()

func _update_ash_visuals(
	owner: Control,
	island_rect: Rect2
) -> void:
	var ash: float = owner.state.get_resource_amount(ResourceIds.ASH)
	var center: Vector2 = owner.size * owner.ISLAND_CENTER_RATIO

	owner.ash_visual_controller.update_realm_visuals(
		owner,
		owner.realm_layout,
		island_rect,
		ash,
		center,
		owner.ASH_VISUAL_RADIUS
	)


	_update_ash_visuals(owner, island_rect)
	_update_braziers(owner, island_rect)
	_update_forge_visuals(owner)


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
