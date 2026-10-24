shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform sampler2D silhouette : filter_nearest, repeat_disable;
uniform vec4 rim_color : source_color=vec4(.55,.58,.62,1.0);
uniform float pixel_width=1.0;
void fragment(){
	vec2 texel=pixel_width/vec2(textureSize(silhouette,0));
	float center=texture(silhouette,UV).a;
	float edge=0.0;
	for(int x=-1;x<=1;x++){
		for(int y=-1;y<=1;y++) edge=max(edge,texture(silhouette,UV+vec2(float(x),float(y))*texel).a);
	}
	if(center>.05 || edge<.05){discard;}
	ALBEDO=rim_color.rgb;
	EMISSION=rim_color.rgb*.65;
	ALPHA=rim_color.a;
}
