
class_name MatterFurnaceVisualController
extends RefCounted


const ANIMATION_PATH: String = "res://Generators/GeneratorDefinitions/Matter_Furnace_Animated.png"
const IDLE_PATH: String = "res://Generators/GeneratorDefinitions/Matter_Furnace.png"

const ANIMATION_HFRAMES: int = 4
const ANIMATION_VFRAMES: int = 4
const ANIMATION_FPS: float = 10.0

const SIZE_MULTIPLIER: float = 1.8
const FRAME_SIZE: Vector2 = Vector2(512.0, 512.0)


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

	if animated_sprite == null:
		return

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

	var idle_sprite: Sprite2D = (
		animated_sprite.get_node_or_null("IdleSprite") as Sprite2D
	)

	if idle_sprite == null:
		idle_sprite = Sprite2D.new()
		idle_sprite.name = "IdleSprite"
		idle_sprite.texture = load(IDLE_PATH) as Texture2D
		idle_sprite.centered = true
		animated_sprite.add_child(idle_sprite)

	var is_running: bool = generator.is_operating()

	generator_visual_renderer.update_animated_sprite(
		animated_sprite,
		generator_position,
		texture_scale,
		is_running
	)

	# The idle sprite inherits its parent's scale.
	# Normalize its texture size to match one animation frame.
	if idle_sprite.texture != null:
		var idle_size: Vector2 = idle_sprite.texture.get_size()
		idle_sprite.scale = Vector2(
			FRAME_SIZE.x / max(idle_size.x, 1.0),
			FRAME_SIZE.y / max(idle_size.y, 1.0)
		)

	idle_sprite.visible = not is_running
	animated_sprite.self_modulate = (
		Color.WHITE if is_running else Color.TRANSPARENT
	)

	if generator.level <= 0:
		animated_sprite.modulate = Color(0.72, 0.62, 0.50, 1.0)
	else:
		animated_sprite.modulate = Color.WHITE
