shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
varying vec3 local_point;
void vertex() { local_point=VERTEX; }
void fragment() {
	vec3 pixel=floor(local_point*32.0);
	float seam=mod(pixel.y,8.0)==0.0 ? .88 : 1.0;
	ALBEDO=COLOR.rgb*seam;
	EMISSION=ALBEDO*.08;
	ROUGHNESS=1.0;
}
