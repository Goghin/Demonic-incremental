class_name LavaMiteVisualController
extends RefCounted


const FRAME_SIZE: Vector2 = Vector2(256.0, 256.0)


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

	var colony_size_multiplier: float = get_size_multiplier(generator.level)

	var target_size: float = (
		machine_size *
		2.0 *
		size_multiplier *
		colony_size_multiplier
	)

	var texture_scale: float = min(
		target_size / max(FRAME_SIZE.x, 1.0),
		target_size / max(FRAME_SIZE.y, 1.0)
	)

	var draw_size: Vector2 = FRAME_SIZE * texture_scale
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

	update_animation_speed(animated_sprite, generator.level)

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

func get_size_multiplier(level: int) -> float:
	if level <= 1:
		return 0.70
	if level <= 21:
		return lerp(0.70, 1.00, float(level - 1) / 20.0)

	var levels_after_21: float = float(level - 21)
	return 1.0 + 0.45 * (1.0 - exp(-levels_after_21 / 30.0))


func update_animation_speed(
	animated_sprite: AnimatedSprite2D,
	level: int
) -> void:
	if animated_sprite.sprite_frames == null:
		return

	var animation_name: StringName = &"default"
	if not animated_sprite.sprite_frames.has_animation(animation_name):
		return

	var animation_speed: float
	if level <= 1:
		animation_speed = 2.5
	elif level <= 50:
		animation_speed = lerp(2.5, 6.5, float(level - 1) / 49.0)
	else:
		var levels_after_50: float = float(level - 50)
		animation_speed = 6.5 + 2.0 * (1.0 - exp(-levels_after_50 / 50.0))

	animated_sprite.sprite_frames.set_animation_speed(
		animation_name,
		animation_speed
	)

