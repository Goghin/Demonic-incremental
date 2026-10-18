class_name Brazier
extends Control


const FLAME_ASSET_ROOT: String = "res://Assets/Flames/Pixel Fire Asset Pack 2 White/"
const FLAME_FRAME_COUNT: int = 14
const FLAME_FPS: float = 12.0
const FLAME_BASE_SCALE: float = 0.55
const FLAME_TRANSITION_WIDTH: float = 0.12


@export var brazier_size: float = 1.0


var stat_name: String = ""
var stat_value: int = 0

var displayed_stat_strength: float = 0.0
var target_stat_strength: float = 0.0

var flame_time: float = 0.0
var base_scale: Vector2

var flame_sprites: Array[AnimatedSprite2D] = []
var flame_frames: SpriteFrames


func _ready() -> void:
	base_scale = Vector2(
		brazier_size,
		brazier_size
	)

	scale = base_scale
	_setup_flame_animation()
	queue_redraw()


func _process(delta: float) -> void:
	flame_time += delta

	# Smoothly move toward the current stat strength.
	displayed_stat_strength = move_toward(
		displayed_stat_strength,
		target_stat_strength,
		delta * 3.0
	)

	_update_flame_sprites()
	queue_redraw()


func _setup_flame_animation() -> void:
	flame_frames = SpriteFrames.new()

	# The three Group 7 variants provide progressively larger flame shapes.
	var variants: Array[String] = [
		"Group 7 - 2",
		"Group 7 - 3",
		"Group 7 - 4"
	]

	for variant in variants:
		flame_frames.add_animation(variant)
		flame_frames.set_animation_speed(variant, FLAME_FPS)
		flame_frames.set_animation_loop(variant, true)

		for frame_index in range(1, FLAME_FRAME_COUNT + 1):
			var frame_path: String = (
				FLAME_ASSET_ROOT +
				variant +
				"/" +
				variant +
				"_" +
				str(frame_index) +
				".png"
			)
			var frame_texture: Texture2D = load(frame_path) as Texture2D

			if frame_texture != null:
				flame_frames.add_frame(variant, frame_texture)

	for variant in variants:
		var flame_sprite := AnimatedSprite2D.new()
		flame_sprite.name = variant.replace(" ", "").replace("-", "")
		flame_sprite.sprite_frames = flame_frames
		flame_sprite.animation = variant
		# Use the sprite's top-left origin and calculate its position so its
		# bottom-center remains anchored to the same point on the brazier.
		flame_sprite.centered = false
		flame_sprite.position = Vector2.ZERO
		flame_sprite.scale = Vector2.ONE * FLAME_BASE_SCALE
		flame_sprite.modulate = get_stat_color()
		flame_sprite.visible = false
		add_child(flame_sprite)
		flame_sprite.play(variant)
		flame_sprites.append(flame_sprite)


func _update_flame_sprites() -> void:
	var strength: float = displayed_stat_strength
	var variant_strengths: Array[float] = [
		1.0 - smoothstep(0.28, 0.52, strength),
		1.0 - absf((strength - 0.5) / 0.24),
		smoothstep(0.48, 0.76, strength)
	]

	for index in range(flame_sprites.size()):
		var flame_sprite: AnimatedSprite2D = flame_sprites[index]
		var variant_weight: float = clampf(variant_strengths[index], 0.0, 1.0)
		var alpha: float = variant_weight

		if strength <= 0.001:
			alpha = 0.0

		flame_sprite.visible = alpha > 0.001
		flame_sprite.modulate = Color(
			get_stat_color().r,
			get_stat_color().g,
			get_stat_color().b,
			alpha
		)

		# Keep the animation's size changes smooth as the selected art variant blends.
		var strength_scale: float = lerpf(0.65, 1.0, strength)
		var flicker: float = (
			1.0 +
			sin(flame_time * 8.0 + float(index)) * 0.025 +
			sin(flame_time * 13.0) * 0.015
		)
		var final_scale: float = FLAME_BASE_SCALE * strength_scale * flicker
		flame_sprite.scale = Vector2.ONE * final_scale

		# Anchor each frame by its bottom-center, regardless of texture size or scale.
		var frame_texture: Texture2D = flame_sprite.sprite_frames.get_frame_texture(
			flame_sprite.animation,
			flame_sprite.frame
		)
		if frame_texture != null:
			var frame_size: Vector2 = frame_texture.get_size()
			flame_sprite.position = Vector2(
				-frame_size.x * final_scale * 0.5,
				-frame_size.y * final_scale
			)


func set_stat(stat: String) -> void:
	stat_name = stat
	_update_flame_sprites()
	queue_redraw()


func set_stat_value(value: int) -> void:
	stat_value = max(value, 0)

	target_stat_strength = clamp(
		float(stat_value) / 100.0,
		0.0,
		1.0
	)


func get_stat_color() -> Color:
	match stat_name:
		"stability":
			return Color(
				0.20,
				0.85,
				0.30
			)

		"density":
			return Color(
				0.20,
				0.45,
				1.0
			)

		"integrity":
			return Color(
				0.65,
				0.20,
				0.95
			)

		"intensity":
			return Color(
				1.0,
				0.80,
				0.12
			)

		"resonance":
			return Color(
				0.10,
				0.90,
				0.90
			)

		_:
			return Color(
				1.0,
				0.35,
				0.08
			)


func _draw() -> void:
	var stat_color: Color = get_stat_color()
	var stat_strength: float = displayed_stat_strength

	# No glow when the stat has no investment.
	if stat_strength <= 0.001:
		return

	var flicker: float = (
		sin(flame_time * 7.0) * 0.08 +
		sin(flame_time * 13.0) * 0.04
	)

	var glow_radius: float = lerp(
		12.0,
		32.0,
		stat_strength
	)

	var glow_alpha: float = lerp(
		0.08,
		0.18,
		stat_strength
	) + flicker

	draw_circle(
		Vector2(0.0, -8.0),
		glow_radius,
		Color(
			stat_color.r,
			stat_color.g,
			stat_color.b,
			glow_alpha
		)
	)
