class_name StandardGeneratorDrawer
extends RefCounted


func draw(
	visual_renderer: GeneratorVisualRenderer,
	generator_layer: Node2D,
	generator_sprites: Dictionary,
	generator_hitboxes: Dictionary,
	generator: Generator,
	generator_id: String,
	generator_position: Vector2,
	machine_size: float,
	size_multiplier: float
) -> void:
	var texture: Texture2D = visual_renderer.get_texture(generator)

	if texture != null:
		_draw_textured_generator(
			visual_renderer,
			generator_layer,
			generator_sprites,
			generator_hitboxes,
			generator,
			generator_id,
			generator_position,
			texture,
			machine_size,
			size_multiplier
		)
	else:
		generator_hitboxes[generator_id] = (
			visual_renderer.get_fallback_hitbox(
				generator_position,
				machine_size,
				size_multiplier
			)
		)


func _draw_textured_generator(
	visual_renderer: GeneratorVisualRenderer,
	generator_layer: Node2D,
	generator_sprites: Dictionary,
	generator_hitboxes: Dictionary,
	generator: Generator,
	generator_id: String,
	generator_position: Vector2,
	texture: Texture2D,
	machine_size: float,
	size_multiplier: float
) -> void:
	var texture_scale: float = visual_renderer.get_texture_scale(
		texture,
		machine_size,
		size_multiplier
	)

	generator_hitboxes[generator_id] = (
		visual_renderer.get_texture_hitbox(
			texture,
			generator_position,
			texture_scale
		)
	)

	var sprite: Sprite2D = visual_renderer.get_or_create_sprite(
		generator_layer,
		generator_sprites,
		generator_id
	)

	visual_renderer.update_sprite(
		sprite,
		generator,
		texture,
		generator_position,
		texture_scale
	)
