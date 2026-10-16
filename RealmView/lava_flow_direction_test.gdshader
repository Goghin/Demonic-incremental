shader_type canvas_item;

uniform sampler2D lava_texture : repeat_enable;

// UVs are measured in flow-local pixels, so a larger scale produces
// smaller texture features and reduces their apparent screen-space speed.
uniform float texture_scale = 3.6;
uniform float flow_speed = 15.0;
uniform vec3 dark_lava = vec3(0.28, 0.010, 0.002);
uniform vec3 red_lava = vec3(0.60, 0.025, 0.003);
uniform vec3 orange_lava = vec3(0.90, 0.070, 0.005);
uniform vec3 bright_lava = vec3(1.0, 0.20, 0.015);
uniform vec3 glow_lava = vec3(1.0, 0.08, 0.01);

void fragment() {
	// The mesh supplies explicit across-channel and cumulative path-distance UVs.
	// This makes texture orientation follow the geometry of each flow segment.
	vec2 uv = UV * texture_scale;
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
