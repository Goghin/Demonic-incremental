shader_type canvas_item;

uniform sampler2D lava_texture : repeat_enable;

uniform float texture_scale = 0.07;
uniform float flow_speed = 15.0;
uniform vec2 segment_start = vec2(0.0, 0.0);
uniform vec2 segment_direction = vec2(1.0, 0.0);
uniform float path_distance_start = 0.0;

uniform vec3 dark_lava = vec3(0.28, 0.010, 0.002);
uniform vec3 red_lava = vec3(0.60, 0.025, 0.003);
uniform vec3 orange_lava = vec3(0.90, 0.070, 0.005);
uniform vec3 bright_lava = vec3(1.0, 0.20, 0.015);
uniform vec3 glow_lava = vec3(1.0, 0.08, 0.01);

// Capture the polygon's local-space vertex position before the fragment stage.
// Fragment-stage VERTEX can be in screen space, which breaks per-segment axes.
varying vec2 segment_local_position;

void vertex() {
	segment_local_position = VERTEX;
}

void fragment() {
	// Project each fragment onto this segment's local tangent and normal.
	// This avoids relying on Polygon2D custom UV interpolation.
	vec2 tangent = normalize(segment_direction);
	vec2 normal = vec2(-tangent.y, tangent.x);
	vec2 relative_position = segment_local_position - segment_start;

	float across = dot(relative_position, normal);
	float along = path_distance_start + dot(relative_position, tangent);

	vec2 uv = vec2(across, along) * texture_scale;
	uv.y -= TIME * flow_speed * 0.01;

	float lava = texture(lava_texture, uv).r;

	float warm = smoothstep(0.25, 0.50, lava);
	float hot = smoothstep(0.50, 0.72, lava);
	float very_hot = smoothstep(0.72, 0.90, lava);

	vec3 color = mix(dark_lava, red_lava, warm);
	color = mix(color, orange_lava, hot);
	color = mix(color, bright_lava, very_hot);

	float glow = smoothstep(0.65, 0.90, lava);
	color += glow_lava * glow * 0.38;

	COLOR = vec4(color, 1.0);
}
