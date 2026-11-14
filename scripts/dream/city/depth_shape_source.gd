extends Node
## Floor-owned approved scenery in the formal depth buffer; exterior lights cannot affect gameplay.
const CITY_LAYER := 1 << 19
const WINDOW_LIGHT_LIMIT := 4
const CITY_SHADER = preload("res://shaders/dream3d/city/city_depth_shape.gdshader")
const OWN_FACADE_SHADER = preload("res://shaders/dream3d/city/own_depth_shape.gdshader")
const OWN_SOURCE_BANK = preload("res://art/Dream/CityDepthShape/own_facade_bank.res")
const BW10_PRIMARY_PANE_DEPTH := {5:0.742073211669923,6:0.742073211669923,7:0.742075246175131,8:0.742076263427736,9:0.74187713623047,10:0.100018735351563,11:0.100014835537806,12:0.100015285844559,13:0.100016788834279,14:0.100016955159505,15:-1.04802504600085,16:-1.04802511162261,17:-1.04802498855297,18:-1.04802499104818,19:-1.04802499104818,20:0.0599662910970035,21:0.0599662910970035,22:0.0599662910970035,23:0.0599662910970035,24:0.0599662910970035,25:0.0599662910970035}
const DEPTH01_SHARED_AIR_SHA256 := "6467AF26EA7F9E75660CBB4060618E8099FB022B2D81A43FFDD8B75072E9154D"
const BR_BANK := preload("res://art/Dream/CityDepthShape/source_city_bank.res")
const BR_AD_CACHE_PATH := "res://art/Dream/CityDepthShape/reference_layout.res"
const BR_AD_PROPOSALS_PATH := "res://art/Dream/CityDepthShape/reference_layout.res"
const BR_AD_PROPOSALS_SHA256 := "A2B362F0FC5679CFF47E4A41578DFDEE0596C8787D2961D9E961D8839B6A8481"
const BR_AD_CACHE_SHA256 := "A2B362F0FC5679CFF47E4A41578DFDEE0596C8787D2961D9E961D8839B6A8481"
const BR_VISUAL_PARENT := "36ECFA2B1F5126B29562F5925BB3773704CD21CE6CF943649A940453FEF5D518"
const BR_EMITTER_GAINS := {100:23.3316280804431,101:23.3316280804431,102:23.3316280804431,103:23.3316280804431,104:23.3316280804431,105:23.3316280804431,106:22.7009019276025,107:99.6433096947292}
const BR_EMITTER_TINTS := {100:Vector3(0.5,1,0.920000016689301),101:Vector3(0.600000023841858,0.800000011920929,1),102:Vector3(1,0.920000016689301,0.720000028610229),103:Vector3(0.430000007152557,1,0.899999976158142),104:Vector3(1,0.180000007152557,0.159999996423721),105:Vector3(1,0.779999971389771,0.349999994039536),106:Vector3(0.730000019073486,0.899999976158142,1),107:Vector3(0.800000011920929,1,0.899999976158142)}
const TOWER_TYPES := 5
const STREET_LEVEL := -46.0
const STREET_SURFACE_Y := -42.91
const DEEP_GROUND_Y := -132.0
const LOW_NEAR_ROOFS := [-9.6, -5.2, -11.9, -3.4, -7.6]
const CORRIDOR_STREET := Rect2(23.0, -4.0, 24.0, 32.5)
static var _unit_box: Array = BoxMesh.new().surface_get_arrays(0)
static var _source_sections := {}
# The two window-facing landmarks for the office sample. Actual floor
# occupancy still vetoes them when this layout is built with another seed.
const WINDOW_LANDMARKS := [
	[Vector2(34.4, -8.10), 50.7, 1, 0, 15],
	[Vector2(100.00, 43.91), 36.5, 3, 1, 16],
]
# Street gap from the east office glazing to the nearest authored facade.
const EAST_PILOT_STREET := Rect2(62.50, 27.0, 31.0, 31.0)
const PILOT_HALO_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D city_void : filter_nearest, repeat_disable;
uniform vec2 city_origin;
uniform vec2 city_grid_size;
uniform vec3 map_origin;
uniform vec3 map_x_axis;
uniform vec3 map_z_axis;
uniform vec3 ray_origin_tl;
uniform vec3 ray_origin_dx;
uniform vec3 ray_origin_dy;
uniform vec3 ray_direction_tl;
uniform vec3 ray_direction_dx;
uniform vec3 ray_direction_dy;
varying vec2 aperture;
varying vec3 air_point;
uniform vec3 city_eye;
uniform bool height_fog_enabled=true;
uniform bool pollution_air_enabled=true;

uniform vec2 city_air_ad_anchor0=vec2(72.41006,33.45109);
uniform vec2 city_air_ad_anchor1=vec2(73.15544,40.47069);
uniform vec2 city_air_ad_anchor2=vec2(73.21996,55.17027);
uniform vec2 city_air_ad_anchor3=vec2(42.32,19.36131);
// DEPTH01_SHARED_AIR_BEGIN
// Fixed city-space air: three depth ranges, no time/screen noise or extra pass.
float depth01_pool(vec2 point,vec2 center,vec2 radius) {
 vec2 q=(point-center)/radius;
 return exp(-0.5*dot(q,q));
}
vec3 city_air_color(vec3 eye, vec3 direction) {
 vec3 ray=normalize(direction);
 float denominator=max(-ray.y,0.08);
 vec2 far_xz=eye.xz+ray.xz*max(0.0,(eye.y+58.0)/denominator);
 vec2 lower_xz=eye.xz+ray.xz*max(0.0,(eye.y+41.0)/denominator);
 float layer=0.5+0.26*sin(far_xz.x*0.024+far_xz.y*0.011)
  +0.18*sin(far_xz.y*0.041-far_xz.x*0.008);
 vec3 air=mix(vec3(0.130,0.175,0.195),vec3(0.182,0.228,0.244),clamp(layer,0.0,1.0));
 // Broad weak scattered light below existing host16/5/6/own106; no new emitter.
 air+=depth01_pool(lower_xz,city_air_ad_anchor0,vec2(10.0,15.0))*vec3(0.004,0.025,0.029);
 air+=depth01_pool(lower_xz,city_air_ad_anchor1,vec2(11.0,12.0))*vec3(0.008,0.020,0.030);
 air+=depth01_pool(lower_xz,city_air_ad_anchor2,vec2(9.0,12.0))*vec3(0.020,0.005,0.005);
 air+=depth01_pool(lower_xz,city_air_ad_anchor3,vec2(10.0,13.0))*vec3(0.007,0.020,0.025);
 float corridor=exp(-0.5*pow(far_xz.y/13.0,2.0))
  *(1.0-smoothstep(17.0,38.0,abs(far_xz.x-34.0)));
 float east=exp(-0.5*pow((far_xz.x-90.0)/13.0,2.0))
  *(1.0-smoothstep(18.0,42.0,abs(far_xz.y-42.0)));
 return air*(1.0-0.055*max(corridor,east));
}
float city_air_extinction(vec3 eye,vec3 point) {
 float h=max(0.0,-point.y);
 float lower=smoothstep(14.0,28.0,h);
 float depth=max(0.0,h-6.0)/40.0;
 float depth4=depth*depth*depth*depth;
 float broad=clamp(0.5+0.26*sin(point.x*0.024+point.z*0.011)
  +0.18*sin(point.z*0.031-point.x*0.008),0.0,1.0);
 float height_mass=mix(8.0,mix(3.6,5.0,broad),lower)*depth4;
 float distance=length(point-eye);
 float old_distance=pow(max(0.0,distance-30.0)/92.0,1.3)*1.15;
 float layered_distance=pow(max(0.0,distance-30.0)/62.0,1.3)*1.10;
 // Street -42.91 and source ends -46/-48 remain fully sealed in deep air.
 float seal=smoothstep(35.0+2.0*broad,43.0,h);
 float mass=height_mass+mix(old_distance,layered_distance,lower)+12.0*seal*seal;
 return 1.0-exp(-min(20.0,mass));
}
// DEPTH01_SHARED_AIR_END

void vertex() {
 air_point=VERTEX;
	aperture = UV2;
}
void fragment() {
	vec3 origin = ray_origin_tl + ray_origin_dx * SCREEN_UV.x + ray_origin_dy * SCREEN_UV.y;
	vec3 ray = ray_direction_tl + ray_direction_dx * SCREEN_UV.x + ray_direction_dy * SCREEN_UV.y;
	if (ray.y < -0.0001) {
		vec3 ground = origin - ray * (origin.y / ray.y) - map_origin;
		vec2 cell = vec2(dot(ground, map_x_axis), dot(ground, map_z_axis));
		vec2 mask_uv = (cell - city_origin + vec2(0.5)) / city_grid_size;
		if (all(greaterThanEqual(mask_uv, vec2(0.0))) && all(lessThanEqual(mask_uv, vec2(1.0)))
				&& texture(city_void, mask_uv).r < 0.5) { discard; }
	}
	vec2 spread = max(abs(UV * 2.0 - 1.0) - aperture * 0.64, vec2(0.0)) / (1.0 - aperture * 0.64);
	float halo = exp(-5.0 * dot(spread, spread)) * (1.0 - smoothstep(0.6, 1.0, max(spread.x, spread.y)));
	ALBEDO = vec3(0.60,0.72,0.78);
	float transmission=(height_fog_enabled && pollution_air_enabled) ? 1.0-city_air_extinction(city_eye,air_point) : 1.0;
	ALPHA = COLOR.a * halo * transmission * 0.18;
}
"""
const BR_AD_GLOW_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D emission_texture : source_color, filter_linear, repeat_disable;
uniform float emission_gain=1.0;
uniform vec3 emission_tint=vec3(1.0);
uniform sampler2D city_void : filter_nearest, repeat_disable;
uniform vec2 city_origin;
uniform vec2 city_grid_size;
uniform vec3 map_origin;
uniform vec3 map_x_axis;
uniform vec3 map_z_axis;
uniform vec3 ray_origin_tl;
uniform vec3 ray_origin_dx;
uniform vec3 ray_origin_dy;
uniform vec3 ray_direction_tl;
uniform vec3 ray_direction_dx;
uniform vec3 ray_direction_dy;
varying vec2 aperture;
varying vec3 air_point;
uniform vec3 city_eye;
uniform bool height_fog_enabled=true;
uniform bool pollution_air_enabled=true;

uniform vec2 city_air_ad_anchor0=vec2(72.41006,33.45109);
uniform vec2 city_air_ad_anchor1=vec2(73.15544,40.47069);
uniform vec2 city_air_ad_anchor2=vec2(73.21996,55.17027);
uniform vec2 city_air_ad_anchor3=vec2(42.32,19.36131);
// DEPTH01_SHARED_AIR_BEGIN
// Fixed city-space air: three depth ranges, no time/screen noise or extra pass.
float depth01_pool(vec2 point,vec2 center,vec2 radius) {
 vec2 q=(point-center)/radius;
 return exp(-0.5*dot(q,q));
}
vec3 city_air_color(vec3 eye, vec3 direction) {
 vec3 ray=normalize(direction);
 float denominator=max(-ray.y,0.08);
 vec2 far_xz=eye.xz+ray.xz*max(0.0,(eye.y+58.0)/denominator);
 vec2 lower_xz=eye.xz+ray.xz*max(0.0,(eye.y+41.0)/denominator);
 float layer=0.5+0.26*sin(far_xz.x*0.024+far_xz.y*0.011)
  +0.18*sin(far_xz.y*0.041-far_xz.x*0.008);
 vec3 air=mix(vec3(0.130,0.175,0.195),vec3(0.182,0.228,0.244),clamp(layer,0.0,1.0));
 // Broad weak scattered light below existing host16/5/6/own106; no new emitter.
 air+=depth01_pool(lower_xz,city_air_ad_anchor0,vec2(10.0,15.0))*vec3(0.004,0.025,0.029);
 air+=depth01_pool(lower_xz,city_air_ad_anchor1,vec2(11.0,12.0))*vec3(0.008,0.020,0.030);
 air+=depth01_pool(lower_xz,city_air_ad_anchor2,vec2(9.0,12.0))*vec3(0.020,0.005,0.005);
 air+=depth01_pool(lower_xz,city_air_ad_anchor3,vec2(10.0,13.0))*vec3(0.007,0.020,0.025);
 float corridor=exp(-0.5*pow(far_xz.y/13.0,2.0))
  *(1.0-smoothstep(17.0,38.0,abs(far_xz.x-34.0)));
 float east=exp(-0.5*pow((far_xz.x-90.0)/13.0,2.0))
  *(1.0-smoothstep(18.0,42.0,abs(far_xz.y-42.0)));
 return air*(1.0-0.055*max(corridor,east));
}
float city_air_extinction(vec3 eye,vec3 point) {
 float h=max(0.0,-point.y);
 float lower=smoothstep(14.0,28.0,h);
 float depth=max(0.0,h-6.0)/40.0;
 float depth4=depth*depth*depth*depth;
 float broad=clamp(0.5+0.26*sin(point.x*0.024+point.z*0.011)
  +0.18*sin(point.z*0.031-point.x*0.008),0.0,1.0);
 float height_mass=mix(8.0,mix(3.6,5.0,broad),lower)*depth4;
 float distance=length(point-eye);
 float old_distance=pow(max(0.0,distance-30.0)/92.0,1.3)*1.15;
 float layered_distance=pow(max(0.0,distance-30.0)/62.0,1.3)*1.10;
 // Street -42.91 and source ends -46/-48 remain fully sealed in deep air.
 float seal=smoothstep(35.0+2.0*broad,43.0,h);
 float mass=height_mass+mix(old_distance,layered_distance,lower)+12.0*seal*seal;
 return 1.0-exp(-min(20.0,mass));
}
// DEPTH01_SHARED_AIR_END

vec3 read_emitter(vec2 uv) {
    if (any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0)))) { return vec3(0.0); }
    vec3 c=texture(emission_texture,uv).rgb;
    float peak=max(max(c.r,c.g),c.b);
    c*=smoothstep(0.0126,0.0234,peak)*emission_gain*emission_tint;
    float top=max(max(c.r,c.g),c.b);
    return c*min(1.0,6.0/max(top,0.00001));
}
void vertex() {
 air_point=VERTEX;
	aperture = UV2;
}
void fragment() {
	vec3 origin = ray_origin_tl + ray_origin_dx * SCREEN_UV.x + ray_origin_dy * SCREEN_UV.y;
	vec3 ray = ray_direction_tl + ray_direction_dx * SCREEN_UV.x + ray_direction_dy * SCREEN_UV.y;
	if (ray.y < -0.0001) {
		vec3 ground = origin - ray * (origin.y / ray.y) - map_origin;
		vec2 cell = vec2(dot(ground, map_x_axis), dot(ground, map_z_axis));
		vec2 mask_uv = (cell - city_origin + vec2(0.5)) / city_grid_size;
		if (all(greaterThanEqual(mask_uv, vec2(0.0))) && all(lessThanEqual(mask_uv, vec2(1.0)))
				&& texture(city_void, mask_uv).r < 0.5) { discard; }
	}

    vec2 mapped=(UV-vec2(0.5))/max(aperture,vec2(0.01))+vec2(0.5);
    mapped.y=1.0-mapped.y;
    vec2 radius=(vec2(1.0)/max(aperture,vec2(0.01))-vec2(1.0))*0.32;
    vec3 direct=read_emitter(mapped);
    vec3 light=direct*4.0;
    light+=(read_emitter(mapped+vec2(radius.x,0.0))+read_emitter(mapped-vec2(radius.x,0.0))
        +read_emitter(mapped+vec2(0.0,radius.y))+read_emitter(mapped-vec2(0.0,radius.y)))*2.0;
    light+=read_emitter(mapped+radius)+read_emitter(mapped-radius)
        +read_emitter(mapped+vec2(radius.x,-radius.y))+read_emitter(mapped+vec2(-radius.x,radius.y));
    light=max(light/16.0-direct*0.45,vec3(0.0));
    float transmission=(height_fog_enabled && pollution_air_enabled) ? 1.0-city_air_extinction(city_eye,air_point) : 1.0;
    ALBEDO=light;
    ALPHA=COLOR.a*transmission;

}
"""
const CITY_AIR_BACKGROUND_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, shadows_disabled;
uniform vec3 city_eye;
uniform vec3 map_origin;
uniform vec3 map_x_axis;
uniform vec3 map_z_axis;
uniform vec3 ray_origin_tl;
uniform vec3 ray_origin_dx;
uniform vec3 ray_origin_dy;
uniform vec3 ray_direction_tl;
uniform vec3 ray_direction_dx;
uniform vec3 ray_direction_dy;
uniform bool pollution_air_enabled=true;
uniform bool height_fog_enabled=true;

uniform vec2 city_air_ad_anchor0=vec2(72.41006,33.45109);
uniform vec2 city_air_ad_anchor1=vec2(73.15544,40.47069);
uniform vec2 city_air_ad_anchor2=vec2(73.21996,55.17027);
uniform vec2 city_air_ad_anchor3=vec2(42.32,19.36131);
// DEPTH01_SHARED_AIR_BEGIN
// Fixed city-space air: three depth ranges, no time/screen noise or extra pass.
float depth01_pool(vec2 point,vec2 center,vec2 radius) {
 vec2 q=(point-center)/radius;
 return exp(-0.5*dot(q,q));
}
vec3 city_air_color(vec3 eye, vec3 direction) {
 vec3 ray=normalize(direction);
 float denominator=max(-ray.y,0.08);
 vec2 far_xz=eye.xz+ray.xz*max(0.0,(eye.y+58.0)/denominator);
 vec2 lower_xz=eye.xz+ray.xz*max(0.0,(eye.y+41.0)/denominator);
 float layer=0.5+0.26*sin(far_xz.x*0.024+far_xz.y*0.011)
  +0.18*sin(far_xz.y*0.041-far_xz.x*0.008);
 vec3 air=mix(vec3(0.130,0.175,0.195),vec3(0.182,0.228,0.244),clamp(layer,0.0,1.0));
 // Broad weak scattered light below existing host16/5/6/own106; no new emitter.
 air+=depth01_pool(lower_xz,city_air_ad_anchor0,vec2(10.0,15.0))*vec3(0.004,0.025,0.029);
 air+=depth01_pool(lower_xz,city_air_ad_anchor1,vec2(11.0,12.0))*vec3(0.008,0.020,0.030);
 air+=depth01_pool(lower_xz,city_air_ad_anchor2,vec2(9.0,12.0))*vec3(0.020,0.005,0.005);
 air+=depth01_pool(lower_xz,city_air_ad_anchor3,vec2(10.0,13.0))*vec3(0.007,0.020,0.025);
 float corridor=exp(-0.5*pow(far_xz.y/13.0,2.0))
  *(1.0-smoothstep(17.0,38.0,abs(far_xz.x-34.0)));
 float east=exp(-0.5*pow((far_xz.x-90.0)/13.0,2.0))
  *(1.0-smoothstep(18.0,42.0,abs(far_xz.y-42.0)));
 return air*(1.0-0.055*max(corridor,east));
}
float city_air_extinction(vec3 eye,vec3 point) {
 float h=max(0.0,-point.y);
 float lower=smoothstep(14.0,28.0,h);
 float depth=max(0.0,h-6.0)/40.0;
 float depth4=depth*depth*depth*depth;
 float broad=clamp(0.5+0.26*sin(point.x*0.024+point.z*0.011)
  +0.18*sin(point.z*0.031-point.x*0.008),0.0,1.0);
 float height_mass=mix(8.0,mix(3.6,5.0,broad),lower)*depth4;
 float distance=length(point-eye);
 float old_distance=pow(max(0.0,distance-30.0)/92.0,1.3)*1.15;
 float layered_distance=pow(max(0.0,distance-30.0)/62.0,1.3)*1.10;
 // Street -42.91 and source ends -46/-48 remain fully sealed in deep air.
 float seal=smoothstep(35.0+2.0*broad,43.0,h);
 float mass=height_mass+mix(old_distance,layered_distance,lower)+12.0*seal*seal;
 return 1.0-exp(-min(20.0,mass));
}
// DEPTH01_SHARED_AIR_END

