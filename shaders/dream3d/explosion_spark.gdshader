shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
varying float strength;
void vertex() { strength=INSTANCE_CUSTOM.r; }
void fragment() {
	ALBEDO=vec3(1.0,.58,.19);
	EMISSION=vec3(1.8,.80,.18)*strength;
	ALPHA=strength*smoothstep(0.0,.35,UV.y);
}
