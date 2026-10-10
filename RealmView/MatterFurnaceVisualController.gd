class_name MatterFurnaceVisualController
extends RefCounted


const SIZE_MULTIPLIER: float = 1.4
const FRAME_SIZE: Vector2 = Vector2(314.0, 321.0)


func reset(generator_sprites: Dictionary) -> void:
	if not generator_sprites.has("matter_furnace"):
		return

	var animated_sprite: AnimatedSprite2D = (
		generator_sprites["matter_furnace"] as AnimatedSprite2D
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
	generator_hitboxes: Dictionary
) -> void:
	var animated_sprite: AnimatedSprite2D = (
		generator_visual_renderer.get_matter_furnace_sprite(
			generator_layer,
			generator_sprites
		)
	)

	var target_size: float = (
		machine_size *
		2.0 *
		SIZE_MULTIPLIER
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
