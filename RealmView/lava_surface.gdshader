shader_type canvas_item;

uniform sampler2D lava_texture : repeat_enable;

uniform float texture_size = 32.0;
uniform vec2 texture_speed = vec2(0.015, 0.008);
uniform float texture_strength = 0.55;

void fragment() {
	vec2 base_uv = VERTEX / texture_size;


	// ------------------------------------------------------------
	// 1. Main moving lava texture
	// ------------------------------------------------------------

	vec2 uv_a = base_uv + texture_speed * TIME;

	vec2 uv_b = base_uv * 0.72;
	uv_b += vec2(-0.009, 0.012) * TIME;

	float texture_a = texture(
		lava_texture,
		uv_a
	).r;

	float texture_b = texture(
		lava_texture,
		uv_b
	).r;

	float surface =
		texture_a * 0.72 +
		texture_b * 0.28;


	// ------------------------------------------------------------
	// 2. Slow secondary texture for irregular crust
	// ------------------------------------------------------------

	vec2 crust_uv = base_uv * 0.42;

	crust_uv += vec2(
		0.004,
		-0.003
	) * TIME;

	float crust_noise = texture(
		lava_texture,
		crust_uv
	).r;


	// ------------------------------------------------------------
	// 3. Create small irregular crust patches
	// ------------------------------------------------------------

	float crust_mask = smoothstep(
		0.18,
		0.42,
		crust_noise
	);

	// Only some of the dark surface becomes crust.
	crust_mask *= smoothstep(
		0.25,
		0.55,
		1.0 - surface
	);

	// Keep crust relatively weak.
	crust_mask *= 0.55;
	
	// Thin molten cracks around crust patches.
	float crust_edge = smoothstep(
		0.05,
		0.20,
		crust_mask
	);

	crust_edge *= 1.0 - smoothstep(
		0.45,
		0.70,
		crust_mask
	);

	crust_edge *= 0.45;

	// ------------------------------------------------------------
	// 4. Hotness from the main lava texture
	// ------------------------------------------------------------

	float warm = smoothstep(
		0.30,
		0.55,
		surface
	);

	float hot = smoothstep(
		0.55,
		0.78,
		surface
	);

	float very_hot = smoothstep(
		0.76,
		0.94,
		surface
	);


	// ------------------------------------------------------------
	// 5. Lava colors
	// ------------------------------------------------------------

	vec3 dark_lava = vec3(0.35, 0.012, 0.002);
	vec3 red_lava = vec3(0.65, 0.028, 0.003);
	vec3 orange_lava = vec3(0.95, 0.075, 0.006);
	vec3 bright_lava = vec3(1.0, 0.24, 0.02);

	vec3 crust_color = vec3(
		0.10,
		0.006,
		0.002
	);


	// ------------------------------------------------------------
	// 6. Build molten color
	// ------------------------------------------------------------

	vec3 lava_color = mix(
		dark_lava,
		red_lava,
		warm
	);

	lava_color = mix(
		lava_color,
		orange_lava,
		hot
	);

	lava_color = mix(
		lava_color,
		bright_lava,
		very_hot
	);


	// ------------------------------------------------------------
	// 7. Apply irregular crust
	// ------------------------------------------------------------

	lava_color = mix(
		lava_color,
		crust_color,
		crust_mask
	);
		// Hot lava showing through cracks in the crust.
	vec3 crack_color = vec3(
		1.0,
		0.16,
		0.008
	);

	lava_color = mix(
		lava_color,
		crack_color,
		crust_edge
	);

	// ------------------------------------------------------------
	// 8. Subtle overall pulsing
	// ------------------------------------------------------------

	float pulse = 0.5 + 0.5 * sin(
		TIME * 0.40 +
		VERTEX.x * 0.008 +
		VERTEX.y * 0.012
	);

	lava_color *= 0.94 + pulse * 0.08;


	// ------------------------------------------------------------
	// 9. Output
	// ------------------------------------------------------------

	COLOR = vec4(
		lava_color,
		texture_strength
	);
}