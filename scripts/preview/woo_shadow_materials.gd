extends "res://scripts/preview/woo_polygon_materials.gd"
## Keep the existing material/lifetime service; replace only the visibility
## lookup with a real omnidirectional depth comparison on the original surfaces.
const SHADOW_HEADER := """
// woo_polygon_material_variant
// woo_light_shadow_variant
global uniform bool hk_woo_polygon_enabled;
global uniform vec4 hk_woo_shadow_origin;
// Shared art treatments also use these world-to-map coordinates.
global uniform vec4 hk_woo_polygon_rect;
global uniform vec4 hk_woo_polygon_map_x;
global uniform vec4 hk_woo_polygon_map_z;
uniform sampler2D woo_polygon_mask : filter_nearest, repeat_disable;
varying vec3 woo_position;
varying float woo_occluded;
float woo_shadow_plane_occlusion(vec3 plane, vec3 ray) {
    if (plane.r >= 0.9999) { return 0.0; }
    vec2 encoded = plane.gb * 2.0 - 1.0;
    vec3 normal = vec3(encoded, 1.0 - abs(encoded.x) - abs(encoded.y));
    if (normal.z < 0.0) {
        normal.xy = (1.0 - abs(normal.yx)) * (step(vec2(0.0), normal.xy) * 2.0 - 1.0);
    }
    normal = normalize(normal);
    float plane_distance = plane.r * hk_woo_shadow_origin.w;
    float precision_bias = 0.0015 + plane_distance * 0.0005;
    return step(plane_distance + precision_bias, dot(normal, ray));
}
float woo_polygon_occlusion(vec3 point) {
    if (!hk_woo_polygon_enabled) { return 0.0; }
    vec3 d = point - hk_woo_shadow_origin.xyz;
    float distance_to_light = length(d);
    if (distance_to_light < 0.025) { return 0.0; }
    if (distance_to_light > hk_woo_shadow_origin.w) { return 1.0; }
    vec3 a = abs(d);
    vec2 projected;
    int face;
    if (a.x >= a.y && a.x >= a.z) {
        if (d.x > 0.0) { face = 0; projected = vec2(d.z, -d.y) / a.x; }
        else { face = 1; projected = vec2(-d.z, -d.y) / a.x; }
    } else if (a.y >= a.z) {
        if (d.y > 0.0) { face = 2; projected = vec2(-d.x, d.z) / a.y; }
        else { face = 3; projected = vec2(-d.x, -d.z) / a.y; }
    } else {
        if (d.z < 0.0) { face = 4; projected = vec2(d.x, -d.y) / a.z; }
        else { face = 5; projected = vec2(-d.x, -d.y) / a.z; }
    }
    vec2 texel = floor((projected * 0.5 + 0.5) * 512.0 - 0.5);
    vec2 tile = vec2(float(face % 3), float(face / 3));
    float hidden = 0.0;
    // Conservative coverage of the four surrounding angular samples closes
    // sub-texel holes on a thin wall's top silhouette. Plane comparisons keep
    // the wall face itself visible. This is binary coverage, not blur/history.
    for (int y = 0; y < 2; y++) {
        for (int x = 0; x < 2; x++) {
            vec2 cell = clamp(texel + vec2(float(x), float(y)) + 0.5, vec2(0.5), vec2(511.5));
            vec2 uv = (cell / 512.0 + tile) / vec2(3.0, 2.0);
            hidden = max(hidden, woo_shadow_plane_occlusion(texture(woo_polygon_mask, uv).rgb, d));
        }
    }
    return hidden;
}
"""

func _node_added(node: Node) -> void:
	# Loading preparation may register temporary native carriers outside the
	# game world. The private depth-only rig must never receive its own shadow.
	if is_instance_valid(field) and field.is_ancestor_of(node): return
	super._node_added(node)

func _variant_for(shader: Shader) -> Shader:
	var variant := super._variant_for(shader)
	if variant == null or variant.code.contains("woo_light_shadow_variant"): return variant
	var code := variant.code.replace(HEADER, SHADOW_HEADER)
	variant.code = code
	return variant
