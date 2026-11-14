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
uniform bool distance_focus_enabled = true;
uniform bool own_facade = false;
uniform bool pilot_geometry = false;
uniform bool street_geometry = false;
uniform bool baked_source = false;
uniform bool baked_building = false;
uniform bool baked_has_albedo = false;
uniform bool baked_has_emission = false;
uniform sampler2D baked_albedo : source_color,filter_nearest,repeat_disable;
uniform sampler2D baked_emission : source_color,filter_nearest,repeat_disable;
uniform vec4 baked_color : source_color = vec4(1.0);
uniform vec3 baked_glow : source_color = vec3(1.0);
uniform float baked_glow_gain = 0.7;
uniform float baked_surface_gain = 1.0;
uniform float baked_glow_cutoff = 0.0;
uniform float baked_glow_limit = 1.7;
uniform vec3 baked_neon_tint = vec3(1.0);

uniform bool architectural_windows = false;
uniform float architectural_family = 0.0;
uniform bool own_reference_material = false;
uniform vec3 own_moon_direction = vec3(0.2,0.8,0.4);
uniform vec3 own_moon_color : source_color = vec3(0.72,0.80,0.86);
uniform float own_moon_energy = 0.0;

uniform bool pollution_air_enabled = true;
uniform vec3 city_eye;

uniform vec2 city_air_ad_anchor0=vec2(72.41006,33.45109);
uniform vec2 city_air_ad_anchor1=vec2(73.15544,40.47069);
uniform vec2 city_air_ad_anchor2=vec2(73.21996,55.17027);
uniform vec2 city_air_ad_anchor3=vec2(42.32,19.36131);
// DEPTH01_SHARED_AIR_BEGIN
// Fixed city-space air: three depth ranges, no time/screen noise or extra pass.
float depth01_pool(vec2 point,vec2 center,vec2 radius) {
 vec2 q=(point-center)/radius;
 return exp(-0.5*dot(q,q));
}
vec3 city_air_color(vec3 eye, vec3 direction) {
 vec3 ray=normalize(direction);
 float denominator=max(-ray.y,0.08);
 vec2 far_xz=eye.xz+ray.xz*max(0.0,(eye.y+58.0)/denominator);
 vec2 lower_xz=eye.xz+ray.xz*max(0.0,(eye.y+41.0)/denominator);
 float layer=0.5+0.26*sin(far_xz.x*0.024+far_xz.y*0.011)
  +0.18*sin(far_xz.y*0.041-far_xz.x*0.008);
 vec3 air=mix(vec3(0.130,0.175,0.195),vec3(0.182,0.228,0.244),clamp(layer,0.0,1.0));
 // Broad weak scattered light below existing host16/5/6/own106; no new emitter.
 air+=depth01_pool(lower_xz,city_air_ad_anchor0,vec2(10.0,15.0))*vec3(0.004,0.025,0.029);
 air+=depth01_pool(lower_xz,city_air_ad_anchor1,vec2(11.0,12.0))*vec3(0.008,0.020,0.030);
 air+=depth01_pool(lower_xz,city_air_ad_anchor2,vec2(9.0,12.0))*vec3(0.020,0.005,0.005);
 air+=depth01_pool(lower_xz,city_air_ad_anchor3,vec2(10.0,13.0))*vec3(0.007,0.020,0.025);
 float corridor=exp(-0.5*pow(far_xz.y/13.0,2.0))
  *(1.0-smoothstep(17.0,38.0,abs(far_xz.x-34.0)));
 float east=exp(-0.5*pow((far_xz.x-90.0)/13.0,2.0))
  *(1.0-smoothstep(18.0,42.0,abs(far_xz.y-42.0)));
 return air*(1.0-0.055*max(corridor,east));
}
float city_air_extinction(vec3 eye,vec3 point) {
 float h=max(0.0,-point.y);
 float lower=smoothstep(14.0,28.0,h);
 float depth=max(0.0,h-6.0)/40.0;
 float depth4=depth*depth*depth*depth;
 float broad=clamp(0.5+0.26*sin(point.x*0.024+point.z*0.011)
  +0.18*sin(point.z*0.031-point.x*0.008),0.0,1.0);
 float height_mass=mix(8.0,mix(3.6,5.0,broad),lower)*depth4;
 float distance=length(point-eye);
 float old_distance=pow(max(0.0,distance-30.0)/92.0,1.3)*1.15;
 float layered_distance=pow(max(0.0,distance-30.0)/62.0,1.3)*1.10;
 // Street -42.91 and source ends -46/-48 remain fully sealed in deep air.
 float seal=smoothstep(35.0+2.0*broad,43.0,h);
 float mass=height_mass+mix(old_distance,layered_distance,lower)+12.0*seal*seal;
 return 1.0-exp(-min(20.0,mass));
}
// DEPTH01_SHARED_AIR_END

