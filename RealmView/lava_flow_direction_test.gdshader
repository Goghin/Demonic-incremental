shader_type canvas_item;

// Diagnostic pass: show interpolated custom UVs as color.
// UV.x maps to red and UV.y maps to green; values above 1 clamp visibly.
void fragment() {
	COLOR = vec4(clamp(UV.x, 0.0, 1.0), clamp(UV.y, 0.0, 1.0), 0.0, 1.0);
}
