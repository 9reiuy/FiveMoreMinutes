// Geometry edge coverage for light-driven rim only. No dark-line pass or emission.
uniform bool edge_style_rim = true;
varying vec3 edge_style_vertex;
varying float edge_style_coverage;

float edge_style_mask(vec3 bary, vec3 flags) {
    vec3 distance_px = bary / max(fwidth(bary), vec3(0.00001));
    vec3 lines = (vec3(1.0) - smoothstep(vec3(0.20), vec3(1.15), distance_px)) * flags;
    return max(lines.x, max(lines.y, lines.z));
}
