shader_type spatial;
render_mode diffuse_lambert;
uniform sampler2D section_pixels : source_color, filter_nearest, repeat_disable;
uniform float section_height=2.6;
uniform float section_thickness=0.5;
varying vec3 section_local;
void vertex(){section_local=VERTEX;}
void fragment(){
    vec2 uv=vec2(section_local.z/section_thickness+0.5,clamp(1.0-section_local.y/section_height,0.0,1.0));
    ALBEDO=texture(section_pixels,uv).rgb;
    EMISSION=ALBEDO*0.30;
    ROUGHNESS=1.0;
    SPECULAR=0.0;
}
