class_name RealmDrawController
extends RefCounted


func draw(owner: Control) -> void:
	if owner.state == null:
		return

	var center: Vector2 = owner.size * owner.ISLAND_CENTER_RATIO

	owner.brazier_visual_controller.update_stat_values(
		owner.braziers,
		owner.BRAZIER_STATS,
		owner.state.realm_configuration
	)

	var ash: float = owner.state.get_resource_amount(
		ResourceIds.ASH
	)
	owner._update_ash_piles(ash)

	owner.realm_background_renderer.draw_background(owner, center)

	var island_rect: Rect2 = owner._get_island_rect()

	owner.brazier_visual_controller.position_braziers(
		owner.braziers,
		owner.BRAZIER_STATS,
		owner.realm_layout,
		island_rect
	)

	owner._draw_generators()

	owner.forge_activity_visual_controller.update(
		owner,
		owner.state.generators.get("infernal_forge"),
		owner._get_generator_position("infernal_forge")
	)

	owner.ash_visual_controller.update_contamination(
		owner,
		center,
		owner.ASH_VISUAL_RADIUS,
		ash
	)

	owner.realm_layout_overlay_renderer.update_overlay(
		owner.realm_layout_editor_controller.layout_mode,
		owner.generator_hitboxes,
		owner.ash_visual_controller.piles,
		owner.braziers,
		owner.BRAZIER_STATS
	)
