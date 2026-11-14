shader_type canvas_item;

// One shared material animates the glow without redrawing each bullet on the CPU.
void fragment() {
	COLOR.a *= 0.9 + 0.1 * sin(TIME * 9.0);
}
