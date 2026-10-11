class_name GeneratorTextureCache
extends RefCounted


# Cache generator illustrations so repeated realm redraws do not reload them.
var textures: Dictionary = {}


func get_texture(generator: Generator) -> Texture2D:
	var path: String = generator.definition.illustration_path

	if path.is_empty():
		return null

	var generator_id: String = generator.definition.id

	if textures.has(generator_id):
		return textures[generator_id]

	var texture: Texture2D = load(path) as Texture2D
	textures[generator_id] = texture

	return texture


func clear() -> void:
	textures.clear()
