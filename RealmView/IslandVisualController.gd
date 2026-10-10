class_name IslandVisualController
extends RefCounted


func update(
	owner: Control,
	realm_layout: Resource,
	island_rect: Rect2
) -> void:
	var island: Sprite2D = owner.get_node_or_null("Island") as Sprite2D

	if island == null:
		return

	if realm_layout == null:
		return

	var island_texture: Texture2D = (
		realm_layout.get("island_texture") as Texture2D
	)

	if island_texture == null:
		return

	island.texture = island_texture
	island.position = (
		island_rect.position +
		island_rect.size * 0.5
	)
	island.scale = (
		island_rect.size /
		island_texture.get_size()
	)
	island.z_index = 5
