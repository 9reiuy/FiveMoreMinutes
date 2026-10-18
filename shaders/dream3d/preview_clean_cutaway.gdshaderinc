uniform bool architecture_cutaway = false;
uniform float architecture_wall_height = 2.6;
uniform float architecture_floor_y = 0.0;
varying vec3 architecture_world;
float architecture_visibility(vec3 p) {
    return step(p.y, architecture_floor_y + architecture_wall_height * 0.3 + 0.001);
}
