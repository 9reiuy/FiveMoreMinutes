shader_type spatial;
// No prewrite: the complete union of fills must cover all interior outlines.
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, blend_mix, depth_draw_never;
#include "res://shaders/dream3d/elemental_particle_common.gdshaderinc"