uniform float hidden_tower_tag = -1.0;
uniform float facade_light_gain : hint_range(0.0, 1.0) = 1.0;
uniform bool height_fog_enabled = true;
uniform float height_fog_start = -2.0;
uniform float height_fog_end = -30.0;

varying vec3 face_normal;
varying vec2 panel_position;
varying vec2 tower_tag;
varying float city_height;
varying vec2 city_xz;
varying float light_visibility;

#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
vec3 city_srgb_to_linear(vec3 encoded) {
	return mix(encoded / 12.92, pow((encoded + 0.055) / 1.055, vec3(2.4)),
		step(vec3(0.04045), encoded));
}
#endif

float panel_band(float value, float start, float end, float radius) {
	return clamp((min(value + radius, end) - max(value - radius, start)) / (2.0 * radius), 0.0, 1.0);
}

float facade_hash(vec2 key) {
	vec3 p = fract(vec3(key.x, key.y, key.x) * vec3(0.1031, 0.11369, 0.13787));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}


vec3 integrated_facade(out vec3 emission, out float roughness) {
 // World units remain fixed when a prototype is stretched into another highrise.
 float floor_h = mix(2.8,3.05,architectural_family);
 float bay_w = mix(1.45,1.22,architectural_family);
 float along = abs(face_normal.x)>abs(face_normal.z) ? city_xz.y : city_xz.x;
 vec2 p=vec2(along,city_height);
 vec2 aa=max(fwidth(p)*0.52,vec2(0.015625));
 vec2 snapped=floor(p*32.0)/32.0;
 float seed=floor(tower_tag.x*997.0);
 float floor_id=floor((snapped.y+1.2)/floor_h);
 float stagger=mod(floor(floor_id/4.0),2.0)*bay_w*0.5;
 float bay_id=floor((snapped.x+stagger)/bay_w);
 vec2 cell=vec2(mod(snapped.x+stagger,bay_w),mod(snapped.y+1.2,floor_h));
 float group=facade_hash(vec2(floor(bay_id/4.0)+seed,floor(floor_id/3.0)));
 float occupied=facade_hash(vec2(bay_id+seed*7.0,floor_id+seed));
 float available=step(0.27,group);
 float window_w=mix(0.86,0.82,architectural_family);
 float window_h=mix(0.94,1.18,architectural_family);
 vec2 lo=vec2((bay_w-window_w)*0.5,0.92);
 vec2 hi=lo+vec2(window_w,window_h);
 float pane=panel_band(cell.x,lo.x,hi.x,aa.x)*panel_band(cell.y,lo.y,hi.y,aa.y)*available;
 float aperture=panel_band(cell.x,lo.x-0.08,hi.x+0.08,aa.x)*panel_band(cell.y,lo.y-0.08,hi.y+0.08,aa.y)*available;
 float rail=panel_band(cell.y,0.07,0.18,aa.y);
 float pier=panel_band(cell.x,0.025,0.085,aa.x);
 float vertical=1.0-smoothstep(0.025,0.10,abs(face_normal.y));
 float face=max(abs(face_normal.x),abs(face_normal.z));
 float wall=vertical*smoothstep(0.94,0.985,face);
 float grain=facade_hash(floor(snapped*vec2(7.0,17.0)));
 vec3 metal=vec3(0.046,0.063,0.070)*(0.95+0.07*grain);
 metal*=1.0-0.20*rail-0.11*pier;
 metal=mix(metal,vec3(0.029,0.042,0.048),clamp(aperture-pane,0.0,1.0)*0.70);
 vec3 glass=vec3(0.008,0.016,0.021)*(0.82+0.22*occupied);
 metal=mix(metal,glass,pane*0.90);
 float room=step(0.59,group)*step(0.42,occupied);
 float focal=room*step(0.81,facade_hash(vec2(floor(bay_id/2.0)+seed*3.0,floor(floor_id/2.0)+9.0)));
 float room_variation=facade_hash(vec2(bay_id+seed,floor_id+31.0));
 float interior=mix(0.10+0.22*room_variation,0.90+1.10*room_variation,focal);
 float far_detail=1.0-smoothstep(0.35,1.2,max(aa.x,aa.y));
 float cell_light=mix(0.018,room*interior,far_detail);
 float blind=1.0-0.28*panel_band(cell.y,lo.y+window_h*0.64,lo.y+window_h*0.72,aa.y);
 float warm=focal*step(0.84,facade_hash(vec2(floor_id+seed,bay_id-2.0)));
 emission=mix(vec3(0.69,0.88,1.0),vec3(1.0,0.94,0.80),warm)*pane*cell_light*blind*wall;
 roughness=mix(0.90,0.72,pane);
 return mix(vec3(0.043,0.059,0.065),metal,wall);
}

