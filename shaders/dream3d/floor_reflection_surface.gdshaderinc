#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
// The existing mirror is an LDR ViewportTexture. Select its sRGB texture
// view in the linear 3D consumer; alpha stays an unconverted coverage value.
uniform sampler2D sample_reflection_texture : source_color, filter_linear, repeat_disable;
#else
uniform sampler2D sample_reflection_texture : filter_linear, repeat_disable;
#endif
uniform mat4 sample_reflection_view;
uniform mat4 sample_reflection_projection;
uniform vec2 sample_reflection_size = vec2(320.0, 180.0);
uniform float sample_reflection_strength = 0.0;
uniform float sample_reflection_blur = 1.0;
uniform float sample_surface_gloss = 0.0;
uniform float sample_surface_roughness = 0.7;
uniform bool sample_surface_enabled = true;
// Comparison switch for the approved-sample delivery, never a global setting.
uniform bool sample_highlight_revision = true;

// These values are initialized from continuous world coordinates at the
// start of fragment(), before discard/lighting branches, once per pixel.
varying float sample_grain_retained;
varying float sample_cluster_retained;

float sample_surface_grain(vec2 point, float retained) {
    vec2 p = floor(point * 32.0);
    return mix(0.5, fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453), retained);
}

vec3 sample_surface_reflection(vec3 world, vec3 floor_colour) {
	if (!sample_surface_enabled || sample_reflection_strength <= 0.0) { return vec3(0.0); }
	vec4 clip = sample_reflection_projection * sample_reflection_view * vec4(world, 1.0);
	if (clip.w <= 0.0) { return vec3(0.0); }
	vec2 uv = clip.xy / clip.w * 0.5 + 0.5;
	uv.y = 1.0 - uv.y;
	vec2 edge = min(uv, 1.0 - uv);
	float border = smoothstep(0.0, 0.025, min(edge.x, edge.y));
	if (min(edge.x, edge.y) <= 0.0) { return vec3(0.0); }
	vec2 step_uv = sample_reflection_blur / sample_reflection_size;
	vec3 colour = texture(sample_reflection_texture, uv).rgb * 0.28;
	colour += texture(sample_reflection_texture, uv + vec2(step_uv.x, 0.0)).rgb * 0.12;
	colour += texture(sample_reflection_texture, uv - vec2(step_uv.x, 0.0)).rgb * 0.12;
	colour += texture(sample_reflection_texture, uv + vec2(0.0, step_uv.y)).rgb * 0.12;
	colour += texture(sample_reflection_texture, uv - vec2(0.0, step_uv.y)).rgb * 0.12;
	colour += texture(sample_reflection_texture, uv + step_uv).rgb * 0.055;
	colour += texture(sample_reflection_texture, uv - step_uv).rgb * 0.055;
	colour += texture(sample_reflection_texture, uv + vec2(step_uv.x, -step_uv.y)).rgb * 0.055;
	colour += texture(sample_reflection_texture, uv + vec2(-step_uv.x, step_uv.y)).rgb * 0.055;
	float grain = mix(0.88, 1.0, sample_surface_grain(world.xz, sample_grain_retained));
	float texture_mask = smoothstep(0.06, 0.42, dot(floor_colour, vec3(0.299, 0.587, 0.114)));
	return colour * sample_reflection_strength * grain * texture_mask * border;
}

vec3 sample_surface_highlight(vec3 normal, vec3 light_direction, vec3 view_direction,
		vec3 light_colour, float attenuation, vec3 world, vec3 floor_colour) {
	if (!sample_surface_enabled || sample_surface_gloss <= 0.0) { return vec3(0.0); }
	vec3 half_vector = normalize(light_direction + view_direction);
	float alignment = max(dot(normalize(normal), half_vector), 0.0);
	float grain = sample_surface_grain(world.xz, sample_grain_retained);
	if (!sample_highlight_revision) {
		float old_lobe = pow(alignment, mix(96.0, 7.0, sample_surface_roughness));
		return light_colour * attenuation * old_lobe * mix(0.72, 1.0, grain) * sample_surface_gloss / PI;
	}
	// Broad frosted reflection with a brighter core. Keep the light's real
	// attenuation/shadow instead of painting an emissive patch onto the floor.
	float broad = pow(alignment, mix(26.0, 4.0, sample_surface_roughness));
	float core = pow(alignment, mix(78.0, 14.0, sample_surface_roughness));
	float polish = 1.0 - smoothstep(0.60, 0.85, sample_surface_roughness);
	float cluster = sample_surface_grain(floor(world.xz * 4.0) / 32.0, sample_cluster_retained);
	// World-anchored microfacets: no TIME noise or random shimmering. Camera
	// and light motion change the glints while the surface grain stays put.
	vec2 slope = vec2(grain, sample_surface_grain(world.xz + vec2(13.3, 7.1), sample_grain_retained)) - 0.5;
	vec3 facet = normalize(normal + vec3(slope.x, 0.0, slope.y) * mix(0.42, 0.16, polish));
	float glint = pow(max(dot(facet, half_vector), 0.0), 110.0);
	glint *= smoothstep(0.76, 0.94, grain) * mix(0.45, 1.0, cluster);
	float texture_mask = mix(0.35, 1.0, smoothstep(0.04, 0.38, dot(floor_colour, vec3(0.299, 0.587, 0.114))));
	float response = broad * mix(1.7, 3.4, polish) * mix(0.62, 1.05, grain)
		+ core * 1.8 * polish + glint * 7.0 * polish;
	return light_colour * attenuation * response * texture_mask * sample_surface_gloss * 0.32 / PI;
}

// Native office mirror uses transparent coverage and linear radiance.
uniform bool sample_native_reflection = false;
vec4 sample_mirror_reflection(vec3 world, vec3 floor_colour) {
    if (!sample_surface_enabled || sample_reflection_strength <= 0.0) return vec4(0.0);
    vec4 clip=sample_reflection_projection*sample_reflection_view*vec4(world,1.0);
    if(clip.w<=0.0) return vec4(0.0);
    vec2 uv=clip.xy/clip.w*0.5+0.5; uv.y=1.0-uv.y;
    float edge=min(min(uv.x,uv.y),min(1.0-uv.x,1.0-uv.y));
    if(edge<=0.0) return vec4(0.0);
    vec2 step_uv=sample_reflection_blur/sample_reflection_size;
    vec4 reflected=texture(sample_reflection_texture,uv)*0.5;
    reflected+=texture(sample_reflection_texture,uv+vec2(step_uv.x,0.0))*0.125;
    reflected+=texture(sample_reflection_texture,uv-vec2(step_uv.x,0.0))*0.125;
    reflected+=texture(sample_reflection_texture,uv+vec2(0.0,step_uv.y))*0.125;
    reflected+=texture(sample_reflection_texture,uv-vec2(0.0,step_uv.y))*0.125;
    float strength=sample_reflection_strength*smoothstep(0.0,0.015,edge);
    strength*=mix(0.72,1.0,smoothstep(0.02,0.35,dot(floor_colour,vec3(0.299,0.587,0.114))));
    // Premultiplied reflected radiance plus matching diffuse energy reduction.
    // Transparent background contributes neither black paint nor a bright patch.
    return vec4(reflected.rgb*strength,reflected.a*strength);
}
