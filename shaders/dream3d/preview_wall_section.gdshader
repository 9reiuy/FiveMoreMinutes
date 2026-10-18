shader_type spatial;
render_mode diffuse_lambert;
uniform sampler2D section_pixels : source_color, filter_nearest, repeat_disable;
uniform float section_height = 2.6;
uniform float section_thickness = 0.5;
varying vec3 section_local;
void vertex() { section_local = VERTEX; }
void fragment() {
    vec2 uv = vec2(section_local.z / section_thickness + 0.5, fract((section_local.x + 0.5) * 32.0 / float(textureSize(section_pixels,0).y)));
    ALBEDO = texture(section_pixels, uv).rgb;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
