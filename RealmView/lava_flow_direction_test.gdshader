shader_type canvas_item;

// Diagnostic pass: amplify custom UVs so small values remain visible.
// Red = across-channel coordinate; green = along-flow coordinate.
void fragment() {
	COLOR = vec4(clamp(UV.x * 3.0, 0.0, 1.0), clamp(UV.y * 20.0, 0.0, 1.0), 0.0, 1.0);
}
