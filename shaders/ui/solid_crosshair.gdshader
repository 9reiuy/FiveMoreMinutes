shader_type canvas_item;
render_mode unshaded;

uniform vec2 canvas_size = vec2(72.0, 72.0);
uniform int shape_type = 3; // 0: SQUARE, 1: T_SHAPE, 2: BRACKET, 3: CIRCLE
uniform float recoil_px = 0.0;
uniform float throw_aim = 0.0;

uniform vec4 reticle_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 pip_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width = 0.60;
uniform vec4 outline_color : source_color = vec4(0.035, 0.047, 0.075, 0.88);

uniform float reloading = 0.0;
uniform float reload_progress = 0.0;
uniform vec4 reload_fill_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 reload_track_color : source_color = vec4(0.04, 0.055, 0.085, 0.56);

vec2 rot2(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * p.x + s * p.y, -s * p.x + c * p.y);
}

float sd_circle(vec2 p, float r) {
	return length(p) - r;
}

float sd_box(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

// Exact symmetric trapezoid along local Y axis: y in [-he, +he], half-widths r1 (bottom) and r2 (top).
float sd_trapezoid_y(vec2 p, float r1, float r2, float he) {
	vec2 k1 = vec2(r2, he);
	vec2 k2 = vec2(r2 - r1, 2.0 * he);
	p.x = abs(p.x);
	vec2 ca = vec2(p.x - min(p.x, (p.y < 0.0) ? r1 : r2), abs(p.y) - he);
	vec2 cb = p - k1 + k2 * clamp(dot(k1 - p, k2) / max(dot(k2, k2), 0.0001), 0.0, 1.0);
	float s = (cb.x < 0.0 && ca.y < 0.0) ? -1.0 : 1.0;
	return s * sqrt(min(dot(ca, ca), dot(cb, cb)));
}

// Tapered bar pointing toward center from outer radius along +X (direction angle `ang`).
float sd_taper_prong(vec2 p, float ang, float inner_gap, float len, float half_w_in, float half_w_out) {
	vec2 q = rot2(p, ang);
	// After rotation, target axis is +X. Shift so center of bar is at X = inner_gap + len * 0.5,
	// then swap X->Y so -he is inner tip and +he is outer end.
	vec2 t = vec2(q.y, q.x - (inner_gap + len * 0.5));
	return sd_trapezoid_y(t, half_w_in, half_w_out, len * 0.5);
}

// Flat radial-cut ring arc centered along normalized direction `sc_dir` with angular half-aperture `half_angle`.
float sd_ring_arc_flat(vec2 p, vec2 sc_dir, float half_angle, float radius, float half_thick) {
	if (half_angle <= 0.0005) {
		return 1e5;
	}
	float d_ring = abs(length(p) - radius) - half_thick;
	if (half_angle >= 3.1410) {
		return d_ring;
	}
	vec2 q = vec2(p.x * sc_dir.x + p.y * sc_dir.y, abs(-p.x * sc_dir.y + p.y * sc_dir.x));
	float ca = cos(half_angle);
	float sa = sin(half_angle);
	float proj_along = q.x * ca + q.y * sa;
	float proj_perp = -q.x * sa + q.y * ca;
	if (proj_perp <= 0.0) {
		return (proj_along > 0.0) ? max(d_ring, proj_perp) : d_ring;
	}
	float clamp_along = clamp(proj_along, radius - half_thick, radius + half_thick);
	return length(vec2(proj_along - clamp_along, proj_perp));
}

float sd_weapon_outer(vec2 p) {
	if (shape_type == 0) {
		// SQUARE (Melee / Unarmed): 4 crisp architectural right-angle corner brackets.
		vec2 ap = abs(p);
		float s = 8.4 + recoil_px * 0.90;
		float arm = 3.8;
		float ht = 0.725;
		float d_h = sd_box(ap - vec2(s - arm * 0.5, s - ht), vec2(arm * 0.5, ht));
		float d_v = sd_box(ap - vec2(s - ht, s - arm * 0.5), vec2(ht, arm * 0.5));
		return min(d_h, d_v);
	}
	if (shape_type == 1) {
		// T_SHAPE (Automatic / SMG): 3 sleek inward-tapered bars (Left, Right, Bottom), top open.
		float gap = 4.2 + recoil_px * 1.05;
		float len = 5.6;
		float d_right = sd_taper_prong(p, 0.0, gap, len, 0.52, 0.92);
		float d_left = sd_taper_prong(p, 3.14159265, gap, len, 0.52, 0.92);
		float d_down = sd_taper_prong(p, 1.57079633, gap, len, 0.52, 0.92);
		return min(min(d_right, d_left), d_down);
	}
	if (shape_type == 2) {
		// BRACKET (Shotgun): opposing curved concave arcs (  ·  ).
		vec2 ap = abs(p);
		float r = 9.0 + recoil_px * 1.30;
		return sd_ring_arc_flat(ap, vec2(1.0, 0.0), radians(48.0), r, 0.80);
	}
	// CIRCLE (Pistol / Precision): 4 symmetric curved quadrant arcs with clean cardinal gaps.
	vec2 ap = abs(p);
	float r = 8.4 + recoil_px;
	return sd_ring_arc_flat(ap, vec2(0.70710678, 0.70710678), radians(31.0), r, 0.725);
}

float sd_center_pip(vec2 p) {
	if (shape_type == 0) {
		// Crisp 45-degree solid diamond for melee/unarmed.
		return (abs(p.x) + abs(p.y)) * 0.70710678 - 1.65;
	}
	return sd_circle(p, 1.42);
}

float coverage(float d) {
	float aa = max(fwidth(d) * 0.55, 0.002);
	return 1.0 - smoothstep(-aa, aa, d);
}

vec4 blend_over(vec4 dst, vec4 src) {
	float out_a = src.a + dst.a * (1.0 - src.a);
	vec3 out_rgb = (src.rgb * src.a + dst.rgb * dst.a * (1.0 - src.a)) / max(out_a, 0.0001);
	return vec4(out_rgb, out_a);
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * canvas_size;

	float d_outer = sd_weapon_outer(p);
	float d_pip = sd_center_pip(p);

	// Optional throw-aim outer diagonal accent chevrons.
	float d_throw = 1e5;
	if (throw_aim > 0.01) {
		vec2 rp = abs(rot2(p, 0.78539816));
		d_throw = sd_box(rp - vec2(12.2 + 2.0 * (1.0 - throw_aim), 0.0), vec2(1.4, 0.60));
	}

	float d_reload_track = 1e5;
	float d_reload_fill = 1e5;
	if (reloading > 0.5) {
		float reload_r = 12.2;
		float reload_ht = 0.85;
		d_reload_track = abs(length(p) - reload_r) - reload_ht;
		float prog = clamp(reload_progress, 0.0, 1.0);
		if (prog > 0.002) {
			float half_ang = prog * 3.14159265;
			float center_ang = -1.57079633 + half_ang;
			d_reload_fill = sd_ring_arc_flat(p, vec2(cos(center_ang), sin(center_ang)), half_ang, reload_r, reload_ht);
		}
	}

	vec4 out_col = vec4(0.0);

	// 1. Razor-thin dark contrast backing (disabled cleanly when outline_width <= 0.0).
	if (outline_width > 0.001) {
		float d_backing = min(min(d_outer, d_pip), min(d_throw, d_reload_fill)) - outline_width;
		float backing_cov = coverage(d_backing);
		out_col = blend_over(out_col, vec4(outline_color.rgb, outline_color.a * backing_cov));
	}

	// 2. Reload subtle track ring.
	if (reloading > 0.5) {
		float track_cov = coverage(d_reload_track);
		out_col = blend_over(out_col, vec4(reload_track_color.rgb, reload_track_color.a * track_cov));
	}

	// 3. Main weapon reticle (dims gently during reload so the sweep ring leads the eye).
	float outer_cov = coverage(d_outer);
	float outer_alpha = reticle_color.a * ((reloading > 0.5) ? 0.36 : 1.0);
	out_col = blend_over(out_col, vec4(reticle_color.rgb, outer_alpha * outer_cov));

	// 4. Optional throw-aim ticks.
	if (throw_aim > 0.01) {
		float throw_cov = coverage(d_throw);
		out_col = blend_over(out_col, vec4(reticle_color.rgb, reticle_color.a * throw_aim * throw_cov));
	}

	// 5. Active reload sweep arc.
	if (reloading > 0.5) {
		float reload_cov = coverage(d_reload_fill);
		out_col = blend_over(out_col, vec4(reload_fill_color.rgb, reload_fill_color.a * reload_cov));
	}

	// 6. Center aim pip (always full clarity on exact aim coordinate).
	float pip_cov = coverage(d_pip);
	out_col = blend_over(out_col, vec4(pip_color.rgb, pip_color.a * pip_cov));

	COLOR = out_col;
}
