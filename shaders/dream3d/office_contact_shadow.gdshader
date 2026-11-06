shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float shadow_opacity = .22;
void fragment() {
    float edge = length((UV - vec2(.5)) * 2.0);
    // Alpha black only attenuates the receiving floor, including blackout.
    ALBEDO = vec3(0.0);
    ALPHA = (1.0 - smoothstep(.45, 1.0, edge)) * shadow_opacity;
}