void own_reference_finish(vec4 vertex_color, out vec3 surface, out vec3 room_light, out float roughness) {
 // Original mesh colors identify existing steel members and real window apertures.
 // This is an original reference reconstruction; no vendor textures are used.
 float value=dot(vertex_color.rgb,vec3(0.2126,0.7152,0.0722));
 float is_glass=max(step(0.001,vertex_color.a),step(value,0.235)*step(vertex_color.r*1.55,vertex_color.b));
 vec2 p=floor(panel_position*32.0)/32.0;
 float brushed=facade_hash(floor(p*vec2(5.0,31.0)));
 float grade=smoothstep(0.26,0.48,value);
 vec3 steel=mix(vec3(0.070,0.082,0.090),vec3(0.175,0.190,0.200),grade)*(0.965+0.065*brushed);
 vec2 joints=mod(p+vec2(0.41,0.23),vec2(1.85,2.7));
 float seam=max(1.0-smoothstep(0.025,0.065,joints.x),1.0-smoothstep(0.025,0.065,joints.y));
 steel*=1.0-0.28*seam;
 vec3 glass=vec3(0.009,0.018,0.023)*(0.91+0.12*brushed);
 surface=mix(steel,glass,is_glass);
 room_light=vec3(0.072,0.105,0.122)*vertex_color.a*(0.48+0.29*facade_hash(floor(p/vec2(1.8,2.8))));
 roughness=mix(0.89-0.12*grade,0.66+0.04*brushed,is_glass);
}

float lit_interior(vec2 p, vec2 low, vec2 high, vec2 radius) {
	float glass = panel_band(p.x, low.x, high.x, radius.x) * panel_band(p.y, low.y, high.y, radius.y);
	vec2 soft = radius + vec2(0.20, 0.13);
	float halo = panel_band(p.x, low.x - 0.06, high.x + 0.06, soft.x)
		* panel_band(p.y, low.y - 0.07, high.y + 0.07, soft.y);
	return glass * 0.81 + halo * 0.16;
}

