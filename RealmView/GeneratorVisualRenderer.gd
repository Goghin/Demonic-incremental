class_name GeneratorVisualRenderer
extends RefCounted


const LAVA_MITE_ANIMATION_PATH: String = "res://Generators/GeneratorDefinitions/Lava_Mite_Colony_Animated.png"
const LAVA_MITE_ANIMATION_HFRAMES: int = 4
const LAVA_MITE_ANIMATION_VFRAMES: int = 4
const LAVA_MITE_ANIMATION_FPS: float = 4.0

const MATTER_FURNACE_ANIMATION_PATH: String = "res://Generators/GeneratorDefinitions/matter furnace_animated.png"
const MATTER_FURNACE_ANIMATION_HFRAMES: int = 4
const MATTER_FURNACE_ANIMATION_VFRAMES: int = 4
const MATTER_FURNACE_ANIMATION_FPS: float = 10.0

# Cache generator illustrations so RealmView does not load the same texture
# repeatedly while redrawing the realm.
var generator_textures: Dictionary = {}


func setup_layer(
	owner: Node,
	existing_layer: Node2D
) -> Node2D:
	if is_instance_valid(existing_layer):
		return existing_layer

	var layer: Node2D = Node2D.new()
	layer.name = "GeneratorLayer"
	layer.z_index = 10
	owner.add_child(layer)

	return layer


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


func clear_cache() -> void:
	generator_textures.clear()


func get_lava_mite_sprite(parent: Node, generator_sprites: Dictionary) -> AnimatedSprite2D:
	return _get_animated_generator_sprite(
		parent,
		generator_sprites,
		"lava_mite_colony",
		"Generator_lava_mite_colony",
		LAVA_MITE_ANIMATION_PATH,
		LAVA_MITE_ANIMATION_HFRAMES,
		LAVA_MITE_ANIMATION_VFRAMES,
		LAVA_MITE_ANIMATION_FPS
	)


func get_matter_furnace_sprite(parent: Node, generator_sprites: Dictionary) -> AnimatedSprite2D:
	return _get_animated_generator_sprite(
		parent,
		generator_sprites,
		"matter_furnace",
		"Generator_matter_furnace",
		MATTER_FURNACE_ANIMATION_PATH,
		MATTER_FURNACE_ANIMATION_HFRAMES,
		MATTER_FURNACE_ANIMATION_VFRAMES,
		MATTER_FURNACE_ANIMATION_FPS
	)


func _get_animated_generator_sprite(
	parent: Node,
	generator_sprites: Dictionary,
	generator_id: String,
	sprite_name: String,
	animation_path: String,
	hframes: int,
	vframes: int,
	animation_fps: float
) -> AnimatedSprite2D:
	if generator_sprites.has(generator_id):
		return generator_sprites[generator_id] as AnimatedSprite2D

	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.name = sprite_name

	var sheet: Texture2D = load(animation_path) as Texture2D
	if sheet == null:
		push_warning("Could not load generator animation: " + animation_path)
		return sprite

	var sprite_frames: SpriteFrames = SpriteFrames.new()
	var animation_name: StringName = &"default"
	if not sprite_frames.has_animation(animation_name):
		sprite_frames.add_animation(animation_name)
	sprite_frames.set_animation_speed(animation_name, animation_fps)
	sprite_frames.set_animation_loop(animation_name, true)

	var frame_width: int = sheet.get_width() / hframes
	var frame_height: int = sheet.get_height() / vframes

	for row in range(vframes):
		for column in range(hframes):
			var atlas_texture: AtlasTexture = AtlasTexture.new()
			atlas_texture.atlas = sheet
			atlas_texture.region = Rect2(
				column * frame_width,
				row * frame_height,
				frame_width,
				frame_height
			)
			sprite_frames.add_frame(animation_name, atlas_texture)

	sprite.sprite_frames = sprite_frames
	sprite.animation = animation_name
	sprite.autoplay = animation_name
	sprite.frame = 0
	sprite.z_index = 0
	parent.add_child(sprite)
	generator_sprites[generator_id] = sprite

	return sprite


func get_lava_mite_size_multiplier(level: int) -> float:
	if level <= 1:
		return 0.70
	if level <= 21:
		return lerp(0.70, 1.00, float(level - 1) / 20.0)

	var levels_after_21: float = float(level - 21)
	return 1.0 + 0.45 * (1.0 - exp(-levels_after_21 / 30.0))


func update_lava_mite_animation_speed(
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

func get_generator_position(
	generator_id: String,
	layout_positions: Dictionary,
	view_size: Vector2,
	island_rect: Rect2
) -> Vector2:
	if not layout_positions.has(generator_id):
		return view_size * Vector2(0.5, 0.5)

	var normalized_position: Vector2 = layout_positions[generator_id]

	return (
		island_rect.position +
		island_rect.size * normalized_position
	)

