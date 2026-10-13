class_name MatterFurnaceVisualController
extends RefCounted


const ANIMATION_PATH: String = "res://Generators/GeneratorDefinitions/matter furnace_animated.png"
const ANIMATION_HFRAMES: int = 4
const ANIMATION_VFRAMES: int = 4
const ANIMATION_FPS: float = 10.0

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
		generator_visual_renderer.create_animated_generator_sprite(
			generator_layer,
			generator_sprites,
			"matter_furnace",
			"Generator_matter_furnace",
			ANIMATION_PATH,
			ANIMATION_HFRAMES,
			ANIMATION_VFRAMES,
			ANIMATION_FPS
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

	generator_visual_renderer.update_animated_sprite(
		animated_sprite,
		generator_position,
		texture_scale,
		generator.is_operating()
	)
	if generator.level <= 0:
		animated_sprite.modulate = Color(0.72, 0.62, 0.50, 1.0)
