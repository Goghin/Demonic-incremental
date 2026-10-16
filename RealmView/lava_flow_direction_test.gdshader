shader_type canvas_item;

// Diagnostic pass: a fixed color confirms whether this material and shader
// are actually being used by the lava surface polygons.
void fragment() {
	COLOR = vec4(1.0, 0.0, 1.0, 1.0);
}
