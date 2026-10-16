shader_type canvas_item;

uniform sampler2D lava_texture : repeat_enable;

// UV.x runs across the channel; UV.y follows distance along the flow.
uniform float channel_texture_scale = 2.2;
uniform float flow_speed = 15.0;

uniform vec3 dark_lava = vec3(0.28, 0.010, 0.002);
uniform vec3 red_lava = vec3(0.60, 0.025, 0.003);
uniform vec3 orange_lava = vec3(0.90, 0.070, 0.005);
uniform vec3 bright_lava = vec3(1.0, 0.20, 0.015);
uniform vec3 glow_lava = vec3(1.0, 0.08, 0.01);

void fragment() {
	// UV.y is distance-based, so the animation follows bends in the channel.
	// A second, slower layer gives the surface the same depth as the lake.
	vec2 base_uv = vec2(UV.x * channel_texture_scale, UV.y);
	float flow_time = TIME * flow_speed * 0.01;

	vec2 uv_a = base_uv;
	uv_a.y -= flow_time;

	vec2 uv_b = base_uv * vec2(0.72, 0.72);
	uv_b.y -= flow_time * 0.62;
	uv_b.x += sin(UV.y * 5.0 - flow_time * 0.3) * 0.025;

	float texture_a = texture(lava_texture, uv_a).r;
	float texture_b = texture(lava_texture, uv_b).r;
	float surface = texture_a * 0.72 + texture_b * 0.28;

	// Slowly shifting crust breaks up the smooth, uniform molten surface.
	vec2 crust_uv = base_uv * 0.42;
	crust_uv.y -= flow_time * 0.24;
	crust_uv.x += 0.004 * TIME;

	float crust_noise = texture(lava_texture, crust_uv).r;
	float crust_mask = smoothstep(0.18, 0.42, crust_noise);
	crust_mask *= smoothstep(0.25, 0.55, 1.0 - surface);
	crust_mask *= 0.55;

	float crust_edge = smoothstep(0.05, 0.20, crust_mask);
	crust_edge *= 1.0 - smoothstep(0.45, 0.70, crust_mask);
	crust_edge *= 0.45;

	float warm = smoothstep(0.30, 0.55, surface);
	float hot = smoothstep(0.55, 0.78, surface);
	float very_hot = smoothstep(0.76, 0.94, surface);

	vec3 color = mix(dark_lava, red_lava, warm);
	color = mix(color, orange_lava, hot);
	color = mix(color, bright_lava, very_hot);

	// Dark crust with thin molten seams, matching the lake's surface treatment.
	color = mix(color, dark_lava * 0.30, crust_mask);
	vec3 crack_color = mix(orange_lava, bright_lava, 0.65);
	color = mix(color, crack_color, crust_edge);

	float glow = smoothstep(0.65, 0.90, surface);
	color += glow_lava * glow * 0.22;

	float pulse = 0.5 + 0.5 * sin(TIME * 0.40 + UV.y * 9.0 + UV.x * 2.0);
	color *= 0.94 + pulse * 0.08;

	COLOR = vec4(color, 1.0);
}
