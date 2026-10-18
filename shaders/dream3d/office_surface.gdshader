shader_type spatial;
render_mode diffuse_burley;
uniform vec4 base_color : source_color = vec4(.35, .39, .43, 1.0);
uniform int pattern = 0;
varying vec3 world_position;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    vec2 p = world_position.xz;
    float shade = 1.0;
    if (pattern == 1) {
        // Carpet: low-contrast broad woven grain, no photographic noise.
        shade = .96 + .04 * step(.5, fract(p.x * 12.0)) * step(.5, fract(p.y * 12.0));
    } else if (pattern == 2 || pattern == 4) {
        float size = pattern == 2 ? .5 : 1.0;
        vec2 tile = fract(p / size);
        float seam = step(.025, tile.x) * step(.025, tile.y);
        shade = mix(.72, 1.0, seam);
    } else if (pattern == 3) {
        vec2 plank = fract(vec2(p.x * 2.0, p.y * .35));
        shade = mix(.8, 1.0, step(.025, plank.x) * step(.015, plank.y));
    }
    ALBEDO = base_color.rgb * shade;
    ROUGHNESS = .9;
    SPECULAR = .12;
}
void light() {
    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * max(dot(NORMAL, LIGHT), 0.0) / PI;
}
