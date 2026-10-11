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
	var overlay: RealmLayoutOverlayRenderer = owner.realm_layout_overlay_renderer
	var layout_mode: bool = owner.realm_layout_editor_controller.layout_mode

	# Refresh while editing, and once when leaving edit mode to clear the overlay.
	if not layout_mode and not overlay.overlay_enabled:
		return

	overlay.update_overlay(
		layout_mode,
		owner.generator_hitboxes,
		owner.ash_visual_controller.piles,
		owner.braziers,
		owner.BRAZIER_STATS
	)
