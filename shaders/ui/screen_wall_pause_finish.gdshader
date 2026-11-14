shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
void fragment() {
	vec4 base = textureLod(screen_texture,SCREEN_UV,0.0);
	vec3 halo = textureLod(screen_texture,SCREEN_UV,2.5).rgb * 0.23;
	halo += textureLod(screen_texture,SCREEN_UV,4.0).rgb * 0.34;
	halo += textureLod(screen_texture,SCREEN_UV,5.3).rgb * 0.22;
	float glow = max(halo.r,max(halo.g,halo.b)) * 0.80;
	float alpha = max(base.a,glow);
	vec3 rgb = base.rgb + halo * 0.80 * (vec3(1.0)-base.rgb);
	COLOR = vec4(rgb/max(alpha,0.001),alpha);
}