vec3 main_shell_color(vec2 p, vec2 aa, float plate_grade, out vec3 window_glow) {
	float tier = floor((p.y + 0.44) / 3.35);
	float level = mod(p.y + 0.44, 3.35);
	float stagger = facade_hash(vec2(tier, 3.0)) * 2.7;
	float bay = floor((p.x + stagger) / 6.4);
	float within_bay = mod(p.x + stagger, 6.4);
	float plate = facade_hash(vec2(bay, tier));
	float join = panel_band(within_bay, 0.0, 0.09, aa.x);
	float plinth = panel_band(level, 0.14, 0.42, aa.y);
	float bevel = panel_band(level, 0.42, 0.54, aa.y);
	vec3 metal = mix(vec3(0.40, 0.47, 0.59), vec3(0.53, 0.58, 0.68), plate_grade) * (0.86 + 0.18 * plate);
	metal *= 1.0 - 0.30 * max(plinth, join);
	metal += bevel * vec3(0.057, 0.069, 0.087);

	float glass_zone = max(step(0.42, facade_hash(vec2(floor((tier + 1.0) / 2.0), 7.2))),
		1.0 - step(0.5, abs(tier + 1.0)));
	float glazing = glass_zone * panel_band(level, 1.12, 1.77, aa.y);
	float glass_lip = glass_zone * panel_band(level, 1.77, 1.88, aa.y);
	metal = mix(metal, vec3(0.20, 0.28, 0.41), glazing);
	metal += glass_lip * vec3(0.045, 0.069, 0.10);
	float occupancy = facade_hash(vec2(bay + 18.4, tier));
	float lit = glass_zone * smoothstep(0.68, 0.91, occupancy)
		* lit_interior(vec2(within_bay, level), vec2(1.0, 1.22), vec2(3.1 + 1.3 * plate, 1.66), aa);
	window_glow = vec3(0.44, 0.62, 0.88) * lit * 0.68;
	return metal;
}

vec3 tower_color(vec2 p, vec2 radius, float seed, float model, float roof_gap, out vec3 window_glow) {
	float tone = facade_hash(vec2(seed * 47.0, 12.6));
	float brightness = 0.79 + 0.33 * facade_hash(vec2(seed * 59.0, 9.8));
	vec3 alloy = mix(vec3(0.44, 0.51, 0.65), vec3(0.53, 0.54, 0.65), tone) * brightness;
	vec3 light_color = mix(vec3(0.51, 0.73, 1.0), vec3(0.80, 0.85, 1.0), tone);
	float crown = panel_band(roof_gap, 0.25, 0.49, radius.y);

	if (model < 0.5 || (model >= 1.5 && model < 2.5)) {
		// Cold vertical slits in the blade towers. Leave entire shafts dark.
		float spacing = 2.15 + seed * 0.53;
		float across = mod(p.x + seed * 3.3, spacing);
		float column = floor((p.x + seed * 3.3) / spacing);
		float groove = panel_band(across, 0.37, 0.75, radius.x);
		float shaft = floor((p.y + seed * 2.0) / 8.7);
		float y = mod(p.y + seed * 2.0, 8.7);
		float occupancy = facade_hash(vec2(column + seed * 21.0, shaft));
		float lit = smoothstep(0.53, 0.83, occupancy)
			* lit_interior(vec2(across, y), vec2(0.45, 1.10), vec2(0.66, 3.7 + occupancy * 2.3), radius);
		window_glow = light_color * (0.77 * lit + 0.11 * crown);
		return alloy * (0.76 - 0.36 * groove);
	}
	if (model >= 2.5 && model < 3.5) {
		// The Crown's appendages and cantilever carry the silhouette.
		float level = mod(p.y + seed * 4.1, 6.9);
		float deck = floor((p.y + seed * 4.1) / 6.9);
		float edge = panel_band(level, 0.15, 0.46, radius.y);
		float housing = panel_band(level, 4.42, 5.63, radius.y);
		float bay = floor((p.x + seed * 5.0) / 7.4);
		float occupancy = facade_hash(vec2(bay + 9.0 * seed, deck));
		float lit = smoothstep(0.49, 0.86, occupancy)
			* lit_interior(vec2(mod(p.x + seed * 5.0, 7.4), level),
				vec2(0.86, 4.67), vec2(2.5 + occupancy * 1.7, 5.39), radius);
		window_glow = mix(light_color, vec3(0.61, 0.67, 1.0), 0.40) * (0.92 * lit + 0.16 * crown);
		return alloy * (0.96 - 0.21 * edge - 0.24 * housing);
	}

	// Terraces and slabs have staggered horizontal ribbons with grouped rooms.
	float interval = 3.5 + seed * 1.2;
	float level = mod(p.y + seed * 3.8, interval);
	float deck = floor((p.y + seed * 3.8) / interval);
	float glass = panel_band(level, 0.92, 1.88, radius.y);
	float beam = panel_band(level, 0.22, 0.38, radius.y);
	float bay_width = 4.9 + seed * 3.6;
	float along = p.x + seed * 7.1 + deck * 1.27;
	float bay = floor(along / bay_width);
	float occupancy = facade_hash(vec2(bay + seed * 17.0, deck));
	float lit = smoothstep(0.48, 0.86, occupancy)
		* lit_interior(vec2(mod(along, bay_width), level), vec2(0.77, 1.05),
			vec2(2.49 + occupancy * 1.62, 1.72), radius);
	window_glow = light_color * (lit * 0.93 + crown * 0.09);
	return mix(alloy + beam * vec3(0.048, 0.061, 0.078), alloy * 0.47, glass);
}