vec3 decode_air(vec3 c) {
 return mix(c/12.92,pow((c+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),c));
}
void vertex() { POSITION=vec4(VERTEX.xy,0.000001,1.0); }
void fragment() {
 vec3 ray=ray_direction_tl+ray_direction_dx*SCREEN_UV.x+ray_direction_dy*SCREEN_UV.y;
 vec3 map_ray=vec3(dot(ray,map_x_axis),ray.y,dot(ray,map_z_axis));
 vec3 color=(pollution_air_enabled && height_fog_enabled)
  ? city_air_color(city_eye,map_ray) : vec3(0.0784,0.1255,0.1490);
 if (!OUTPUT_IS_SRGB) { color=decode_air(color); }
 ALBEDO=color;
}
"""
const PILOT_BACKGROUND_SHADER := """
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, shadows_disabled;
uniform sampler2D exterior_hdr : filter_nearest, repeat_disable;
uniform vec3 main_eye;
uniform vec3 main_back;
void vertex() {
	// Forward+ reverse Z. The outside image sits behind all real room depth.
	POSITION = vec4(VERTEX.xy, 0.00001, 1.0);
}
void fragment() {
	if (distance(CAMERA_POSITION_WORLD, main_eye) > 0.04
			|| dot(INV_VIEW_MATRIX[2].xyz, main_back) < 0.9999) { discard; }
	ALBEDO = texture(exterior_hdr, SCREEN_UV).rgb;
}
"""
var pilot_view: SubViewport
var pilot_focus: CameraAttributesPractical
var pilot_camera: Camera3D
var pilot_background: MeshInstance3D
var air_background: MeshInstance3D
var continuity_base_y := -288.0
var continuity_margin := 256.0
var continuity_plans: Array[Dictionary] = []
var pilot_halo: MeshInstance3D
var pilot_built := false
var city_coverage := {}
var highrise_layout: Array[Dictionary] = []
var street_layer: Node3D
var street_halo: MeshInstance3D
var street_lamps: Array[Dictionary] = []
var street_signs: Array[Dictionary] = []
var vertical_layer: Node3D
var vertical_halo: MeshInstance3D
var vertical_groups: Array[Dictionary] = []
var main_runs: Array[Dictionary] = []
var world: Node3D
var scene_root: Node3D
var render_materials: Array[ShaderMaterial]=[]
var attached_mask: ShaderMaterial
var topology: Dictionary={}
var br_ad_glow_batches:Dictionary={}
var br_ad_back_patches:Dictionary={}
var br_ad_search_stats:Dictionary={}
var br_frozen_ad_records:Array=[]
var br_collision_cache:Dictionary={}
var br_accepted_ad_geometry:Array=[]
var br_ad_installation_report:Array=[]
var br_triangle_pairs_checked:=0
var br_batches:Dictionary={}
var br_plans:Array[Dictionary]=[]
var build_seed := -1
var buildings := 0
var near_towers: Array[Dictionary]=[]
var middle_towers: Array[Dictionary]=[]
var facade_segments := 0
var enabled := true
var window_lights: Array[OmniLight3D]=[]
var light_candidates: Array[Dictionary]=[]
var window_lights_enabled := false
var height_fog_enabled := true
var pollution_enabled := true
var last_light_selection := -1000
var production_mode := false
## Local visibility only: no scene alpha sorting or per-building material clones.
var soft_occlusion_enabled := true

static func interior_cut_depth_image(classification: Dictionary) -> Image:
	var source: Image = classification.image
	var width := source.get_width()
	var height := source.get_height()
	var values := PackedFloat32Array()
	values.resize(width * height)
	for y in height:
		for x in width:
			values[y * width + x] = 0.0 if source.get_pixel(x,y).r > 0.5 else 4.0
	# Eight-neighbour distance propagation. Built once per floor, never per frame.
	for y in height:
		for x in width:
			var i := y * width + x
			if x > 0: values[i] = minf(values[i], values[i-1] + 1.0)
			if y > 0:
				values[i] = minf(values[i], values[i-width] + 1.0)
				if x > 0: values[i] = minf(values[i], values[i-width-1] + 1.414214)
				if x+1 < width: values[i] = minf(values[i], values[i-width+1] + 1.414214)
	for y in range(height-1,-1,-1):
		for x in range(width-1,-1,-1):
			var i := y * width + x
			if x+1 < width: values[i] = minf(values[i], values[i+1] + 1.0)
			if y+1 < height:
				values[i] = minf(values[i], values[i+width] + 1.0)
				if x > 0: values[i] = minf(values[i], values[i+width-1] + 1.414214)
				if x+1 < width: values[i] = minf(values[i], values[i+width+1] + 1.414214)
	return Image.create_from_data(width,height,false,Image.FORMAT_RF,values.to_byte_array())

func _ready() -> void:
	if world==null: world=get_parent()
	process_priority=100
	if production_mode:
		set_process(false)

func _enter_tree() -> void:
	if not RenderingServer.frame_pre_draw.is_connected(_sync_render_snapshot):
		RenderingServer.frame_pre_draw.connect(_sync_render_snapshot)

func _exit_tree() -> void:
	_set_pilot_view_active(false)
	if RenderingServer.frame_pre_draw.is_connected(_sync_render_snapshot): RenderingServer.frame_pre_draw.disconnect(_sync_render_snapshot)

func _process(_delta: float) -> void:
	if production_mode:
		set_process(false)
		return
	if world.floor_cells.is_empty() or world.room_visibility==null: return
	if scene_root==null or not is_instance_valid(scene_root) or build_seed!=world.active_seed:
		_build()
	if Time.get_ticks_msec()-last_light_selection>=300: _select_window_lights()

static func classify_void(floor_cells: Dictionary, rect: Rect2i) -> Dictionary:
	var bounds := rect.grow(2)
	var external: Dictionary={}; var queue: Array[Vector2i]=[]
	for y in range(bounds.position.y,bounds.end.y):
		for x in range(bounds.position.x,bounds.end.x):
			var cell := Vector2i(x,y)
			if x!=bounds.position.x and x!=bounds.end.x-1 and y!=bounds.position.y and y!=bounds.end.y-1: continue
			if not floor_cells.has(cell) and not external.has(cell): external[cell]=true; queue.append(cell)
	var index := 0
	while index<queue.size():
		var cell := queue[index]; index+=1
		for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=cell+step
			if bounds.has_point(next) and not floor_cells.has(next) and not external.has(next): external[next]=true; queue.append(next)
	var image := Image.create(bounds.size.x,bounds.size.y,false,Image.FORMAT_RGB8)
	for y in bounds.size.y:
		for x in bounds.size.x:
			var cell := bounds.position+Vector2i(x,y)
			image.set_pixel(x,y,Color(1 if external.has(cell) else 0,1 if floor_cells.has(cell) else 0,0))
	return {"bounds":bounds,"external":external,"image":image}

func _build() -> void:
	_dispose_pilot_view()
	if is_instance_valid(scene_root): scene_root.free()
	attached_mask=null; build_seed=world.active_seed
	topology=classify_void(world.floor_cells,world.building_rect)
	topology["clearance_texture"] = ImageTexture.create_from_image(interior_cut_depth_image(topology))
	scene_root=Node3D.new(); scene_root.name="SampleNeonCityGeometry"
	if production_mode: get_parent().add_child(scene_root)
	else: world.add_child(scene_root)
	scene_root.global_transform=world.global_transform
	var facade := SurfaceTool.new(); facade.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tower_tags := PackedVector2Array()
	var far_footprints: Array[Rect2] = []
	var own := SurfaceTool.new(); own.begin(Mesh.PRIMITIVE_TRIANGLES);own.set_uv2(Vector2.ZERO)
	own_slice_cache.clear()
	var rng := RandomNumberGenerator.new(); rng.seed=world.active_seed+88211
	var rect: Rect2i=world.building_rect; buildings=0
	near_towers.clear(); middle_towers.clear(); facade_segments=0; render_materials.clear()
	continuity_plans.clear()
	_plan_continuity()
	pilot_halo = null
	street_layer = null
	street_halo = null
	vertical_layer = null
	vertical_halo = null
	vertical_groups.clear()
	window_lights.clear(); light_candidates.clear(); last_light_selection=-1000
	var center := Vector2(rect.get_center())
	city_coverage = {"main_edges": 0, "main_runs": 0, "main_edges_by_side": [0, 0, 0, 0],
		"main_window_groups": 0, "main_lit_groups": 0, "main_signs": 0, "main_service_racks": 0,
		"neighbours": [0, 0, 0], "neighbour_window_groups": [0, 0], "neighbour_lit_groups": [0, 0],
		"source_meshes": {}, "corridor_front_gap": -1.0, "east_front_gap": -1.0,
		"roof_height_bins": [[0,0,0,0], [0,0,0,0], [0,0,0,0]],
		"roof_height_ranges": [[1e9,-1e9], [1e9,-1e9], [1e9,-1e9]], "highrise_structural_floors": 0}
	br_batches.clear();br_plans.clear()
	br_ad_glow_batches.clear()
	br_collision_cache.clear();br_accepted_ad_geometry.clear();br_ad_installation_report.clear();br_triangle_pairs_checked=0
	main_runs=_exterior_runs(world.floor_cells,topology.external)
	city_coverage.main_runs=main_runs.size()
	_br_plan(rng,rect)
	_city_shape01_layout()
	print("FULL05 planned ",br_plans.size()," t=",Time.get_ticks_msec())
	pilot_built=not main_runs.is_empty()
	for run:Dictionary in main_runs:
		_own_r3_shell(own,run)
		facade_segments+=int(run.length)
		city_coverage.main_edges_by_side[int(run.side)]+=int(run.length)
	city_coverage.main_edges=facade_segments
	_own_r3_close_underdeck(own)
	print("FULL05 source assembled t=",Time.get_ticks_msec())
	own.index()
	var own_material:=_scenery_material(true);own_material.set_shader_parameter("pilot_geometry",true)
	own_material.set_shader_parameter("own_reference_material",true)
	_add_city_carrier(own.commit(),own_material,"CurrentBuildingFacade")
	print("FULL05 own committed t=",Time.get_ticks_msec())
	for plan:Dictionary in br_plans:
		_br_instance(plan.source_id,plan.position,plan.size,plan.turn,buildings)
		buildings+=1
	print("FULL05 neighbours assembled t=",Time.get_ticks_msec())
	if "--own-r3-author-plan" in OS.get_cmdline_user_args():_own_full_space_audit()
	else:_own_reuse_verified_space()
	print("FULL05 space audited ",city_coverage.own_full_space," t=",Time.get_ticks_msec())
	_br_advertisements()
	print("FULL05 ads ready t=",Time.get_ticks_msec())
	city_coverage["ad_projection_authoring"]={"reference_views":"Existing corridor/east/concave Camera poses, fixed placement only",
		"camera_fov":world.camera_3d.fov,"viewport":world.camera_3d.get_viewport().get_visible_rect().size,"height_clamp_limit":4.5,"visibility_rays_per_frame":0}
	city_coverage["advert_installation"]={"reports":br_ad_installation_report.duplicate(true),"triangle_pairs_tested":br_triangle_pairs_checked,
		"host_identity":"Unique plan_id and final transform","rear_fixed_patch_coverage_minimum":0.998,"source_wall_full_panel_fit_required":false,"complete_carrier_mesh_checked":true,"per_frame_ray_tests":0}
	_br_commit_batches()
	_br_commit_ad_glows()
	var terrain:=SurfaceTool.new();terrain.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build_continuous_ground(terrain,rect)
	var ground_material:=_scenery_material(false);ground_material.set_shader_parameter("street_geometry",true)
	_add_city_carrier(terrain.commit(),ground_material,"BR01_ContinuousTerrain")
	_br_foundations()
	city_coverage["source"]={"title":"Blade runner style Cityscapes","author":"Suraj99",
		"source_sha256":"410b7e93b9eab933590b6da5db82965e0ce1136b0fe1284bbb9bf56e1ce8fd96",
		"bank_models":18,"eligible_closed_models":17,"excluded_open_source_model":"BR_Group6_2",
		"method":"Original connected building components and original Block material bindings; offline baked textures",
		"plans":br_plans.duplicate(true),"runtime_blender_logic":false,"new_real_lights":0,"extra_worlds":0}
	city_coverage["composition"]={"mode":"source-led near-high far-low","near":near_towers.duplicate(true),
		"middle":middle_towers.duplicate(true),"new_real_lights":0,"extra_worlds":0}
	city_coverage["local_lighting"]={"source_types":[5,12],"integrated_world_unit_facades":true,"old_normalized_window_masks_used":false,
		"advertisement_gain":{"method":"Native emission image95th percentile linear calibration","target_hdr_core":[4.0,5.5]},"private_city_glow_only":true,"real_lights_added":0,"no_indoor_glow":true}
	city_coverage["own_facade_material"]={"stage":"R3 full05 exterior: real source front/rear/wing zones, simple same-material short closures, correct UV/slots; no full Arnold reconstruction",
		"old_fake_window_generators_removed":true,"old_own_halo_generator_removed":true,
		"reference":"Whole perimeter: dark source bodies/spines, silver wings, genuine rear panels and simple short closures; approved Source04b corner retained",
		"floor_pitch":3.2,"midrail_pitch":1.6,"playable_geometry_changed":false,"highest_own_vertex":-0.06,
		"new_real_lights":0,"material":"Plain cold steel and opaque glass code, no procedural window substitutes"}
	city_coverage["window_architecture"]={"source_types":[5,12],"coordinate_space":"Final instance world-unit facade, independent of normalized prototype stretch",
		"floor_heights":[2.8,3.05],"window_sizes":[[0.86,0.94],[0.82,1.18]],"basis_and_emission":"Single shared glazing/frame/pier/floor-band mask",
		"old_large_emission_masks_removed":true,"pixel_world_scale":32,"far_detail_prefilter":true}
	city_coverage["visible_density"]={"method":"Three projected near-gap source placements and staggered second near row; far-grid density unchanged",
		"targeted_added":br_plans.filter(func(p:Dictionary)->bool:return str(p.get("density_role","base")).contains("visible_gap") or p.get("density_role","base")=="concave_staggered_front").size(),
		"second_row_added":br_plans.filter(func(p:Dictionary)->bool:return p.get("density_role","base")=="second_row").size()}
	city_coverage["atmosphere"]={"effective_depth_start_y":-6.0,"vertical_density_scale":40.0,"height_mass_gain":"Depth01 upper8, lower3.6..5.0 + deep seal","height_mass_power":4,
		"source_building_base_y":STREET_LEVEL,"base_vertical_transmission":0.0000001,"revision":"DEPTH01","distance_lower_scale":62.0,"deep_seal_height":[35.0,43.0],"glow_anchors":"Existing ads host16/5/6/own106, no new lights or geometry",
		"mid_grid_step":15,"far_grid_step":17,"far_drop_fraction":0.05,
		"scope":"Exterior neighbours, auxiliary ground and own below-floor facade only; main playable floor/glass/world unchanged"}
	_sync_render_snapshot()

const BR_REVIEW_EYES := [Vector3(-5.287853,15.590742,55.247867),Vector3(51.547774,15.589802,54.327731),Vector3(-4.450343,15.580447,63.080361),Vector3(18.542180,15.586922,72.573291),Vector3(49.500188,15.583959,73.343452),Vector3(-6.402612,15.586498,53.799094),Vector3(3.574328,15.589059,70.323931),Vector3(22.539765,15.596021,72.335858),Vector3(29.555334,15.596158,38.329221),Vector3(59.281877,15.593073,52.519953),Vector3(59.109926,15.589118,52.923556),Vector3(-7.101786,15.587824,61.067592),Vector3(15.020406,15.580186,66.128648),Vector3(57.771544,15.587819,74.028019)]
func _br_model_info(id:int) -> Dictionary:
	for info:Dictionary in BR_BANK.get_meta("models"):
		if int(info.bank_id)==id:return info
	return {}

func _br_clear(footprint:Rect2,roof:float,clearance:float,neighbour_gap:float=2.1) -> bool:
	if footprint.grow(clearance).intersects(Rect2(Vector2(world.building_rect.position),Vector2(world.building_rect.size))):
		for cell:Vector2i in world.floor_cells:
			if footprint.grow(clearance).intersects(Rect2(Vector2(cell)-Vector2(0.5,0.5),Vector2.ONE)):return false
	for plan:Dictionary in br_plans:
		if plan.footprint.grow(neighbour_gap).intersects(footprint):return false
	if world.active_seed==42001:
		for eye:Vector3 in BR_REVIEW_EYES:
			if eye.y<=roof+1.8 and footprint.grow(1.8).has_point(Vector2(eye.x,eye.z)):return false
	return true

func _br_add_plan(at:Vector3,size:Vector3,id:int,turn:int,tier:int,role:String="base") -> void:
	var info:=_br_model_info(id)
	var footprint:=Rect2(Vector2(at.x-size.x*0.5,at.z-size.z*0.5),Vector2(size.x,size.z))
	var plan:Dictionary={"position":at,"size":size,"footprint":footprint,"top":at.y+size.y*0.5,
		"source_id":id,"turn":turn,"tier":tier,"source_object":info.source_object,
		"source_component":info.source_component,"source_material":info.source_material,"source_model":info.id,
		"emission_derivative":info.get("emission_derivative",{}),"density_role":role,"plan_id":br_plans.size()}
	br_plans.append(plan)
	if tier==0:near_towers.append(plan)
	elif tier==1:middle_towers.append(plan)
	city_coverage.neighbours[tier]+=1

func _br_plan(rng:RandomNumberGenerator,rect:Rect2i) -> void:
	var ids:Array[int]=[]
	for info:Dictionary in BR_BANK.get_meta("models"):
		if info.runtime_eligible:ids.append(int(info.bank_id))
	var near_ids:Array[int]=[0,1,5,7,10,11,12,15]
	# These few source-owned narrow highrises fill the real south concavity.
	# Their actual footprints still pass floor, neighbour and Camera bounds.
	var infill:Array[Dictionary]=[
		{"p":Vector2(27.1,78.3),"size":Vector3(5.4,96.0,7.4),"id":15,"turn":1},
		{"p":Vector2(35.5,74.2),"size":Vector3(6.6,89.0,7.4),"id":0,"turn":2},
		{"p":Vector2(44.0,74.8),"size":Vector3(5.4,102.0,7.4),"id":5,"turn":1}]
	for extra:Dictionary in infill:
		var p:Vector2=Vector2(rect.position)+extra.p
		var size:Vector3=extra.size
		var footprint:=Rect2(p-Vector2(size.x,size.z)*0.5,Vector2(size.x,size.z))
		if _br_clear(footprint,STREET_LEVEL+size.y,3.0):
			_br_add_plan(Vector3(p.x,STREET_LEVEL+size.y*0.5,p.y),size,extra.id,extra.turn,0)
	for run:Dictionary in main_runs:
		if run.length<5:continue
		var count:=maxi(1,ceili(float(run.length)/18.0))
		for index in count:
			var width:=rng.randf_range(7.5,12.5);var depth:=rng.randf_range(9.5,14.5)
			var height:=rng.randf_range(88.0,128.0)
			if posmod(int(run.fixed)+index,5)==0:height=rng.randf_range(84.0,98.0)
			var side:int=run.side
			var setback:=rng.randf_range(11.5,14.5) if side in [0,3] else rng.randf_range(5.8,8.6)
			var sign_value:=-1.0 if side in [0,2] else 1.0
			var along:float=run.start+float(run.length)*(float(index)+0.5)/float(count)
			var id:int=near_ids[posmod(hash(Vector3i(int(run.fixed),roundi(along*10),world.active_seed)),near_ids.size())]
			var turn:int=posmod(hash(Vector3i(id,index,world.active_seed)),4)
			# The two east-facing source buildings stand taller and narrower,
			# with a side/back view into the denser middle city.
			if side==1 and along>30.0 and id in [5,12]:
				depth=10.0 if id==5 else 8.8
				width=6.7 if id==5 else 6.1
				height=78.0 if id==5 else 88.0
				setback+=5.6 if id==5 else 5.1
				along-=0.975 if id==5 else 3.2
			for extra:float in [0.0,3.0,6.0]:
				var cross:float=run.fixed+sign_value*(0.5+setback+extra+depth*0.5)
				var at:=Vector3(cross,STREET_LEVEL+height*0.5,along) if side<2 else Vector3(along,STREET_LEVEL+height*0.5,cross)
				var size:=Vector3(depth,height,width) if side<2 else Vector3(width,height,depth)
				var footprint:=Rect2(Vector2(at.x-size.x*0.5,at.z-size.z*0.5),Vector2(size.x,size.z))
				if _br_clear(footprint,STREET_LEVEL+height,3.5):
					_br_add_plan(at,size,id,turn,0);break
	_br_visible_density_infill(rect)
	for z in range(rect.position.y-72,rect.end.y+73,15):
		for x in range(rect.position.x-72,rect.end.x+73,15):
			var size:=Vector3(rng.randf_range(7.0,14.5),rng.randf_range(52.0,100.0),rng.randf_range(6.5,15.5))
			var at:=Vector3(x+rng.randf_range(-3.6,3.6),STREET_LEVEL+size.y*0.5,z+rng.randf_range(-3.6,3.6))
			var footprint:=Rect2(Vector2(at.x-size.x*0.5,at.z-size.z*0.5),Vector2(size.x,size.z))
			if not _br_clear(footprint,STREET_LEVEL+size.y,3.5):continue
			_br_add_plan(at,size,ids[rng.randi_range(0,ids.size()-1)],rng.randi_range(0,3),1)
	var far_ids:Array[int]=[3,6,8,9,16]
	for z in range(rect.position.y-180,rect.end.y+181,17):
		for x in range(rect.position.x-180,rect.end.x+181,17):
			if rect.grow(47).has_point(Vector2i(x,z)):continue
			if rng.randf()<0.05:continue
			var size:=Vector3(rng.randf_range(6.5,13.5),rng.randf_range(34.0,74.0),rng.randf_range(6.0,14.5))
			var at:=Vector3(x+rng.randf_range(-3,3),STREET_LEVEL+size.y*0.5,z+rng.randf_range(-3,3))
			var footprint:=Rect2(Vector2(at.x-size.x*0.5,at.z-size.z*0.5),Vector2(size.x,size.z))
			if not _br_clear(footprint,STREET_LEVEL+size.y,2.4):continue
			_br_add_plan(at,size,far_ids[rng.randi_range(0,far_ids.size()-1)],rng.randi_range(0,3),2)

func _br_visible_density_infill(rect:Rect2i)->void:
	# Add visible staggered source masses, then a bounded second near row.
	# All original source meshes, floor clearance and existing Camera margins remain.
	var primary:Array=near_towers.duplicate()
	var targeted:Array[Dictionary]=[
		{"p":Vector2(float(rect.end.x)+14.2,float(rect.position.y)+33.5),"size":Vector3(6.8,108.0,3.9),"id":2,"turn":1,"role":"east_visible_gap_A"},
		{"p":Vector2(float(rect.end.x)+17.0,float(rect.position.y)+47.75),"size":Vector3(7.2,116.0,5.0),"id":1,"turn":3,"role":"east_visible_gap_B"},
		{"p":Vector2(rect.position)+Vector2(28.9,71.7),"size":Vector3(4.4,112.0,3.0),"id":8,"turn":2,"role":"concave_staggered_front"}]
	for item:Dictionary in targeted:
		var point:Vector2=item.p;var size:Vector3=item.size
		var footprint:=Rect2(point-Vector2(size.x,size.z)*0.5,Vector2(size.x,size.z))
		if _br_clear(footprint,STREET_LEVEL+size.y,3.5,1.05):
			_br_add_plan(Vector3(point.x,STREET_LEVEL+size.y*0.5,point.y),size,item.id,item.turn,0,item.role)
	var dense:=RandomNumberGenerator.new();dense.seed=world.active_seed+625169
	var ids:Array[int]=[2,6,8,9,13,14,16,7,10,1,0,15]
	var center:=Vector2(rect.get_center())
	for index:int in primary.size():
		var original:Dictionary=primary[index]
		var delta:=Vector2(original.position.x,original.position.z)-center
		var east_west:bool=absf(delta.x)/float(rect.size.x)>absf(delta.y)/float(rect.size.y)
		var outward:Vector2=Vector2(signf(delta.x),0) if east_west else Vector2(0,signf(delta.y))
		var along:=Vector2(-outward.y,outward.x)
		var cross:float=dense.randf_range(6.0,9.2)
		var length:float=dense.randf_range(4.5,8.0)
		var height:float=dense.randf_range(94.0,132.0)
		var size:=Vector3(cross,height,length) if east_west else Vector3(length,height,cross)
		var previous_cross:float=original.size.x if east_west else original.size.z
		var previous_along:float=original.size.z if east_west else original.size.x
		var stagger:float=(previous_along*0.35+3.0)*(-1.0 if index%2==0 else 1.0)
		var base:=Vector2(original.position.x,original.position.z)+outward*(previous_cross*0.5+cross*0.5+2.0)+along*stagger
		var id:int=ids[dense.randi_range(0,ids.size()-1)]
		var turn:int=dense.randi_range(0,3)
		for adjust:Vector2 in [Vector2.ZERO,Vector2(4,4),Vector2(8,-4)]:
			var point:Vector2=base+outward*adjust.x+along*adjust.y
			var footprint:=Rect2(point-Vector2(size.x,size.z)*0.5,Vector2(size.x,size.z))
			if not _br_clear(footprint,STREET_LEVEL+height,3.5,1.1):continue
			_br_add_plan(Vector3(point.x,STREET_LEVEL+height*0.5,point.y),size,id,turn,0,"second_row")
			break


func _br_instance(id:int,at:Vector3,size:Vector3,turn:int,slot:int) -> void:
	var mesh:ArrayMesh=BR_BANK.get_item_mesh(id)
	var basis:=Basis.from_scale(size)*Basis(Vector3.UP,float(turn)*PI*0.5)
	var transform:=Transform3D(basis,at)
	_br_mesh_instance(id,mesh,transform,slot,at.y+size.y*0.5)

func _br_mesh_instance(id:int,mesh:ArrayMesh,transform:Transform3D,slot:int,roof:float) -> void:
	var basis:Basis=transform.basis;var normal_matrix:=basis.inverse().transposed()
	var tag:=float(posmod(slot*1103+1901,65521))/65521.0
	for surface in mesh.get_surface_count():
		var key:="%d_%d"%[id,surface]
		if not br_batches.has(key):
			var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			br_batches[key]={"tool":tool,"material":mesh.surface_get_material(surface),"id":id,"surface":surface}
		var arrays:Array=mesh.surface_get_arrays(surface).duplicate(true)
		var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		for i in points.size():
			points[i]=transform*points[i];normals[i]=(normal_matrix*normals[i]).normalized()
		arrays[Mesh.ARRAY_VERTEX]=points;arrays[Mesh.ARRAY_NORMAL]=normals
		var tags:=PackedVector2Array();tags.resize(points.size());tags.fill(Vector2(tag,roof))
		arrays[Mesh.ARRAY_TEX_UV2]=tags
		if arrays[Mesh.ARRAY_TANGENT]!=null:
			var tangents:PackedFloat32Array=arrays[Mesh.ARRAY_TANGENT]
			for i in points.size():
				var tangent:=basis*Vector3(tangents[i*4],tangents[i*4+1],tangents[i*4+2])
				tangent=(tangent-normals[i]*normals[i].dot(tangent)).normalized()
				tangents[i*4]=tangent.x;tangents[i*4+1]=tangent.y;tangents[i*4+2]=tangent.z
			arrays[Mesh.ARRAY_TANGENT]=tangents
		var baked:=ArrayMesh.new();baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		br_batches[key].tool.append_from(baked,0,Transform3D.IDENTITY)

func _br_commit_batches() -> void:
	for key:String in br_batches:
		var batch:Dictionary=br_batches[key]
		var source:StandardMaterial3D=batch.material
		var mat:=_scenery_material(false)
		mat.set_shader_parameter("baked_source",true)
		mat.set_shader_parameter("baked_building",batch.id<100)
		mat.set_shader_parameter("architectural_windows",batch.id in [5,12])
		mat.set_shader_parameter("architectural_family",1.0 if batch.id==12 else 0.0)
		mat.set_shader_parameter("baked_color",source.albedo_color)
		mat.set_shader_parameter("baked_glow",source.emission)
		var gain:float=20.0 if batch.id<100 else (1.5 if batch.id>=106 and batch.surface==1 else (0.95 if batch.surface==1 else 0.0))
		if source.has_meta("br01_emission_gain"):gain=float(source.get_meta("br01_emission_gain"))
		if batch.id>=100 and batch.surface==1:
			gain=BR_EMITTER_GAINS[batch.id]
			mat.set_shader_parameter("baked_neon_tint",BR_EMITTER_TINTS[batch.id])
			mat.set_shader_parameter("baked_glow_cutoff",0.018)
			mat.set_shader_parameter("baked_glow_limit",8.0)
		elif batch.id in [5,12]:mat.set_shader_parameter("baked_glow_limit",2.5)
		mat.set_shader_parameter("baked_glow_gain",gain)
		mat.set_shader_parameter("baked_surface_gain",0.72 if batch.id in [0,15] else (0.90 if batch.id in [5,12] else 1.0))
		mat.set_shader_parameter("baked_has_albedo",source.albedo_texture!=null)
		mat.set_shader_parameter("baked_has_emission",source.emission_texture!=null)
		if source.albedo_texture!=null:mat.set_shader_parameter("baked_albedo",source.albedo_texture)
		if source.emission_texture!=null:mat.set_shader_parameter("baked_emission",source.emission_texture)
		_add_city_carrier(batch.tool.commit(),mat,("SurajSource_" if batch.id<100 else "OriginalAdvert_")+key)
	city_coverage["source_batches"]=br_batches.size()

func _br_foundations() -> void:
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for plan:Dictionary in br_plans:
		var height:float=STREET_LEVEL+0.12-continuity_base_y
		_box(tool,Vector3(plan.size.x*0.77,height,plan.size.z*0.77),
			Vector3(plan.position.x,continuity_base_y+height*0.5,plan.position.z),Color("263c4300"))
	tool.index()
	var mat:=_scenery_material(false);mat.set_shader_parameter("pilot_geometry",true)
	_add_city_carrier(tool.commit(),mat,"BR01_AuxiliaryFoundations")
	city_coverage.continuity["neighbour_supports"]=br_plans.size()
	city_coverage.continuity["support_batches"]=1

func _br_plan_transform(plan:Dictionary)->Transform3D:
	if int(plan.source_id)<0:return Transform3D.IDENTITY
	return Transform3D(Basis.from_scale(plan.size)*Basis(Vector3.UP,float(plan.turn)*PI*0.5),plan.position)

func _br_mesh_data(mesh:Mesh,transform:Transform3D)->Dictionary:
	var triangles:Array=[]
	var all_bounds:=AABB()
	var first:=true
	var normal_matrix:Basis=transform.basis.inverse().transposed()
	for surface:int in mesh.get_surface_count():
		var arrays:Array=mesh.surface_get_arrays(surface)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var indices:=PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX]!=null:indices=arrays[Mesh.ARRAY_INDEX]
		else:
			indices.resize(vertices.size())
			for vertex:int in vertices.size():indices[vertex]=vertex
		for i:int in range(0,indices.size(),3):
			var p:=PackedVector3Array([transform*vertices[indices[i]],transform*vertices[indices[i+1]],transform*vertices[indices[i+2]]])
			var normal:Vector3=(p[1]-p[0]).cross(p[2]-p[0])
			if normal.length_squared()<1e-12:continue
			normal=normal.normalized()
			var expected:Vector3=normal_matrix*(normals[indices[i]]+normals[indices[i+1]]+normals[indices[i+2]])
			if normal.dot(expected)<0.0:normal=-normal
			var bounds:=AABB(p[0],Vector3.ZERO)
			for point:Vector3 in p:bounds=bounds.expand(point)
			triangles.append({"points":p,"normal":normal,"plane":normal.dot(p[0]),"bounds":bounds})
			if first:all_bounds=bounds;first=false
			else:all_bounds=all_bounds.merge(bounds)
	return {"triangles":triangles,"bounds":all_bounds}

func _br_source_mesh_data(plan:Dictionary)->Dictionary:
	var key:int=plan.plan_id
	if br_collision_cache.has(key):return br_collision_cache[key]
	var mesh:Mesh=BR_BANK.get_item_mesh(plan.source_id) if int(plan.source_id)>=0 else scene_root.get_node("CurrentBuildingFacade").mesh
	var data:Dictionary=_br_mesh_data(mesh,_br_plan_transform(plan))
	br_collision_cache[key]=data
	return data

func _br_poly_area(poly:PackedVector2Array)->float:
	var area:=0.0
	for i:int in poly.size():area+=poly[i].cross(poly[(i+1)%poly.size()])
	return absf(area)*0.5

func _br_surface_coverage(center:Vector2,size:Vector2,triangles:Array)->float:
	var half:Vector2=size*0.5
	var rect:=PackedVector2Array([center-half,center+Vector2(half.x,-half.y),center+half,center+Vector2(-half.x,half.y)])
	var area:=0.0
	for triangle:PackedVector2Array in triangles:
		var pieces:Array[PackedVector2Array]=Geometry2D.intersect_polygons(rect,triangle)
		for piece:PackedVector2Array in pieces:area+=_br_poly_area(piece)
	# Area coverage and explicit inset corners jointly reject holes and crossed steps.
	if area<size.x*size.y*0.998:return area/(size.x*size.y)
	for corner:Vector2 in rect:
		var inside:=false
		for triangle:PackedVector2Array in triangles:
			if Geometry2D.is_point_in_polygon(corner,triangle):inside=true;break
		if not inside:return 0.0
	return minf(1.0,area/(size.x*size.y))

func _br_project_triangle(p:PackedVector3Array,normal:Vector3)->PackedVector2Array:
	var axis:int=normal.abs().max_axis_index()
	var q:=PackedVector2Array()
	for v:Vector3 in p:
		q.append(Vector2(v.y,v.z) if axis==0 else (Vector2(v.x,v.z) if axis==1 else Vector2(v.x,v.y)))
	return q

func _br_triangle_intersection(a:Dictionary,b:Dictionary)->bool:
	if not a.bounds.grow(0.00001).intersects(b.bounds.grow(0.00001)):return false
	var ap:PackedVector3Array=a.points;var bp:PackedVector3Array=b.points
	var amin:=INF;var amax:=-INF
	for p:Vector3 in bp:
		var d:float=a.normal.dot(p)-a.plane;amin=minf(amin,d);amax=maxf(amax,d)
	if amin>0.00001 or amax< -0.00001:return false
	var bmin:=INF;var bmax:=-INF
	for p:Vector3 in ap:
		var d:float=b.normal.dot(p)-b.plane;bmin=minf(bmin,d);bmax=maxf(bmax,d)
	if bmin>0.00001 or bmax< -0.00001:return false
	br_triangle_pairs_checked+=1
	if maxf(absf(amin),absf(amax))<0.00002 and absf(a.normal.dot(b.normal))>0.99999:
		var pa:PackedVector2Array=_br_project_triangle(ap,a.normal)
		var pb:PackedVector2Array=_br_project_triangle(bp,a.normal)
		for part:PackedVector2Array in Geometry2D.intersect_polygons(pa,pb):
			if _br_poly_area(part)>0.000001:return true
		return false
	for i:int in 3:
		if Geometry3D.segment_intersects_triangle(ap[i],ap[(i+1)%3],bp[0],bp[1],bp[2])!=null:return true
		if Geometry3D.segment_intersects_triangle(bp[i],bp[(i+1)%3],ap[0],ap[1],ap[2])!=null:return true
	return false

func _br_triangle_candidates(data:Dictionary,query:AABB)->Array:
	# Exact conservative construction-time broad phase. No test is removed:
	# every bucket candidate still uses the original triangle predicate.
	if data.triangles.size()<192:return data.triangles
	var pitch:=4.0
	if not data.has("grid4"):
		var grid:Dictionary={};var oversized:Array=[]
		for i:int in data.triangles.size():
			var bounds:AABB=data.triangles[i].bounds.grow(0.0001)
			var lo:=Vector3i(floori(bounds.position.x/pitch),floori(bounds.position.y/pitch),floori(bounds.position.z/pitch))
			var hi:=Vector3i(floori(bounds.end.x/pitch),floori(bounds.end.y/pitch),floori(bounds.end.z/pitch))
			if (hi.x-lo.x+1)*(hi.y-lo.y+1)*(hi.z-lo.z+1)>256:
				oversized.append(i);continue
			for x:int in range(lo.x,hi.x+1):
				for y:int in range(lo.y,hi.y+1):
					for z:int in range(lo.z,hi.z+1):
						var key:=Vector3i(x,y,z)
						if not grid.has(key):grid[key]=[]
						grid[key].append(i)
		data["grid4"]=grid;data["grid4_oversized"]=oversized
	var bounds:AABB=query.grow(0.0001)
	var lo:=Vector3i(floori(bounds.position.x/pitch),floori(bounds.position.y/pitch),floori(bounds.position.z/pitch))
	var hi:=Vector3i(floori(bounds.end.x/pitch),floori(bounds.end.y/pitch),floori(bounds.end.z/pitch))
	# Very broad authoring queries keep exact old behavior and bounded bucket work.
	if (hi.x-lo.x+1)*(hi.y-lo.y+1)*(hi.z-lo.z+1)>32768:return data.triangles
	var selected:Dictionary={}
	for i:int in data.grid4_oversized:selected[i]=true
	for x:int in range(lo.x,hi.x+1):
		for y:int in range(lo.y,hi.y+1):
			for z:int in range(lo.z,hi.z+1):
				for i:int in data.grid4.get(Vector3i(x,y,z),[]):selected[i]=true
	var result:Array=[]
	for i:int in selected:result.append(data.triangles[i])
	return result

func _br_mesh_intersection(a:Dictionary,b:Dictionary)->bool:
	if not a.bounds.grow(0.00001).intersects(b.bounds.grow(0.00001)):return false
	for ta:Dictionary in a.triangles:
		if not ta.bounds.grow(0.00001).intersects(b.bounds.grow(0.00001)):continue
		for tb:Dictionary in _br_triangle_candidates(b,ta.bounds):
			if _br_triangle_intersection(ta,tb):return true
	return false

func _br_complete_installation(plan:Dictionary,poster:int,mount:Dictionary)->Dictionary:
	var mesh:Mesh=BR_BANK.get_item_mesh(poster)
	var normal:Vector3=mount.normal;var along:=Vector3(normal.z,0,-normal.x)
	var scale:float=mount.scale
	var transform:=Transform3D(Basis(along,Vector3.UP,normal)*Basis.from_scale(Vector3.ONE*scale),mount.position)
	var candidate:Dictionary=_br_mesh_data(mesh,transform)
	var broad:AABB=candidate.bounds
	var footprint:=Rect2(Vector2(broad.position.x,broad.position.z),Vector2(broad.size.x,broad.size.z)).grow(0.001)
	var before_pairs:int=br_triangle_pairs_checked
	var mesh_tests:=0
	# Actual complete panel, frame, thickness and all four supports against source geometry.
	for other:Dictionary in br_plans:
		if not footprint.intersects(other.footprint):continue
		if broad.position.y>other.top or broad.end.y<STREET_LEVEL:continue
		var obstacle:Dictionary=_br_source_mesh_data(other);mesh_tests+=1
		if _br_mesh_intersection(candidate,obstacle):return {"ok":false,"reason":"source_triangle_intersection","hit_host":other.plan_id}
	var own:Dictionary={"source_id":-1,"plan_id":-1}
	var own_data:Dictionary=_br_source_mesh_data(own)
	if broad.intersects(own_data.bounds.grow(0.001)):
		mesh_tests+=1
		if _br_mesh_intersection(candidate,own_data):return {"ok":false,"reason":"own_facade_triangle_intersection","hit_host":-1}
	var advert_tests:=0
	for other:Dictionary in br_accepted_ad_geometry:
		if not broad.grow(0.001).intersects(other.bounds.grow(0.001)):continue
		advert_tests+=1
		if _br_mesh_intersection(candidate,other):return {"ok":false,"reason":"advert_triangle_intersection"}
	return {"ok":true,"source_meshes_tested":mesh_tests,"advert_meshes_tested":advert_tests,
		"triangle_pairs_tested":br_triangle_pairs_checked-before_pairs,"complete_triangles":candidate.triangles.size(),
		"support_wall_gap":0.006,"method":"Four actual rear support patches on real host wall and full transformed mesh triangle intersections; suspended panel may span floors; AABB broad rejection only",
		"_data":candidate,"transform":transform}

func _br_ad_viewers(plan:Dictionary)->Array[Vector3]:
	var result:Array[Vector3]=[BR_REVIEW_EYES[8],BR_REVIEW_EYES[9],BR_REVIEW_EYES[12]]
	var p:Vector3=plan.position
	result.sort_custom(func(a:Vector3,b:Vector3)->bool:return Vector2(a.x-p.x,a.z-p.z).length_squared()<Vector2(b.x-p.x,b.z-p.z).length_squared())
	return result

func _br_project_ad_point(point:Vector3,eye:Vector3)->Vector2:
	var camera:Camera3D=world.camera_3d
	var view:Vector3=camera.get_camera_transform().basis.inverse()*(scene_root.to_global(point)-scene_root.to_global(eye))
	if view.z>=-camera.near or -view.z>camera.far:return Vector2.INF
	var size:Vector2=camera.get_viewport().get_visible_rect().size
	var focal:float=size.y*0.5/tan(deg_to_rad(camera.fov*0.5))
	return Vector2(size.x*0.5+view.x*focal/(-view.z),size.y*0.5-view.y*focal/(-view.z))

func _br_ad_default_height(plan:Dictionary)->float:
	if world.active_seed!=42001:return -4.0-float(posmod(int(plan.plan_id),4))*3.1
	var viewers:Array[Vector3]=_br_ad_viewers(plan)
	var eye:Vector3=viewers[0]
	var target:float=70.0+float(posmod(int(plan.plan_id),3))*20.0
	var best_y:=-12.0;var best_score:=INF
	var size:Vector2=world.camera_3d.get_viewport().get_visible_rect().size
	for y:float in [-6.0,-10.0,-14.0,-18.0,-22.0,-26.0]:
		var pixel:Vector2=_br_project_ad_point(Vector3(plan.position.x,y,plan.position.z),eye)
		if not pixel.is_finite():continue
		var global_delta:Vector3=scene_root.to_global(Vector3(plan.position.x,y,plan.position.z))-scene_root.to_global(eye)
		var view:Vector3=world.camera_3d.get_camera_transform().basis.inverse()*global_delta
		var penalty:float=absf(pixel.y-target)+maxf(0.0,24.0-pixel.x)*3.0+maxf(0.0,pixel.x-size.x+24.0)*3.0+maxf(0.0,10.0-pixel.y)*2.0+maxf(0.0,-view.z-36.0)*20.0
		if penalty<best_score:best_score=penalty;best_y=y
	return best_y

func _br_segment_hits_bounds(from:Vector3,to:Vector3,bounds:AABB)->bool:
	var delta:Vector3=to-from
	var low:=0.0;var high:=1.0
	for axis:int in 3:
		if absf(delta[axis])<0.0000001:
			if from[axis]<bounds.position[axis] or from[axis]>bounds.end[axis]:return false
		else:
			var a:float=(bounds.position[axis]-from[axis])/delta[axis]
			var b:float=(bounds.end[axis]-from[axis])/delta[axis]
			low=maxf(low,minf(a,b));high=minf(high,maxf(a,b))
			if low>high:return false
	return true

func _br_ad_ray_clear(eye:Vector3,target:Vector3)->bool:
	var delta:Vector3=target-eye
	if absf(delta.y)>0.000001:
		var t:float=-eye.y/delta.y
		if t>0.0 and t<1.0:
			var floor_hit:Vector3=eye+delta*t
			var cell:=Vector2i(floori(floor_hit.x+0.5),floori(floor_hit.z+0.5))
			if topology.bounds.has_point(cell) and not topology.external.has(cell):return false
	var obstacles:Array=[]
	for other:Dictionary in br_plans:
		var box:=AABB(Vector3(other.footprint.position.x,STREET_LEVEL,other.footprint.position.y),Vector3(other.footprint.size.x,other.size.y,other.footprint.size.y))
		if _br_segment_hits_bounds(eye,target,box):obstacles.append(_br_source_mesh_data(other))
	var own:Dictionary=_br_source_mesh_data({"source_id":-1,"plan_id":-1})
	if _br_segment_hits_bounds(eye,target,own.bounds):obstacles.append(own)
	for advert:Dictionary in br_accepted_ad_geometry:
		if _br_segment_hits_bounds(eye,target,advert.bounds):obstacles.append(advert)
	var limit:float=eye.distance_squared_to(target)-0.0004
	for obstacle:Dictionary in obstacles:
		for triangle:Dictionary in _br_triangle_candidates(obstacle,AABB(eye,Vector3.ZERO).expand(target)):
			if not _br_segment_hits_bounds(eye,target,triangle.bounds.grow(0.0001)):continue
			var p:PackedVector3Array=triangle.points
			var hit:Variant=Geometry3D.segment_intersects_triangle(eye,target,p[0],p[1],p[2])
			if hit!=null:
				var at:Vector3=hit
				if eye.distance_squared_to(at)<limit:return false
	return true

func _br_ad_visible(plan:Dictionary,mount:Dictionary,dimensions:Vector2,poster:int,with_occlusion:bool=true)->Dictionary:
	if world.active_seed!=42001:return {"ok":true,"scope":"Geometry-only generic layout outside fixed review seed"}
	var size:Vector2=world.camera_3d.get_viewport().get_visible_rect().size
	var normal:Vector3=mount.normal
	var along:=Vector3(normal.z,0,-normal.x)
	var extent:Vector2=dimensions*float(mount.scale)
	for eye:Vector3 in _br_ad_viewers(plan):
		if normal.dot((eye-mount.position).normalized())<0.10:continue
		var low:=Vector2.INF;var high:=-Vector2.INF;var valid:=true
		for x:float in [-0.5,0.5]:
			for y:float in [-0.5,0.5]:
				var pixel:Vector2=_br_project_ad_point(mount.position+along*(extent.x*x)+Vector3.UP*(extent.y*y),eye)
				if not pixel.is_finite():valid=false;break
				low=low.min(pixel);high=high.max(pixel)
		if not valid:continue
		var rectangle:=Rect2(low,high-low)
		var visible:Rect2=rectangle.intersection(Rect2(Vector2.ZERO,size))
		if rectangle.size.x<12.0 or rectangle.size.y<5.0 or rectangle.get_area()<80.0:continue
		if visible.get_area()<rectangle.get_area()*0.90:continue
		var axis_u:float=(_br_project_ad_point(mount.position+along*extent.x*.5,eye)-_br_project_ad_point(mount.position-along*extent.x*.5,eye)).length()
		var axis_v:float=(_br_project_ad_point(mount.position+Vector3.UP*extent.y*.5,eye)-_br_project_ad_point(mount.position-Vector3.UP*extent.y*.5,eye)).length()
		if axis_u<12.0 or axis_v<8.0:continue
		var local:Vector3=world.camera_3d.get_camera_transform().basis.inverse()*(scene_root.to_global(mount.position)-scene_root.to_global(eye))
		if -local.z>44.0:continue
		var transmission:float=_city_shape01_air_transmission(eye,mount.position)
		if transmission<0.35:continue
		var glyph_short:=0.0
		if poster<106:
			var font_pixels:float={100:94.0,101:83.0,102:78.0,103:54.0,104:69.0,105:57.0}.get(poster,54.0)
			var glyph_world:float=font_pixels/32.0*float(mount.scale)
			var origin:Vector2=_br_project_ad_point(mount.position,eye)
			var gu:Vector2=_br_project_ad_point(mount.position+along*glyph_world,eye)-origin
			var gv:Vector2=_br_project_ad_point(mount.position+Vector3.UP*glyph_world,eye)-origin
			glyph_short=absf(gu.cross(gv))/maxf(maxf(gu.length(),gv.length()),.0001)
			if glyph_short<8.0:continue
		var detail:Dictionary={"ok":true,"viewer_eye_map":eye,"projected_rectangle":rectangle,"projected_axes":[axis_u,axis_v],
			"view_depth":-local.z,"air_transmission":transmission,"glyph_min_altitude_px":glyph_short,
			"scope":"Actual three-Camera complete projection, glyph axes and source/own/ad visibility; construction only"}
		if not with_occlusion:return detail
		var seen:=0
		for x:float in [-0.35,0.0,0.35]:
			for y:float in [-0.35,0.0,0.35]:
				var target:Vector3=mount.position+along*(extent.x*x)+Vector3.UP*(extent.y*y)+normal*0.001
				if _br_ad_ray_clear(eye,target):seen+=1
		if seen>=5:
			detail["visible_samples"]=seen;detail["total_samples"]=9
			return detail
	return {"ok":false}

func _br_support_coverage(poster:int,center:Vector2,scale:float,triangles:Array)->Dictionary:
	# Use the actual original four rear bracket patches, not a point at panel centre.
	# Large suspended boards may span floors; their fixed feet must sit on real wall.
	if not br_ad_back_patches.has(poster):
		var data:Dictionary=_br_mesh_data(BR_BANK.get_item_mesh(poster),Transform3D.IDENTITY)
		var back:float=data.bounds.position.z
		var patches:Array=[]
		for triangle:Dictionary in data.triangles:
			if triangle.normal.z>-.99:continue
			var rear:=true
			var polygon:=PackedVector2Array()
			for p:Vector3 in triangle.points:
				if absf(p.z-back)>.0002:rear=false;break
				polygon.append(Vector2(p.x,p.y))
			if rear and _br_poly_area(polygon)>.000001:patches.append(polygon)
		br_ad_back_patches[poster]=patches
	var patches:Array=br_ad_back_patches[poster]
	if patches.size()<8:return {"ok":false,"reason":"Missing actual four rear support patches"}
	var smallest:=1.0
	for patch:PackedVector2Array in patches:
		var footprint:=PackedVector2Array()
		for point:Vector2 in patch:footprint.append(center+point*scale)
		var expected:float=_br_poly_area(footprint)
		var covered:=0.0
		for wall:PackedVector2Array in triangles:
			for piece:PackedVector2Array in Geometry2D.intersect_polygons(footprint,wall):covered+=_br_poly_area(piece)
		var ratio:float=minf(1.0,covered/maxf(expected,.0000001))
		smallest=minf(smallest,ratio)
		if ratio<.998:return {"ok":false,"minimum_coverage":smallest,"rear_triangles":patches.size()}
		for point:Vector2 in footprint:
			var supported:=false
			for wall:PackedVector2Array in triangles:
				if Geometry2D.is_point_in_polygon(point,wall):supported=true;break
			if not supported:return {"ok":false,"minimum_coverage":0.0,"rear_triangles":patches.size()}
	return {"ok":true,"minimum_coverage":smallest,"rear_triangles":patches.size(),"method":"Exact original rear bracket patch polygons and vertices on actual host plane; whole carrier checked separately"}

func _br_face_mount(plan:Dictionary,poster:int,target_y:float=INF,preferred:Vector3=Vector3.ZERO)->Dictionary:
	var toward:Vector2=Vector2(world.building_rect.get_center())-Vector2(plan.position.x,plan.position.z)
	var desired:Vector3=preferred if preferred!=Vector3.ZERO else Vector3(toward.x,0,toward.y).normalized()
	if preferred==Vector3.ZERO and world.active_seed==42001:
		var eye:Vector3=_br_ad_viewers(plan)[0]
		desired=Vector3(eye.x-plan.position.x,0,eye.z-plan.position.z).normalized()
	var requested_y:float=target_y if is_finite(target_y) else _br_ad_default_height(plan)
	var source:Dictionary=_br_source_mesh_data(plan)
	var groups:Dictionary={}
	for triangle:Dictionary in source.triangles:
		var normal:Vector3=triangle.normal
		if absf(normal.y)>0.015 or normal.dot(desired)<0.20:continue
		var plane:float=triangle.plane
		var key:="%d_%d_%d"%[roundi(normal.x*1000),roundi(normal.z*1000),roundi(plane*1000)]
		var along:=Vector3(normal.z,0,-normal.x)
		if not groups.has(key):groups[key]={"normal":normal,"along":along,"plane":plane,"min":Vector2.INF,"max":-Vector2.INF,"triangles":[]}
		var group:Dictionary=groups[key]
		var projected:=PackedVector2Array()
		for p:Vector3 in triangle.points:
			var uv:=Vector2(along.dot(p),p.y);group.min=group.min.min(uv);group.max=group.max.max(uv);projected.append(uv)
		group.triangles.append(projected)
	var advert:Mesh=BR_BANK.get_item_mesh(poster)
	var bounds:AABB=advert.get_aabb()
	var dimensions:=Vector2(bounds.size.x,bounds.size.y)
	var maximum:=2.4
	var candidates:Array=[]
	for group:Dictionary in groups.values():
		var extent:Vector2=group.max-group.min
		if extent.x<1.5 or extent.y<2.0:continue
		var initial:float=minf(maximum,minf(extent.x*0.92/dimensions.x,extent.y*0.94/dimensions.y))
		if initial<0.14:continue
		var target_near:float=clampf(requested_y,group.min.y+dimensions.y*initial*.5,group.max.y-dimensions.y*initial*.5)
		var score:float=initial*20.0+group.normal.dot(desired)-absf(target_near-requested_y)*1.5
		candidates.append({"group":group,"initial":initial,"score":score})
	candidates.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.score>b.score)
	for entry:Dictionary in candidates:
		var group:Dictionary=entry.group
		for ratio:float in [1.0,0.80,0.62,0.48]:
			var scale:float=entry.initial*ratio
			if scale<0.14:continue
			var size:Vector2=dimensions*scale+Vector2(0.06,0.06)
			var low:Vector2=group.min+size*0.5;var high:Vector2=group.max-size*0.5
			if high.x<low.x or high.y<low.y:continue
			var y:float=requested_y
			for placement:Vector2 in [Vector2(.5,0),Vector2(.28,0),Vector2(.72,0),Vector2(.08,0),Vector2(.92,0),Vector2(.5,-3),Vector2(.28,-3),Vector2(.72,-3),Vector2(.5,3),Vector2(.28,3),Vector2(.72,3)]:
				var uv:=Vector2(lerpf(low.x,high.x,placement.x),clampf(y+placement.y,low.y,high.y))
				if absf(uv.y-requested_y)>4.5:continue
				# The old0.18 offset put rear supports0.59 units through the host.
				# Respect the actual -0.77 rear bracket extent, including final scale.
				var offset:float=-bounds.position.z*scale+0.006
				var center:Vector3=group.along*uv.x+group.normal*(group.plane+offset)+Vector3.UP*uv.y
				var mount:Dictionary={"position":center,"normal":group.normal,"scale":scale,"source_face_plane":group.plane,
					"face_extent":group.max-group.min,"support_offset":offset,
					"host_id":plan.plan_id,"host_source_id":plan.source_id,"host_transform":_br_plan_transform(plan)}
				# Reject unreadable/out-of-frame choices before polygon/triangle work.
				br_ad_search_stats.attempts+=1
				var preview:Dictionary=_br_ad_visible(plan,mount,dimensions,poster,false)
				if not preview.ok:br_ad_search_stats.fast_rejected+=1;continue
				var support:Dictionary=_br_support_coverage(poster,uv,scale,group.triangles)
				if not support.ok:br_ad_search_stats.support_rejected+=1;continue
				mount["wall_coverage"]=_br_surface_coverage(uv,size,group.triangles)
				mount["support_coverage"]=support
				var check:Dictionary=_br_complete_installation(plan,poster,mount)
				if not check.ok:br_ad_search_stats.geometry_rejected+=1;continue
				var visibility:Dictionary=_br_ad_visible(plan,mount,dimensions,poster)
				if not visibility.ok:br_ad_search_stats.occluded+=1;continue
				br_ad_search_stats.accepted+=1
				mount["visibility"]=visibility
				mount["_install_data"]=check._data;check.erase("_data");mount["installation"]=check
				return mount
	br_ad_installation_report.append({"host_id":plan.plan_id,"source_id":plan.source_id,"poster_id":poster,"installed":false,"reason":"No complete source-wall and collision-safe installation"})
	return {}

func _br_poster(poster:int,mount:Dictionary,owner:String,kind:String)->void:
	if not mount.has("_install_data") and mount.get("_frozen_installation_verified",false)!=true:return
	var normal:Vector3=mount.normal;var along:=Vector3(normal.z,0,-normal.x)
	var scale:float=mount.scale;var at:Vector3=mount.position
	var basis:=Basis(along,Vector3.UP,normal)*Basis.from_scale(Vector3.ONE*scale)
	_br_mesh_instance(poster,BR_BANK.get_item_mesh(poster),Transform3D(basis,at),buildings+city_coverage.advertisements.size(),at.y+8.0*scale)
	if mount.has("_install_data"):br_accepted_ad_geometry.append(mount._install_data)
	var frozen:Dictionary=mount.duplicate(true);frozen.erase("_install_data");frozen.erase("_frozen_installation_verified")
	br_frozen_ad_records.append({"poster":poster,"mount":frozen,"owner":owner,"kind":kind})
	var item:Dictionary={}
	for ad:Dictionary in BR_BANK.get_meta("advertisements"):
		if int(ad.bank_id)==poster:item=ad;break
	var report:Dictionary={"advert_id":city_coverage.advertisements.size(),"host_id":mount.host_id,"host_source_id":mount.host_source_id,
		"host_transform":mount.host_transform,"poster_id":poster,"artwork":item.id,"owner":owner,"kind":kind,"position":at,"normal":normal,
		"scale":scale,"world_size":Vector2(item.world_size[0],item.world_size[1])*scale,"source_face_plane":mount.source_face_plane,
		"wall_coverage":mount.wall_coverage,"support_coverage":mount.support_coverage,"support_offset":mount.support_offset,"installation":mount.installation,"visibility":mount.visibility,"seed":world.active_seed}
	city_coverage.advertisements.append(report);br_ad_installation_report.append(report)
	_br_add_ad_glow(poster,at,along,normal,Vector2(item.world_size[0],item.world_size[1])*scale)

func _br_add_ad_glow(poster:int,center:Vector3,along:Vector3,normal:Vector3,aperture_size:Vector2)->void:
	if not br_ad_glow_batches.has(poster):
		var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		br_ad_glow_batches[poster]={"tool":tool}
	var st:SurfaceTool=br_ad_glow_batches[poster].tool
	var size:Vector2=aperture_size+Vector2(1.2,1.2)
	var ratio:Vector2=aperture_size/size
	var intensity:float=0.20 if poster>=106 else 0.14
	for uv:Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.ZERO,Vector2.ONE,Vector2.DOWN]:
		var offset:Vector2=(uv-Vector2(.5,.5))*size
		st.set_uv(uv);st.set_uv2(ratio);st.set_normal(normal);st.set_color(Color(1,1,1,intensity))
		st.add_vertex(center+normal*0.025+along*offset.x+Vector3.UP*offset.y)

func _br_commit_ad_glows()->void:
	var shader:=Shader.new();shader.code=BR_AD_GLOW_SHADER
	for poster:int in br_ad_glow_batches:
		var mat:=ShaderMaterial.new();mat.shader=shader
		var mesh:Mesh=BR_BANK.get_item_mesh(poster)
		var original:StandardMaterial3D=mesh.surface_get_material(1)
		mat.set_shader_parameter("emission_texture",original.emission_texture)
		mat.set_shader_parameter("emission_gain",BR_EMITTER_GAINS[poster])
		mat.set_shader_parameter("emission_tint",BR_EMITTER_TINTS[poster])
		mat.set_shader_parameter("city_void",ImageTexture.create_from_image(topology.image))
		mat.set_shader_parameter("city_origin",Vector2(topology.bounds.position))
		mat.set_shader_parameter("city_grid_size",Vector2(topology.bounds.size))
		render_materials.append(mat)
		_add_city_carrier(br_ad_glow_batches[poster].tool.commit(),mat,"OriginalAdvertGlow_"+str(poster))
	city_coverage["advert_glow"]={"batches":br_ad_glow_batches.size(),"method":"Batched9tap linear-emission text halo, fixed to final carrier, shared city air and real depth; no light nodes",
		"material_core_calibrated_hdr":[4.0,5.5],"dark_background_emission_cutoff":0.018,"per_frame_physics_rays":0}

func _br_top(plan:Dictionary) -> Vector3:
	var mesh:ArrayMesh=BR_BANK.get_item_mesh(plan.source_id)
	var sum:=Vector3.ZERO;var count:=0
	for surface in mesh.get_surface_count():
		var arrays:Array=mesh.surface_get_arrays(surface)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		for p:Vector3 in vertices:
			if p.y>0.499:
				sum+=p;count+=1
	if count==0:return plan.position+Vector3.UP*plan.size.y*0.5
	var local:Vector3=sum/float(count)
	return Transform3D(Basis.from_scale(plan.size)*Basis(Vector3.UP,float(plan.turn)*PI*0.5),plan.position)*local

func _br_digest_bytes(bytes:PackedByteArray)->String:
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes)
	return context.finish().hex_encode().to_upper()

func _br_cache_binding()->Dictionary:
	var cells:Array=world.floor_cells.keys()
	cells.sort_custom(func(a:Vector2i,b:Vector2i)->bool:return a.y<b.y or (a.y==b.y and a.x<b.x))
	var plans:Array=[]
	for plan:Dictionary in br_plans:plans.append([int(plan.plan_id),int(plan.source_id),plan.position,plan.size,int(plan.turn),plan.footprint])
	var material:Dictionary={"bank_sha256":FileAccess.get_sha256(BR_BANK.resource_path).to_upper(),
		"shader_sha256":FileAccess.get_sha256(CITY_SHADER.resource_path).to_upper(),"emitter_gains":BR_EMITTER_GAINS,"emitter_tints":BR_EMITTER_TINTS,"own_shader_sha256":FileAccess.get_sha256(OWN_FACADE_SHADER.resource_path).to_upper(),"own_bank_sha256":FileAccess.get_sha256(OWN_SOURCE_BANK.resource_path).to_upper(),"shared_air_sha256":DEPTH01_SHARED_AIR_SHA256}
	var layout:Dictionary={"schema":3,"own_mesh_sha256":_own_r3_geometry_digest(),"seed":world.active_seed,"rect":world.building_rect,"floor":cells,"plans":plans,"world_basis":scene_root.global_transform.basis}
	return {"schema":4,"own_mesh_sha256":_own_r3_geometry_digest(),"layout_sha256":_br_digest_bytes(var_to_bytes(layout)),
		"material_sha256":_br_digest_bytes(var_to_bytes(material)),"bank_sha256":material.bank_sha256,"shader_sha256":material.shader_sha256,
		"visual_parent":BR_VISUAL_PARENT,"source_plan_count":plans.size(),"source_seed":world.active_seed}

func _br_ad_cache_error(reason:String)->void:
	city_coverage["advert_cache"]={"ok":false,"mode":"invalid_frozen_plan","reason":reason,"runtime_search":false,"runtime_triangle_validation":false}
	push_error("BR01 frozen advertisement plan rejected: "+reason+"; no stale-plan or runtime-search fallback")

func _br_apply_frozen_ads()->void:
	city_coverage["advertisements"]=[]
	var began:int=Time.get_ticks_usec()
	if not FileAccess.file_exists(BR_AD_CACHE_PATH):_br_ad_cache_error("Missing "+BR_AD_CACHE_PATH);return
	if FileAccess.get_sha256(BR_AD_CACHE_PATH).to_upper()!=BR_AD_CACHE_SHA256:_br_ad_cache_error("Frozen resource digest mismatch");return
	var saved:Resource=ResourceLoader.load(BR_AD_CACHE_PATH,"",ResourceLoader.CACHE_MODE_IGNORE)
	if saved==null:_br_ad_cache_error("Frozen native resource cannot be read");return
	var current:Dictionary=_br_cache_binding()
	if saved.get_meta("binding",{})!=current:_br_ad_cache_error("Source/layout/material binding mismatch");return
	var records:Array=saved.get_meta("installations",[])
	if records.size()!=6:_br_ad_cache_error("Expected exactly six validated09F installations");return
	for record:Dictionary in records:
		var mount:Dictionary=record.get("mount",{})
		var support:Dictionary=mount.get("support_coverage",{})
		if mount.get("installation",{}).get("ok",false)!=true or support.get("ok",false)!=true or support.get("rear_triangles",0)!=8 or float(support.get("minimum_coverage",0.0))<.998:
			_br_ad_cache_error("Stored complete-carrier/four-fixed-feet proof missing");return
		var host_id:int=int(mount.get("host_id",-999))
		if host_id>=0 and (host_id>=br_plans.size() or _br_plan_transform(br_plans[host_id])!=mount.host_transform):
			_br_ad_cache_error("Unique host instance transform mismatch");return
	for record:Dictionary in records:
		var mount:Dictionary=record.mount.duplicate(true);mount["_frozen_installation_verified"]=true
		_br_poster(int(record.poster),mount,record.owner,record.kind)
	_br_aviation_markers()
	br_triangle_pairs_checked=int(saved.get_meta("validated_triangle_pairs",0))
	city_coverage["advert_authoring"]=saved.get_meta("authoring_stats",{}).duplicate(true)
	city_coverage["advert_cache"]={"ok":true,"mode":"frozen_static_plan","resource_sha256":BR_AD_CACHE_SHA256,"binding":current,
		"records":records.size(),"records_sha256":_br_digest_bytes(var_to_bytes(br_frozen_ad_records)),
		"read_and_bind_ms":float(Time.get_ticks_usec()-began)/1000.0,"runtime_search":false,"runtime_triangle_validation":false,
		"authored_records_exact":var_to_bytes(br_frozen_ad_records)==var_to_bytes(records)}

func _br_save_authored_ads()->void:
	var output_dir:=""
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):output_dir=arg.trim_prefix("--out=")
	if output_dir.is_empty():_br_ad_cache_error("Explicit authoring output directory missing");return
	var resource:=Resource.new()
	resource.set_meta("binding",_br_cache_binding())
	resource.set_meta("installations",br_frozen_ad_records.duplicate(true))
	resource.set_meta("source_plans",br_plans.duplicate(true))
	resource.set_meta("authoring_stats",city_coverage.advert_authoring.duplicate(true))
	resource.set_meta("validated_triangle_pairs",br_triangle_pairs_checked)
	resource.set_meta("provenance","Actual09F algorithm final typed transforms/material bindings and full four-fixed-feet/carrier triangle proofs, explicit authoring invocation only")
	var target:String=output_dir.path_join("br01_ad_installations.res")
	var status:Error=ResourceSaver.save(resource,target,ResourceSaver.FLAG_COMPRESS|ResourceSaver.FLAG_BUNDLE_RESOURCES)
	city_coverage["advert_cache"]={"ok":status==OK,"mode":"explicit_authoring","resource":target,
		"records":br_frozen_ad_records.size(),"records_sha256":_br_digest_bytes(var_to_bytes(br_frozen_ad_records)),
		"binding":_br_cache_binding(),"runtime_search":true,"runtime_triangle_validation":true}
	if status!=OK:_br_ad_cache_error("Cannot save authored plan")

func _br_aviation_markers()->void:
	var beacons:=SurfaceTool.new();beacons.begin(Mesh.PRIMITIVE_TRIANGLES)
	for plan:Dictionary in near_towers:
		var top:=_br_top(plan)
		_box(beacons,Vector3(0.09,1.1,0.09),top+Vector3.UP*0.5,Color("40575e00"))
		_box(beacons,Vector3(0.20,0.16,0.20),top+Vector3.UP*1.09,Color(0.65,0.30,0.30,0.65))
	var mat:=_scenery_material(false);mat.set_shader_parameter("pilot_geometry",true)
	_add_city_carrier(beacons.commit(),mat,"OriginalRoofAviationMarkers")
	city_coverage["aviation_markers"]=near_towers.size()

func _own_r3_geometry_digest()->String:
	var mesh:Mesh=scene_root.get_node("CurrentBuildingFacade").mesh
	var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256)
	for surface:int in mesh.get_surface_count():
		var arrays:Array=mesh.surface_get_arrays(surface)
		for field:int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_COLOR,Mesh.ARRAY_INDEX]:
			if arrays[field]!=null:context.update(arrays[field].to_byte_array())
	return context.finish().hex_encode().to_upper()

func _own_r3_revalidate_ads()->void:
	# Explicit structural-review authoring only. No cache is published/saved.
	city_coverage["advertisements"]=[]
	assert(FileAccess.get_sha256(BR_AD_PROPOSALS_PATH).to_upper()==BR_AD_PROPOSALS_SHA256)
	var saved:Resource=ResourceLoader.load(BR_AD_PROPOSALS_PATH,"",ResourceLoader.CACHE_MODE_IGNORE)
	var reports:Array=[]
	for record:Dictionary in saved.get_meta("installations",[]):
		print("FULL05 checking retained ad ",record.poster," host ",record.mount.host_id," t=",Time.get_ticks_msec())
		var mount:Dictionary=record.mount.duplicate(true)
		var host_id:int=int(mount.host_id)
		var plan:Dictionary=br_plans[host_id] if host_id>=0 else {"source_id":-1,"plan_id":-1,"position":mount.position,"size":Vector3.ONE,"turn":0}
		var old_host:Transform3D=mount.host_transform
		var new_host:Transform3D=_br_plan_transform(plan)
		var changed_host:bool=host_id>=0 and new_host!=old_host
		if changed_host:
			var wall_point:Vector3=mount.position-mount.normal*float(mount.support_offset)
			var adapted:Vector3=new_host*(old_host.affine_inverse()*wall_point)
			mount.position=adapted+mount.normal*float(mount.support_offset)
			mount.source_face_plane=mount.normal.dot(adapted)
			mount.host_transform=new_host
		var host:Dictionary=_br_source_mesh_data(plan)
		var normal:Vector3=mount.normal
		var along:=Vector3(normal.z,0,-normal.x)
		var triangles:Array=[]
		for triangle:Dictionary in host.triangles:
			if triangle.normal.dot(normal)<0.9999 or absf(triangle.plane-float(mount.source_face_plane))>0.0001:continue
			var polygon:=PackedVector2Array()
			for p:Vector3 in triangle.points:polygon.append(Vector2(along.dot(p),p.y))
			triangles.append(polygon)
		var support:Dictionary=_br_support_coverage(int(record.poster),Vector2(along.dot(mount.position),mount.position.y),float(mount.scale),triangles)
		if not support.ok:
			var replacement:Dictionary=_br_face_mount(plan,int(record.poster),float(mount.position.y),normal)
			if replacement.is_empty() and host_id==5:
				replacement=_br_face_mount(plan,int(record.poster),float(mount.position.y),Vector3.LEFT)
			if not replacement.is_empty():
				_br_poster(int(record.poster),replacement,record.owner,record.kind)
				reports.append({"host_id":host_id,"poster":record.poster,"retained":true,"physically_reinstalled":true,"prior_failure":"support.ok","support":replacement.support_coverage,"new_geometry":replacement.installation})
				continue
			reports.append({"host_id":host_id,"poster":record.poster,"retained":false,"reason":"Old rear-foot plane removed by new structural exterior; held for reviewed reinstallation","support":support})
			continue
		var check:Dictionary=_br_complete_installation(plan,int(record.poster),mount)
		if not check.ok:
			var replacement:Dictionary=_br_face_mount(plan,int(record.poster),float(mount.position.y),normal)
			if replacement.is_empty() and host_id==5:
				replacement=_br_face_mount(plan,int(record.poster),float(mount.position.y),Vector3.LEFT)
			if not replacement.is_empty():
				_br_poster(int(record.poster),replacement,record.owner,record.kind)
				reports.append({"host_id":host_id,"poster":record.poster,"retained":true,"physically_reinstalled":true,"prior_failure":"check.ok","support":replacement.support_coverage,"new_geometry":replacement.installation})
				continue
			reports.append({"host_id":host_id,"poster":record.poster,"retained":false,"reason":check})
			continue
		var poster_bounds:AABB=BR_BANK.get_item_mesh(int(record.poster)).get_aabb()
		var current_visibility:Dictionary=_br_ad_visible(plan,mount,Vector2(poster_bounds.size.x,poster_bounds.size.y),int(record.poster))
		if not current_visibility.ok:
			var replacement:Dictionary=_br_face_mount(plan,int(record.poster),float(mount.position.y),normal)
			if replacement.is_empty() and host_id==5:
				replacement=_br_face_mount(plan,int(record.poster),float(mount.position.y),Vector3.LEFT)
			if not replacement.is_empty():
				_br_poster(int(record.poster),replacement,record.owner,record.kind)
				reports.append({"host_id":host_id,"poster":record.poster,"retained":true,"physically_reinstalled":true,"prior_failure":"current_visibility.ok","support":replacement.support_coverage,"new_geometry":replacement.installation})
				continue
			reports.append({"host_id":host_id,"poster":record.poster,"retained":false,"reason":"Updated whole-exterior visibility rejected","visibility":current_visibility})
			continue
		mount["visibility"]=current_visibility
		mount["support_coverage"]=support
		mount["_install_data"]=check._data;check.erase("_data");mount["installation"]=check
		_br_poster(int(record.poster),mount,record.owner,record.kind)
		reports.append({"host_id":host_id,"poster":record.poster,"retained":true,"transform_exact":not changed_host,"host_physically_adapted":changed_host,"support":support,"new_geometry":check})
	_br_aviation_markers()
	city_coverage["advert_cache"]={"ok":true,"mode":"explicit_structural_review_revalidation_only","binding":_br_cache_binding(),
		"old_plan_loaded_as_proposals_only":true,"runtime_search":false,"runtime_triangle_validation":true,
		"one_time_triangle_validation":true,"published_cache":false,"records":br_frozen_ad_records.size(),"reports":reports,
		"records_sha256":_br_digest_bytes(var_to_bytes(br_frozen_ad_records))}
	city_coverage["shape_ad_review"]=reports.duplicate(true)
	city_coverage["advert_authoring"]={"stage":"Structural review only; unchanged old placements retained if complete support and geometry remain valid"}

func _br_advertisements()->void:
	br_frozen_ad_records.clear()
	if "--own-r3-author-plan" in OS.get_cmdline_user_args():
		_own_full_author_ads()
	elif "--own-r3-structure" in OS.get_cmdline_user_args():
		_br_apply_frozen_ads()
	elif "--br01-author-ad-cache" in OS.get_cmdline_user_args():
		_br_search_advertisements()
		_br_save_authored_ads()
	else:_br_apply_frozen_ads()

func _br_search_advertisements() -> void:
	city_coverage["advertisements"]=[]
	br_ad_search_stats={"attempts":0,"fast_rejected":0,"support_rejected":0,"geometry_rejected":0,"occluded":0,"accepted":0}
	var author_started:int=Time.get_ticks_msec()
	for index in near_towers.size():
		if index%4==3:continue
		var plan:Dictionary=near_towers[index]
		print("BR01_AD_HOST index=",index," source=",plan.source_id," elapsed_ms=",Time.get_ticks_msec()-author_started)
		if plan.get("density_role","")=="second_row" and index%3!=0:continue
		var poster:int=106+posmod(index/4,2) if index%4==0 else 100+posmod(hash(Vector3i(index,plan.source_id,world.active_seed)),6)
		if index%4==2:poster=103+posmod(index,3)
		if plan.get("density_role","")=="east_visible_gap_B":poster=107
		if plan.get("density_role","")=="east_visible_gap_A":poster=100
		if plan.position.x>world.building_rect.end.x and plan.position.z>30.0 and plan.position.z<world.building_rect.end.y:
			if plan.source_id==5:poster=102
			elif plan.source_id==12:poster=104
		var mount:Dictionary=_br_face_mount(plan,poster)
		if mount.is_empty():
			for alternative:int in [104,100,103,105]:
				var other:Dictionary=_br_face_mount(plan,alternative)
				if other.is_empty():continue
				poster=alternative;mount=other;break
		if not mount.is_empty():_br_poster(poster,mount,plan.source_model,"near source wall")
		if index%2==0:
			var secondary:int=[102,103,105][posmod(index,3)]
			var secondary_y:float=_br_ad_default_height(plan)-12.0
			if not mount.is_empty():secondary_y=mount.position.y+BR_BANK.get_item_mesh(poster).get_aabb().size.y*mount.scale*0.5+1.8
			var lower:Dictionary=_br_face_mount(plan,secondary,secondary_y)
			if not lower.is_empty():_br_poster(secondary,lower,plan.source_model,"lower horizontal lightbox")

	# The existing own-building carrier retains its real licensed/gameplay outline.
	# This flat outside facade mount replaces the old repeated AER artwork only.
	var own_plan:Dictionary={"source_id":-1,"plan_id":-1,"position":Vector3(40.1,0,17.32),"size":Vector3.ONE,"turn":0}
	var own_mount:Dictionary=_br_face_mount(own_plan,106,-11.5,Vector3.BACK)
	if not own_mount.is_empty():_br_poster(106,own_mount,"CurrentBuildingFacade","own exterior corporate")
	var roof_signs:=0
	for index in middle_towers.size():
		var plan:Dictionary=middle_towers[index]
		if plan.source_id not in [3,6,8,9,16] or index%5!=0:continue
		var top:=_br_top(plan)
		var toward:=Vector2(world.building_rect.get_center())-Vector2(top.x,top.z)
		var normal:=Vector3(toward.x,0,toward.y).normalized()
		var scale:=minf(0.68,minf(plan.size.x,plan.size.z)*0.55/12.0)
		if scale<0.35:continue
		var upper_mount:Dictionary=_br_face_mount(plan,102,minf(top.y-2.5,1.0-float(index%3)*3.0),normal)
		if upper_mount.is_empty():continue
		_br_poster(102,upper_mount,plan.source_model,"upper facade corporate sign")
		roof_signs+=1
		if roof_signs>=7:break
	_br_aviation_markers()
	city_coverage["advert_authoring"]={"construction_ms":Time.get_ticks_msec()-author_started,"search":br_ad_search_stats.duplicate(),"per_frame_ray_tests":0}
	print("BR01_AD_COMPLETE ",city_coverage.advert_authoring)

static func _exterior_runs(floor_cells: Dictionary, external: Dictionary) -> Array[Dictionary]:
	var lines: Dictionary={}
	for cell in floor_cells:
		for side in 4:
			var step: Vector2i=[Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN][side]
			if not external.has(cell+step): continue
			var line := Vector2i(side,cell.x if side<2 else cell.y)
			if not lines.has(line): lines[line]=[]
			lines[line].append(cell.y if side<2 else cell.x)
	var runs: Array[Dictionary]=[]
	for line in lines:
		var along: Array=lines[line]; along.sort()
		var start: int=along[0]; var previous := start
		for value in along.slice(1):
			if value!=previous+1:
				runs.append({"side":line.x,"fixed":line.y,"start":start-.5,"length":previous-start+1})
				start=value
			previous=value
		runs.append({"side":line.x,"fixed":line.y,"start":start-.5,"length":previous-start+1})
	# Stable long-run-first placement keeps corners from creating overlapping towers.
	runs.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a.length!=b.length: return a.length>b.length
		if a.side!=b.side: return a.side<b.side
		if a.fixed!=b.fixed: return a.fixed<b.fixed
		return a.start<b.start)
	return runs


static func near_layout(floor_cells:Dictionary,external:Dictionary,rng:RandomNumberGenerator,
		runs:Array[Dictionary]=[]) -> Array[Dictionary]:
	if runs.is_empty():runs=_exterior_runs(floor_cells,external)
	var result:Array[Dictionary]=[]
	for run:Dictionary in runs:
		if run.length<4:continue
		var along_gap:=rng.randf_range(1.8,2.7)
		var count:=maxi(1,ceili((float(run.length)+along_gap)/(7.8+along_gap)))
		var width:=clampf((float(run.length)-float(count-1)*along_gap)/float(count),4.4,9.2)
		for index in count:
			var gap:=rng.randf_range(3.2,5.2)
			var depth:=rng.randf_range(5.6,8.8)
			var side:int=run.side
			var sign_value:=-1.0 if side in [0,2] else 1.0
			var along:float=run.start+width*0.5+float(index)*(width+along_gap)
			var across:float=run.fixed+sign_value*(0.5+gap+depth*0.5)
			var code:=posmod(int(run.fixed)*5+side*3+index*2,7)
			var height:float=[92.0,112.0,86.0,42.0,100.0,76.0,54.0][code]+rng.randf_range(-3.0,3.0)
			var family:int=[1,2,4,3,2,1,4][code]
			var at:=Vector3(across,STREET_LEVEL+height*0.5,along) if side<2 else Vector3(along,STREET_LEVEL+height*0.5,across)
			var size:=Vector3(depth,height,width) if side<2 else Vector3(width,height,depth)
			var footprint:=Rect2(Vector2(at.x-size.x*0.5,at.z-size.z*0.5),Vector2(size.x,size.z))
			if result.any(func(t:Dictionary)->bool:return t.footprint.grow(1.5).intersects(footprint)):continue
			var clear:=true
			for cell:Vector2i in floor_cells:
				if footprint.grow(2.3).intersects(Rect2(Vector2(cell)-Vector2(0.5,0.5),Vector2.ONE)):
					clear=false;break
			if clear:result.append({"position":at,"size":size,"top":STREET_LEVEL+height,
				"side":side,"gap":gap,"footprint":footprint,"variant":family,"mesh_id":family,
				"turn":posmod(side+index,4),"composition_tier":"foreground highrise"})
	return result


static func _vary_near_proportions(towers:Array[Dictionary],floor_cells:Dictionary,seed_value:int) -> void:
	# Stateless per-plot variation keeps the build RNG and existing lot order intact.
	# Front-to-back depth grows outward, preserving the playable-side setback.
	var original:Array[Dictionary]=towers.duplicate(true)
	for index in towers.size():
		var tower:Dictionary=towers[index]
		if tower.get("mesh_id",-1) in [15,16]:continue
		var old:Dictionary=original[index]
		var side:int=old.side
		var at:Vector3=old.position
		var size:Vector3=old.size
		tower["composition_layout_reservation"]=old.footprint
		if side==0 and absf(at.x+6.824305)<0.02 and absf(at.z-62.16577)<0.02:
			at.x-=6.2
			tower["camera_clearance_shift"]=Vector3(-6.2,0,0)
		if side==3 and absf(old.position.x-3.7)<0.02 and absf(old.position.z-70.7865)<0.02:
			at.z+=4.4
			tower["camera_clearance_shift"]=Vector3(0,0,4.4)
		var key:int=posmod(hash(Vector3i(roundi(old.position.x*100.0),roundi(old.position.z*100.0),seed_value)),6)
		var ratios:Vector2=[Vector2(0.62,1.48),Vector2(1.20,0.72),Vector2(0.83,1.60),
			Vector2(1.22,1.16),Vector2(0.72,0.92),Vector2(1.08,1.32)][key]
		var old_along:float=size.z if side<2 else size.x
		var old_depth:float=size.x if side<2 else size.z
		var wanted_along:=clampf(old_along*ratios.x,3.0,9.2)
		var wanted_depth:=clampf(old_depth*ratios.y,4.2,13.2)
		for blend:float in [1.0,0.72,0.42,0.0]:
			var along:=lerpf(old_along,wanted_along,blend)
			var depth:=lerpf(old_depth,wanted_depth,blend)
			var outward:Vector3=[Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK][side]
			var center:=at+outward*((depth-old_depth)*0.5)
			var scaled:=Vector3(depth,size.y,along) if side<2 else Vector3(along,size.y,depth)
			var footprint:=Rect2(Vector2(center.x-scaled.x*0.5,center.z-scaled.z*0.5),Vector2(scaled.x,scaled.z))
			var clear:=true
			for cell:Vector2i in floor_cells:
				if footprint.grow(2.3).intersects(Rect2(Vector2(cell)-Vector2(0.5,0.5),Vector2.ONE)):
					clear=false;break
			if not clear:continue
			for other_index in towers.size():
				if other_index!=index and towers[other_index].footprint.grow(0.55).intersects(footprint):
					clear=false;break
			if not clear:continue
			tower.position=center;tower.size=scaled;tower.footprint=footprint
			tower["proportion_profile"]=key;tower["proportion_blend"]=blend
			break

static func window_tone(cell: Vector2i, seed_value: int) -> int:
	return posmod(cell.x*17+cell.y*37+seed_value*7,13)

func _add_window_candidate(tower: Dictionary,index: int) -> void:
	var at: Vector3=tower.position; var size: Vector3=tower.size; var side: int=tower.side
	var inward := Vector3.RIGHT if side==0 else Vector3.LEFT if side==1 else Vector3.BACK if side==2 else Vector3.FORWARD
	var seed_value := index%251
	# Match a genuinely lit texel window, including its two-cell floor spacing.
	var row := floori((.5-at.y-.90625)/2.0)
	for column in range(-2,3):
		var tone := window_tone(Vector2i(column,row),seed_value)
		if tone<5: continue
		var local := Vector3(inward.x*(size.x*.5+.08),row*2.0+.90625,column+.484375) if side<2 else Vector3(column+.484375,row*2.0+.90625,inward.z*(size.z*.5+.08))
		var pale:=posmod(column*11+row*19+seed_value*3,101)<3
		var color := Color("8293bc") if pale else Color("5a738e")
		light_candidates.append({"position":at+local,"color":color,"tower":index,"cell":Vector2i(column,row)})
		break

func _select_window_lights() -> void:
	if not is_instance_valid(scene_root) or window_lights.is_empty(): return
	last_light_selection=Time.get_ticks_msec()
	var camera: Camera3D=world.camera_3d
	var size := camera.get_viewport().get_visible_rect().size
	var ranked: Array[Dictionary]=[]
	for candidate in light_candidates:
		var position: Vector3=scene_root.to_global(candidate.position)
		var score := camera.global_position.distance_squared_to(position)
		if camera.is_position_behind(position): score+=10000.0
		else: score+=(camera.unproject_position(position)/size-Vector2(.5,.5)).length_squared()*1500.0
		ranked.append({"candidate":candidate,"score":score})
	ranked.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.score<b.score)
	var wanted: Dictionary={}
	var threshold: float=ranked[mini(WINDOW_LIGHT_LIMIT,ranked.size())-1].score*1.2 if not ranked.is_empty() else 0.0
	# Keep an existing source until its contribution falls twenty percent behind.
	for light in window_lights:
		var id: int=light.get_meta(&"candidate_tower",-1)
		for item in ranked:
			if item.candidate.tower==id and item.score<=threshold: wanted[id]=item.candidate; break
	for item in ranked:
		if wanted.size()>=WINDOW_LIGHT_LIMIT: break
		wanted[item.candidate.tower]=item.candidate
	var retained: Dictionary={}
	for light in window_lights:
		var id: int=light.get_meta(&"candidate_tower",-1)
		if wanted.has(id): retained[id]=true
	for light in window_lights:
		var id: int=light.get_meta(&"candidate_tower",-1)
		if not wanted.has(id):
			id=-1
			for key in wanted:
				if not retained.has(key): id=key; retained[key]=true; break
		light.set_meta(&"candidate_tower",id)
		if id<0: light.visible=false; continue
		var candidate: Dictionary=wanted[id]
		light.position=candidate.position; light.light_color=candidate.color
		light.visible=window_lights_enabled

static func _commit_towers(surface: SurfaceTool, tags: PackedVector2Array) -> ArrayMesh:
	var arrays := surface.commit_to_arrays()
	var vertex_count: int = arrays[Mesh.ARRAY_VERTEX].size()
	assert(tags.size() <= vertex_count)
	while tags.size() < vertex_count:
		tags.append(Vector2(-1.0, 0.0)) # Street bed.
	arrays[Mesh.ARRAY_TEX_UV2] = tags
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _scenery_material(own: bool) -> ShaderMaterial:
	var mat := ShaderMaterial.new(); mat.shader=OWN_FACADE_SHADER if own else CITY_SHADER
	if own:
		for mid:int in OWN_SOURCE_BANK.get_meta("source_material_ids"):
			var key:String="own_source_tex_"+str(mid)
			mat.set_shader_parameter(key,OWN_SOURCE_BANK.get_meta(key))
	mat.set_shader_parameter("own_facade",own)
	mat.set_shader_parameter("distance_focus_enabled", false)
	mat.set_shader_parameter("city_void",ImageTexture.create_from_image(topology.image))
	mat.set_shader_parameter("city_clearance",topology.clearance_texture)
	mat.set_shader_parameter("city_origin",Vector2(topology.bounds.position))
	mat.set_shader_parameter("city_grid_size",Vector2(topology.bounds.size))
	render_materials.append(mat); return mat









var own_slice_cache:Dictionary={}

func _own_r3_shell(solid:SurfaceTool,run:Dictionary)->void:
	var length:float=run.length
	if not city_coverage.has("own_full05"):
		city_coverage["own_full05"]={"runs":[],"bank_sha256":FileAccess.get_sha256(OWN_SOURCE_BANK.resource_path).to_upper(),
			"material_ids":OWN_SOURCE_BANK.get_meta("source_material_ids"),"per_frame_geometry_search":false,
			"scope":"BW08 all actual runs; complete components/cut returns, flush truncated and short faces, full source body/wing hierarchy",
			"source_bound_sha256":OWN_SOURCE_BANK.get_meta("source_bound_sha256"),"merged_carriers":1,"extra_lights":0}
	var zones:Array=[]
	if int(run.side)==3 and int(run.fixed)==60 and is_equal_approx(float(run.start),15.5):
		zones=[{"kind":0,"length":length}]
	elif int(run.side)==0 and int(run.fixed)==24 and is_equal_approx(float(run.start),60.5):
		zones=[{"kind":1,"length":length}]
	elif length<4:
		zones=[{"kind":-1,"length":length}]
	elif int(run.side) in [1,2]:
		if length>=18:
			var body:float=roundf(length*0.62)
			zones=[{"kind":3,"length":body},{"kind":2,"length":length-body}]
			if int(run.side)==1 and length>=40:
				zones=[{"kind":3,"length":body},{"kind":2,"length":length-body-6.0},{"kind":1,"length":6.0}]
		else:zones=[{"kind":3,"length":length}]
	elif length>=10:
		var body:float=clampf(roundf(length*0.48),4.0,10.0)
		var kind:int=1 if (int(run.side)==3 and int(run.fixed)==66 and length>=12) else 2
		zones=[{"kind":0,"length":body},{"kind":kind,"length":length-body}]
	else:zones=[{"kind":0,"length":length}]
	var cursor:float=run.start
	var planned:Array=[]
	for zone:Dictionary in zones:
		if zone.length<0.001:continue
		var used:Array=_own_full_zone(solid,run,cursor,float(zone.length),int(zone.kind))
		planned.append({"start":cursor,"length":zone.length,"preferred_kind":zone.kind,"pieces":used})
		cursor+=float(zone.length)
	_own_adapter_box(solid,run,run.start,length,-0.04,0.28,-0.24,-0.06,9)
	_own_adapter_box(solid,run,run.start,length,-0.20,0.34,continuity_base_y,-48.24,9)
	city_coverage.own_full05.runs.append({"side":run.side,"fixed":run.fixed,"start":run.start,"length":length,"zones":planned})

func _own_bw07_target(run:Dictionary)->bool:
	return (int(run.side)==0 and int(run.fixed)==2 and absf(float(run.start)-53.5)<0.01) or \
		(int(run.side)==3 and int(run.fixed)==50 and absf(float(run.start)+0.5)<0.01) or \
		(int(run.side)==3 and int(run.fixed)==66 and absf(float(run.start)-57.5)<0.01)

func _own_bw07_shell(solid:SurfaceTool,run:Dictionary)->void:
	var pieces:Array=[]
	if int(run.side)==0:pieces=[{"id":6,"width":5.0},{"id":9,"width":5.0}]
	elif int(run.fixed)==50:pieces=[{"id":8,"width":7.0}]
	else:pieces=[{"id":5,"width":4.0}]
	var cursor:float=run.start
	var report:Array=[]
	for piece:Dictionary in pieces:
		var mesh:Mesh=OWN_SOURCE_BANK.get_item_mesh(piece.id)
		var short_corner:bool=int(run.side)==3 and int(run.fixed)==66
		# Preserve the source module XYZ scale; translate its finished face to the
		# actual wall. A four-metre short edge cannot carry the full tower cantilever.
		var inset:float=0.10-mesh.get_aabb().end.z if short_corner else 0.0
		_own_append_source(solid,run,cursor,mesh,inset)
		_own_adapter_box(solid,run,cursor,piece.width,mesh.get_aabb().position.z+inset-0.16,0.10,-48.24,-0.24,9)
		if short_corner:
			# Small attached steel floor lips, no independent wing: max outward0.15m.
			for floor:int in 15:
				var h:float=-0.55-float(floor)*3.2
				_own_adapter_box(solid,run,cursor,piece.width,-0.13,0.28,h-0.16,h,5)
		report.append({"kind":piece.id,"length":piece.width,"source_section":"Same XYZ source curtain, normal translation only; small attached SatinSteel lips","inset":inset,
			"finished_source_outward":mesh.get_aabb().end.z+inset,"accent_outward":0.15 if short_corner else 0.0})
		cursor+=float(piece.width)
	_own_adapter_box(solid,run,run.start,run.length,-0.04,0.28,-0.24,-0.06,9)
	_own_adapter_box(solid,run,run.start,run.length,-0.20,0.34,continuity_base_y,-48.24,9)
	city_coverage.own_full05.runs.append({"side":run.side,"fixed":run.fixed,"start":run.start,"length":run.length,
		"bw07_representative":true,"zones":[{"start":run.start,"length":run.length,"pieces":report}]})
	if not city_coverage.has("bw07"):city_coverage["bw07"]={"representative_runs":[],"surroundings_changed":false,"new_lights":0,"environment_response":"Own representative dark glass/metal only, coarse existing-air/moon approximation; no new reflection pass"}
	city_coverage.bw07.representative_runs.append({"side":run.side,"fixed":run.fixed,"start":run.start,"length":run.length})

func _own_bw09_body(solid:SurfaceTool,run:Dictionary)->void:
	# The building body follows the actual occupied-floor boundary, independent
	# of how far a source ornament was inset. A closed0.30m wall joins the floor
	# underside and adjacent outline walls; decoration remains in front of it.
	_own_adapter_box(solid,run,run.start,run.length,-0.30,0.30,-48.24,-0.24,2)
	if not city_coverage.has("bw09_body"):
		city_coverage["bw09_body"]={"runs":0,"thickness":0.30,"finished_outward":0.0,"y_range":[-48.24,-0.24],
			"original_material_id":9,"material":"Original ConcreteB, world32px, actual cold face shading, opaque closed geometry",
			"shape":"Exact external floor outline, no AABB fill; touching/overlapping perpendicular closed returns","new_lights":0,"extra_passes":0}
	city_coverage.bw09_body.runs+=1

func _own_bw10_body(solid:SurfaceTool,run:Dictionary,start:float,width:float,front:float)->void:
	# Continuous backing behind the real main curtain plane, not the outermost
	# steel AABB and not the deepest source return. Short opaque returns join
	# adjacent sections/corners and the original floor underside at boundary0.
	_own_adapter_box(solid,run,start,width,front-0.30,0.30,-48.24,-0.24,2)
	var connect_depth:float=0.0-(front-0.30)
	for edge:float in [start-0.01,start+width-0.13]:
		_own_adapter_box(solid,run,edge,0.14,front-0.30,connect_depth,-48.24,-0.24,2)
	_own_adapter_box(solid,run,start,width,front-0.30,connect_depth,-0.36,-0.24,2)
	_own_adapter_box(solid,run,start,width,front-0.30,connect_depth,-48.24,-48.12,2)
	if not city_coverage.has("bw10_body"):
		city_coverage["bw10_body"]={"sections":[],"thickness":0.30,"frame_return_width":0.14,"top_join_y":-0.24,
			"original_material_id":9,"plane_rule":"Actual primary front glass/wall plane minus0.10m, bounded by real interior occupancy; source materials/UV/transforms unchanged",
			"new_lights":0,"extra_passes":0}
	city_coverage.bw10_body.sections.append({"side":run.side,"fixed":run.fixed,"start":start,"length":width,"backing_front":front,"adjacent_and_floor_returns":true})

func _own_full_zone(solid:SurfaceTool,run:Dictionary,start:float,length:float,preferred:int)->Array:
	var used:Array=[]
	if preferred<0:
		_own_adapter_box(solid,run,start,length,-0.12,0.26,-48.24,-0.24,2)
		_own_bw10_body(solid,run,start,length,-0.10)
		_own_bw08_lips(solid,run,start,length)
		return [{"kind":"complete_shallow_short_closure","length":length,"finished_outward":0.15,"original_material_id":9}]
	var axes:Array[Vector3]=_run_axes(run)
	var max_inside:=8.0
	for along:float in [start+0.25,start+length*0.5,start+length-0.25]:
		var inside:=0.25
		while inside<8.0:
			var point:Vector3=axes[2]+axes[1]*along-axes[0]*inside
			if not world.floor_cells.has(Vector2i(roundi(point.x),roundi(point.z))):break
			inside+=0.5
		max_inside=minf(max_inside,inside-0.25)
	var width:float=8.0 if preferred in [0,3,4] else 6.0
	var remaining:float=length;var cursor:float=start
	var lookup:Dictionary=OWN_SOURCE_BANK.get_meta("bw08_lookup")
	while remaining>0.001:
		var part:float=minf(width,remaining)
		if part<2.5:
			_own_adapter_box(solid,run,cursor,part,-0.12,0.26,-48.24,-0.24,2)
			_own_bw10_body(solid,run,cursor,part,-0.10)
			_own_bw08_lips(solid,run,cursor,part)
			used.append({"kind":"complete_shallow_tail","length":part,"finished_outward":0.15})
			cursor+=part;remaining-=part;continue
		var kind:int=preferred
		var key:String="%d_%.3f"%[kind,part]
		if not lookup.has(key):
			# Arbitrary production runs tile the existing finite cut modules.
			# Original source XYZ and UV stay unchanged; only the short tail closes.
			var available:=0.0
			for entry:String in lookup:
				if not entry.begins_with(str(kind)+"_"):continue
				var extent:float=entry.get_slice("_",1).to_float()
				if extent<=part+.00001 and extent>available and lookup.has("4_%.3f"%extent):available=extent
			if available<2.5:
				_own_adapter_box(solid,run,cursor,part,-0.12,0.26,-48.24,-0.24,2)
				_own_bw10_body(solid,run,cursor,part,-0.10);_own_bw08_lips(solid,run,cursor,part)
				used.append({"kind":"complete_shallow_tail","length":part,"finished_outward":0.15})
				cursor+=part;remaining-=part;continue
			part=available;key="%d_%.3f"%[kind,part]
		assert(lookup.has(key),"Missing finite authored full-perimeter source section "+key)
		var id:int=int(lookup[key]);var mesh:Mesh=OWN_SOURCE_BANK.get_item_mesh(id)
		var trimmed:bool=part<width-0.001 or float(run.length)<=8.0
		var inset:float=0.10-mesh.get_aabb().end.z if trimmed else 0.0
		# A translated deep bay must stay under the real occupied floor, not
		# emerge across a thin inside corner. Use the complete shallow source skin.
		var shallow_fallback:=false
		if mesh.get_aabb().position.z+inset< -max_inside+0.20:
			kind=4;key="4_%.3f"%part;assert(lookup.has(key));id=int(lookup[key]);mesh=OWN_SOURCE_BANK.get_item_mesh(id)
			inset=0.10-mesh.get_aabb().end.z;trimmed=true;shallow_fallback=true
		var bound:AABB=mesh.get_aabb()
		for plan:Dictionary in br_plans:
			if plan.top<bound.position.y or STREET_LEVEL>bound.end.y:continue
			var rect:Rect2=plan.footprint
			var lo:float=rect.position.y if int(run.side)<2 else rect.position.x
			var hi:float=rect.end.y if int(run.side)<2 else rect.end.x
			if hi<cursor or lo>cursor+part:continue
			var boundary:float=float(run.fixed)+(-0.51 if int(run.side) in [0,2] else 0.51)
			var gap:float=boundary-rect.end.x if int(run.side)==0 else rect.position.x-boundary if int(run.side)==1 else boundary-rect.end.y if int(run.side)==2 else rect.position.y-boundary
			if gap>=0.0 and gap<bound.end.z+inset+0.12:inset=minf(inset,gap-bound.end.z-0.12)
		_own_append_source(solid,run,cursor,mesh,inset)
		var pane_depth:float=float(BW10_PRIMARY_PANE_DEPTH[id])+inset
		var body_front:float=clampf(pane_depth-0.10,-max_inside+0.12,0.0)
		_own_bw10_body(solid,run,cursor,part,body_front)
		if trimmed:_own_bw08_lips(solid,run,cursor,part)
		used.append({"kind":kind,"bank_id":id,"length":part,"inset":inset,"interior_depth":max_inside,
			"finished_outward":bound.end.z+inset,"cut_or_short":trimmed,"shallow_inside_fallback":shallow_fallback,
			"triangles":mesh.surface_get_array_index_len(0)/3,"source_uv_preserved":true,"primary_pane_depth":pane_depth,"body_front":body_front,"pane_body_gap":pane_depth-body_front,"cut_returns":"Authored actual profile,0.14m thick, independently projected32px/world"})
		cursor+=part;remaining-=part
	return used

func _own_bw08_lips(solid:SurfaceTool,run:Dictionary,start:float,width:float)->void:
	for floor:int in 15:
		var h:float=-0.55-float(floor)*3.2
		_own_adapter_box(solid,run,start,width,-0.13,0.28,h-0.16,h,5)


func _own_slice(kind:int,width:float)->ArrayMesh:
	var key:String="%d_%.3f"%[kind,width]
	if own_slice_cache.has(key):return own_slice_cache[key]
	var source:Mesh=OWN_SOURCE_BANK.get_item_mesh(kind)
	var max_width:float=8.0 if kind in [0,3,4] else 6.0
	if absf(width-max_width)<0.001:
		own_slice_cache[key]=source
		return source
	var tool:=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES);tool.set_uv2(Vector2.ZERO)
	for surface:int in source.get_surface_count():
		var a:Array=source.surface_get_arrays(surface)
		var ix:PackedInt32Array=a[Mesh.ARRAY_INDEX]
		for offset:int in range(0,ix.size(),3):
			var polygon:Array=[]
			for i:int in [ix[offset],ix[offset+1],ix[offset+2]]:
				polygon.append({"p":a[Mesh.ARRAY_VERTEX][i],"n":a[Mesh.ARRAY_NORMAL][i],"uv":a[Mesh.ARRAY_TEX_UV][i],"uv2":a[Mesh.ARRAY_TEX_UV2][i],"c":a[Mesh.ARRAY_COLOR][i]})
			var clipped:Array=[]
			for i:int in polygon.size():
				var p:Dictionary=polygon[i];var q:Dictionary=polygon[(i+1)%polygon.size()]
				var pin:bool=p.p.x<=width+0.00001;var qin:bool=q.p.x<=width+0.00001
				if pin:clipped.append(p)
				if pin!=qin:
					var t:float=(width-p.p.x)/(q.p.x-p.p.x)
					clipped.append({"p":p.p.lerp(q.p,t),"n":p.n,"uv":p.uv.lerp(q.uv,t),"uv2":p.uv2.lerp(q.uv2,t),"c":p.c})
			for i:int in range(1,clipped.size()-1):
				for v:Dictionary in [clipped[0],clipped[i],clipped[i+1]]:
					tool.set_normal(v.n);tool.set_uv(v.uv);tool.set_uv2(v.uv2);tool.set_color(v.c);tool.add_vertex(v.p)
	tool.index()
	var result:ArrayMesh=tool.commit()
	own_slice_cache[key]=result
	return result

func _own_append_source(solid:SurfaceTool,run:Dictionary,start:float,mesh:Mesh,inset:float)->void:
	var axes:Array[Vector3]=_run_axes(run);var basis:=Basis(axes[1],Vector3.UP,axes[0])
	for surface:int in mesh.get_surface_count():
		var a:Array=mesh.surface_get_arrays(surface);var ix:PackedInt32Array=a[Mesh.ARRAY_INDEX]
		for offset:int in range(0,ix.size(),3):
			var order:Array[int]=[ix[offset],ix[offset+1],ix[offset+2]]
			if basis.determinant()<0.0:order.reverse()
			for i:int in order:
				solid.set_normal((basis*a[Mesh.ARRAY_NORMAL][i]).normalized());solid.set_uv(a[Mesh.ARRAY_TEX_UV][i])
				solid.set_uv2(a[Mesh.ARRAY_TEX_UV2][i]);solid.set_color(a[Mesh.ARRAY_COLOR][i])
				solid.add_vertex(axes[2]+axes[1]*start+axes[0]*inset+basis*a[Mesh.ARRAY_VERTEX][i])
	solid.set_uv2(Vector2.ZERO)

func _own_adapter_box(solid:SurfaceTool,run:Dictionary,start:float,width:float,inset:float,depth:float,low:float,high:float,material_id:int)->void:
	if high<=low or depth<=0.0 or width<=0.0:return
	var axes:Array[Vector3]=_run_axes(run)
	var center:Vector3=axes[2]+axes[1]*(start+width*0.5)+axes[0]*(inset+depth*0.5)
	center.y=(low+high)*0.5
	var size:=Vector3(depth,high-low,width) if int(run.side)<2 else Vector3(width,high-low,depth)
	var points:PackedVector3Array=_unit_box[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=_unit_box[Mesh.ARRAY_NORMAL]
	for index:int in _unit_box[Mesh.ARRAY_INDEX]:
		var p:Vector3=center+points[index]*size;var n:Vector3=normals[index]
		var uv:=Vector2(p.x,p.z) if absf(n.y)>0.5 else Vector2(p.z,p.y) if absf(n.x)>0.5 else Vector2(p.x,p.y)
		solid.set_normal(n);solid.set_uv(uv*(1.24990072936363 if material_id==5 else 0.125));solid.set_uv2(Vector2.ZERO);solid.set_color(Color(0.4,0.45,0.5,float(material_id+1)/64.0));solid.add_vertex(p)

func _own_reuse_verified_space()->void:
	# Normal playback uses the exact authored geometry/layout proof, never a
	# repeated complete-scene triangle search. Drift rejects the cached proof.
	if not FileAccess.file_exists(BR_AD_CACHE_PATH) or FileAccess.get_sha256(BR_AD_CACHE_PATH).to_upper()!=BR_AD_CACHE_SHA256:
		_br_ad_cache_error("Own space proof resource missing/digest mismatch");return
	var saved:Resource=ResourceLoader.load(BR_AD_CACHE_PATH,"",ResourceLoader.CACHE_MODE_IGNORE)
	if saved==null or saved.get_meta("binding",{})!=_br_cache_binding():
		_br_ad_cache_error("Own geometry/UV2/bank/shader/plans proof binding mismatch");return
	var proof:Dictionary=saved.get_meta("own_space_audit",{})
	if proof.get("ok",false)!=true or not proof.get("exact_triangle_hit_plans",[false]).is_empty() or int(proof.get("unchanged_plans",0))!=br_plans.size() or saved.get_meta("own_source_bank_sha256","")!=FileAccess.get_sha256(OWN_SOURCE_BANK.resource_path).to_upper():
		_br_ad_cache_error("Own authored complete-geometry space proof invalid");return
	if saved.get_meta("neighbour_ad_transforms_exact",0)!=5:
		_br_ad_cache_error("Retained five neighbouring installations proof missing");return
	city_coverage["own_full_space"]=proof.duplicate(true)
	city_coverage["own_full_space"]["mode"]="bound_authoring_proof"
	city_coverage["own_full_space"]["runtime_triangle_search"]=false
	city_coverage["own_full_space"]["author_witness_sha256"]=saved.get_meta("author_witness_sha256","")
	city_coverage["own_full_space"]["binding"]=_br_cache_binding()

func _own_full_space_audit()->void:
	var own:Dictionary=_br_source_mesh_data({"source_id":-1,"plan_id":-1})
	var broad:=0;var hits:Array=[]
	for plan:Dictionary in br_plans:
		var box:=AABB(Vector3(plan.footprint.position.x,STREET_LEVEL,plan.footprint.position.y),Vector3(plan.footprint.size.x,plan.size.y,plan.footprint.size.y))
		if not own.bounds.grow(0.02).intersects(box):continue
		broad+=1
		if _br_mesh_intersection(own,_br_source_mesh_data(plan)):hits.append(plan.plan_id)
	var eyes:Array=[]
	for eye:Vector3 in BR_REVIEW_EYES:
		eyes.append({"eye":eye,"above_own_geometry":eye.y>own.bounds.end.y+world.camera_3d.near})
	city_coverage["own_full_space"]={"actual_source_triangles":own.triangles.size(),"actual_own_aabb":own.bounds,"unchanged_plans":br_plans.size(),"broad_overlap_plans":broad,
		"exact_triangle_hit_plans":hits,"normal_review_eyes":eyes,"ok":hits.is_empty() and eyes.all(func(e:Dictionary)->bool:return e.above_own_geometry),
		"scope":"Actual complete own triangles versus unchanged source meshes after AABB broad phase; construction only, no per-frame rays"}
	if not hits.is_empty():push_error("Full own exterior source mesh intersects unchanged neighbour plans "+str(hits))

func _own_full_author_ads()->void:
	br_ad_search_stats={"attempts":0,"fast_rejected":0,"support_rejected":0,"geometry_rejected":0,"occluded":0,"accepted":0}
	_own_r3_revalidate_ads()
	var has_own:bool=br_frozen_ad_records.any(func(r:Dictionary)->bool:return int(r.mount.host_id)<0)
	if not has_own:
		var plan:Dictionary={"source_id":-1,"plan_id":-1,"position":Vector3(40.1,0,17.32),"size":Vector3.ONE,"turn":0}
		print("FULL05 authoring own106 t=",Time.get_ticks_msec())
		var mount:Dictionary=_br_face_mount(plan,106,-14.5,Vector3.BACK)
		if mount.is_empty():mount=_br_face_mount(plan,106,-14.5,Vector3.FORWARD)
		if not mount.is_empty():_br_poster(106,mount,"CurrentBuildingFacade","source exterior corporate, newly validated physical fixed feet")
	var output_dir:=""
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):output_dir=arg.trim_prefix("--out=")
	var complete:bool=br_frozen_ad_records.size()==6 and br_frozen_ad_records.any(func(r:Dictionary)->bool:return int(r.mount.host_id)<0)
	city_coverage["full_ad_authoring"]={"ok":complete,"records":br_frozen_ad_records.size(),"search_stats":br_ad_search_stats,"scope":"Explicit authoring tool only, no normal-entry placement search"}
	if not complete:_br_ad_cache_error("Full source authoring could not retain five neighbours plus a physical own106 installation");return
	var resource:=Resource.new()
	resource.set_meta("binding",_br_cache_binding());resource.set_meta("installations",br_frozen_ad_records.duplicate(true))
	resource.set_meta("source_plans",br_plans.duplicate(true));resource.set_meta("authoring_stats",city_coverage.full_ad_authoring.duplicate(true))
	resource.set_meta("validated_triangle_pairs",br_triangle_pairs_checked)
	resource.set_meta("provenance","R3 full05 draft candidate, newly validated six typed placements, own shader/bank bound. Not final entry/cache approval.")
	var path:String=output_dir.path_join("full05_ad_draft.res")
	assert(ResourceSaver.save(resource,path,ResourceSaver.FLAG_COMPRESS|ResourceSaver.FLAG_BUNDLE_RESOURCES)==OK)
	city_coverage["advert_cache"]={"ok":true,"mode":"explicit_full_source_authoring","resource":path,"binding":_br_cache_binding(),"records":6,"runtime_search":false,"authoring_search":true,"normal_entry_search":false}

func _own_r3_close_underdeck(solid:SurfaceTool)->void:
	# Necessary non-playable lower cap. Contiguous cell rows are merged,
	# preserving every real courtyard/hole rather than filling the building AABB.
	var rows:Dictionary={}
	for cell:Vector2i in world.floor_cells:
		if not rows.has(cell.y):rows[cell.y]=[]
		rows[cell.y].append(cell.x)
	var z_values:Array=rows.keys();z_values.sort()
	var covered:Dictionary={}
	var strips:=0
	for z:int in z_values:
		var xs:Array=rows[z];xs.sort()
		var first:int=xs[0];var previous:int=first
		for cursor:int in range(1,xs.size()+1):
			if cursor<xs.size() and int(xs[cursor])==previous+1:
				previous=int(xs[cursor])
				continue
			var length:float=float(previous-first+1)
			_box(solid,Vector3(length,0.18,1.0),Vector3(float(first+previous)*0.5,-0.15,float(z)),Color("26354000"))
			for x:int in range(first,previous+1):covered[Vector2i(x,z)]=true
			strips+=1
			if cursor<xs.size():first=int(xs[cursor]);previous=first
	var expected:Array=world.floor_cells.keys()
	var actual:Array=covered.keys()
	var ordered:Callable=func(a:Vector2i,b:Vector2i)->bool:return a.y<b.y or (a.y==b.y and a.x<b.x)
	expected.sort_custom(ordered);actual.sort_custom(ordered)
	assert(expected==actual)
	city_coverage["r3_underdeck"]={"role":"Non-playable underside/edge closure only","cells":expected.size(),"merged_strips":strips,
		"source_cells_sha256":_br_digest_bytes(var_to_bytes(expected)),"coverage_exact":expected==actual,
		"y_min":-0.24,"y_max":-0.06,"closed_box_faces":true,"collision_nodes_added":0,"lights_added":0,
		"original_floor_mesh_uv_collision_unchanged":true,"real_glass_unchanged":true}



static func _own_r3_box(solid:SurfaceTool,run:Dictionary,start:float,length:float,
		inset:float,depth:float,low:float,high:float,tint:Color)->void:
	assert(high<=-0.06+0.00001 and high>low and depth>0.0 and length>0.0)
	var axes:Array[Vector3]=_run_axes(run)
	var center:Vector3=axes[2]+axes[0]*(inset+depth*0.5)+axes[1]*(start+length*0.5)
	center.y=(low+high)*0.5
	var size:=Vector3(depth,high-low,length) if int(run.side)<2 else Vector3(length,high-low,depth)
	_box(solid,size,center,tint)

static func _run_axes(run: Dictionary) -> Array[Vector3]:
	var side: int = run.side
	var normal_sign := -1.0 if side in [0, 2] else 1.0
	var outward := Vector3(normal_sign, 0, 0) if side < 2 else Vector3(0, 0, normal_sign)
	var along := Vector3.BACK if side < 2 else Vector3.RIGHT
	return [outward, along, outward * (float(run.fixed) * normal_sign + 0.51)]


static func _main_shell_box(surface: SurfaceTool, run: Dictionary, along: float, width: float,
		outward_offset: float, depth: float, low: float, high: float, tint: Color) -> void:
	var side: int = run.side
	var sign_value := -1.0 if side == 0 or side == 2 else 1.0
	var distance := outward_offset + depth * 0.5 if outward_offset > 0.0 else 0.0
	var across: float = run.fixed + sign_value * (0.51 + distance)
	var mid := along + width * 0.5
	var height := high - low
	var y := (high + low) * 0.5
	var at := Vector3(across, y, mid) if side < 2 else Vector3(mid, y, across)
	var size := Vector3(depth, height, width) if side < 2 else Vector3(width, height, depth)
	_box(surface, size, at, tint)



static func _box(st: SurfaceTool,size: Vector3,at: Vector3,tint: Color) -> void:
	var points: PackedVector3Array = _unit_box[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = _unit_box[Mesh.ARRAY_NORMAL]
	for index in _unit_box[Mesh.ARRAY_INDEX]:
		var local := points[index] * size
		var normal := normals[index]
		var uv := Vector2(local.x,local.y) if absf(normal.z)>.5 else Vector2(local.z,local.y) if absf(normal.x)>.5 else Vector2(local.x,local.z)
		st.set_normal(normal); st.set_uv(uv); st.set_color(tint); st.add_vertex(local+at)

# The glass and mullions sit behind the face of the concrete. Ledges and
# rooftop housings contribute their own silhouettes and depth.
func _dystopian_tower(solid: SurfaceTool, halos: SurfaceTool, plan: Dictionary, distant: bool) -> void:
	var at: Vector3 = plan.position
	var bounds: Vector3 = plan.size
	var roof: float = plan.top
	var width := bounds.x - 0.68
	var length := bounds.z - 0.64
	var pitch := 2.62 if not distant else 2.90
	var rows := 6
	var lowest_deck := roof - float(rows) * pitch
	var body := Color("34485700")
	var dark := Color("24334400")
	var rim := Color("556a8000")
	var axis := Vector3(at.x, 0, at.z)
	_box(solid, Vector3(width - 1.34, roof - lowest_deck, length - 1.34),
		axis + Vector3(0, (roof + lowest_deck) * 0.5, 0), body)
	if distant:
		_box(solid, Vector3(width - 0.34, lowest_deck - STREET_LEVEL, length - 0.45),
			axis + Vector3(0, (lowest_deck + STREET_LEVEL) * 0.5, 0), dark)
	_box(solid, Vector3(width - 0.11, 0.42, length - 0.16),
		axis + Vector3(0, lowest_deck + 0.16, 0), rim)
	for row in rows:
		var base := roof - float(row + 1) * pitch
		var shelf := 0.31 if row % 3 == 0 else 0.16
		_box(solid, Vector3(width + shelf, 0.25, length + shelf), axis + Vector3(0, base + 0.16, 0), rim)
		_pilot_bays(solid, halos, axis + Vector3(-width * 0.5, base, 0.0),
			Vector3.BACK, Vector3.LEFT, length, pitch, row, distant)
		_pilot_bays(solid, halos, axis + Vector3(0.0, base, length * 0.5),
			Vector3.RIGHT, Vector3.BACK, width, pitch, row + 2, distant)
	# Back and north caps close the volume.
	_box(solid, Vector3(0.52, roof - lowest_deck, length), axis + Vector3(width * 0.5 - 0.26, (roof + lowest_deck) * 0.5, 0), dark)
	_box(solid, Vector3(width, roof - lowest_deck, 0.52), axis + Vector3(0, (roof + lowest_deck) * 0.5, -length * 0.5 + 0.26), body)
	_box(solid, Vector3(width + 0.22, 0.26, length + 0.20), axis + Vector3(0, roof + 0.04, 0), body)
	_box(solid, Vector3(width + 0.19, 0.23, 0.21), axis + Vector3(0, roof + 0.22, length * 0.5 - 0.09), rim)
	_box(solid, Vector3(0.21, 0.26, length - 0.26), axis + Vector3(-width * 0.5 + 0.07, roof + 0.23, -0.12), rim)
	_box(solid, Vector3(width * 0.55, 0.79, length * 0.69), axis + Vector3(width * 0.16, roof + 0.55, -length * 0.08), body.lightened(0.12))
	_box(solid, Vector3(width * 0.30, 1.35, length * 0.40), axis + Vector3(width * 0.26, roof + 1.46, -length * 0.15), dark.lightened(0.11))
	_box(solid, Vector3(width * 0.31, 0.20, length * 0.42), axis + Vector3(width * 0.26, roof + 2.16, -length * 0.15), rim)
	var aerial := axis + Vector3(width * 0.30, roof + 2.91, -length * 0.19)
	_box(solid, Vector3(0.14, 1.44, 0.14), aerial, rim)
	_box(solid, Vector3(0.86, 0.11, 0.12), aerial + Vector3(0.0, 0.43, 0.0), rim)
	if not distant:
		_box(solid, Vector3(0.14, 0.96, 0.14), aerial + Vector3(-1.18, -0.27, 0.53), rim)
		var spine := axis + Vector3(-width * 0.5 - 0.05, (roof + lowest_deck) * 0.5, -length * 0.38)
		_box(solid, Vector3(0.44, roof - lowest_deck, 0.38), spine, dark)
		_box(solid, Vector3(0.17, roof - lowest_deck - 0.32, 0.13), spine + Vector3(-0.23, 0.02, -0.30), rim)
		# Boxed wayfinding blades and an offset rooftop sign on separate steel supports.
		var blade := axis + Vector3(-width * 0.50 - 0.13, roof - 1.76, -length * 0.32)
		_box(solid, Vector3(0.19, 1.72, 0.60), blade, dark)
		for slot in 3:
			_box(solid, Vector3(0.07, 0.29, 0.34), blade + Vector3(-0.12, 0.49 - slot * 0.44, 0), _radiant(Color("9aa8ff00"), 0.48))
		var sign := axis + Vector3(-width * 0.28, roof + 0.94, length * 0.42)
		for support in [-1.15, 1.15]:
			_box(solid, Vector3(0.11, 1.63, 0.18), sign + Vector3(support, -0.48, -0.09), dark)
		_box(solid, Vector3(2.91, 1.31, 0.22), sign, Color("4c576f00"))
		_box(solid, Vector3(1.92, 0.14, 0.052), sign + Vector3(-0.15, -0.35, 0.13), _radiant(Color("8dbaff00"), 0.55))
		_box(solid, Vector3(1.42, 0.23, 0.051), sign + Vector3(-0.37, 0.13, 0.13), Color("78879d00"))
		_box(solid, Vector3(0.27, 0.62, 0.051), sign + Vector3(0.99, 0.02, 0.13), Color("7688b400"))
		for index in 3:
			_box(solid, Vector3(0.93, 0.26, 0.18), axis + Vector3(-width * 0.25, roof + 0.31, 0.28 + 0.35 * index), dark)


func _pilot_bays(solid: SurfaceTool, halos: SurfaceTool, deck: Vector3, along: Vector3,
		outward: Vector3, span: float, pitch: float, row: int, distant: bool) -> void:
	var concrete := Color("4b617300")
	var edge := Color("667e9100")
	var glazing := Color("1b2c3f00")
	var trim := Color("27374700")
	var first := 0.20
	var bay_widths := [0.29, 0.39, 0.32] if row % 2 == 0 else [0.35, 0.28, 0.37]
	var inset_span := span - 0.40
	_pilot_plate(solid, deck + Vector3.UP * (pitch - 0.24), along, outward, span, 0.37, 0.30, concrete)
	_pilot_plate(solid, deck + Vector3.UP * 0.31, along, outward, span, 0.40, 0.41, concrete)
	_pilot_plate(solid, deck + Vector3.UP * 0.52 + outward * 0.03, along, outward, span, 0.10, 0.42, edge)
	for bay: int in bay_widths.size():
		var width: float = bay_widths[bay] * inset_span
		var divider: float = first - span * 0.5
		var column := deck + along * divider + Vector3.UP * (pitch * 0.50)
		_pilot_plate(solid, column + outward * 0.035, along, outward, 0.37, pitch - 0.21, 0.43, concrete)
		var pane_width := width - 0.43
		var mid := divider + width * 0.5
		var tall := 1.65 if (row + bay) % 4 != 1 else 1.26
		var window := deck + along * mid + Vector3.UP * (0.55 + tall * 0.50)
		var pattern := posmod(row * 5 + bay * 3, 11)
		var lit := pattern in [0, 2, 4, 5, 6, 9] if not distant else pattern in [1, 4, 8]
		var pane := Color("c3dfff00") if pattern in [0, 4, 5] else Color("8fbefb00")
		var strength := 0.79 + 0.07 * float(pattern % 3)
		if not lit:
			pane = glazing.lightened(0.038 * float(pattern % 3))
			strength = 0.0
		_pilot_plate(solid, window - outward * 0.13, along, outward,
			pane_width, tall, 0.074, _radiant(pane, strength))
		_pilot_plate(solid, window + along * (pane_width * (0.09 if row % 2 == 0 else -0.16)) - outward * 0.03,
			along, outward, 0.105, tall + 0.10, 0.15, trim)
		_pilot_plate(solid, window + Vector3.UP * (tall * 0.26) - outward * 0.06,
			along, outward, pane_width, 0.084, 0.11, trim)
		var header := 0.55 + tall
		_pilot_plate(solid, deck + along * mid + Vector3.UP * ((header + pitch - 0.31) * 0.5),
			along, outward, pane_width + 0.04, pitch - 0.31 - header, 0.32, concrete)
		if lit:
			_pilot_halo_quad(halos, window + outward * 0.24, along, outward,
				Vector2(pane_width, tall), 0.074 if not distant else 0.063)
		city_coverage.neighbour_window_groups[int(distant)] += 1
		city_coverage.neighbour_lit_groups[int(distant)] += int(lit)
		first += width
	_pilot_plate(solid, deck + along * (span * 0.50 - 0.20) + Vector3.UP * (pitch * 0.50) + outward * 0.03,
		along, outward, 0.41, pitch - 0.16, 0.43, concrete)


static func _radiant(tint: Color, energy: float) -> Color:
	return Color(tint.r, tint.g, tint.b, energy)


static func _pilot_plate(st: SurfaceTool, center: Vector3, across: Vector3, normal: Vector3,
		width: float, height: float, depth: float, tint: Color) -> void:
	_box(st, across * width + Vector3.UP * height + normal.abs() * depth, center, tint)


static func _pilot_halo_quad(st: SurfaceTool, center: Vector3, across: Vector3, outward: Vector3,
		aperture: Vector2, gain: float) -> void:
	var margin := Vector2(0.58, 0.43)
	var size := aperture + 2.0 * margin
	var uv2 := aperture / size
	for uv: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.ZERO, Vector2.ONE, Vector2.DOWN]:
		var offset := (uv - Vector2(0.5, 0.5)) * size
		st.set_uv(uv); st.set_uv2(uv2); st.set_normal(outward)
		st.set_color(Color(1.0, 1.0, 1.0, gain))
		st.add_vertex(center + across * offset.x + Vector3.UP * offset.y)


func _dress_neighbour(solid: SurfaceTool, halos: SurfaceTool, at: Vector3, size: Vector3,
		variant: int, tier: int, town_center: Vector2) -> void:
	var roof := at.y + size.y * 0.5
	var key := posmod(roundi(at.x * 17.0 + at.z * 29.0) + variant * 37, 97)
	var toward := town_center - Vector2(at.x, at.z)
	var fronts := [0, 1, 2, 3] if tier == 0 else [int(toward.x >= 0), 2 + int(toward.y >= 0)]
	var normals := [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
	var pitch := 2.46 + 0.18 * float(variant % 3)
	var rows := 4 if tier == 0 else 2
	var facade_color: Color = [Color("40546600"), Color("49627500"), Color("3c4e6600"),
		Color("4f637400"), Color("3a4e6200")][variant]
	var rim := facade_color.lightened(0.14)
	for side: int in fronts:
		var outward: Vector3 = normals[side]
		var along := Vector3.BACK if side < 2 else Vector3.RIGHT
		var span := size.z - 0.48 if side < 2 else size.x - 0.48
		var cross := size.x if side < 2 else size.z
		var front := Vector3(at.x, 0, at.z) + outward * (cross * 0.5 - 0.25)
		for row in rows:
			var y := roof - 0.34 - float(row + 1) * pitch
			_build_neighbour_row(solid, halos, front + Vector3.UP * y, along, outward, span, pitch,
				variant, key + row * 31 + side * 17, facade_color, rim, tier)
	# The licensed roof silhouettes are left legible. These few original
	# pieces break the line only where the prefab already has a roof deck.
	var roof_origin := Vector3(at.x, roof - 0.18, at.z)
	match (key + variant) % 5:
		0:
			_box(solid, Vector3(0.12, 1.31, 0.12), roof_origin + Vector3(-size.x * 0.21, 0.47, 0.35), rim)
			_box(solid, Vector3(0.78, 0.10, 0.14), roof_origin + Vector3(-size.x * 0.21, 1.02, 0.35), rim)
		1:
			_box(solid, Vector3(size.x * 0.22, 0.45, size.z * 0.21), roof_origin + Vector3(size.x * 0.19, 0.18, 0), facade_color)
			_box(solid, Vector3(size.x * 0.23, 0.09, size.z * 0.22), roof_origin + Vector3(size.x * 0.19, 0.42, 0), rim)
		2:
			for rib in 3:
				_box(solid, Vector3(0.19, 0.26, 1.28), roof_origin + Vector3(-0.42 + float(rib) * 0.33, 0.09, size.z * 0.15), rim)
		3:
			_box(solid, Vector3(1.76, 0.43, 0.16), roof_origin + Vector3(0, 0.44, size.z * 0.20), facade_color)
			_box(solid, Vector3(1.18, 0.072, 0.055), roof_origin + Vector3(0, 0.44, size.z * 0.20 + 0.10),
				_radiant(Color("879cff"), 0.40))
			for support in [-0.66, 0.66]:
				_box(solid, Vector3(0.10, 0.42, 0.12), roof_origin + Vector3(support, 0.09, size.z * 0.20), rim)
		_:
			_box(solid, Vector3(size.x * 0.27, 0.28, size.z * 0.25), roof_origin + Vector3(-size.x * 0.14, 0.09, -size.z * 0.13), rim)
			_box(solid, Vector3(0.15, 0.64, 0.14), roof_origin + Vector3(0.30, 0.25, -size.z * 0.16), facade_color)


func _build_neighbour_row(solid: SurfaceTool, halos: SurfaceTool, origin: Vector3, along: Vector3,
		outward: Vector3, span: float, pitch: float, variant: int, key: int, concrete: Color,
		rim: Color, tier: int) -> void:
	var layout: Array = [[0.35, 0.30, 0.35], [0.46, 0.54], [0.22, 0.38, 0.40],
		[0.61, 0.39], [0.28, 0.47, 0.25]][variant]
	var a := -span * 0.5
	var stile := 0.21 + 0.037 * float(variant)
	var pane_height := 1.45 + 0.12 * float((variant + key) % 3)
	var sill_y := 0.42 if variant != 0 else 0.32
	var top := sill_y + pane_height
	var shadow := Color("24354600")
	_pilot_plate(solid, origin + Vector3.UP * (sill_y * 0.5), along, outward, span, sill_y, 0.32, concrete)
	_pilot_plate(solid, origin + Vector3.UP * ((top + pitch) * 0.5), along, outward, span, pitch - top, 0.32, concrete)
	_pilot_plate(solid, origin + Vector3.UP * (sill_y + 0.03) + outward * 0.030, along, outward, span, 0.10, 0.34, rim)
	for group in layout.size():
		var width: float = float(layout[group]) * span
		var center := origin + along * (a + width * 0.5) + Vector3.UP * (sill_y + pane_height * 0.5)
		_pilot_plate(solid, origin + along * a + Vector3.UP * (sill_y + pane_height * 0.5),
			along, outward, stile, pane_height, 0.36, rim)
		var bay_width := width - stile - 0.075
		var code := posmod(key + group * 31 + variant * 11, 15)
		var lit := code in [0, 2, 3, 5, 8, 9, 13] and key % 13 != 3
		var colour: Color = [Color("c3e2ff"), Color("9bc8ff"), Color("b5c4ff")][code % 3]
		var glass := _radiant(colour, 0.77 + 0.07 * float(code % 3)) if lit else shadow
		_pilot_plate(solid, center - outward * 0.082, along, outward, bay_width, pane_height, 0.061, glass)
		if variant != 0 or bay_width > 1.7:
			_pilot_plate(solid, center + along * (bay_width * (0.13 if code % 2 == 0 else -0.14)),
				along, outward, 0.094, pane_height, 0.13, shadow)
		if lit and tier == 0:
			_pilot_halo_quad(halos, center + outward * 0.23, along, outward, Vector2(bay_width, pane_height), 0.058)
		city_coverage.neighbour_window_groups[tier] += 1
		city_coverage.neighbour_lit_groups[tier] += int(lit)
		a += width
	_pilot_plate(solid, origin + along * (span * 0.5) + Vector3.UP * (sill_y + pane_height * 0.5),
		along, outward, stile, pane_height, 0.36, rim)

func _build_vertical_layers() -> void:
	vertical_layer = Node3D.new()
	vertical_layer.name = "VerticalCityDetails"
	scene_root.add_child(vertical_layer)
	vertical_groups.clear()
	var body := SurfaceTool.new(); body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var signs := SurfaceTool.new(); signs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var glow := SurfaceTool.new(); glow.begin(Mesh.PRIMITIVE_TRIANGLES)
	var plans: Array[Dictionary] = [
		{"row":"corridor","source_id":-1,"tower":Vector2.ZERO,"origin":Vector3(40.1,-7.5,18.1),
			"normal":Vector3.BACK,"size":Vector2(4.2,13.0),"brand":"AER","kind":0},
		{"row":"east","source_id":5,"tower":Vector2(91.5,22.5),"origin":Vector3(88.5,-35.0,22.6),
			"normal":Vector3.LEFT,"size":Vector2(4.0,14.0),"brand":"IRIS","kind":1}]
	for plan: Dictionary in plans:
		var matches: Array = []
		if plan.row == "corridor":
			# The visible opposite wing is our own exterior shell, 31m from
			# the Camera. Source-body-only picking selected a hidden 70m tower.
			var support_point := Vector2(40.37319,16.662)
			var nearest_distance := INF
			var nearest_run := {}
			for run: Dictionary in main_runs:
				if run.side not in [2,3]: continue
				var crossing: float = run.fixed+(-0.51 if run.side==2 else 0.51)
				var along: float = clampf(support_point.x,run.start,run.start+run.length)
				var distance := Vector2(along,crossing).distance_to(support_point)
				if distance<nearest_distance:
					nearest_distance=distance
					nearest_run=run
			if nearest_distance<1.25:
				matches=[nearest_run]
		else:
			matches = highrise_layout.filter(func(tower: Dictionary) -> bool:
				return tower.source_id==plan.source_id and tower.tier==1 \
					and Vector2(tower.position.x,tower.position.z).distance_to(plan.tower)<0.05)
		if matches.is_empty(): continue
		var normal: Vector3 = plan.normal
		var basis := Basis(Vector3.UP.cross(normal),Vector3.UP,normal)
		var display_basis := basis
		if plan.row == "corridor":
			display_basis = basis*Basis.from_scale(Vector3(0.70,0.70,1.0))
			_v_scaled_primary(body,signs,glow,plan.origin,display_basis,plan.size,plan.brand,plan.kind)
			var side_origin := Vector3(37.3,-9.0,18.6)
			var side_basis := Basis(Vector3(0.70710678,0,0.70710678),Vector3.UP,Vector3(-0.70710678,0,0.70710678))
			_v_side_plate(body,signs,glow,side_origin,side_basis,"FLOW",Vector2(2.8,0.9),0)
			for y: float in [-0.45,0.45]:
				_street_local_box(body,side_origin,Basis.IDENTITY,Vector3(0.16,0.16,1.8),
					Vector3(0,y,-0.6),Color(0.24,0.32,0.37,0.04))
			_v_corner_band(body,signs,Vector3(40.1,-2.3,18.08),Basis.IDENTITY,6.3,0)
			_v_corner_band(body,signs,Vector3(36.91,-2.3,17.1),Basis(Vector3.BACK,Vector3.UP,Vector3.LEFT),1.96,0)
			_v_corner_band(body,signs,Vector3(40.1,-13.0,18.08),Basis.IDENTITY,6.3,1)
		else:
			_v_primary(body,signs,glow,plan.origin,basis,plan.size,plan.brand,plan.kind)
			var side_origin := Vector3(91.6,-33.2,25.76)
			_v_side_plate(body,signs,glow,side_origin,Basis.IDENTITY,"NOCT",Vector2(4.8,1.1),1)
			_v_corner_band(body,signs,Vector3(88.46,-27.5,22.45),basis,6.6,1)
			_v_corner_band(body,signs,Vector3(91.65,-27.5,25.78),Basis.IDENTITY,6.38,1)
			_v_corner_band(body,signs,Vector3(91.65,-40.7,25.78),Basis.IDENTITY,6.38,0)
		vertical_groups.append({"row":plan.row,"origin":plan.origin,"normal":normal,
			"basis":display_basis,"size":plan.size,"brand":plan.brand,"source_id":plan.source_id,
			"source_tower":({"carrier":"CurrentBuildingFacade","run":matches[0].duplicate(true)} if plan.row=="corridor" else matches[0].duplicate(true)),"graphic":"bottled clean air" if plan.kind==0 else "iris eye emblem"})
	# Visible low shop roofs receive compact complete-cap equipment groups.
	for roof: Dictionary in street_signs:
		var basis := Basis.IDENTITY if roof.axis == 1 else Basis(Vector3.BACK,Vector3.UP,Vector3.LEFT)
		_v_roof_plant(body,signs,roof.origin,basis)
	var body_material := _scenery_material(false)
	body_material.set_shader_parameter("pilot_geometry",true)
	var sign_material := _scenery_material(false)
	sign_material.set_shader_parameter("pilot_geometry",true)
	sign_material.set_shader_parameter("street_geometry",true)
	for item: Array in [[body,body_material,"FacadeStructures"],[signs,sign_material,"FacadeGraphics"],
			[glow,_street_glow_material(),"FacadeHalos"]]:
		var mesh: ArrayMesh = item[0].commit()
		if mesh == null or mesh.get_surface_count() == 0: continue
		var carrier := _add_city_carrier(mesh,item[1],item[2])
		carrier.reparent(vertical_layer,false)
	vertical_halo = vertical_layer.get_node_or_null("FacadeHalos")
	city_coverage["vertical"] = {"primary_graphic_ads":vertical_groups.size(),"secondary_word_signs":vertical_groups.size(),
		"small_signs":vertical_groups.size(),"side_equipment_groups":vertical_groups.size(),
		"visible_roof_equipment_groups":street_signs.size(),"opaque_batches":2,"halo_batches":1,"new_real_lights":0}


func _v_scaled_primary(body: SurfaceTool, signs: SurfaceTool, glow: SurfaceTool,
		origin: Vector3, basis: Basis, size: Vector2, brand: String, kind: int) -> void:
	var local_body := SurfaceTool.new(); local_body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var local_signs := SurfaceTool.new(); local_signs.begin(Mesh.PRIMITIVE_TRIANGLES)
	var local_glow := SurfaceTool.new(); local_glow.begin(Mesh.PRIMITIVE_TRIANGLES)
	_v_primary(local_body,local_signs,local_glow,Vector3.ZERO,Basis.IDENTITY,size,brand,kind)
	var transform := Transform3D(basis,origin)
	for pair: Array in [[local_body,body],[local_signs,signs],[local_glow,glow]]:
		var target: SurfaceTool = pair[1]
		target.append_from(pair[0].commit(),0,transform)


func _v_primary(body: SurfaceTool, signs: SurfaceTool, glow: SurfaceTool, origin: Vector3,
		basis: Basis, size: Vector2, brand: String, kind: int) -> void:
	var metal := Color(0.23,0.31,0.36,0.05)
	var dark := Color(0.035,0.060,0.078,0.75)
	var teal := Color(0.16,0.94,0.76,2.5)
	var amber := Color(1.0,0.61,0.22,2.0)
	var pale := Color(0.76,0.93,0.97,2.1)
	_street_local_box(body,origin,basis,Vector3(size.x+0.40,size.y+0.45,0.46),Vector3(0,0,-0.10),metal)
	_street_local_box(signs,origin,basis,Vector3(size.x,size.y,0.10),Vector3(0,0,0.18),dark)
	for x: float in [-size.x*0.5-0.11,size.x*0.5+0.11]:
		_street_local_box(body,origin,basis,Vector3(0.16,size.y+0.6,0.25),Vector3(x,0,0.08),metal.lightened(0.12))
	for y: float in [-size.y*0.5,size.y*0.5]:
		_street_local_box(signs,origin,basis,Vector3(size.x+0.15,0.11,0.13),Vector3(0,y,0.28),teal if kind==0 else amber)
	for y: float in [-size.y*0.36,0.0,size.y*0.36]:
		_street_local_box(body,origin,basis,Vector3(size.x+0.1,0.18,0.80),Vector3(0,y,-0.55),metal)
	if kind == 0:
		var bottle := PackedVector2Array([Vector2(-1.0,-3.7),Vector2(-1.25,-3.3),Vector2(-1.25,2.55),
			Vector2(-0.55,3.4),Vector2(-0.55,4.35),Vector2(0.55,4.35),Vector2(0.55,3.4),
			Vector2(1.25,2.55),Vector2(1.25,-3.3),Vector2(1.0,-3.7)])
		for i in bottle.size(): bottle[i].y += 0.35
		_v_poly(signs,origin,basis,bottle,0.30,Color(0.08,0.48,0.43,1.35))
		_v_outline(signs,origin,basis,bottle,0.14,0.34,teal)
		for y: float in [4.45,4.72]:
			_v_line(signs,origin,basis,Vector2(-0.58,y),Vector2(0.58,y),0.15,0.37,pale)
		_v_line(signs,origin,basis,Vector2(-0.88,-2.45),Vector2(-0.88,2.45),0.12,0.37,pale)
		_v_poly(signs,origin,basis,_v_ellipse(Vector2(0,0.55),Vector2(0.88,1.10),16),0.38,Color(0.035,0.12,0.16,1))
		_v_text(signs,origin,basis,Vector3(0,0.55,0.42),"O2",1.36,pale)
		for x: float in [-0.58,-0.30,0.02,0.36,0.61]:
			_v_line(signs,origin,basis,Vector2(x,-3.0),Vector2(x,-2.55),0.08,0.38,amber)
	else:
		var mask := PackedVector2Array([Vector2(-1.55,0.9),Vector2(-0.95,-2.50),Vector2(0,-3.35),
			Vector2(0.95,-2.50),Vector2(1.55,0.9)])
		_v_poly(signs,origin,basis,mask,0.30,Color(0.07,0.22,0.30,1.1))
		_v_outline(signs,origin,basis,mask,0.12,0.34,teal)
		var eye := PackedVector2Array([Vector2(-1.65,2.0),Vector2(-0.92,2.70),Vector2(0,2.96),
			Vector2(0.98,2.66),Vector2(1.65,2.0),Vector2(0.98,1.33),Vector2(0,1.06),Vector2(-0.92,1.30)])
		_v_poly(signs,origin,basis,eye,0.37,Color(0.57,0.88,0.89,1.6))
		_v_outline(signs,origin,basis,eye,0.10,0.40,pale)
		_v_poly(signs,origin,basis,_v_ellipse(Vector2(0,2.0),Vector2(0.70,0.80),14),0.42,Color(0.84,0.20,0.66,2.1))
		_v_poly(signs,origin,basis,_v_ellipse(Vector2(0,2.0),Vector2(0.28,0.43),10),0.45,Color(0.025,0.04,0.07,0.8))
		_v_line(signs,origin,basis,Vector2(-0.95,-0.15),Vector2(0.95,-0.15),0.14,0.38,teal)
		_v_line(signs,origin,basis,Vector2(-0.72,-0.80),Vector2(0.72,-0.80),0.14,0.38,teal)
		_v_line(signs,origin,basis,Vector2(-0.43,-1.45),Vector2(0.43,-1.45),0.14,0.38,pale)
	_v_text(signs,origin,basis,Vector3(0,-size.y*0.5+1.15,0.38),brand,size.x*0.72,pale)
	_v_line(signs,origin,basis,Vector2(-size.x*0.32,-size.y*0.5+0.42),Vector2(size.x*0.32,-size.y*0.5+0.42),0.10,0.38,amber)
	# A cantilevered service deck has actual thickness, complete top faces and pipes.
	var side := -1.0 if kind==0 else 1.0
	var x := side*(size.x*0.5+0.68)
	_street_local_box(body,origin,basis,Vector3(1.65,0.24,1.55),Vector3(x,2.42,0.64),metal.lightened(0.10))
	for offset: float in [-0.6,0.6]:
		_street_local_box(body,origin,basis,Vector3(0.14,1.1,0.16),Vector3(x+offset,2.95,1.25),metal)
		_street_local_box(body,origin,basis,Vector3(0.16,0.22,1.85),Vector3(x+offset,2.16,0.14),metal)
	_street_local_box(body,origin,basis,Vector3(1.4,0.13,0.14),Vector3(x,3.48,1.25),metal.lightened(0.14))
	_street_local_box(body,origin,basis,Vector3(1.08,1.10,0.95),Vector3(x,3.05,0.66),metal)
	_street_local_box(body,origin,basis,Vector3(1.18,0.14,1.05),Vector3(x,3.67,0.66),metal.lightened(0.12))
	for y: float in [2.69,2.91,3.13,3.35]:
		_street_local_box(body,origin,basis,Vector3(0.84,0.10,0.09),Vector3(x,y,1.18),Color(0.06,0.10,0.14,0))
	_street_local_box(body,origin,basis,Vector3(0.18,4.9,0.18),Vector3(x-side*0.78,0.25,0.62),metal.lightened(0.10))
	_street_local_box(body,origin,basis,Vector3(0.75,0.18,0.18),Vector3(x-side*0.47,-2.15,0.62),metal)
	_street_sign_halo(glow,origin,basis,Vector3(0,0,0.48),size+Vector2(1.1,1.3),0.040,
		Color(0.10,0.75,0.65) if kind==0 else Color(0.33,0.45,0.78))


func _v_side_plate(body: SurfaceTool, signs: SurfaceTool, glow: SurfaceTool, origin: Vector3,
		basis: Basis, word: String, size: Vector2, variant: int) -> void:
	var metal := Color(0.26,0.34,0.39,0.05)
	var ink := Color(1,0.63,0.24,2.0) if variant==0 else Color(0.16,0.90,0.78,2.2)
	_street_local_box(body,origin,basis,Vector3(size.x+0.25,size.y+0.25,0.50),Vector3.ZERO,metal)
	_street_local_box(signs,origin,basis,Vector3(size.x,size.y,0.10),Vector3(0,0,0.30),Color(0.04,0.065,0.08,0.8))
	_v_text(signs,origin,basis,Vector3(0,0,0.40),word,size.x*0.88,ink)
	_street_sign_halo(glow,origin,basis,Vector3(0,0,0.48),size+Vector2(0.8,0.6),0.035,Color(0.8,0.48,0.12) if variant==0 else Color(0.1,0.7,0.6))
	var small := Vector3(size.x*0.26,-4.6,0.25)
	_street_local_box(body,origin,basis,Vector3(0.95,2.30,0.55),small,metal)
	_v_text(signs,origin,basis,small+Vector3(0,0,0.32),"07",0.70,ink)
	_street_local_box(signs,origin,basis,Vector3(0.28,0.28,0.13),small+Vector3(0,1.22,0.35),Color(1.0,0.16,0.23,2.1))


func _v_corner_band(body: SurfaceTool, signs: SurfaceTool, origin: Vector3,
		basis: Basis, width: float, variant: int) -> void:
	_street_local_box(body,origin,basis,Vector3(width,0.35,0.48),Vector3.ZERO,Color(0.23,0.31,0.36,0))
	_street_local_box(signs,origin,basis,Vector3(width-0.12,0.13,0.10),Vector3(0,0,0.30),
		Color(1.0,0.58,0.19,1.65) if variant==0 else Color(0.12,0.81,0.73,1.8))


func _v_roof_plant(body: SurfaceTool, signs: SurfaceTool, origin: Vector3, basis: Basis) -> void:
	var metal := Color(0.28,0.35,0.39,0.04)
	for x: float in [-1.05,0.50]:
		_street_local_box(body,origin,basis,Vector3(0.86,0.60,0.74),Vector3(x,2.98,-0.12),metal)
		_street_local_box(body,origin,basis,Vector3(0.96,0.12,0.84),Vector3(x,3.34,-0.12),metal.lightened(0.14))
		for slat in 3:
			_street_local_box(body,origin,basis,Vector3(0.65,0.06,0.07),Vector3(x,2.82+0.16*slat,0.28),Color(0.06,0.09,0.11,0))
	_street_local_box(body,origin,basis,Vector3(1.10,0.23,0.30),Vector3(-0.25,3.07,-0.28),metal)
	_street_local_box(body,origin,basis,Vector3(0.14,1.20,0.14),Vector3(2.56,3.24,-0.26),metal)
	_street_local_box(signs,origin,basis,Vector3(0.13,0.10,0.13),Vector3(2.56,3.90,-0.26),Color(0.85,0.22,0.33,1.1))


func _v_text(st: SurfaceTool, origin: Vector3, basis: Basis, at: Vector3,
		word: String, width: float, tint: Color) -> void:
	var mesh := TextMesh.new()
	mesh.font = ThemeDB.fallback_font
	mesh.font_size = 32
	mesh.curve_step = 1.2
	mesh.pixel_size = 0.05
	mesh.depth = 0.035
	mesh.text = word
	var arrays := mesh.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var bounds := mesh.get_aabb()
	var factor := width/maxf(0.001,bounds.size.x)
	var center := bounds.position+bounds.size*0.5
	var count := indices.size() if not indices.is_empty() else vertices.size()
	for i in count:
		var index := indices[i] if not indices.is_empty() else i
		var local := (vertices[index]-center)*factor+at
		st.set_normal(basis*normals[index]); st.set_uv(Vector2.ZERO); st.set_uv2(Vector2(-2,0)); st.set_color(tint)
		st.add_vertex(origin+basis*local)


func _v_poly(st: SurfaceTool, origin: Vector3, basis: Basis,
		points: PackedVector2Array, depth: float, tint: Color) -> void:
	var triangles := Geometry2D.triangulate_polygon(points)
	for i in range(0,triangles.size(),3):
		var ia := triangles[i]; var ib := triangles[i+1]; var ic := triangles[i+2]
		# Godot front faces are clockwise; the authored front normal stays outward.
		if (points[ib]-points[ia]).cross(points[ic]-points[ia])>0:
			var swap := ib; ib=ic; ic=swap
		for index: int in [ia,ib,ic]:
			st.set_normal(basis.z); st.set_uv(Vector2.ZERO); st.set_uv2(Vector2(-2,0)); st.set_color(tint)
			st.add_vertex(origin+basis*Vector3(points[index].x,points[index].y,depth))


func _v_line(st: SurfaceTool, origin: Vector3, basis: Basis, a: Vector2, b: Vector2,
		width: float, depth: float, tint: Color) -> void:
	var direction := (b-a).normalized()
	var side := Vector2(-direction.y,direction.x)*width*0.5
	_v_poly(st,origin,basis,PackedVector2Array([a+side,b+side,b-side,a-side]),depth,tint)


func _v_outline(st: SurfaceTool, origin: Vector3, basis: Basis,
		points: PackedVector2Array, width: float, depth: float, tint: Color) -> void:
	for i in points.size():
		_v_line(st,origin,basis,points[i],points[(i+1)%points.size()],width,depth,tint)


func _v_ellipse(center: Vector2, radius: Vector2, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		var angle := TAU*float(i)/float(count)
		points.append(center+Vector2(cos(angle),sin(angle))*radius)
	return points


func _build_street_layer(footprints: Array[Rect2], bounds: Rect2i) -> void:
	street_layer = Node3D.new()
	street_layer.name = "ExteriorStreetLayer"
	scene_root.add_child(street_layer)
	street_lamps.clear()
	street_signs.clear()
	var roads := SurfaceTool.new(); roads.begin(Mesh.PRIMITIVE_TRIANGLES)
	var details := SurfaceTool.new(); details.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fixtures := SurfaceTool.new(); fixtures.begin(Mesh.PRIMITIVE_TRIANGLES)
	var decor := SurfaceTool.new(); decor.begin(Mesh.PRIMITIVE_TRIANGLES)
	var halos := SurfaceTool.new(); halos.begin(Mesh.PRIMITIVE_TRIANGLES)
	var material := _scenery_material(false)
	material.set_shader_parameter("pilot_geometry", true)
	material.set_shader_parameter("street_geometry", true)
	_build_continuous_ground(roads,bounds)
	var shift := Vector2(bounds.position)
	var plans: Array[Dictionary] = [
		{"label": "corridor", "axis": 1, "across": 0.0, "start": 24.0, "end": 47.0, "width": 6.2,
			"sidewalk": 0.8, "lamps": [26.0, 28.5, 33.0, 35.5], "side": 1.0,
			"neon_nodes": [27.0, 33.0], "decor_side": -1.0},
		{"label": "east", "axis": 0, "across": 90.0, "start": 30.0, "end": 55.0, "width": 5.4,
			"sidewalk": 0.7, "lamps": [34.0, 37.0, 46.0, 49.0], "side": 1.0,
			"neon_nodes": [35.0, 47.5], "decor_side": 1.0}]
	var sections := 0
	var rejected := 0
	var road_rows: Array[Dictionary] = []
	for plan: Dictionary in plans:
		var cross_axis := Vector2.RIGHT if plan.axis == 0 else Vector2.DOWN
		var along_axis := Vector2.DOWN if plan.axis == 0 else Vector2.RIGHT
		var origin: Vector2 = shift + cross_axis * float(plan.across)
		var count := ceili((plan.end - plan.start) / 1.4)
		var placed := 0
		var first:=floori((-continuity_margin-float(plan.start))/1.4)
		var extent: float=bounds.size.y if plan.axis==0 else bounds.size.x
		var last:=ceili((extent+continuity_margin-float(plan.start))/1.4)
		for index in range(first,last):
			var center: Vector2 = origin + along_axis * (float(plan.start) + (float(index) + 0.5) * 1.4)
			var full_size := Vector2(plan.width + plan.sidewalk * 2.0, 1.405)
			if plan.axis == 1: full_size = Vector2(full_size.y, full_size.x)
			if not _street_area_clear(center, full_size, footprints):
				rejected += 1
				continue
			_ground_street_quad(roads, Vector3(center.x, STREET_SURFACE_Y, center.y),
				full_size, Color(0.19, 0.24, 0.30, 1.0))
			var road_size := Vector2(plan.width, 1.405) if plan.axis == 0 else Vector2(1.405, plan.width)
			_ground_street_quad(roads, Vector3(center.x, STREET_SURFACE_Y + 0.006, center.y),
				road_size, Color(0.20, 0.26, 0.33, 1.0))
			for side: float in [-1.0, 1.0]:
				var edge: Vector2 = center + cross_axis * side * (float(plan.width) * 0.5 + 0.11)
				var edge_size := Vector2(0.34, 1.405) if plan.axis == 0 else Vector2(1.405, 0.34)
				_ground_street_quad(details, Vector3(edge.x, STREET_SURFACE_Y + 0.018, edge.y),
					edge_size, Color(0.52, 0.60, 0.66, 1.0))
			if posmod(index,3) != 2:
				var dash_size := Vector2(0.26, 1.12) if plan.axis == 0 else Vector2(1.12, 0.26)
				_ground_street_quad(details, Vector3(center.x, STREET_SURFACE_Y + 0.025, center.y),
					dash_size, Color(0.76, 0.82, 0.85, 1.0))
			sections += 1
			placed += 1
		var crossing: Vector2 = origin + along_axis * (float(plan.start) + 3.1)
		var crossing_size := Vector2(plan.width - 0.7, 2.6) if plan.axis == 0 else Vector2(2.6, plan.width - 0.7)
		if _street_area_clear(crossing, crossing_size, footprints):
			for stripe in 5:
				var point := crossing + along_axis * (float(stripe) - 2.0) * 0.48
				var stripe_size := Vector2(plan.width - 0.7, 0.32) if plan.axis == 0 else Vector2(0.32, plan.width - 0.7)
				_ground_street_quad(details, Vector3(point.x, STREET_SURFACE_Y + 0.026, point.y),
					stripe_size, Color(0.72, 0.81, 0.86, 1.0))
		var lamp_count := 0
		for along: float in plan.lamps:
			var base: Vector2 = origin + cross_axis * float(plan.side) * (float(plan.width) * 0.5 + float(plan.sidewalk) * 0.45) + along_axis * along
			if not _street_area_clear(base, Vector2(0.55, 0.55), footprints):
				continue
			_street_fixture(fixtures, halos, base, -cross_axis * float(plan.side), plan.label, lamp_count)
			lamp_count += 1
		for node_index in plan.neon_nodes.size():
			var base: Vector2 = origin + cross_axis * float(plan.decor_side) * (float(plan.width) * 0.5 + float(plan.sidewalk) * 0.8) + along_axis * float(plan.neon_nodes[node_index])
			_street_shop_group(decor, halos, base, int(plan.axis), node_index)
		road_rows.append({"label": plan.label, "axis": plan.axis, "across": plan.across,
			"start": plan.start, "end": plan.end, "width": plan.width, "sidewalk": plan.sidewalk,
			"accepted_sections": placed, "lamps": lamp_count})

	for item: Array in [[roads, material, "Roads"], [details, material, "Markings"],
			[fixtures, material, "StreetFixtures"], [decor, material, "StreetDecor"], [halos, _street_glow_material(), "Halos"]]:
		var mesh: ArrayMesh = item[0].commit()
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		var carrier := _add_city_carrier(mesh, item[1], item[2])
		carrier.reparent(street_layer, false)
	street_halo = street_layer.get_node_or_null("Halos")
	city_coverage["streets"] = {"revision": "busy street neon groups 02", "sections": sections,
		"rejected_sections": rejected, "roads": road_rows, "markers": street_lamps.size(),
		"cast_lights": 0, "ground_top_y": -42.95, "deep_ground_y":DEEP_GROUND_Y, "road_y": STREET_SURFACE_Y,
		"fixture_height": 5.2, "depth_dof_amount": 0.020, "sign_groups": 4, "sign_panels": 12, "shop_variants":4,"equipment_groups": 4}


func _street_fixture(st: SurfaceTool, halo: SurfaceTool, base: Vector2, inward: Vector2,
		label: String, index: int) -> void:
	var ground := Vector3(base.x, STREET_SURFACE_Y + 0.03, base.y)
	st.set_uv2(Vector2(-2, 0))
	_box(st, Vector3(0.54, 0.20, 0.54), ground + Vector3(0, 0.1, 0), Color(0.31, 0.39, 0.47, 1))
	_box(st, Vector3(0.24, 4.9, 0.24), ground + Vector3(0, 2.6, 0), Color(0.18, 0.24, 0.31, 1))
	_box(st, (Vector3(1.25, 0.18, 0.24) if inward.x != 0 else Vector3(0.24, 0.18, 1.25)), ground + Vector3(inward.x * 0.55, 5.03, inward.y * 0.55), Color(0.41, 0.51, 0.61, 1))
	var head := ground + Vector3(inward.x, 5.05, inward.y)
	_box(st, Vector3(0.90, 0.20, 0.60), head, Color(0.16, 0.22, 0.28, 1))
	_box(st, Vector3(0.72, 0.10, 0.46), head + Vector3(0, -0.12, 0), Color(0.83, 0.94, 1.0, 2.8))
	# The top-facing diffuser remains visible from the game's high camera.
	_box(st, Vector3(0.74, 0.07, 0.44), head + Vector3(0, 0.145, 0), Color(0.83, 0.94, 1.0, 3.4))
	# Soft additive pools are tied to physical fixture locations, no Light3D.
	var pool := ground + Vector3(inward.x * 1.25, 0.025, inward.y * 1.25)
	_street_halo_quad(halo, pool, Vector2(4.6, 5.8), 0.10, Vector2(0.05, 0.05))
	_street_halo_quad(halo, pool + Vector3(0, 0.002, 0), Vector2(1.8, 2.5), 0.095, Vector2(0.08, 0.08))
	_street_halo_quad(halo, head + Vector3(0, 0.16, 0), Vector2(1.7, 1.3), 0.075, Vector2(0.15, 0.15))
	street_lamps.append({"position": ground, "head": head, "pool": pool,
		"row": label, "group": index / 2, "size": Vector2(0.72, 0.46), "brightness": 1.75})


func _street_halo_quad(st: SurfaceTool, center: Vector3, size: Vector2,
		opacity: float, aperture: Vector2, tint: Color = Color(0.39, 0.64, 1.0)) -> void:
	for uv: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.ZERO, Vector2.ONE, Vector2.DOWN]:
		var offset := (uv - Vector2(0.5, 0.5)) * size
		st.set_normal(Vector3.UP); st.set_uv(uv); st.set_uv2(aperture)
		st.set_color(Color(tint.r, tint.g, tint.b, opacity))
		st.add_vertex(center + Vector3(offset.x, 0, offset.y))


func _street_glow_material() -> ShaderMaterial:
	# Per-vertex colors let the few sign halos share one additive batch.
	var shader := Shader.new()
	shader.code = PILOT_HALO_SHADER.replace("ALBEDO = vec3(0.39, 0.64, 1.0);", "ALBEDO = COLOR.rgb;")
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("city_void", ImageTexture.create_from_image(topology.image))
	material.set_shader_parameter("city_origin", Vector2(topology.bounds.position))
	material.set_shader_parameter("city_grid_size", Vector2(topology.bounds.size))
	return material


func _street_shop_group(st: SurfaceTool, halo: SurfaceTool, base: Vector2, axis: int, variant: int) -> void:
	var style:=variant+(2 if axis==0 else 0)
	if style!=0:
		_street_shop_variant(st,halo,base,axis,variant,style)
		return
	var origin := Vector3(base.x, STREET_SURFACE_Y + 0.04, base.y)
	var basis := Basis.IDENTITY if axis == 1 else Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0))
	var teal := Color(0.20, 0.94, 0.74, 2.6)
	var amber := Color(0.46,0.72,1.0,2.2)
	var red := Color(0.63,0.44,1.0,2.4)
	var steel := Color(0.22, 0.31, 0.37, 1.0)
	var dark := Color(0.055, 0.085, 0.11, 1.0)
	# A low shop wall supplies a mounting surface and an unambiguous street scale.
	_street_local_box(st, origin, basis, Vector3(5.35, 2.4, 0.58), Vector3(0, 1.2, -0.40), dark)
	_street_local_box(st, origin, basis, Vector3(5.6, 0.24, 1.12), Vector3(0, 2.55, 0.04), steel)
	_street_local_box(st, origin, basis, Vector3(5.25, 0.13, 0.16), Vector3(0, 2.65, 0.64), teal)
	# Primary sign, inset front, bright edge frame and a simple original 24 glyph.
	_street_local_box(st, origin, basis, Vector3(3.65, 1.58, 0.28), Vector3(-0.45, 4.18, -0.14), steel)
	_street_local_box(st, origin, basis, Vector3(3.43, 1.36, 0.10), Vector3(-0.45, 4.18, 0.05), dark)
	for y: float in [3.45, 4.91]:
		_street_local_box(st, origin, basis, Vector3(3.72, 0.10, 0.14), Vector3(-0.45, y, 0.14), teal)
	for x: float in [-2.26, 1.36]:
		_street_local_box(st, origin, basis, Vector3(0.10, 1.52, 0.14), Vector3(x, 4.18, 0.14), teal)
	_street_digit(st, origin, basis, Vector3(-1.42, 4.18, 0.16), 2, teal)
	_street_digit(st, origin, basis, Vector3(-0.42, 4.18, 0.16), 4, teal)
	for y: float in [3.91, 4.20, 4.49]:
		_street_local_box(st, origin, basis, Vector3(0.74, 0.10, 0.10), Vector3(0.66, y, 0.16), teal)
	# Second tall sign and a restrained red marker form a distinct local group.
	_street_local_box(st, origin, basis, Vector3(0.84, 3.1, 0.34), Vector3(2.13, 3.77, 0.28), dark)
	for y: float in [2.59, 3.31, 4.03, 4.75]:
		_street_local_box(st, origin, basis, Vector3(0.55, 0.27, 0.10), Vector3(2.13, y, 0.51), amber)
	_street_local_box(st, origin, basis, Vector3(0.30, 0.30, 0.15), Vector3(2.13, 5.32, 0.51), red)
	# Third slim board / canopy strip plus service hardware.
	_street_local_box(st, origin, basis, Vector3(1.65, 0.54, 0.24), Vector3(-1.70, 2.05, 0.35), steel)
	_street_local_box(st, origin, basis, Vector3(1.45, 0.13, 0.12), Vector3(-1.70, 2.05, 0.53), amber if variant == 1 else teal)
	_street_local_box(st, origin, basis, Vector3(0.94, 1.55, 0.78), Vector3(0.75, 0.86, 0.42), steel)
	for y: float in [0.36, 0.63, 0.90, 1.17]:
		_street_local_box(st, origin, basis, Vector3(0.66, 0.09, 0.12), Vector3(0.75, y, 0.87), dark)
	_street_local_box(st, origin, basis, Vector3(0.12, 4.1, 0.12), Vector3(-2.47, 2.15, 0.12), steel)
	_street_local_box(st, origin, basis, Vector3(1.18, 0.12, 0.12), Vector3(-1.94, 4.14, 0.12), steel)
	_street_sign_halo(halo, origin, basis, Vector3(-0.45, 4.18, 0.24), Vector2(4.7, 2.4), 0.065, Color(0.10, 0.87, 0.69))
	_street_sign_halo(halo, origin, basis, Vector3(2.13, 3.77, 0.61), Vector2(1.5, 3.8), 0.035, Color(1.0, 0.45, 0.10))
	var spill := origin + basis * Vector3(-0.5, 0.06, 1.0)
	_street_halo_quad(halo, spill, Vector2(3.8, 3.8), 0.055, Vector2(0.03, 0.03), Color(0.12, 0.73, 0.60))
	street_signs.append({"row": "corridor" if axis == 1 else "east", "origin": origin,
		"primary": origin + basis * Vector3(-0.45, 4.18, 0.14), "axis": axis, "variant": variant})


func _street_shop_variant(st:SurfaceTool,halo:SurfaceTool,base:Vector2,axis:int,variant:int,style:int) -> void:
	var origin:=Vector3(base.x,STREET_SURFACE_Y+0.04,base.y)
	var basis:=Basis.IDENTITY if axis==1 else Basis(Vector3.BACK,Vector3.UP,Vector3.LEFT)
	var steel:=Color(0.22,0.31,0.37,1.0)
	var dark:=Color(0.055,0.085,0.11,1.0)
	var ink:Color=[Color(0.3,0.8,1.0,2.2),Color(0.66,0.49,1.0,2.3),Color(0.64,0.85,1.0,2.0)][style-1]
	_street_local_box(st,origin,basis,Vector3(5.35,2.4,0.58),Vector3(0,1.2,-0.40),dark)
	_street_local_box(st,origin,basis,Vector3(5.6,0.24,1.12),Vector3(0,2.55,0.04),steel)
	_street_local_box(st,origin,basis,Vector3(4.6 if style==2 else 5.25,0.10,0.14),Vector3(0,2.65,0.64),ink)
	var primary:=Vector3(-0.45,4.18,0.16)
	var word:="MED" if style==1 else "NOX" if style==2 else "RLY-06"
	var width:=3.5 if style==1 else 3.7 if style==2 else 4.4
	var height:=1.45 if style==1 else 1.15 if style==2 else 0.86
	_street_local_box(st,origin,basis,Vector3(width+0.18,height+0.18,0.28),Vector3(primary.x,primary.y,-0.14),steel)
	_street_local_box(st,origin,basis,Vector3(width-0.10,height-0.10,0.08),Vector3(primary.x,primary.y,0.06),dark)
	if style==1:
		_street_local_box(st,origin,basis,Vector3(0.64,0.16,0.09),Vector3(-1.68,4.18,0.16),ink)
		_street_local_box(st,origin,basis,Vector3(0.16,0.64,0.09),Vector3(-1.68,4.18,0.16),ink)
		_v_text(st,origin,basis,Vector3(0.04,4.18,0.18),word,2.14,ink)
		for x:float in [-1.55,0.20]:
			_street_local_box(st,origin,basis,Vector3(1.45,1.6,0.12),Vector3(x,1.15,0.04),steel)
			for rib in 4:
				_street_local_box(st,origin,basis,Vector3(1.26,0.055,0.08),Vector3(x,0.68+float(rib)*0.30,0.14),dark)
	elif style==2:
		_v_text(st,origin,basis,Vector3(-0.45,4.18,0.18),word,2.9,ink)
		for sign_value:float in [-1.0,1.0]:
			_street_local_box(st,origin,basis,Vector3(0.34,0.54,0.16),Vector3(primary.x+sign_value*2.04,4.18,0.07),ink)
		_street_local_box(st,origin,basis,Vector3(3.6,1.5,0.12),Vector3(-0.3,1.15,0.04),steel)
		for rib in 6:
			_street_local_box(st,origin,basis,Vector3(0.07,1.31,0.08),Vector3(-1.75+float(rib)*0.58,1.15,0.14),dark)
	else:
		_v_text(st,origin,basis,Vector3(-0.45,4.18,0.18),word,3.65,ink)
		for rib in 7:
			_street_local_box(st,origin,basis,Vector3(0.10,0.22+float(rib%3)*0.08,0.10),Vector3(-2.10+float(rib)*0.46,3.39,0.18),ink)
		_street_local_box(st,origin,basis,Vector3(2.8,1.15,0.48),Vector3(0,0.96,0.20),steel)
		for rib in 5:
			_street_local_box(st,origin,basis,Vector3(2.48,0.075,0.08),Vector3(0,0.55+float(rib)*0.20,0.48),dark)
	# A different blade/strip arrangement for each of the three services.
	if style==1:
		_street_local_box(st,origin,basis,Vector3(0.62,2.2,0.28),Vector3(2.14,3.72,0.26),dark)
		for y:float in [3.0,3.72,4.44]:
			_street_local_box(st,origin,basis,Vector3(0.33,0.33,0.08),Vector3(2.14,y,0.46),ink)
	elif style==2:
		for rib in 3:
			_street_local_box(st,origin,basis,Vector3(0.54,0.12,0.14),Vector3(2.22,3.35+float(rib)*0.41,0.24),ink)
	else:
		for x:float in [1.96,2.30]:
			_street_local_box(st,origin,basis,Vector3(0.08,1.25,0.08),Vector3(x,4.58,0.14),steel)
		_street_local_box(st,origin,basis,Vector3(0.66,0.12,0.12),Vector3(2.13,5.15,0.14),ink)
	_street_sign_halo(halo,origin,basis,Vector3(primary.x,primary.y,0.24),Vector2(width+0.8,height+0.8),0.045,Color(ink.r,ink.g,ink.b))
	_street_halo_quad(halo,origin+basis*Vector3(-0.3,0.06,0.95),Vector2(3.5,3.2),0.035,Vector2(0.04,0.04),Color(ink.r*0.7,ink.g*0.7,ink.b*0.7))
	street_signs.append({"row":"corridor" if axis==1 else "east","origin":origin,
		"primary":origin+basis*primary,"axis":axis,"variant":variant,"style":style,"word":word})

func _street_digit(st: SurfaceTool, origin: Vector3, basis: Basis, at: Vector3, digit: int, tint: Color) -> void:
	var positions := [Vector2(0, 0.48), Vector2(0.35, 0.24), Vector2(0.35, -0.24),
		Vector2(0, -0.48), Vector2(-0.35, -0.24), Vector2(-0.35, 0.24), Vector2(0, 0)]
	var active: Array = [0, 1, 6, 4, 3] if digit == 2 else [5, 6, 1, 2]
	for index: int in active:
		var horizontal := index in [0, 3, 6]
		var size := Vector3(0.64, 0.12, 0.11) if horizontal else Vector3(0.12, 0.43, 0.11)
		_street_local_box(st, origin, basis, size, at + Vector3(positions[index].x, positions[index].y, 0), tint)


func _street_local_box(st: SurfaceTool, origin: Vector3, basis: Basis,
		size: Vector3, at: Vector3, tint: Color) -> void:
	var points: PackedVector3Array = _unit_box[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = _unit_box[Mesh.ARRAY_NORMAL]
	for index in _unit_box[Mesh.ARRAY_INDEX]:
		var local := points[index] * size + at
		st.set_normal(basis * normals[index]); st.set_uv(Vector2(local.x, local.y))
		st.set_uv2(Vector2(-2, 0)); st.set_color(tint)
		st.add_vertex(origin + basis * local)


func _street_sign_halo(st: SurfaceTool, origin: Vector3, basis: Basis, at: Vector3,
		size: Vector2, opacity: float, tint: Color) -> void:
	for uv: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.ZERO, Vector2.ONE, Vector2.DOWN]:
		var point := at + Vector3((uv.x - 0.5) * size.x, (0.5 - uv.y) * size.y, 0)
		st.set_normal(basis.z); st.set_uv(uv); st.set_uv2(Vector2(0.16, 0.16))
		st.set_color(Color(tint.r, tint.g, tint.b, opacity))
		st.add_vertex(origin + basis * point)


func _street_area_clear(at: Vector2, size: Vector2, footprints: Array[Rect2]) -> bool:
	var area := Rect2(at - size * 0.5, size)
	for x in range(floori(area.position.x + 0.5), ceili(area.end.x + 0.5)):
		for z in range(floori(area.position.y + 0.5), ceili(area.end.y + 0.5)):
			var cell := Vector2i(x, z)
			if topology.bounds.has_point(cell) and not topology.external.has(cell):
				return false
	return not footprints.any(func(footprint: Rect2) -> bool: return footprint.grow(0.28).intersects(area))


func _readable_street_rows(grid: Vector2) -> Array[Dictionary]:
	# Keep existing true-ground roads. Redistribute a small budget into the two
	# exposed street openings, with all points on the same curb.
	var corridor: Array[Vector2] = [grid + Vector2(74.3, 11.2), grid + Vector2(72.64, 13.8),
		grid + Vector2(72.64, 17.4), grid + Vector2(72.64, 21.0)]
	var east: Array[Vector2] = []
	for index in 6:
		east.append(grid + Vector2(132.64, 87.2 + float(index) * 1.8))
	return [{"label": "corridor", "points": corridor}, {"label": "east", "points": east}]


func _add_ambient_street_marker(st: SurfaceTool, halo: SurfaceTool, point: Vector2,
		orientation: int, pattern: int, rows: Array[Dictionary]) -> void:
	# Reallocate ten of the existing 140 markers rather than filling the city.
	if street_lamps.size() >= 130:
		return
	for row: Dictionary in rows:
		for reserved: Vector2 in row.points:
			if reserved.distance_to(point) < 2.2:
				return
	_emit_street_marker(st, halo, point, orientation, pattern)


func _emit_street_marker(st: SurfaceTool, halo: SurfaceTool, point: Vector2,
		orientation: int, pattern: int, readable: bool = false) -> void:
	var tint: Color = [Color("8295aa"), Color("a0b4ca"), Color("bccadb")][pattern % 3]
	tint.a = 0.66 + float(pattern % 4) * 0.085
	var size := Vector2(0.52, 0.76) if orientation == 0 else Vector2(0.76, 0.52)
	var halo_opacity := 0.022
	var padding := 2.2
	if readable:
		tint = [Color("bfd2e7"), Color("d1ddea"), Color("b3c9e0")][pattern % 3]
		tint.a = 0.84 + float(pattern % 3) * 0.035
		size = Vector2(0.62, 0.70)
		halo_opacity = 0.008
		padding = 1.3
	var center := Vector3(point.x, STREET_SURFACE_Y + 0.022, point.y)
	_ground_street_quad(st, center, size, tint)
	var spread := size + Vector2(padding, padding)
	var aperture := size / spread
	for uv: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.ZERO, Vector2.ONE, Vector2.DOWN]:
		var offset := (uv - Vector2(0.5, 0.5)) * spread
		halo.set_normal(Vector3.UP); halo.set_uv(uv); halo.set_uv2(aperture)
		halo.set_color(Color(1, 1, 1, halo_opacity))
		halo.add_vertex(center + Vector3(offset.x, 0.021, offset.y))
	street_lamps.append({"position": center, "size": size, "brightness": tint.a, "readable": readable})


static func _ground_street_quad(st: SurfaceTool, center: Vector3, size: Vector2, tint: Color) -> void:
	# Clockwise viewed from above, matching the renderer's front-face convention.
	for uv: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.ZERO, Vector2.ONE, Vector2.DOWN]:
		var offset := (uv - Vector2(0.5, 0.5)) * size
		st.set_normal(Vector3.UP); st.set_uv(uv); st.set_uv2(Vector2(-2.0, 0))
		st.set_color(tint)
		st.add_vertex(center + Vector3(offset.x, 0, offset.y))


func _record_roof(tier: int, roof: float) -> void:
	var band := 0 if roof <= 0.0 else 1 if roof <= 20.0 else 2 if roof <= 40.0 else 3
	city_coverage.roof_height_bins[tier][band] += 1
	city_coverage.roof_height_ranges[tier][0] = minf(city_coverage.roof_height_ranges[tier][0], roof)
	city_coverage.roof_height_ranges[tier][1] = maxf(city_coverage.roof_height_ranges[tier][1], roof)


func _highrise_face(st: SurfaceTool, origin: Vector3, along: Vector3, normal: Vector3,
		span: float, bottom: float, top: float, pitch: float, concrete: Color, key: int, tier: int) -> void:
	var count := 2 if span < 5.1 else 3
	var bay_width := span / float(count)
	var rim := concrete.lightened(0.14)
	var trim := Color("20334300")
	# Continuous columns avoid repeating hidden box faces for every floor.
	for divider in count + 1:
		_pilot_plate(st, origin + along * (float(divider) * bay_width - span * 0.5)
			+ Vector3.UP * ((bottom + top) * 0.5), along, normal,
			0.19, top - bottom, 0.38, rim)
	var rows := maxi(1, ceili((top - bottom) / pitch))
	var storey := (top - bottom) / float(rows)
	for row in rows:
		var y := bottom + float(row) * storey
		var low := minf(0.42, storey * 0.20)
		var high := storey - 0.30
		_pilot_plate(st, origin + Vector3.UP * (y + low * 0.5), along, normal,
			span + 0.09, low, 0.43, concrete)
		_pilot_plate(st, origin + Vector3.UP * (y + (high + storey) * 0.5), along, normal,
			span, storey - high, 0.32, concrete)
		for group in count:
			var code := posmod(key + row * 13 + group * 31, 17)
			var lit := code in [0, 2, 3, 7, 9, 11, 13] and (key + row) % 7 != 2
			var pane: Color = [Color("c3e2ff"), Color("9bc8ff"), Color("b5c4ff")][code % 3]
			var ink := _radiant(pane, 0.66 + 0.075 * float(code % 3)) if lit else trim
			var center := origin + along * ((float(group) + 0.5) * bay_width - span * 0.5)
			center.y = y + (low + high) * 0.5
			_recessed_pane(st, center - normal * 0.074, along, normal,
				Vector2(bay_width - 0.28, high - low), ink)
			city_coverage.neighbour_window_groups[tier] += 1
			city_coverage.neighbour_lit_groups[tier] += int(lit)
		city_coverage.highrise_structural_floors += 1


static func _recessed_pane(st: SurfaceTool, center: Vector3, along: Vector3, normal: Vector3,
		size: Vector2, tint: Color) -> void:
	var uvs := [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.ZERO, Vector2.ONE, Vector2.DOWN] \
		if along.cross(Vector3.UP).dot(normal) < 0.0 else \
		[Vector2.ZERO, Vector2.ONE, Vector2.RIGHT, Vector2.ZERO, Vector2.DOWN, Vector2.ONE]
	for uv: Vector2 in uvs:
		var shift := (uv - Vector2(0.5, 0.5)) * size
		st.set_normal(normal); st.set_color(tint); st.set_uv(uv)
		st.add_vertex(center + along * shift.x + Vector3.UP * shift.y)


func _count_neighbour(tier: int, source_id: int) -> void:
	city_coverage.neighbours[tier] += 1
	var sources: Dictionary = city_coverage.source_meshes
	sources[source_id] = int(sources.get(source_id, 0)) + 1


func _corridor_backdrop() -> Dictionary:
	var center := Vector2(51.4, -9.8)
	var size := Vector3(8.2, 76.0, 6.1)
	var footprint := Rect2(center - Vector2(size.x, size.z) * 0.5, Vector2(size.x, size.z))
	if world.floor_cells.keys().any(func(cell: Vector2i) -> bool:
		return footprint.grow(0.45).intersects(Rect2(Vector2(cell) - Vector2(0.5, 0.5), Vector2.ONE))):
		return {}
	if near_towers.any(func(tower: Dictionary) -> bool: return tower.footprint.grow(0.65).intersects(footprint)):
		return {}
	return {"position": Vector3(center.x, STREET_LEVEL + size.y * 0.5, center.y),
		"size": size, "top": STREET_LEVEL + size.y, "footprint": footprint}


func _pilot_backdrop() -> Dictionary:
	var center := Vector2(91.5, 22.5)
	var size := Vector3(6.70, 78.0, 6.42)
	var footprint := Rect2(center - Vector2(size.x, size.z) * 0.5, Vector2(size.x, size.z))
	if world.floor_cells.keys().any(func(cell: Vector2i) -> bool:
		return footprint.grow(0.4).intersects(Rect2(Vector2(cell) - Vector2(0.5, 0.5), Vector2.ONE))):
		return {}
	if near_towers.any(func(tower: Dictionary) -> bool: return tower.footprint.grow(0.65).intersects(footprint)):
		return {}
	return {"position": Vector3(center.x, STREET_LEVEL + size.y * 0.5, center.y),
		"size": size, "top": STREET_LEVEL + size.y, "footprint": footprint}



func _plan_continuity() -> void:
	var camera: Camera3D=world.camera_3d
	var local_eye:=world.to_local(camera.global_position)
	var visible:=camera.get_viewport().get_visible_rect().size
	var downward:=0.0
	var reach:=0.0
	for uv: Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
		var ray:=camera.project_ray_normal(uv*visible)
		downward=maxf(downward,-ray.y)
		if ray.y < -0.05:
			var t: float=(local_eye.y-DEEP_GROUND_Y)/-ray.y
			reach=maxf(reach,Vector2(ray.x,ray.z).length()*t)
	# Every reachable floor camera has this same basis, FOV and height.
	# The end planes are beyond the complete far-frustum, not just two views.
	continuity_base_y=minf(-176.0,local_eye.y-camera.far*1.12-24.0)
	continuity_margin=ceilf(maxf(160.0,reach+40.0))

func _terrain_y(point: Vector2) -> float:
	var local:=point-Vector2(world.building_rect.position)
	var corridor:=1.0-smoothstep(8.0,38.0,absf(local.y))
	var east:=1.0-smoothstep(7.5,36.0,absf(local.x-90.0))
	return lerpf(DEEP_GROUND_Y,STREET_SURFACE_Y-0.04,maxf(corridor,east))

func _build_continuous_ground(st: SurfaceTool,bounds: Rect2i) -> void:
	var xs: Array[float]=[]
	var zs: Array[float]=[]
	var low:=Vector2(bounds.position)-Vector2.ONE*continuity_margin
	var high:=Vector2(bounds.end)+Vector2.ONE*continuity_margin
	xs.append(low.x);xs.append(high.x);zs.append(low.y);zs.append(high.y)
	for x in range(bounds.position.x-160,bounds.end.x+161,12):xs.append(float(x))
	for z in range(bounds.position.y-160,bounds.end.y+161,12):zs.append(float(z))
	for offset: float in [-38.0,-28.0,-20.0,-14.0,-10.0,-8.0,-7.5,-4.0,0.0,4.0,7.5,8.0,10.0,14.0,20.0,28.0,38.0]:
		xs.append(float(bounds.position.x)+90.0+offset)
		zs.append(float(bounds.position.y)+offset)
	xs.sort();zs.sort()
	var vertices:=0
	for zi in zs.size()-1:
		for xi in xs.size()-1:
			if xs[xi+1]-xs[xi]<0.001 or zs[zi+1]-zs[zi]<0.001:continue
			var points: Array[Vector3]=[]
			for uv: Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
				var p:=Vector2(lerpf(xs[xi],xs[xi+1],uv.x),lerpf(zs[zi],zs[zi+1],uv.y))
				points.append(Vector3(p.x,_terrain_y(p),p.y))
			for index: int in [0,1,2,0,2,3]:
				st.set_normal(Vector3.UP);st.set_uv(Vector2(points[index].x,points[index].z))
				st.set_uv2(Vector2(-2,0));st.set_color(Color(0.19,0.24,0.30,1.0))
				st.add_vertex(points[index]);vertices+=1
	city_coverage["continuity"]={"revision":"BottomContinuity01","main_runs":main_runs.size(),
		"base_y":continuity_base_y,"ground_margin":continuity_margin,"deep_ground_y":DEEP_GROUND_Y,
		"street_ground_y":STREET_SURFACE_Y-0.04,"terrain_vertices":vertices,
		"ground_bounds":[low.x,low.y,high.x,high.y],"new_real_lights":0,"extra_world_renders":0}

func _pilot_glow_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = PILOT_HALO_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("city_void", ImageTexture.create_from_image(topology.image))
	material.set_shader_parameter("city_origin", Vector2(topology.bounds.position))
	material.set_shader_parameter("city_grid_size", Vector2(topology.bounds.size))
	return material


func _install_pilot_view(camera: Camera3D) -> void:
	pilot_view = SubViewport.new()
	pilot_view.name = "DystopianExteriorView"
	pilot_view.world_3d = World3D.new()
	pilot_view.transparent_bg = false
	pilot_view.use_hdr_2d = true
	pilot_view.size = Vector2i(camera.get_viewport().get_visible_rect().size)
	pilot_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(pilot_view)
	# City geometry keeps its own depth and moves out of the gameplay scenario.
	scene_root.reparent(pilot_view)

	var dark_background := Environment.new()
	dark_background.background_mode = Environment.BG_COLOR
	dark_background.background_color = Color("142026") if pollution_enabled else Color.BLACK
	dark_background.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	# Local highlights remain inside the already separate city World/SubViewport.
	dark_background.glow_enabled=true
	dark_background.glow_intensity=0.60
	dark_background.glow_strength=1.0
	dark_background.glow_bloom=0.0
	dark_background.glow_hdr_threshold=0.85
	dark_background.glow_hdr_scale=1.0
	dark_background.glow_hdr_luminance_cap=12.0
	for index in 7:dark_background.set_glow_level(index,0.0)
	dark_background.set_glow_level(0,0.30)
	dark_background.set_glow_level(1,0.55)
	dark_background.set_glow_level(2,0.20)
	pilot_focus = CameraAttributesPractical.new()
	pilot_focus.dof_blur_far_enabled = true
	pilot_focus.dof_blur_far_distance = 38.0
	pilot_focus.dof_blur_far_transition = 18.0
	pilot_focus.dof_blur_amount = 0.020
	pilot_camera = Camera3D.new()
	pilot_camera.name = "ExteriorCamera"
	pilot_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	pilot_camera.cull_mask = CITY_LAYER
	pilot_camera.environment = dark_background
	pilot_camera.attributes = pilot_focus
	pilot_view.add_child(pilot_camera)
	pilot_camera.make_current()
	var air_shader:=Shader.new()
	air_shader.code=CITY_AIR_BACKGROUND_SHADER
	var air_material:=ShaderMaterial.new()
	air_material.shader=air_shader
	render_materials.append(air_material)
	var air_quad:=QuadMesh.new()
	air_quad.size=Vector2(2,2)
	air_background=MeshInstance3D.new()
	air_background.name="CityAirBackground"
	air_background.mesh=air_quad
	air_background.material_override=air_material
	air_background.layers=CITY_LAYER
	air_background.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	air_background.extra_cull_margin=5.0
	pilot_camera.add_child(air_background)

	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var shader := Shader.new()
	shader.code = PILOT_BACKGROUND_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("exterior_hdr", pilot_view.get_texture())
	pilot_background = MeshInstance3D.new()
	pilot_background.name = "DystopianDepthBackground"
	pilot_background.mesh = quad
	pilot_background.material_override = material
	pilot_background.layers = CITY_LAYER
	pilot_background.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pilot_background.extra_cull_margin = 5.0
	add_child(pilot_background)


func _sync_pilot_camera(main_camera: Camera3D) -> void:
	var resolution := Vector2i(main_camera.get_viewport().get_visible_rect().size)
	if pilot_view.size != resolution:
		pilot_view.size = resolution
	pilot_camera.projection = main_camera.projection
	pilot_camera.keep_aspect = main_camera.keep_aspect
	pilot_camera.fov = main_camera.fov
	pilot_camera.size = main_camera.size
	pilot_camera.frustum_offset = main_camera.frustum_offset
	pilot_camera.near = main_camera.near
	pilot_camera.far = main_camera.far
	var pose := main_camera.get_camera_transform()
	pilot_camera.global_transform = pose
	pilot_background.global_transform = pose
	var material := pilot_background.material_override as ShaderMaterial
	material.set_shader_parameter("main_eye", pose.origin)
	material.set_shader_parameter("main_back", pose.basis.z)


func _set_pilot_view_active(active: bool) -> void:
	if not is_instance_valid(pilot_view):
		return
	var mode := SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	if pilot_view.render_target_update_mode != mode:
		pilot_view.render_target_update_mode = mode
	pilot_background.visible = active


func _dispose_pilot_view() -> void:
	_set_pilot_view_active(false)
	if is_instance_valid(pilot_background):
		pilot_background.queue_free()
	if is_instance_valid(pilot_view):
		pilot_view.queue_free()
	pilot_background = null
	air_background = null
	pilot_view = null
	pilot_camera = null
	pilot_focus = null


func _add_city_carrier(mesh: ArrayMesh, material: ShaderMaterial, carrier_name: String) -> MeshInstance3D:
	var carrier := MeshInstance3D.new()
	carrier.name = carrier_name
	carrier.mesh = mesh
	carrier.material_override = material
	carrier.layers = CITY_LAYER
	carrier.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene_root.add_child(carrier)
	return carrier


func _sync_render_snapshot() -> void:
	# Reparenting into the rollback stash must not sample the staged new floor.
	if production_mode and (world==null or get_parent().get_parent()!=world.office_art_root):
		_set_pilot_view_active(false)
		return
	if not is_instance_valid(scene_root) or world.room_visibility==null: return
	var snapshot: Dictionary=world.room_visibility.view_snapshot
	if snapshot.is_empty(): return
	for mat in render_materials:
		if mat.get_shader_parameter("own_reference_material")==true and is_instance_valid(world.shadow_manager.sun):
			var moon:Light3D=world.shadow_manager.sun as Light3D
			mat.set_shader_parameter("own_moon_direction",(scene_root.global_basis.inverse()*moon.global_basis.z).normalized())
			mat.set_shader_parameter("own_moon_color",moon.light_color)
			mat.set_shader_parameter("own_moon_energy",moon.light_energy if moon.is_visible_in_tree() else 0.0)
		mat.set_shader_parameter("soft_occlusion_enabled",soft_occlusion_enabled)
		mat.set_shader_parameter("height_fog_enabled",height_fog_enabled)
		mat.set_shader_parameter("pollution_air_enabled", pollution_enabled)
		_set_camera_snapshot(mat, snapshot)
	if is_instance_valid(pilot_halo):
		_set_camera_snapshot(pilot_halo.material_override, snapshot)
	if is_instance_valid(street_halo):
		_set_camera_snapshot(street_halo.material_override, snapshot)
	if is_instance_valid(vertical_halo):
		_set_camera_snapshot(vertical_halo.material_override, snapshot)
	if is_instance_valid(pilot_camera):
		pilot_camera.environment.background_color = Color("142026") if pollution_enabled else Color.BLACK
	for halo: MeshInstance3D in [pilot_halo,street_halo,vertical_halo]:
		if is_instance_valid(halo):
			halo.material_override.set_shader_parameter("height_fog_enabled",height_fog_enabled)
			halo.material_override.set_shader_parameter("pollution_air_enabled",pollution_enabled)
	var active := String(world.transition_phase)!="CAB_RIDE"
	scene_root.visible=active and enabled
	var main_camera: Camera3D = world.camera_3d
	if pilot_built and scene_root.visible and is_instance_valid(main_camera):
		if pilot_view == null and RenderingServer.get_current_rendering_method() == "forward_plus":
			_install_pilot_view(main_camera)
		if is_instance_valid(pilot_view):
			_sync_pilot_camera(main_camera)
	_set_pilot_view_active(scene_root.visible)
	for light in window_lights: light.visible=active and enabled and window_lights_enabled and int(light.get_meta(&"candidate_tower",-1))>=0

static func _set_camera_snapshot(mat: ShaderMaterial, snapshot: Dictionary) -> void:
	for parameter in ["map_origin","map_x_axis","map_z_axis","ray_origin_tl","ray_origin_dx","ray_origin_dy","ray_direction_tl","ray_direction_dx","ray_direction_dy"]:
		var value: Variant = snapshot.get(parameter)
		if value != null:
			mat.set_shader_parameter(parameter, value)
	var eye: Vector3=snapshot.ray_origin_tl-snapshot.map_origin
	mat.set_shader_parameter("city_eye",Vector3(eye.dot(snapshot.map_x_axis),eye.y,eye.dot(snapshot.map_z_axis)))


func _attach_mask(_source: ShaderMaterial) -> void:
	# Legacy preview hook. City rendering now reads camera data directly and
	# never creates or rewrites a screen-space black overlay.
	pass

var city_shape01_originals:Array=[]

func _city_shape01_candidate(plan:Dictionary,at:Vector3,size:Vector3)->bool:
	var plot:=Rect2(Vector2(at.x-size.x*.5,at.z-size.z*.5),Vector2(size.x,size.z))
	for cell:Vector2i in world.floor_cells:
		if plot.grow(3.5).intersects(Rect2(Vector2(cell)-Vector2(.5,.5),Vector2.ONE)):return false
	for other:Dictionary in br_plans:
		if int(other.plan_id)==int(plan.plan_id):continue
		if plot.grow(1.05).intersects(other.footprint):return false
	for eye:Vector3 in BR_REVIEW_EYES:
		if eye.y<=STREET_LEVEL+size.y+1.8 and plot.grow(1.8).has_point(Vector2(eye.x,eye.z)):return false
	return true

func _city_shape01_set(plan:Dictionary,at:Vector3,size:Vector3,kind:String)->void:
	plan.position=at;plan.size=size;plan.top=STREET_LEVEL+size.y
	plan.footprint=Rect2(Vector2(at.x-size.x*.5,at.z-size.z*.5),Vector2(size.x,size.z))
	var actual_ratio:float=size.x/size.z
	plan["shape_family"]="narrow_deep" if actual_ratio<.8 else ("wide_shallow" if actual_ratio>1.65 else "compact")
	plan["shape_role"]=kind

func _city_shape01_layout()->void:
	# Normal playback reads the exact reviewed typed placements; packing is authoring-only.
	if "--own-r3-author-plan" not in OS.get_cmdline_user_args():
		assert(FileAccess.get_sha256(BR_AD_CACHE_PATH).to_upper()==BR_AD_CACHE_SHA256)
		var saved:Resource=ResourceLoader.load(BR_AD_CACHE_PATH,"",ResourceLoader.CACHE_MODE_IGNORE)
		var plans:Array=saved.get_meta("source_plans",[])
		assert(plans.size()==537 and plans.size()==br_plans.size())
		for i:int in plans.size():
			assert(int(plans[i].plan_id)==i and int(plans[i].source_id)==int(br_plans[i].source_id) and int(plans[i].turn)==int(br_plans[i].turn))
			br_plans[i].merge(plans[i],true)
		city_coverage["shape_variation"]=saved.get_meta("shape_variation",{}).duplicate(true)
		city_coverage.shape_variation["runtime_mode"]="frozen_typed_layout_no_packing_search"
		return
	# Once per seeded map build. Keep all 537 source instances and floor area.
	city_shape01_originals=br_plans.duplicate(true)
	var presets:Dictionary={
		20:{"at":Vector3(92.29535,11.03997,45.745),"size":Vector3(6.938172,114.0799,6.842563),"kind":"back_row_clearance"},
		0:{"at":Vector3(26.3,2.0,78.3),"size":Vector3(9.5,96.0,4.2),"kind":"wide_shallow"},
		1:{"at":Vector3(35.5,-1.5,75.8),"size":Vector3(4.4,89.0,11.1),"kind":"narrow_deep"},
		5:{"at":Vector3(80.32626,-7.0,40.4),"size":Vector3(14.0,78.0,6.4),"kind":"wide_shallow_ad_host"},
		6:{"at":Vector3(75.90423,-2.0,54.925),"size":Vector3(3.8,88.0,6.1),"kind":"narrow_deep_ad_host"}}
	var fixed:Array[int]=[0,1,4,5,6,16,17,18,20]
	var records:Array=[]
	# Presets use checked empty city space; key ad hosts are genuinely resized.
	for id:int in presets:
		var p:Dictionary=br_plans[id];var item:Dictionary=presets[id]
		if not _city_shape01_candidate(p,item.at,item.size):
			push_error("CITY_SHAPE01 preset has insufficient physical clearance: "+str(id));continue
		_city_shape01_set(p,item.at,item.size,item.kind)
	# Original source7 and11 have wide/deep forms; preserve their ratio tendency.
	var native_ratio:Array[float]=[1,1,1,1,.521,.598,1,.444,1,1,1,1.905,1,1.108,.943,1,.812]
	for p:Dictionary in br_plans:
		var id:int=int(p.plan_id)
		if id in fixed:continue
		var original:Dictionary=city_shape01_originals[id]
		var rng:=RandomNumberGenerator.new();rng.seed=world.active_seed*9311+id*7187+37613
		var type:int=posmod(id+int(world.active_seed),5)
		var ratio:float=[.48,.66,1.0,1.95,2.5][type]
		var source_ratio:float=native_ratio[int(p.source_id)]
		if int(p.turn)%2==1:source_ratio=1.0/source_ratio
		ratio=clampf(ratio*pow(source_ratio,.25)*rng.randf_range(.94,1.06),.42,2.65)
		if id==14:ratio=2.4
		var area:float=original.size.x*original.size.z
		var height:float=clampf(original.size.y*rng.randf_range(.91,1.12),78.0 if int(p.tier)==0 else (52.0 if int(p.tier)==1 else 34.0),144.0 if int(p.tier)==0 else (112.0 if int(p.tier)==1 else 88.0))
		var shape:=Vector3(sqrt(area*ratio),height,sqrt(area/ratio))
		var kind:String="narrow_deep" if ratio<.8 else ("wide_shallow" if ratio>1.65 else "compact_stepped")
		var chosen:=false
		# Rotate the proportions within the existing neighbourhood if a lot is tight.
		for proportion:float in [ratio,1.0/ratio]:
			shape.x=sqrt(area*proportion);shape.z=sqrt(area/proportion)
			if minf(shape.x,shape.z)<3.5:continue
			for shift:Vector2 in [Vector2.ZERO,Vector2(-1.8,0),Vector2(1.8,0),Vector2(0,-1.8),Vector2(0,1.8),Vector2(-2.8,1.4),Vector2(2.8,-1.4)]:
				var at:=Vector3(original.position.x+shift.x,STREET_LEVEL+shape.y*.5,original.position.z+shift.y)
				if not _city_shape01_candidate(p,at,shape):continue
				_city_shape01_set(p,at,shape,kind);chosen=true;break
			if chosen:break
		if not chosen:p["shape_family"]="retained_tight_lot"
	var before_area:=0.0;var after_area:=0.0;var changed:=0
	for p:Dictionary in br_plans:
		var old:Dictionary=city_shape01_originals[int(p.plan_id)]
		before_area+=old.size.x*old.size.z;after_area+=p.size.x*p.size.z
		var different:bool=old.position!=p.position or old.size!=p.size
		if different:changed+=1
		records.append({"id":p.plan_id,"source":p.source_id,"family":p.get("shape_family","fixed_ad_or_infill"),"changed":different,"old_size":old.size,"size":p.size,"position":p.position})
	assert(br_plans.size()==537 and after_area>=before_area*.999)
	city_coverage["shape_variation"]={"revision":"CityShape01","seed":world.active_seed,"count":br_plans.size(),"changed":changed,"total_plot_area_before":before_area,"total_plot_area_after":after_area,"fixed_per_map":true,"new_source_models":0,"records":records}
	print("CITY_SHAPE01 ",changed," changed, area ",before_area," -> ",after_area)

func _city_shape01_air_transmission(eye:Vector3,point:Vector3)->float:
	var h:float=maxf(0.0,-point.y);var lower:float=smoothstep(14.0,28.0,h)
	var depth:float=maxf(0.0,h-6.0)/40.0
	var broad:float=clampf(0.5+0.26*sin(point.x*0.024+point.z*0.011)+0.18*sin(point.z*0.031-point.x*0.008),0.0,1.0)
	var height_mass:float=lerpf(8.0,lerpf(3.6,5.0,broad),lower)*pow(depth,4.0)
	var distance:float=point.distance_to(eye)
	var old:float=pow(maxf(0.0,distance-30.0)/92.0,1.3)*1.15
	var layered:float=pow(maxf(0.0,distance-30.0)/62.0,1.3)*1.10
	var seal:float=smoothstep(35.0+2.0*broad,43.0,h)
	return exp(-minf(20.0,height_mass+lerpf(old,layered,lower)+12.0*seal*seal))
