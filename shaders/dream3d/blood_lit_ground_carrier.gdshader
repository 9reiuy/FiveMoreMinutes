shader_type spatial;
render_mode cull_disabled, fog_disabled, blend_mix, depth_prepass_alpha, diffuse_lambert, specular_disabled;

#define BLOOD_GROUND_EDGE_BLEND
#include "res://shaders/dream3d/blood_lit_carrier_common.gdshaderinc"
