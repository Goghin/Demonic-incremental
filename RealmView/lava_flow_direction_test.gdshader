shader_type canvas_item;

uniform sampler2D lava_texture : repeat_enable;

uniform float texture_scale = 0.07;
uniform float flow_speed = 15.0;
uniform vec3 dark_lava = vec3(0.28, 0.010, 0.002);
uniform vec3 red_lava = vec3(0.60, 0.025, 0.003);
uniform vec3 orange_lava = vec3(0.90, 0.070, 0.005);
uniform vec3 bright_lava = vec3(1.0, 0.20, 0.015);
uniform vec3 glow_lava = vec3(1.0, 0.08, 0.01);

void fragment() {
	// Diagnostic pass: visualize the custom Polygon2D UV coordinates directly.
	// Red shows across-channel UV; green shows distance along the flow.
	COLOR = vec4(fract(UV.x * 2.0), fract(UV.y * 0.25), 0.0, 1.0);
}
