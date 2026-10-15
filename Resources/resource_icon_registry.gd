class_name ResourceIconRegistry
extends RefCounted


const ICON_PATHS: Dictionary = {
	ResourceIds.HEAT: "res://Assets/ResourceIcons/heat.svg",
	ResourceIds.MATTER: "res://Assets/ResourceIcons/matter.svg",
	ResourceIds.ASH: "res://Assets/ResourceIcons/ash.svg",
	ResourceIds.CRYSTALLIZED_FLAME: "res://Assets/ResourceIcons/crystallized_flame.svg",
	ResourceIds.ESSENCE: "res://Assets/ResourceIcons/essence.svg",
	ResourceIds.NEXUM: "res://Assets/ResourceIcons/nexum.svg",
}


static var _texture_cache: Dictionary = {}


static func get_texture(resource_id: String) -> Texture2D:
	if _texture_cache.has(resource_id):
		return _texture_cache[resource_id]

	var icon_path: String = ICON_PATHS.get(resource_id, "")
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		return null

	var texture: Texture2D = load(icon_path) as Texture2D
	if texture != null:
		_texture_cache[resource_id] = texture

	return texture


static func get_icon_path(resource_id: String) -> String:
	return ICON_PATHS.get(resource_id, "")
