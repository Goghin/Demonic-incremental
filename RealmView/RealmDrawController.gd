class_name RealmDrawController
extends RefCounted


func draw(owner: RealmView) -> void:
	if owner.state == null:
		return

	owner.realm_background_renderer.draw_background(owner)
