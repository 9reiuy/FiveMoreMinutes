shader_type spatial;
// Keep late floor surfaces behind the visible streak without disabling occlusion.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;
#include "res://shaders/dream3d/phase_dash_ink.gdshaderinc"
uniform float half_length = 84.0;
uniform float progress = 0.0;
uniform float opacity = 0.0;
uniform bool refreshed = false;
uniform float pulse = 0.0;
uniform float color_phase = 0.0;
varying vec2 pixel;
void vertex(){ pixel = VERTEX.xz*32.0; }
void fragment(){
	vec2 p = floor(pixel)+vec2(.5);
	float head = mix(-half_length,half_length,progress);
	float longitudinal = max(max(-half_length-p.x,p.x-head),0.0);
	float distance_head = length(vec2(p.x-head,p.y));
	float pulse_radius = refreshed ? mix(12.0,30.0,1.0-pulse) : mix(7.0,24.0,1.0-pulse);
	bool ring = pulse>0.01 && abs(distance_head-pulse_radius)<(refreshed ? 2.5 : 1.5);
	bool streak_body = length(vec2(longitudinal,p.y))<=12.0 && p.x>head-78.0;
	if(!streak_body && !ring){ discard; }
	float streak = mod(floor(p.x/7.0)+floor(p.y/3.0)*3.0,5.0);
	if(!ring && abs(p.y)>2.0 && streak<2.0){ discard; }
	float core = 1.0-step(2.0,abs(p.y));
	float front = 1.0-step(8.0,abs(p.x-head));
	float density = ring ? opacity : opacity*mix(.45,.95,max(core,front));
	if (density<phase_dash_coverage(FRAGCOORD.xy)) discard;
	ALBEDO = phase_dash_ink(refreshed && ring ? 0.0 : floor((p.x+half_length)/28.0)+color_phase);
}
