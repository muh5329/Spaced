shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float charge = 0.0;
void fragment() {
 vec2 p=UV*2.0-1.0;
 float r=length(p);
 float angle=atan(p.y,p.x);
 float rings=pow(0.5+0.5*sin(r*65.0-TIME*5.0),9.0);
 float spiral=pow(0.5+0.5*sin(angle*5.0-r*14.0+TIME*1.8),5.0);
 float edge=smoothstep(1.0,0.83,r);
 float core=exp(-r*6.0);
 ALBEDO=mix(vec3(0.12,0.44,0.78),vec3(0.55,0.84,1.0),core)*2.0;
 ALPHA=edge*(rings*0.34+spiral*0.13+core*0.8)*charge;
}
