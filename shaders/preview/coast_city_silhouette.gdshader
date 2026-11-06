shader_type spatial;
render_mode specular_disabled;
uniform float moon_visibility=1.;
uniform vec3 city_tint : source_color=vec3(.040,.055,.090);
varying vec3 city_position;
varying float city_distance;
void vertex(){city_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;city_distance=length(city_position-CAMERA_POSITION_WORLD);}
void fragment(){
 // Only broad structural ribs survive at this distance. No tiled bright windows.
 float rib=1.-smoothstep(.05,.13,abs(fract(city_position.x*.075)-.5));
 float tier=1.-smoothstep(.025,.08,abs(fract(city_position.y*.10)-.5));
 ALBEDO=city_tint*(1.+rib*.16+tier*.08)*mix(.18,1.,moon_visibility);
 float far_haze=smoothstep(580.,880.,city_distance);
 vec3 haze=mix(vec3(.014,.019,.034),vec3(.039,.038,.067),far_haze);
 EMISSION=(city_tint*.30+haze)*mix(.12,1.,moon_visibility);
 ROUGHNESS=.92;
}
