class_name GeneratorVisualRenderer
extends RefCounted


# Cache generator illustrations so RealmView does not load the same texture
# repeatedly while redrawing the realm.
var generator_textures: Dictionary = {}


func get_texture(generator: Generator) -> Texture2D:
	var path: String = generator.definition.illustration_path

	if path.is_empty():
		return null

	var generator_id: String = generator.definition.id

	if generator_textures.has(generator_id):
		return generator_textures[generator_id]

	var texture: Texture2D = load(path) as Texture2D
	generator_textures[generator_id] = texture

	return texture
