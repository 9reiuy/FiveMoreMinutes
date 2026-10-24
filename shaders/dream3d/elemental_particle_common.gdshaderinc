uniform int particle_kind = 0;
uniform bool outline_pass = false;
uniform float contour_world_width = 0.02;
uniform vec4 contour_color : source_color = vec4(0.055,0.045,0.085,1.0);
void vertex() {
	vec2 size = vec2(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz));
	if (outline_pass) { size += vec2(contour_world_width*2.5); }
	mat4 facing = mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX*facing;
	VERTEX.xy *= size;
}
void fragment() {
	vec2 p = (floor(UV*16.0)+0.5)/16.0*2.0-1.0;
	float edge = min(length(p*vec2(1.05,1.10))-.77,
		min(length((p-vec2(-.36,.10))*vec2(1.2,1.3))-.52,
		length((p-vec2(.28,-.28))*vec2(1.3,1.15))-.55));
	if (particle_kind==2) { edge=max(abs(p.x),abs(p.y))-.62; }
	if (edge>0.0) discard;
	float coverage=mod(floor(FRAGCOORD.x)*2.0+floor(FRAGCOORD.y)*3.0,5.0)/5.0;
	if (COLOR.a<coverage+.04) discard;
	vec3 ink=COLOR.rgb;
	if (particle_kind==1 && p.y<-.2) { ink*=1.08; }
	ALBEDO=outline_pass ? contour_color.rgb : ink;
	// Intentional solid alpha: joins the ordered transparent pass, NOT soft
	// blending. Scene depth testing stays enabled in both passes.
	ALPHA=1.0;
}
