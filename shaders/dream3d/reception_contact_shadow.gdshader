shader_type spatial;
render_mode unshaded,cull_disabled,blend_mix,depth_draw_never;
uniform sampler2D shadow_texture:filter_nearest,repeat_disable;
uniform vec4 shadow_region=vec4(0.,0.,1.,1.);
uniform float opacity=.26;
void fragment(){ALBEDO=vec3(0.);ALPHA=texture(shadow_texture,shadow_region.xy+UV*shadow_region.zw).a*opacity;ROUGHNESS=1.;SPECULAR=0.;}
