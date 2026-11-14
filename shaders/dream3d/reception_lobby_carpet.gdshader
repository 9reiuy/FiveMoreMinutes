shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D carpet_albedo : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D pile_normal : hint_normal, filter_nearest_mipmap, repeat_enable;
// Neutral tint darkens the photograph's own burgundy without replacing it.
uniform vec4 fabric_colour : source_color = vec4(.78,.71,.72,1.0);
varying vec3 carpet_world;
void vertex(){carpet_world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	// Keep the complete original photograph and stable 32px/m presentation.
	// Unsnapped gradients retain proper minification when the Camera moves.
	vec2 nap_uv=(floor(carpet_world.xz*32.0)+.5)/128.0;
	vec2 dx=dFdx(carpet_world.xz)*.25;
	vec2 dy=dFdy(carpet_world.xz)*.25;
	vec3 cloth=textureGrad(carpet_albedo,nap_uv,dx,dy).rgb*fabric_colour.rgb;
	// The binding has actual folded geometry and a dark, solid backing.
	cloth*=COLOR.r;
	ALBEDO=cloth;ROUGHNESS=.96;
	NORMAL_MAP=textureGrad(pile_normal,nap_uv,dx,dy).rgb;NORMAL_MAP_DEPTH=.32;
	METALLIC=0.0;SPECULAR=.025;
	// Broad wool sheen reacts to the lamps; no plastic clearcoat or emission.
	RIM=.055;RIM_TINT=.65;
}
