shader_type canvas_item;

// Diagnostic pass: capture the built-in UV in the vertex stage and
// forward it explicitly to the fragment stage.
varying vec2 diagnostic_uv;

void vertex() {
	diagnostic_uv = UV;
}

void fragment() {
	COLOR = vec4(
		clamp(diagnostic_uv.x * 3.0, 0.0, 1.0),
		clamp(diagnostic_uv.y * 20.0, 0.0, 1.0),
		0.0,
		1.0
	);
}
