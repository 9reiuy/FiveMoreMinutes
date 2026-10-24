uniform bool group_outline = true;
uniform float outline_width_texels = 2.0;
uniform float smoke_clock = 0.0;
uniform bool clip_at_floor = false;
uniform bool receive_scene_light = true;
uniform bool fusion_enabled = false;
uniform bool outer_outline_pass = false;
uniform bool collective_fusion = false;
uniform sampler2D fusion_field : filter_nearest, repeat_disable;
uniform mat4 world_to_floor;
varying float card_size;
varying float floor_height;
varying vec4 fusion_link;
float cloud_union(float a,float b,float width) {
	float h=clamp(.5+.5*(b-a)/max(.0001,width),0.0,1.0);
	return mix(b,a,h)-width*h*(1.0-h);
}
float cloud_hash(float value) {
	return fract(sin(value*127.1+311.7)*43758.5453);
}
// Shared analytic field for all contributing groups. Smooth minimum creates
// a real bulging neck before contact, without any capsule between two centres.
float group_field(vec2 point,float visual_seed,float time) {
	vec2 q=point*.72;
	float seed=visual_seed*6.283185;
	float angle=cloud_hash(seed+2.0)*6.283185;
	vec2 axis=vec2(cos(angle),sin(angle));
	vec2 cross_axis=vec2(-axis.y,axis.x);
	vec2 a=-axis*(.075+.045*cloud_hash(seed+3.0));
	vec2 b=axis*(.065+.045*cloud_hash(seed+4.0))+cross_axis*(cloud_hash(seed+5.0)-.5)*.06;
	float ra=.165+.05*cloud_hash(seed+6.0);
	float rb=.145+.06*cloud_hash(seed+7.0);
	float result=cloud_union(length(q-a)-ra,length(q-b)-rb,.045);
	int count=7+int(min(6.0,floor(visual_seed*7.0)));
	for(int i=2;i<13;i++) {
		if(i>=count)break;
		float item=seed+float(i)*19.37;
		float r=.045+.13*pow(cloud_hash(item+1.0),1.35);
		vec2 c=axis*(cloud_hash(item+2.0)-.5)*(.38+.17*cloud_hash(seed+8.0))
			+cross_axis*(cloud_hash(item+3.0)-.5)*(.23+.18*cloud_hash(seed+9.0));
		c=clamp(c,vec2(-.44+r),vec2(.44-r));
		bool near_a=length(c-a)<length(c-b);
		vec2 anchor=near_a ? a : b;
		float reach=(near_a ? ra : rb)+r-.025;
		vec2 delta=c-anchor;
		c=anchor+delta*min(1.0,reach/max(.001,length(delta)));
		c+=cross_axis*sin((time*.55+seed)*.7+float(i))*.006;
		result=cloud_union(result,length(q-c)-r,.025);
	}
	return result/.72;
}
void vertex() {
	card_size=length(MODEL_MATRIX[0].xyz);
	fusion_link=INSTANCE_CUSTOM;
	// Give the thicker exterior ink real quad margin; never chop it at UV=0/1.
	float padding=(fusion_enabled ? .12 : 0.0)+(group_outline ? outline_width_texels/max(8.0,round(card_size*32.0)) : 0.0);
	VERTEX.xy*=1.0+2.0*padding;
	floor_height=(world_to_floor*MODEL_MATRIX*vec4(VERTEX,1.0)).y;
}
void fragment() {
	// One quad carries 7-13 circles. Production draws all black silhouettes
	// before coloured fills; paired neighbours can share a small soft neck.
	// Only its ground-contact base may be cut flat, never its outer sides.
	if(clip_at_floor && floor_height<.06)discard;
	float pixels=max(8.0,round(card_size*32.0));
	float extent=1.0+2.0*((fusion_enabled ? .12 : 0.0)+(group_outline ? outline_width_texels/pixels : 0.0));
	vec2 sheet_uv=(UV-vec2(.5))*extent+vec2(.5);
	vec2 texel=floor(sheet_uv*pixels);
	vec2 p=(texel+vec2(.5))/pixels-vec2(.5);
	float seed=COLOR.r*6.283185;
	float phase=smoke_clock*.55+seed;
	vec2 q=p;
	int circles=7+int(min(6.0,floor(COLOR.r*7.0)));
	// Two modest overlapping supports, not a fixed giant central ball.
	// All remaining circles have independently varied radii and positions.
	float angle=cloud_hash(seed+2.0)*6.283185;
	vec2 axis=vec2(cos(angle),sin(angle));
	vec2 cross_axis=vec2(-axis.y,axis.x);
	vec2 anchor_a=-axis*(.075+.045*cloud_hash(seed+3.0));
	vec2 anchor_b=axis*(.065+.045*cloud_hash(seed+4.0))+cross_axis*(cloud_hash(seed+5.0)-.5)*.06;
	float radius_a=.165+.05*cloud_hash(seed+6.0);
	float radius_b=.145+.06*cloud_hash(seed+7.0);
	float shape=min(length(q-anchor_a)-radius_a,length(q-anchor_b)-radius_b);
	for(int i=2;i<13;i++) {
		if(i>=circles)break;
		float item=seed+float(i)*19.37;
		float radius=.045+.13*pow(cloud_hash(item+1.0),1.35);
		vec2 center=axis*(cloud_hash(item+2.0)-.5)*(.38+.17*cloud_hash(seed+8.0))
			+cross_axis*(cloud_hash(item+3.0)-.5)*(.23+.18*cloud_hash(seed+9.0));
		center=clamp(center,vec2(-.44+radius),vec2(.44-radius));
		bool near_a=length(center-anchor_a)<length(center-anchor_b);
		vec2 anchor=near_a ? anchor_a : anchor_b;
		float overlap=(near_a ? radius_a : radius_b)+radius-.025;
		vec2 offset=center-anchor;
		center=anchor+offset*min(1.0,overlap/max(.001,length(offset)));
		center+=cross_axis*sin(phase*.7+float(i))*.006;
		float circle=length(q-center)-radius;
		shape=fusion_enabled ? cloud_union(shape,circle,.018) : min(shape,circle);
	}
	if(fusion_enabled && fusion_link.w>.001) {
		// A small shared neck, mirrored by the paired neighbour. The controller
		// only links nearby, same-region puffs; no fluid simulation or blur.
		vec2 end=fusion_link.xy*.5;
		float t=clamp(dot(p,end)/max(.0001,dot(end,end)),0.0,1.0);
		float neck=length(p-end*t)-.070*fusion_link.w;
		shape=cloud_union(shape,neck,.035*fusion_link.w);
	}
	if(collective_fusion) {
		float own=group_field(p,COLOR.r,smoke_clock);
		shape=own;
		for(int n=0;n<4;n++) {
			vec4 other=texture(fusion_field,vec2((float(n)*2.0+.5)/8.0,fusion_link.r));
			float strength=texture(fusion_field,vec2((float(n)*2.0+1.5)/8.0,fusion_link.r)).r;
			if(strength<.001 || other.z<.001)continue;
			float neighbour=group_field((p-other.xy)/other.z,other.w,smoke_clock)*other.z;
			float joined=cloud_union(shape,neighbour,.22*min(1.0,other.z)*strength);
			// Each card owns a rounded local band, not the neighbour's entire
			// silhouette. This avoids rectangular quad-edge cuts and duplicates.
			shape=max(joined,own-.08*strength);
		}
	}
	float edge=group_outline && (!fusion_enabled || outer_outline_pass) ? outline_width_texels/pixels : 0.0;
	if(shape>edge)discard;
	if(COLOR.a<.01)discard;
	// Broad offset shadow patches follow cloud bulges, rather than wavy
	// fire stripes. Their dark values are printed as opaque halftone dots.
	vec2 shift=vec2(sin(phase)*.025,cos(phase*.7)*.02);
	vec2 shadow_q=vec2(dot(q,axis),dot(q,cross_axis));
	float patch=min(length((shadow_q-vec2(-.10,.10)-shift)*vec2(.9,1.3))-(.13+.05*cloud_hash(seed+11.0)),
		min(length((shadow_q-vec2(.13,.13)+shift)*vec2(1.0,1.4))-(.14+.05*cloud_hash(seed+12.0)),
		length((shadow_q-vec2(.02,-.04)-shift)*vec2(1.2,.85))-.11));
	float shadow=clamp(.35-patch*6.0,0.0,1.0);
	if(fusion_enabled) {
		// Inner overlaps retain dotted shade, never per-puff black rings. All
		// black silhouettes are drawn first, then all coloured fills cover them.
		float inner_edge=1.0-smoothstep(.015,.075,max(0.0,-shape));
		shadow=max(shadow,inner_edge*.82);
	}
	vec2 dot_pixel=mod(texel,vec2(6.0))-vec2(3.0);
	// Both shadow levels share the SAME light paper. Only printed dot size /
	// coverage changes; there is no solid grey patch beneath either level.
	// Shrink smoothly across the shadow boundary, down to a single texel.
	// No hard two-level cutoff, grey backing block, or alpha holes.
	float dot_radius=2.15*smoothstep(0.0,1.0,shadow);
	float shade=.93;
	if(length(dot_pixel)<dot_radius)shade=.56;
	bool black=fusion_enabled ? outer_outline_pass : shape>0.0;
	vec3 ink=black ? vec3(0.0) : vec3(shade*.96,shade,shade*1.02);
	ALBEDO=receive_scene_light ? ink : vec3(0.0);
	EMISSION=ink*(receive_scene_light ? .035 : 1.0);
	ROUGHNESS=1.0;
	NORMAL=normalize(vec3(p.x*.5,-p.y*.5,1.0));
	ALPHA=COLOR.a;
}
