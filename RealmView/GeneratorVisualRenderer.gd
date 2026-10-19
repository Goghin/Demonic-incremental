class_name GeneratorVisualRenderer
extends RefCounted


var texture_cache: GeneratorTextureCache = GeneratorTextureCache.new()
var sprite_manager: GeneratorSpriteManager = GeneratorSpriteManager.new()


func setup_layer(
	owner: Node,
	existing_layer: Node2D
) -> Node2D:
	return sprite_manager.setup_layer(owner, existing_layer)


func get_or_create_sprite(
	parent: Node,
	generator_sprites: Dictionary,
	generator_id: String
) -> Sprite2D:
	return sprite_manager.get_or_create_sprite(
		parent,
		generator_sprites,
		generator_id
	)


func get_texture_scale(
	texture: Texture2D,
	machine_size: float,
	size_multiplier: float
) -> float:
	var texture_size: Vector2 = texture.get_size()
	var target_size: float = machine_size * 2.0 * size_multiplier

	return min(
		target_size / max(texture_size.x, 1.0),
		target_size / max(texture_size.y, 1.0)
	)


func get_texture_hitbox(
	texture: Texture2D,
	generator_position: Vector2,
	texture_scale: float
) -> Rect2:
	var draw_size: Vector2 = texture.get_size() * texture_scale
	return Rect2(generator_position - draw_size * 0.5, draw_size)


func get_fallback_hitbox(
	generator_position: Vector2,
	machine_size: float,
	size_multiplier: float
) -> Rect2:
	var fallback_size: float = machine_size * size_multiplier

	return Rect2(
		generator_position - Vector2(fallback_size, fallback_size),
		Vector2(fallback_size * 2.0, fallback_size * 2.0)
	)


func update_sprite(
	sprite: Sprite2D,
	generator: Generator,
	texture: Texture2D,
	generator_position: Vector2,
	texture_scale: float
) -> void:
	if sprite.z_index != 0:
		sprite.z_index = 0
	if sprite.texture != texture:
		sprite.texture = texture
	if sprite.position != generator_position:
		sprite.position = generator_position

	if generator.definition.id == "atomic_friction":
		var base_scale: Vector2 = Vector2(texture_scale, texture_scale)
		if not sprite.has_meta("atomic_friction_base_scale") or sprite.get_meta("atomic_friction_base_scale") != base_scale:
			sprite.set_meta("atomic_friction_base_scale", base_scale)
		# While operating, the animation controller owns sprite.scale every
		# frame. Only restore the dormant base scale when animation is inactive.
		if not generator.is_operating():
			var dormant_scale: Vector2 = base_scale * 0.64
			if sprite.scale != dormant_scale:
				sprite.scale = dormant_scale
	else:
		var target_scale: Vector2 = Vector2(texture_scale, texture_scale)
		if sprite.scale != target_scale:
			sprite.scale = target_scale

	if not sprite.visible:
		sprite.visible = true

	var target_modulate: Color
	if generator.level <= 0:
		# Unbuilt machines should read as dormant, not as active machinery.
		target_modulate = Color(0.72, 0.62, 0.50, 1.0)
	elif generator.is_operating():
		var operating_alpha: float = 0.75
		if generator.definition.id == "infernal_forge":
			operating_alpha = 1.0
		target_modulate = Color(1.0, 1.0, 1.0, operating_alpha)
	else:
		target_modulate = Color(0.70, 0.70, 0.70, 1.0)
	if sprite.modulate != target_modulate:
		sprite.modulate = target_modulate


func get_texture(generator: Generator) -> Texture2D:
	return texture_cache.get_texture(generator)


func clear_cache() -> void:
	texture_cache.clear()


func reset_generator_rotations(generator_sprites: Dictionary) -> void:
	sprite_manager.reset_generator_rotations(generator_sprites)


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
	return sprite_manager.create_animated_generator_sprite(
		parent,
		generator_sprites,
		generator_id,
		sprite_name,
		animation_path,
		hframes,
		vframes,
		animation_fps
	)



func update_animated_sprite(
	sprite: AnimatedSprite2D,
	generator_position: Vector2,
	texture_scale: float,
	is_operating: bool,
	operating_alpha: float = 0.75
) -> bool:
	sprite.position = generator_position
	sprite.scale = Vector2(texture_scale, texture_scale)
	sprite.z_index = 0

	if sprite.sprite_frames == null:
		sprite.visible = false
		return false

	var animation_name: StringName = &"default"
	if not sprite.sprite_frames.has_animation(animation_name):
		sprite.visible = false
		return false

	sprite.animation = animation_name
	sprite.visible = true

	if is_operating:
		sprite.modulate = Color(1.0, 1.0, 1.0, operating_alpha)
		if not sprite.is_playing():
			sprite.play()
	else:
		sprite.modulate = Color(0.70, 0.70, 0.70, 1.0)
		if sprite.is_playing():
			sprite.pause()

	return true
