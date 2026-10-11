class_name StandardGeneratorDrawer
extends RefCounted


func draw(
	owner: Control,
	generator: Generator,
	generator_id: String,
	generator_position: Vector2,
	machine_size: float,
	size_multiplier: float
) -> void:
	var visual_renderer: GeneratorVisualRenderer = (
		owner.generator_visual_renderer
	)
	var texture: Texture2D = visual_renderer.get_texture(generator)

	if texture != null:
		_draw_textured_generator(
			owner,
			visual_renderer,
			generator,
			generator_id,
			generator_position,
			texture,
			machine_size,
			size_multiplier
		)
	else:
		owner.generator_hitboxes[generator_id] = (
			visual_renderer.get_fallback_hitbox(
				generator_position,
				machine_size,
				size_multiplier
			)
		)


func _draw_textured_generator(
	owner: Control,
	visual_renderer: GeneratorVisualRenderer,
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

	owner.generator_hitboxes[generator_id] = (
		visual_renderer.get_texture_hitbox(
			texture,
			generator_position,
			texture_scale
		)
	)

	var sprite: Sprite2D = visual_renderer.get_or_create_sprite(
		owner.generator_layer,
		owner.generator_sprites,
		generator_id
	)

	visual_renderer.update_sprite(
		sprite,
		generator,
		texture,
		generator_position,
		texture_scale
	)
