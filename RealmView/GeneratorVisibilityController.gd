class_name GeneratorVisibilityController
extends RefCounted


func update_visibility(
	active_ids: Dictionary,
	generator_sprites: Dictionary
) -> void:
	_update_standard_sprites(active_ids, generator_sprites)
	_update_special_sprites(active_ids, generator_sprites)


func _update_standard_sprites(
	active_ids: Dictionary,
	generator_sprites: Dictionary
) -> void:
	for generator_id in generator_sprites:
		if (
			generator_id == "lava_mite_colony"
			or
			generator_id == "matter_furnace"
		):
			continue

		if not active_ids.has(generator_id):
			var sprite: Sprite2D = generator_sprites[generator_id]
			sprite.visible = false


func _update_special_sprites(
	active_ids: Dictionary,
	generator_sprites: Dictionary
) -> void:
	_update_special_sprite(
		active_ids,
		generator_sprites,
		"lava_mite_colony"
	)
	_update_special_sprite(
		active_ids,
		generator_sprites,
		"matter_furnace"
	)


func _update_special_sprite(
	active_ids: Dictionary,
	generator_sprites: Dictionary,
	generator_id: String
) -> void:
	if not generator_sprites.has(generator_id):
		return

	var sprite: AnimatedSprite2D = (
		generator_sprites[generator_id] as AnimatedSprite2D
	)
	if sprite != null:
		sprite.visible = active_ids.has(generator_id)
