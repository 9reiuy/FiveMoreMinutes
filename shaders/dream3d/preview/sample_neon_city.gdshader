shader_type spatial;
render_mode ambient_light_disabled, specular_disabled, fog_disabled;

uniform sampler2D city_void : filter_nearest, repeat_disable;
uniform vec2 city_origin;
uniform vec2 city_grid_size;
uniform sampler2D city_clearance : filter_linear, repeat_disable;
uniform bool soft_occlusion_enabled = true;
uniform vec3 map_origin;
uniform vec3 map_x_axis;
uniform vec3 map_z_axis;
uniform vec3 ray_origin_tl;
uniform vec3 ray_origin_dx;
uniform vec3 ray_origin_dy;
uniform vec3 ray_direction_tl;
uniform vec3 ray_direction_dx;
uniform vec3 ray_direction_dy;
uniform bool neon_surface = false;
uniform bool own_facade = false;
uniform bool height_fog_enabled = true;
uniform float height_fog_start = -2.0;
uniform float height_fog_end = -30.0;

varying vec3 face_normal;
varying float city_height;
varying float light_visibility;

void vertex() {
	face_normal = NORMAL;
	city_height = VERTEX.y;
}

void fragment() {
	// Preserve formal world depth; feather only foreground city overlap inward.
	vec3 ray_start = ray_origin_tl + ray_origin_dx * SCREEN_UV.x + ray_origin_dy * SCREEN_UV.y;
	vec3 ray = ray_direction_tl + ray_direction_dx * SCREEN_UV.x + ray_direction_dy * SCREEN_UV.y;
	float retention = 1.0;
	if (ray.y < -0.0001) {
		vec3 relative = ray_start + ray * (-ray_start.y / ray.y) - map_origin;
		vec2 cell = vec2(dot(relative, map_x_axis), dot(relative, map_z_axis));
		vec2 mask_uv = (cell - city_origin + vec2(0.5)) / city_grid_size;
		if (all(greaterThanEqual(mask_uv, vec2(0.0))) && all(lessThanEqual(mask_uv, vec2(1.0)))) {
			// Enclosed voids have an opaque 3D backing. Do not project an exterior
			// tower into them, even in the narrow floor-edge dissolve band.
			vec2 classification = texture(city_void, mask_uv).rg;
			if (classification.r < 0.5 && classification.g < 0.5) { discard; }
			if (soft_occlusion_enabled && !own_facade && texture(city_void, mask_uv).r < 0.5) {
				// The exterior remains SOLID. Only the overlap inside the playable
				// silhouette dissolves, beginning exactly at its half-cell boundary.
				float interior_depth = max(0.0, texture(city_clearance, mask_uv).r - 0.5);
				retention = 1.0 - smoothstep(0.0, 1.5, interior_depth);
			} else if ((!soft_occlusion_enabled || own_facade) && texture(city_void, mask_uv).r < 0.5) {
				discard;
			}
		}
	}
	// Stable 2x2 logical-pixel ordered dissolve: no frame-random sparkle,
	// alpha blend sorting, screen texture capture or new rendering pass.
	vec2 logical_pixel = floor(SCREEN_UV * vec2(640.0,360.0) / 2.0);
	vec2 b = mod(logical_pixel, 4.0);
	float threshold = (mod(b.x,2.0)*8.0 + mod(b.y,2.0)*12.0
		- mod(b.x,2.0)*mod(b.y,2.0)*16.0 + floor(b.x/2.0)*2.0
		+ floor(b.y/2.0)*3.0 - floor(b.x/2.0)*floor(b.y/2.0)*4.0 + 0.5) / 16.0;
	if (retention < threshold) { discard; }
	vec3 col = COLOR.rgb;
	if (!neon_surface) {
		vec2 p = floor(UV * 32.0);
		vec2 spacing = own_facade ? vec2(32.0, 96.0) : vec2(32.0, 64.0);
		vec2 part = mod(p, spacing);
		vec2 window_cell = floor(p / spacing);
		float seed = floor(COLOR.a * 255.0 + 0.5);
		float tone = mod(window_cell.x * 17.0 + window_cell.y * 37.0 + seed * 7.0, 13.0);
		col *= abs(face_normal.y) > 0.5 ? 0.48 : abs(face_normal.x) > 0.5 ? 0.55 : 0.74;
		if (abs(face_normal.y) < 0.5) {
			if (part.y < 2.0) { col *= 0.72; }
			else if (part.x >= 7.0 && part.x < 24.0 && part.y >= 14.0 && part.y < (own_facade ? 68.0 : 44.0)) {
				// Dark, dim and lit apartments; no blurred glow or per-window light objects.
				if (tone >= 9.0) { col = vec3(0.71, 0.54, 0.34) * (0.80 + tone * 0.018); }
				else if (tone >= 5.0) { col = vec3(0.32, 0.52, 0.59); }
				else if (tone >= 3.0) { col = vec3(0.20, 0.22, 0.31); }
				else { col *= 0.35; }
			}
		}
	}
	// Quantized vertical haze is locked to building height, not camera motion.
	float down = clamp((height_fog_start - city_height) / (height_fog_start - height_fog_end), 0.0, 1.0);
	down = down * down * (3.0 - 2.0 * down);
	down = height_fog_enabled ? floor(down * 16.0 + 0.5) / 16.0 : 0.0;
	float far_haze = own_facade ? 0.0 : clamp(length(VERTEX) / 260.0, 0.0, 0.42);
	float haze = max(down * 0.94, far_haze);
	light_visibility = 1.0 - haze;
	ALBEDO = col;
	EMISSION = mix(col, vec3(0.025, 0.035, 0.075), haze);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	// Only the four exterior light slots can reach the separate city layer.
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * max(dot(NORMAL, LIGHT), 0.0) * light_visibility / PI;
}
