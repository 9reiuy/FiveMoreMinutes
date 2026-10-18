shader_type spatial;
render_mode diffuse_lambert, cull_disabled;
uniform bool slice = false;
uniform float wall_height = 2.6;
varying vec3 sample_world;
void vertex() {
    if (slice) {
        vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
        p.y = wall_height * 0.3 + VERTEX.y;
        VERTEX = (inverse(MODEL_MATRIX) * vec4(p, 1.0)).xyz;
    }
    sample_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    // Geometry vertex colours encode the boundary of the complete wall union.
    // World-space joints never restart at individual one-cell segment origins.
    vec3 paint = COLOR.rgb;
    if (slice) { paint = vec3(0.64, 0.66, 0.65); }
    ALBEDO = paint;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
    EMISSION = paint * 0.35;
}
