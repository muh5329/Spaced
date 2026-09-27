shader_type spatial;
render_mode unshaded;
uniform vec3 tint : source_color = vec3(0.16,0.22,0.26);
void fragment(){
 float rim=pow(1.0-max(dot(normalize(NORMAL),normalize(VIEW)),0.0),6.0);
 float bands=sin(UV.y*65.0+sin(UV.x*18.0)*0.4)*0.0007;
 ALBEDO=max(tint*(0.12+0.45*max(dot(normalize(NORMAL),normalize(vec3(-0.7,0.3,1.0))),0.0))+bands,vec3(0.0004))+rim*vec3(0.014,0.055,0.083);
}
