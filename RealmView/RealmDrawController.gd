
class_name RealmDrawController
extends RefCounted


func draw(owner: Control) -> void:
	if owner.state == null:
		return

	var center: Vector2 = owner.size * owner.ISLAND_CENTER_RATIO

	owner.realm_background_renderer.draw_background(
		owner,
		center
	)
	owner._draw_generators()
	_update_layout_overlay(owner)


func _update_layout_overlay(owner: Control) -> void:
	owner.realm_layout_overlay_renderer.update_overlay(
		owner.realm_layout_editor_controller.layout_mode,
		owner.generator_hitboxes,
		owner.ash_visual_controller.piles,
		owner.braziers,
		owner.BRAZIER_STATS
	)