void vertex() {
	face_normal = NORMAL;
	city_height = VERTEX.y;
	city_xz = VERTEX.xz;
	vec2 planar = abs(NORMAL.y) > 0.52 ? VERTEX.xz
		: abs(NORMAL.x) > 0.52 ? VERTEX.zy : VERTEX.xy;
	panel_position = planar;
	tower_tag = UV2;
}

void fragment() {
	light_visibility = 1.0;
	if (hidden_tower_tag >= 0.0 && abs(tower_tag.x - hidden_tower_tag) < 0.000002) { discard; }
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
	float down = 1.0 - smoothstep(height_fog_end, height_fog_start, city_height);
	down = height_fog_enabled ? down : 0.0;
	float eye_distance = length(VERTEX);
	// Exterior air is evaluated in city/world height and distance, never over the room.
	vec3 air_color = mix(vec3(0.078, 0.115, 0.145), vec3(0.142, 0.185, 0.178), down);
	float corridor_air = exp(-0.5 * pow(city_xz.y / 8.0, 2.0))
		* (1.0 - smoothstep(11.0, 24.0, abs(city_xz.x - 30.0)));
	float east_air = exp(-0.5 * pow((city_xz.x - 90.0) / 8.0, 2.0))
		* (1.0 - smoothstep(12.0, 27.0, abs(city_xz.y - 42.0)));
	float local_air = max(corridor_air, east_air) * down;
	air_color = mix(air_color, vec3(0.235, 0.205, 0.157), local_air * 0.31);
	air_color *= mix(0.94, 1.14, smoothstep(40.0, 125.0, eye_distance));

	if (baked_source) {
		// Actual source Block node output was baked offline, never evaluated per frame.
		vec3 diffuse = baked_color.rgb * (baked_has_albedo ? texture(baked_albedo,UV).rgb : vec3(1.0));
		vec3 emitter_sample = baked_has_emission ? texture(baked_emission,UV).rgb : vec3(0.0);
        float emitter_mask=1.0;
        if (baked_glow_cutoff>0.0) {
            float emitter_peak=max(max(emitter_sample.r,emitter_sample.g),emitter_sample.b);
            emitter_mask=smoothstep(baked_glow_cutoff*0.7,baked_glow_cutoff*1.3,emitter_peak);
        }
        vec3 glow = emitter_sample*baked_glow*baked_glow_gain*baked_neon_tint*emitter_mask;
        float material_roughness=1.0;
        if (architectural_windows) {
            vec3 window_light;
            diffuse=integrated_facade(window_light,material_roughness);
            glow=window_light;
        }
		float shade = baked_building ? (0.36+0.12*max(-face_normal.x,0.0)+0.28*max(face_normal.z,0.0)+0.56*max(face_normal.y,0.0)) : (0.68+0.16*max(-face_normal.x,0.0)+0.15*max(face_normal.z,0.0)+0.28*max(face_normal.y,0.0));
		ALBEDO = diffuse*0.05;
		float glow_peak=max(max(glow.r,glow.g),glow.b);
        if (glow_peak>baked_glow_limit) { glow*=baked_glow_limit/max(glow_peak,0.00001); }
        EMISSION = diffuse*shade*baked_surface_gain+glow;
		ROUGHNESS = material_roughness;
		SPECULAR = 0.0;
	} else if (street_geometry) {
		vec3 encoded = COLOR.rgb;
  if (city_height < -42.93) {
   // Continuous service-ground colour, authored at the same scale as roads.
   float lot=facade_hash(floor(city_xz/13.0));
   float lane=max(1.0-smoothstep(4.2,10.5,abs(city_xz.y)),
    1.0-smoothstep(3.9,10.0,abs(city_xz.x-90.0)));
   encoded=mix(vec3(0.163,0.214,0.259)*(0.95+0.10*lot),vec3(0.19,0.24,0.30),lane);
  }
		#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
			if (!OUTPUT_IS_SRGB) { encoded = city_srgb_to_linear(encoded); }
		#endif
		vec3 lit_street = encoded * COLOR.a;
		if (pollution_air_enabled) {
			vec3 air_linear = air_color;
			#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
				if (!OUTPUT_IS_SRGB) { air_linear = city_srgb_to_linear(air_color); }
			#endif
			lit_street = mix(lit_street, air_linear, 0.11 + local_air * 0.04);
		}
		EMISSION = lit_street;
		ALBEDO = vec3(0.0);
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	} else if (pilot_geometry) {
        if (own_facade && own_reference_material) {
            vec3 surface;
            vec3 room_light;
            float material_roughness;
            own_reference_finish(COLOR,surface,room_light,material_roughness);
            float diffuse_light=max(dot(normalize(face_normal),normalize(own_moon_direction)),0.0);
            vec3 illumination=vec3(0.20,0.23,0.25)+own_moon_color*(0.38*clamp(own_moon_energy,0.0,1.8)*diffuse_light);
            EMISSION=surface*illumination+room_light;
            ALBEDO=surface*0.08;
            ROUGHNESS=material_roughness;
            SPECULAR=0.0;
        } else {
		// Alpha carries vertex-authored emission intensity; the mesh is opaque.
		float material_shade = 0.74 + 0.10 * max(-face_normal.x, 0.0)
			+ 0.10 * max(face_normal.z, 0.0) + 0.25 * max(face_normal.y, 0.0);
		vec2 panel = panel_position;
		float stain = facade_hash(floor(panel * vec2(1.35, 0.31)));
		float grain = facade_hash(floor(panel * 19.0));
		float age = 0.92 + 0.14 * stain + 0.06 * grain;
		float mist = max(down * 0.57, smoothstep(34.0, 100.0, eye_distance) * 0.56);
		vec3 masonry = mix(COLOR.rgb * material_shade * age, (pollution_air_enabled ? air_color : vec3(0.093, 0.128, 0.178)), mist);
		vec3 glass = COLOR.rgb * (0.93 + 0.11 * smoothstep(-0.54, 0.54, UV.y));
		#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
			if (!OUTPUT_IS_SRGB) {
				masonry = city_srgb_to_linear(masonry);
				glass = city_srgb_to_linear(glass);
			}
		#endif
		float energy = COLOR.a * (1.56 - 0.66 * mist);
		EMISSION = masonry + glass * energy;
		ALBEDO = vec3(0.0);
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;

        }
	} else {
		vec2 aa = max(fwidth(panel_position) * 0.54, vec2(0.018));
		float defocus = max(smoothstep(13.0, 43.0, eye_distance), down * 0.64);
		vec2 focus_radius = aa + vec2(0.64, 0.41) * defocus * float(distance_focus_enabled);
		float roof = smoothstep(0.43, 0.78, abs(face_normal.y));
		float facing = clamp(0.85 + 0.19 * face_normal.z - 0.13 * face_normal.x, 0.57, 1.10);
		float model = floor(COLOR.a * 4.0 + 0.5);
		vec3 col = COLOR.rgb;
		vec3 window_glow = vec3(0.0);
		if (own_facade) {
			vec3 wall = main_shell_color(panel_position, aa, COLOR.a, window_glow);
			col = mix(wall, mix(vec3(0.31, 0.38, 0.50), vec3(0.50, 0.54, 0.65), COLOR.a), roof);
		} else if (tower_tag.x >= 0.0) {
			vec3 wall = tower_color(panel_position, focus_radius, tower_tag.x, model, tower_tag.y - city_height, window_glow);
			// Existing roof decks and support geometry supply the visible relief.
			vec3 top = vec3(0.44, 0.49, 0.61) * (0.91 + 0.20 * tower_tag.x);
			col = mix(wall, top, roof);
		}
		col *= mix(facing, 0.95, roof);
		float haze = own_facade ? down * 0.74 : max(down * 0.83, smoothstep(16.0, 77.0, eye_distance) * 0.69);
		light_visibility = 1.0 - haze;
		ALBEDO = col * facade_light_gain;
		// The windows have a surface emission channel. The diffuse
		// material, scene lights and their culling masks stay independent.
		vec3 night = mix(col, (pollution_air_enabled ? air_color : vec3(0.096, 0.120, 0.181)), haze) * facade_light_gain;
		// Far source variants use a few cold groups large enough to survive depth blur.
		float light_stock = mix(1.13, 1.72, facade_hash(vec2(tower_tag.x * 91.0, 31.3)));
		vec3 windows = window_glow * (1.0 - roof) * (1.0 - haze * 0.66) * min(facade_light_gain * 3.6, 1.0) * light_stock;
		EMISSION = min(night + windows, vec3(0.98));
		#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
			// COLOR and the window/haze constants above are authored display
			// codes. Match the Compatibility albedo/emission decode boundary,
			// after the existing shading pattern and facade gain.
			if (!OUTPUT_IS_SRGB) {
				ALBEDO = city_srgb_to_linear(ALBEDO);
				EMISSION = city_srgb_to_linear(EMISSION);
			}
		#endif
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	}
 // Extinguish the complete outgoing surface, including emission. A bright
 // window cannot retain a silhouette after its host has entered dense air.
 if (height_fog_enabled && pollution_air_enabled) {
  vec3 point = vec3(city_xz.x,city_height,city_xz.y);
  float extinction = city_air_extinction(city_eye,point);
  vec3 air = city_air_color(city_eye,point-city_eye);
  #if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
   if (!OUTPUT_IS_SRGB) { air=city_srgb_to_linear(air); }
  #endif
  EMISSION=mix(EMISSION,air,extinction);
  ALBEDO*=1.0-extinction;
  light_visibility*=1.0-extinction;
 }
}

void light() {
	// Only the four exterior light slots can reach the separate city layer.
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * max(dot(NORMAL, LIGHT), 0.0) * light_visibility / PI;
}
