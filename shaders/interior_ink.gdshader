shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
uniform float width = 0.014;
void vertex() { VERTEX += NORMAL * width; }
void fragment() { ALBEDO = vec3(0.023, 0.031, 0.043); }
