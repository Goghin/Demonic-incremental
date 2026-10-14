class_name GeneratorSpriteManager
extends RefCounted


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


func get_or_create_sprite(
	parent: Node,
	generator_sprites: Dictionary,
	generator_id: String
) -> Sprite2D:
	if generator_sprites.has(generator_id):
		return generator_sprites[generator_id] as Sprite2D

	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "Generator_" + generator_id
	parent.add_child(sprite)
	generator_sprites[generator_id] = sprite

	return sprite


func reset_generator_rotations(generator_sprites: Dictionary) -> void:
	for generator_id in generator_sprites:
		if (
			generator_id == "lava_mite_colony"
			or
			generator_id == "matter_furnace"
		):
			continue

		var sprite: Sprite2D = generator_sprites[generator_id]

		if sprite == null:
			continue

		sprite.rotation = 0.0



func create_animated_generator_sprite(
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
		parent.add_child(sprite)
		generator_sprites[generator_id] = sprite
		return sprite

	if hframes <= 0 or vframes <= 0:
		push_warning(
			"Invalid generator animation frame grid for " +
			generator_id +
			": " +
			str(hframes) +
			"x" +
			str(vframes)
		)
		parent.add_child(sprite)
		generator_sprites[generator_id] = sprite
		return sprite

	var sprite_frames: SpriteFrames = SpriteFrames.new()
	var animation_name: StringName = &"default"

	if not sprite_frames.has_animation(animation_name):
		sprite_frames.add_animation(animation_name)

	sprite_frames.set_animation_speed(animation_name, animation_fps)
	sprite_frames.set_animation_loop(animation_name, true)

	var frame_width: int = int(float(sheet.get_width()) / hframes)
	var frame_height: int = int(float(sheet.get_height()) / vframes)

	if frame_width <= 0 or frame_height <= 0:
		push_warning(
			"Generator animation sheet is too small for " +
			generator_id +
			": " +
			str(sheet.get_width()) +
			"x" +
			str(sheet.get_height())
		)
		parent.add_child(sprite)
		generator_sprites[generator_id] = sprite
		return sprite

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

	# Configure autoplay before entering the scene tree.
	parent.add_child(sprite)
	generator_sprites[generator_id] = sprite

	return sprite
