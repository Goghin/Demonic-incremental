shader_type canvas_item;

uniform sampler2D lava_texture : repeat_enable;

uniform float texture_scale = 0.07;
uniform float flow_speed = 15.0;

void fragment() {
	vec2 pos = VERTEX;

	// --------------------------------------------------------
	// Animated coordinates
	// --------------------------------------------------------

	vec2 uv = pos * texture_scale;
	uv.y -= TIME * flow_speed * 0.01;

	float lava = texture(
		lava_texture,
		uv
	).r;

	// --------------------------------------------------------
	// Base lava colour
	// --------------------------------------------------------

	float warm = smoothstep(
		0.25,
		0.50,
		lava
	);

	float hot = smoothstep(
		0.50,
		0.72,
		lava
	);

	float very_hot = smoothstep(
		0.72,
		0.90,
		lava
	);

	vec3 dark_lava = vec3(
		0.28,
		0.010,
		0.002
	);

	vec3 red_lava = vec3(
		0.60,
		0.025,
		0.003
	);

	vec3 orange_lava = vec3(
		0.90,
		0.070,
		0.005
	);

	vec3 bright_lava = vec3(
		1.0,
		0.20,
		0.015
	);

	vec3 color = mix(
		dark_lava,
		red_lava,
		warm
	);

	color = mix(
		color,
		orange_lava,
		hot
	);

	color = mix(
		color,
		bright_lava,
		very_hot
	);

	// --------------------------------------------------------
	// Irregular moving blob pattern
	// --------------------------------------------------------

	vec2 blob_uv = uv;

	float large_blob = sin(
		blob_uv.y * 5.7 +
		sin(blob_uv.x * 3.1 + blob_uv.y * 1.7) * 2.4
	);

	float medium_blob = sin(
		blob_uv.y * 11.3 +
		sin(blob_uv.x * 6.7 - blob_uv.y * 2.3) * 1.8 +
		sin(blob_uv.x * 2.2) * 1.2
	);

	float small_blob = sin(
		blob_uv.y * 22.0 +
		sin(blob_uv.x * 11.0 + blob_uv.y * 3.0) * 1.2 +
		sin(blob_uv.x * 4.0) * 0.8
	);

	float distortion = sin(
		blob_uv.x * 7.0 +
		sin(blob_uv.y * 4.0) * 2.0
	);

	float blobs = (
		large_blob * 0.52 +
		medium_blob * 0.33 +
		small_blob * 0.15
	);

	blobs += distortion * 0.10;

	blobs = blobs * 0.5 + 0.5;

	// --------------------------------------------------------
	// Strong dark valleys
	// --------------------------------------------------------

	float blob_mask = smoothstep(
		0.40,
		0.62,
		blobs
	);

	vec3 dark_blob = vec3(
		0.07,
		0.001,
		0.0002
	);

	color = mix(
		dark_blob,
		color,
		blob_mask
	);

	// --------------------------------------------------------
	// Small bright molten cores
	// --------------------------------------------------------

	float bright_core = smoothstep(
		0.84,
		0.96,
		blobs
	);

	vec3 bright_blob = vec3(
		1.20,
		0.16,
		0.008
	);

	color = mix(
		color,
		bright_blob,
		bright_core * 0.45
	);

	// --------------------------------------------------------
	// Glow
	// --------------------------------------------------------

	float glow = smoothstep(
		0.65,
		0.90,
		lava
	);

	color += (
		vec3(1.0, 0.08, 0.01) *
		glow *
		0.45
	);

	COLOR = vec4(
		color,
		1.0
	);
}