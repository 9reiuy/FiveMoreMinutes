shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

uniform vec4 vision_origin_range;
varying vec3 vision_world_position;

void vertex() {
    vision_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    // Depth testing still selects the nearest real triangle. Store its plane,
    // rather than a radial distance sampled at a neighbouring angular ray.
    // The plane is constant over a wall, including at grazing view angles.
    vec3 delta = vision_world_position - vision_origin_range.xyz;
    vec3 normal = normalize(cross(dFdx(vision_world_position), dFdy(vision_world_position)));
    if (dot(normal, delta) < 0.0) { normal = -normal; }
    vec3 oct = normal / (abs(normal.x) + abs(normal.y) + abs(normal.z));
    vec2 encoded = oct.xy;
    if (oct.z < 0.0) {
        encoded = (1.0 - abs(oct.yx)) * (step(vec2(0.0), oct.xy) * 2.0 - 1.0);
    }
    // Use exact half-float-representable codes. Otherwise a tiny derivative
    // error around zero can alternate between 0.5 and the half value below it.
    encoded = round((encoded * 0.5 + 0.5) * 1024.0) / 1024.0;
    vec2 packed_normal = encoded * 2.0 - 1.0;
    normal = vec3(packed_normal, 1.0 - abs(packed_normal.x) - abs(packed_normal.y));
    if (normal.z < 0.0) {
        normal.xy = (1.0 - abs(normal.yx)) * (step(vec2(0.0), normal.xy) * 2.0 - 1.0);
    }
    normal = normalize(normal);
    float plane_distance = max(dot(normal, delta), 0.0);
    // Linear HDR data: R=plane distance/range, GB=octahedral world normal.
    ALBEDO = vec3(min(plane_distance / vision_origin_range.w, 0.999), encoded);
}
