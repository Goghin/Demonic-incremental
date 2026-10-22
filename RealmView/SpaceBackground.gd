extends TextureRect

const BACKGROUND_TEXTURES: Array[Texture2D] = [
	preload("res://Assets/Backgrounds/Blue Nebula/Blue_Nebula_01-1024x1024.png"),
	preload("res://Assets/Backgrounds/Blue Nebula/Blue_Nebula_02-1024x1024.png"),
	preload("res://Assets/Backgrounds/Blue Nebula/Blue_Nebula_03-1024x1024.png"),
	preload("res://Assets/Backgrounds/Blue Nebula/Blue_Nebula_04-1024x1024.png"),
	preload("res://Assets/Backgrounds/Blue Nebula/Blue_Nebula_05-1024x1024.png"),
	preload("res://Assets/Backgrounds/Blue Nebula/Blue_Nebula_06-1024x1024.png"),
	preload("res://Assets/Backgrounds/Blue Nebula/Blue_Nebula_07-1024x1024.png"),
	preload("res://Assets/Backgrounds/Blue Nebula/Blue_Nebula_08-1024x1024.png"),
	preload("res://Assets/Backgrounds/Green Nebula/Green_Nebula_01-1024x1024.png"),
	preload("res://Assets/Backgrounds/Green Nebula/Green_Nebula_02-1024x1024.png"),
	preload("res://Assets/Backgrounds/Green Nebula/Green_Nebula_03-1024x1024.png"),
	preload("res://Assets/Backgrounds/Green Nebula/Green_Nebula_04-1024x1024.png"),
	preload("res://Assets/Backgrounds/Green Nebula/Green_Nebula_05-1024x1024.png"),
	preload("res://Assets/Backgrounds/Green Nebula/Green_Nebula_06-1024x1024.png"),
	preload("res://Assets/Backgrounds/Green Nebula/Green_Nebula_07-1024x1024.png"),
	preload("res://Assets/Backgrounds/Green Nebula/Green_Nebula_08-1024x1024.png"),
	preload("res://Assets/Backgrounds/Purple Nebula/Purple_Nebula_01-1024x1024.png"),
	preload("res://Assets/Backgrounds/Purple Nebula/Purple_Nebula_02-1024x1024.png"),
	preload("res://Assets/Backgrounds/Purple Nebula/Purple_Nebula_03-1024x1024.png"),
	preload("res://Assets/Backgrounds/Purple Nebula/Purple_Nebula_04-1024x1024.png"),
	preload("res://Assets/Backgrounds/Purple Nebula/Purple_Nebula_05-1024x1024.png"),
	preload("res://Assets/Backgrounds/Purple Nebula/Purple_Nebula_06-1024x1024.png"),
	preload("res://Assets/Backgrounds/Purple Nebula/Purple_Nebula_07-1024x1024.png"),
	preload("res://Assets/Backgrounds/Purple Nebula/Purple_Nebula_08-1024x1024.png"),
	preload("res://Assets/Backgrounds/Starfields/Starfield_01-1024x1024.png"),
	preload("res://Assets/Backgrounds/Starfields/Starfield_02-1024x1024.png"),
	preload("res://Assets/Backgrounds/Starfields/Starfield_03-1024x1024.png"),
	preload("res://Assets/Backgrounds/Starfields/Starfield_04-1024x1024.png"),
	preload("res://Assets/Backgrounds/Starfields/Starfield_05-1024x1024.png"),
	preload("res://Assets/Backgrounds/Starfields/Starfield_06-1024x1024.png"),
	preload("res://Assets/Backgrounds/Starfields/Starfield_07-1024x1024.png"),
	preload("res://Assets/Backgrounds/Starfields/Starfield_08-1024x1024.png")
]

const SCROLL_SPEED := Vector2(0.0012, 0.0005)

var _current_background_index: int = -1


func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var background_shader := Shader.new()
	background_shader.code = """
shader_type canvas_item;

uniform sampler2D background_texture : source_color, repeat_enable;
uniform vec2 scroll_speed = vec2(0.0012, 0.0005);

void fragment() {
	vec2 texture_size = vec2(textureSize(background_texture, 0));
	vec2 tiled_uv = FRAGCOORD.xy / texture_size + TIME * scroll_speed;
	COLOR = texture(background_texture, tiled_uv);
}
"""

	var shader_material := ShaderMaterial.new()
	shader_material.shader = background_shader
	material = shader_material

	choose_random_background()


func choose_random_background() -> void:
	if BACKGROUND_TEXTURES.is_empty():
		return

	var next_index := randi_range(0, BACKGROUND_TEXTURES.size() - 1)
	if BACKGROUND_TEXTURES.size() > 1 and next_index == _current_background_index:
		next_index = (next_index + randi_range(1, BACKGROUND_TEXTURES.size() - 1)) % BACKGROUND_TEXTURES.size()

	_current_background_index = next_index
	texture = BACKGROUND_TEXTURES[_current_background_index]
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("background_texture", texture)
