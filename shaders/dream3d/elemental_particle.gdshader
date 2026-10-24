shader_type spatial;
// Explicit ordering: every expanded dark silhouette precedes every fill.
// Fill writes depth so later transparent walls behind the fire cannot erase it.
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, blend_mix, depth_draw_always;
#include "res://shaders/dream3d/elemental_particle_common.gdshaderinc"
