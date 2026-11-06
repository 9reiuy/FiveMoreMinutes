shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha, diffuse_lambert;
uniform sampler2D sleep_texture : source_color, filter_nearest, repeat_disable;
void vertex() {
 VERTEX.z += sin(TIME * 1.8) * 0.002;
}
void fragment() {
 vec4 ink=texture(sleep_texture,UV);
 // The head rests on the pillow; shoulders disappear under the real duvet edge.
 if(ink.a<.5 || UV.y>.60) discard;
 ALBEDO=ink.rgb;
 ROUGHNESS=.9;
 SPECULAR=0.;
}
