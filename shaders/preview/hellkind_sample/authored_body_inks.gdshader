shader_type canvas_item;
render_mode unshaded;

uniform vec2 frame_origin = vec2(0.0);
uniform int facing = 0;
varying vec4 inherited_modulate;

void vertex() {
	inherited_modulate = COLOR;
}

bool hair_strokes(int view, int k) {
	// Sparse source-texel strokes, one set per authored direction. Blinks
	// reuse the same marks. Original texture alpha and silhouette are intact.
	if (view == 0) return k==142 || k==172 || k==203 || k==234 || k==179 || k==213 || k==246;
	if (view == 1) return k==142 || k==172 || k==203 || k==234 || k==181 || k==215 || k==248;
	if (view == 2) return k==141 || k==171 || k==202 || k==233 || k==146 || k==180 || k==213 || k==246;
	if (view == 3) return k==139 || k==169 || k==200 || k==231 || k==178 || k==212 || k==245;
	if (view == 4) return k==140 || k==170 || k==201 || k==232 || k==147 || k==181 || k==215 || k==248;
	if (view == 5) return k==142 || k==172 || k==203 || k==234 || k==181 || k==215 || k==248;
	if (view == 6) return k==140 || k==171 || k==202 || k==233 || k==278 || k==311 || k==343 || k==376;
	return k==139 || k==169 || k==200 || k==231 || k==178 || k==212 || k==245;
}

bool collar_marks(int view, int k) {
	if (view == 0) return k==780 || k==748;
	if (view == 1) return k==784 || k==787 || k==752;
	if (view == 2) return k==782 || k==785;
	if (view == 3) return k==780 || k==783 || k==751;
	if (view == 4) return k==787 || k==755;
	if (view == 5) return k==785 || k==786 || k==787;
	if (view == 6) return k==815 || k==816 || k==817;
	return k==780 || k==781 || k==782;
}

bool authored_colour(vec3 rgb, vec3 rgb8) {
	return distance(rgb * 255.0, rgb8) < 2.1;
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	ivec2 cell = ivec2(floor(UV / TEXTURE_PIXEL_SIZE) - frame_origin);
	int k = cell.x + cell.y * 32;
	bool face = cell.y <= 22 && (
		authored_colour(source.rgb, vec3(255.0,237.0,237.0))
		|| authored_colour(source.rgb, vec3(235.0,206.0,206.0))
		|| authored_colour(source.rgb, vec3(223.0,175.0,175.0))
		|| authored_colour(source.rgb, vec3(191.0,150.0,151.0))
		|| authored_colour(source.rgb, vec3(225.0,213.0,213.0))
		|| authored_colour(source.rgb, vec3(215.0,215.0,215.0))
		|| authored_colour(source.rgb, vec3(199.0,199.0,199.0))
		|| (cell.y <= 20 && authored_colour(source.rgb, vec3(255.0))));
	bool clip = cell.y < 17 && authored_colour(source.rgb, vec3(164.0,145.0,116.0));
	bool front_bangs_detail = facing == 2 && cell.y >= 10 && cell.y <= 17
		&& authored_colour(source.rgb, vec3(179.0,180.0,181.0));
	// The light hood lies around the neck, below the face. Retain the
	// original white/silver hood texels and the dark folds between them.
	int hood_end = (facing == 0 || facing == 4) ? 25 : 24;
	bool hood = cell.y >= 21 && cell.y <= hood_end && (
		authored_colour(source.rgb, vec3(255.0))
		|| authored_colour(source.rgb, vec3(148.0))
		|| authored_colour(source.rgb, vec3(199.0)));
	bool pocket = cell.y >= 24 && authored_colour(source.rgb, vec3(105.0,143.0,166.0));
	bool line = hair_strokes(facing, k) || collar_marks(facing, k);
	float ink = (face || clip || front_bangs_detail || hood || pocket || line) ? 1.0 : 0.0;
	COLOR = vec4(vec3(ink), source.a) * inherited_modulate;
}
