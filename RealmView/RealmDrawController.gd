class_name RealmDrawController
extends RefCounted


func draw(owner: Control) -> void:
	if owner.state == null:
		return

	var center: Vector2 = owner.size * owner.ISLAND_CENTER_RATIO
	var ash: float = _prepare_ash_visuals(owner)

	_draw_realm_scene(owner, center)
	_update_realm_foreground(owner, center, ash)


func _prepare_ash_visuals(owner: Control) -> float:
	var ash: float = owner.state.get_resource_amount(
		ResourceIds.ASH
	)
	owner._update_ash_piles(ash)
	return ash


func _draw_realm_scene(owner: Control, center: Vector2) -> void:
	owner.realm_background_renderer.draw_background(owner, center)

	var island_rect: Rect2 = owner._get_island_rect()
	_update_braziers(owner, island_rect)
	owner._draw_generators()

	owner.forge_activity_visual_controller.update(
		owner,
		owner.state.generators.get("infernal_forge"),
		owner._get_generator_position("infernal_forge")
	)


func _update_realm_foreground(
	owner: Control,
	center: Vector2,
	ash: float
) -> void:
	owner.ash_visual_controller.update_contamination(
		owner,
		center,
		owner.ASH_VISUAL_RADIUS,
		ash
	)
	_update_layout_overlay(owner)


func _update_layout_overlay(owner: Control) -> void:
	owner.realm_layout_overlay_renderer.update_overlay(
		owner.realm_layout_editor_controller.layout_mode,
		owner.generator_hitboxes,
		owner.ash_visual_controller.piles,
		owner.braziers,
		owner.BRAZIER_STATS
	)


func _update_braziers(owner: Control, island_rect: Rect2) -> void:
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
