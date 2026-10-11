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
