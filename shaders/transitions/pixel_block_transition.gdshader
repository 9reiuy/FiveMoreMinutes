shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(0.0,1.0) = 0.0;
uniform bool invert = false;
uniform vec2 logical_size = vec2(640.0,360.0);
uniform float block_size = 4.0;
uniform int transition_mode = 0;
uniform vec4 cover_color : source_color = vec4(0.0,0.0,0.0,1.0);

float cell_noise(vec2 cell) {
	vec3 p=fract(vec3(cell.xyx)*0.1031);
	p+=dot(p,p.yzx+33.33);
	return fract((p.x+p.y)*p.z);
}

void fragment() {
	float amount=invert ? 1.0-progress : progress;
	if(amount<=0.0){COLOR=vec4(0.0);}
	else if(amount>=1.0){COLOR=cover_color;}
	else {
		vec2 grid=logical_size/max(block_size,1.0);
		vec2 cell=floor(UV*grid);
		vec2 center=(cell+0.5)/grid;
		// Measure in logical pixels so a circular iris remains round on a
		// widescreen output. Its initial radius includes all four corners.
		float radial=length((center-vec2(0.5))*logical_size)/length(logical_size*0.5);
		float wave=1.0-radial;
		if(transition_mode==1){wave=(center.x+center.y)*0.5;}
		else if(transition_mode==2){wave=1.0-radial;}
		else if(transition_mode==3){wave=center.x;}
		float threshold=(transition_mode==0 || transition_mode==2) ? wave : mix(wave,cell_noise(cell),0.22);
		COLOR=vec4(cover_color.rgb,cover_color.a*step(threshold,amount));
	}
}
