shader_type sky;
uniform vec3 nebula_tint : source_color = vec3(0.035,0.10,0.15);
// Direction-based nebula and stars stay infinitely distant while the camera orbits.
float hash3(vec3 p) { return fract(sin(dot(p, vec3(127.1,311.7,74.7))) * 43758.5453); }
float noise3(vec3 p) {
 vec3 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
 float a=mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y);
 float b=mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y);
 return mix(a,b,f.z);
}
float fbm(vec3 p) { float a=0.5,n=0.0; for(int i=0;i<5;i++){n+=a*noise3(p);p=p*2.03+vec3(7.1,4.8,2.7);a*=0.51;}return n; }
void sky() {
 vec3 direction=normalize(EYEDIR);
 float dust=fbm(direction*4.0+fbm(direction*2.0)*2.0);
 float cloud=pow(smoothstep(0.32,0.82,dust),2.3);
 vec3 cold=nebula_tint,warm=vec3(0.12,0.075,0.05);
 vec3 color=vec3(0.001,0.0025,0.005)+mix(cold,warm,fbm(direction*3.0))*cloud;
 vec2 uv=vec2(atan(direction.z,direction.x)/6.2831853+0.5,asin(direction.y)/3.1415927+0.5);
 vec2 cell=uv*vec2(2600.0,1300.0);
 float star=hash3(vec3(floor(cell),17.0));
 float point=exp(-length(fract(cell)-0.5)*20.0)*step(0.994,star);
 color+=mix(vec3(0.5,0.7,1.0),vec3(1.0,0.84,0.58),star)*point*1.3;
 COLOR=color;
}
