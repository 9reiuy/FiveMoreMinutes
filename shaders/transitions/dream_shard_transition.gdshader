shader_type canvas_item;

// Multi-Scale Sharp Triangle Crystal Field Transition Shader
// Fully procedural 3x3 Cellular/Voronoi SDF crystal swarm
// Cold Indigo 16 Palette (#05060A Void, #111426 Deep Indigo, #313A70 Specular Edge)

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float width : hint_range(0.05, 0.8) = 0.35;
uniform vec2 shape_tiling = vec2(32.0, 18.0);
uniform int transition_mode : hint_range(0, 3) = 0; // 0: Bilateral (两翼向中央夹逼), 1: Diagonal (45°斜向撕裂), 2: Radial (四周向心聚拢), 3: Horizontal (横向推进)
uniform float noise_amount : hint_range(0.0, 0.4) = 0.14;
uniform bool invert = false;

// Cold Indigo Palette Contract
uniform vec4 primary_color : source_color = vec4(0.0196, 0.0235, 0.0392, 1.0); // #05060A Void
uniform vec4 secondary_color : source_color = vec4(0.0667, 0.0784, 0.1490, 1.0); // #111426 Refractive Body
uniform vec4 edge_color : source_color = vec4(0.1922, 0.2275, 0.4392, 1.0); // #313A70 Specular Edge
uniform float edge_thickness : hint_range(0.0, 0.15) = 0.05;

// Exact analytical distance to sharp equilateral triangle
float sd_triangle(vec2 p, float r) {
	const float k = 1.73205080757; // sqrt(3.0)
	p.x = abs(p.x) - r;
	p.y = p.y + r / k;
	if (p.x + k * p.y > 0.0) {
		p = vec2(p.x - k * p.y, -k * p.x - p.y) * 0.5;
	}
	p.x -= clamp(p.x, -2.0 * r, 0.0);
	return -length(p) * sign(p.y);
}

// Bounded, overflow-free pseudo-random hash for Voronoi cell jitter, scale, and rotation
vec4 hash4(vec2 p) {
	vec4 p4 = fract((vec4(p.xyxy) + vec4(127.1, 311.7, 269.5, 183.3)) * vec4(0.1031, 0.1030, 0.0973, 0.1099));
	p4 += dot(p4, p4.wzxy + vec4(33.33));
	return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

void fragment() {
	float p = invert ? (1.0 - progress) : progress;

	if (p <= 0.0001) {
		COLOR = vec4(0.0);
	} else if (p >= 0.9999) {
		COLOR = primary_color;
	} else {
		vec2 st = UV * shape_tiling;
		vec2 i_st = floor(st);

		float min_d = 999.0;
		float best_facet = 0.0;

		// 3x3 Cellular/Voronoi Neighbor Search across 9 crystal nuclei
		for (int dy = -1; dy <= 1; dy++) {
			for (int dx = -1; dx <= 1; dx++) {
				vec2 cell_pos = i_st + vec2(float(dx), float(dy));
				vec4 rnd = hash4(cell_pos);

				// Pseudo-random nucleus position within the cell
				vec2 nucleus_offset = vec2(0.5) + (rnd.xy - vec2(0.5)) * 0.6;
				vec2 nucleus_st = cell_pos + nucleus_offset;
				vec2 nucleus_uv = nucleus_st / shape_tiling;

				// Macro progression gradient calculation based on nucleus UV
				float grad = 0.0;
				if (transition_mode == 0) {
					// 0: Bilateral (两翼向中央夹逼)
					grad = abs(nucleus_uv.x - 0.5) * 2.0;
				} else if (transition_mode == 1) {
					// 1: Diagonal (45°斜向撕裂)
					grad = 1.0 - (nucleus_uv.x + nucleus_uv.y) * 0.5;
				} else if (transition_mode == 2) {
					// 2: Radial (四周向心聚拢)
					grad = distance(nucleus_uv, vec2(0.5)) * 1.4142;
				} else {
					// 3: Horizontal (横向推进)
					grad = 1.0 - nucleus_uv.x;
				}

				// Organic jitter along the wavefront
				float jitter = (rnd.x - 0.5) * noise_amount;
				grad = clamp(grad + jitter, 0.0, 1.0);

				// Wavefront cutoff: expands progressively towards interior
				float cell_cutoff = (grad - (1.0 - p * (1.0 + width))) / width;
				cell_cutoff = clamp(cell_cutoff, 0.0, 1.0);

				if (cell_cutoff > 0.001) {
					// Multi-scale shard sizing: 0.5x (splinter) to 1.8x (fracture plate)
					float shard_scale = mix(0.5, 1.8, rnd.z);

					// Dynamic expansion: starts sharp/small, expands to interlock into solid void
					float expansion = cell_cutoff + smoothstep(0.4, 1.0, cell_cutoff) * 0.85;
					float r = 0.95 * shard_scale * expansion;

					if (r > 0.001) {
						// Pseudo-random orientation
						float rot_angle = rnd.w * 6.28318530718;
						float ca = cos(rot_angle);
						float sa = sin(rot_angle);

						// Relative coordinate vector from nucleus to current pixel
						vec2 delta = st - nucleus_st;
						vec2 p_local = vec2(
							delta.x * ca + delta.y * sa,
							-delta.x * sa + delta.y * ca
						);

						// Needle sharpness aspect ratio variation
						float stretch = mix(0.85, 1.25, rnd.y);
						vec2 p_stretched = vec2(p_local.x, p_local.y * stretch);

						// Analytical signed distance to triangle
						float d = sd_triangle(p_stretched, r) * min(1.0, stretch);

						// Union of 9 distance fields: min_d = min(min_d, d)
						if (d < min_d) {
							min_d = d;
							best_facet = rnd.x;
						}
					}
				}
			}
		}

		// Color mapping contract
		if (min_d < 0.0) {
			if (min_d > -edge_thickness) {
				// Sharp specular crystal edge (only on outer frontier)
				COLOR = edge_color;
			} else {
				// Faceted refractive body behind the edge, fading to deep void
				float safe_thickness = max(edge_thickness * 2.5, 0.001);
				float depth = clamp((-min_d - edge_thickness) / safe_thickness, 0.0, 1.0);
				vec4 facet_color = mix(secondary_color, primary_color, best_facet * 0.4);
				COLOR = mix(facet_color, primary_color, depth);
			}
		} else {
			// Uncovered background (transparent)
			COLOR = vec4(0.0);
		}
	}
}
