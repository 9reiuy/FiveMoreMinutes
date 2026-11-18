shader_type particles;
render_mode keep_data, disable_velocity, disable_force;
// Rendering consumes the exact physics snapshot used by smoke occupancy.
// No independent particle simulation or delayed fading remains on the GPU.
uniform sampler2D cloud_poses : filter_nearest, repeat_disable;
uniform sampler2D cloud_metadata : filter_nearest, repeat_disable;
uniform mat4 floor_to_world;
uniform float capacity=280.0;
void start() { ACTIVE=true; VELOCITY=vec3(0.0); }
void process() {
    vec2 uv=vec2((float(INDEX)+.5)/capacity,.5);
    vec4 pose=textureLod(cloud_poses,uv,0.0);
    vec4 meta=textureLod(cloud_metadata,uv,0.0);
    float c=cos(meta.x),s=sin(meta.x);
    mat3 rotation=mat3(vec3(c,0.0,-s),vec3(0.0,1.0,0.0),vec3(s,0.0,c));
    mat3 basis=mat3(floor_to_world)*rotation*max(.0001,pose.w);
    TRANSFORM[0]=vec4(basis[0],0.0);
    TRANSFORM[1]=vec4(basis[1],0.0);
    TRANSFORM[2]=vec4(basis[2],0.0);
    TRANSFORM[3]=floor_to_world*vec4(pose.xyz,1.0);
    CUSTOM=vec4(meta.x,meta.y,pose.w,meta.z);
    COLOR=vec4(1.0,1.0,1.0,pose.w>.001 ? 1.0 : 0.0);
    VELOCITY=vec3(0.0);
    ACTIVE=true;
}
