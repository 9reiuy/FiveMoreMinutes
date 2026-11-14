shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_draw_never;
uniform sampler2D smoke_sheet : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D billow_noise : filter_linear_mipmap, repeat_enable;
varying vec4 particle;

vec3 authored_rgb(vec3 c) {
	return mix(c / 12.92, pow((c + vec3(.055)) / 1.055, vec3(2.4)), step(vec3(.04045), c));
}
void vertex() {
	particle = INSTANCE_CUSTOM;
	vec2 size = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	mat4 facing = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
	VERTEX.xy *= size;
}
void fragment() {
	float cs = cos(particle.b);
	float sn = sin(particle.b);
	vec2 local_uv = mat2(vec2(cs, sn), vec2(-sn, cs)) * (UV - .5) + .5;
	if (any(lessThan(local_uv, vec2(0.0))) || any(greaterThan(local_uv, vec2(1.0)))) discard;
	float opacity;
	float shade;
	vec3 ink;
	vec2 cell = vec2(mod(particle.a, 2.0), floor(particle.a / 2.0));
	if (particle.g < .5) {
		// Each particle retains one puff variant. Gentle UV advection makes its
		// density roll during its own lifetime; variants are not flipbook frames.
		vec2 warp = vec2(sin(local_uv.y * 13.0 + particle.r * 4.0),
			cos(local_uv.x * 11.0 - particle.r * 5.0)) * .025 * sin(particle.r * 3.14159);
		vec4 puff = textureLod(smoke_sheet, (cell + local_uv + warp) * .5, 1.0);
		opacity = smoothstep(.07, .70, puff.a);
		vec2 p = (local_uv - .5) * 2.0;
		vec3 normal = normalize(vec3(p.x, -p.y, sqrt(max(.02, 1.0 - dot(p, p)))));
		shade = .55 + .45 * max(dot(normal, normalize(vec3(-.4, .65, .8))), 0.0);
		float billow = texture(billow_noise, local_uv * .8 + vec2(particle.a * .19, -particle.r * .32)).r;
		float body = clamp((puff.a * .65 + puff.r * .35) * (.44 + billow * .90), 0.0, 1.0);
		vec3 base = authored_rgb(COLOR.rgb);
		vec3 edge = base * vec3(.85, .42, .22);
		vec3 core = mix(base, vec3(1.6, 1.05, .44), .42 * (1.0 - smoothstep(.0, .6, particle.r)));
		ink = mix(edge, core, smoothstep(.24, .96, body)) * shade;
		EMISSION = ink * .28 * (1.0 - smoothstep(.1, .65, particle.r));
	} else {
		vec4 puff = textureLod(smoke_sheet, (cell + local_uv) * .5, 1.0);
		opacity = smoothstep(.08, .62, puff.a);
		shade = .65 + .35 * puff.r;
		ink = authored_rgb(COLOR.rgb) * shade;
	}
	float alpha = opacity * COLOR.a;
	if (alpha < .005) discard;
	ALBEDO = ink;
	ALPHA = alpha;
}
