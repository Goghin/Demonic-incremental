class_name LavaMiteVisualController
extends RefCounted


func reset(generator_sprites: Dictionary) -> void:
	if not generator_sprites.has("lava_mite_colony"):
		return

	var animated_sprite: AnimatedSprite2D = (
		generator_sprites["lava_mite_colony"] as AnimatedSprite2D
	)

	if animated_sprite == null:
		return

	animated_sprite.stop()
	animated_sprite.frame = 0


func update(
	generator_visual_renderer: GeneratorVisualRenderer,
	generator_layer: Node2D,
	generator_sprites: Dictionary,
	generator: Generator,
	generator_position: Vector2,
	machine_size: float,
	size_multiplier: float,
	generator_hitboxes: Dictionary
) -> void:
	var animated_sprite: AnimatedSprite2D = (
		generator_visual_renderer.get_lava_mite_sprite(
			generator_layer,
			generator_sprites
		)
	)

	var frame_size: Vector2 = Vector2(
		256.0,
		256.0
	)

	# Level 1 = 70%; level 21 = 100%.
	# Above level 21, size growth diminishes.
	var colony_size_multiplier: float = (
		generator_visual_renderer.get_lava_mite_size_multiplier(
			generator.level
		)
	)

	var target_size: float = (
		machine_size *
		2.0 *
		size_multiplier *
		colony_size_multiplier
	)

	var texture_scale: float = min(
		target_size / max(frame_size.x, 1.0),
		target_size / max(frame_size.y, 1.0)
	)

	var draw_size: Vector2 = frame_size * texture_scale
	generator_hitboxes[generator.definition.id] = Rect2(
		generator_position - draw_size * 0.5,
		draw_size
	)

	animated_sprite.position = generator_position
	animated_sprite.scale = Vector2(
		texture_scale,
		texture_scale
	)
	animated_sprite.z_index = 0
	animated_sprite.visible = true

	generator_visual_renderer.update_lava_mite_animation_speed(
		animated_sprite,
		generator.level
	)

	if generator.is_operating():
		animated_sprite.modulate = Color(1.0, 1.0, 1.0, 0.75)

		if animated_sprite.animation != &"default":
			animated_sprite.animation = &"default"

		if not animated_sprite.is_playing():
			animated_sprite.play()
	else:
		animated_sprite.modulate = Color(0.70, 0.70, 0.70, 1.0)

		if animated_sprite.is_playing():
			animated_sprite.pause()
