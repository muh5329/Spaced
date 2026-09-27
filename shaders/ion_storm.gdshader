shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float activity = 0.08;
void fragment() {
 float streak = pow(max(0.0, sin(UV.x * 120.0 + sin(UV.y * 28.0 + TIME * 7.0) * 3.0)), 18.0);
 float bands = pow(max(0.0, sin(UV.y * 56.0 - TIME * 3.0)), 12.0);
 ALBEDO = vec3(0.32, 0.37, 0.9);
 EMISSION = vec3(0.3,0.5,1.0) * streak * activity * 2.0;
 ALPHA = (0.035 + streak * 0.35 + bands * 0.08) * activity;
}
