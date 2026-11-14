// Direct-light finish trial. Same atlas/geometry/shadows, no emission or new lights.
uniform bool furniture_finish_enabled = true;
uniform bool material_filtered_normals_enabled = true;
uniform sampler2D furniture_normal_atlas : filter_linear_mipmap, repeat_disable;
uniform bool furniture_finish_atlas_enabled = false;
uniform sampler2D furniture_finish_atlas : filter_nearest_mipmap, repeat_disable;
uniform vec2 furniture_finish_uniform = vec2(1.0,0.0);
varying vec3 furniture_direct_normal;
varying vec2 furniture_direct_finish;
instance uniform vec3 material_bounds_min : instance_index(12) = vec3(0.0);
instance uniform vec3 material_bounds_size : instance_index(13) = vec3(1.0);
varying vec3 material_local_point;
varying vec3 material_local_normal;
varying vec3 material_axis_x;
varying vec3 material_axis_y;
varying vec3 material_axis_z;
varying vec3 material_axis_scale;

vec3 material_family(vec2 finish) {
	float metal=step(0.30,finish.y);
	float wood=(1.0-metal)*step(0.85,finish.x)*(1.0-step(.975,finish.x))*step(0.003,finish.y);
	float plastic=(1.0-metal)*(1.0-wood)*step(0.05,finish.y);
	return vec3(metal,plastic,wood);
}

vec3 material_box_normal(vec3 base,vec2 finish) {
	vec3 family=material_family(finish);
	vec3 n=normalize(material_local_normal);
	vec3 p=clamp((material_local_point-material_bounds_min)/max(material_bounds_size,vec3(.0001)),vec3(0.0),vec3(1.0));
	vec3 edge=(1.0-smoothstep(vec3(0.0),vec3(.12),vec3(1.0)-p))-(1.0-smoothstep(vec3(0.0),vec3(.12),p));
	vec3 delta=edge*(vec3(1.0)-abs(n))*(.34*family.x+.54*family.y+.17*family.z);
	vec3 tangent=abs(n.x)>.6?vec3(0.0,0.0,1.0):vec3(1.0,0.0,0.0);
	float along=abs(n.x)>.6?p.z:p.x;
	delta+=tangent*(along-.5)*(.20*family.x+.50*family.y);
	vec3 texel=material_local_point*material_axis_scale*32.0;
	float grain_position=abs(n.x)>.6?texel.z:texel.x;
	float footprint=max(length(dFdx(texel)),length(dFdy(texel)));
	float grain=sin(floor(grain_position)*.6981317)*(.13*family.z+.028*family.x)*(1.0-smoothstep(2.0,6.0,footprint));
	if(material_filtered_normals_enabled){
		float phase=grain_position*.6981317;
		float dx=dFdx(phase);float dy=dFdy(phase);
		grain=.13*family.z*sin(phase)*exp(-(dx*dx+dy*dy)/24.0);
	}
	delta+=tangent*grain;
	return normalize(base+material_axis_x*delta.x+material_axis_y*delta.y+material_axis_z*delta.z);
}

float material_wood_occlusion(vec2 uv) {
	float slope;
	if(furniture_finish_atlas_enabled){
		slope=(texture(furniture_finish_atlas,uv).r*255.0-128.0)/127.0;
	}else{
		vec3 texel=material_local_point*material_axis_scale*32.0;
		float along=abs(material_local_normal.x)>.6?texel.z:texel.x;
		slope=.13*sin(floor(along)*.6981317);
	}
	// Shallow cavities only remove incident light; the original colour atlas stays intact.
	return 1.0-.42*clamp((.02-slope)/.16,0.0,1.0);
}

vec3 furniture_finish_normal(vec3 normal,vec3 point,vec2 uv,vec2 slope) {
	if(material_filtered_normals_enabled && furniture_finish_atlas_enabled){
		vec2 footprint=max(abs(dFdx(uv)),abs(dFdy(uv)))*vec2(textureSize(furniture_normal_atlas,0));
		float detail=1.0-smoothstep(2.0,5.0,max(footprint.x,footprint.y));
		slope=(textureGrad(furniture_normal_atlas,uv,dFdx(uv),dFdy(uv)).rg*255.0-vec2(128.0))*(detail/127.0);
	}
	vec3 dx=dFdx(point);vec3 dy=dFdy(point);
	vec2 ux=dFdx(uv);vec2 uy=dFdy(uv);
	float orientation=sign(ux.x*uy.y-ux.y*uy.x);
	vec3 tangent=(dx*uy.y-dy*ux.y)*orientation;
	vec3 bitangent=(dy*ux.x-dx*uy.x)*orientation;
	tangent*=inversesqrt(max(dot(tangent,tangent),1e-16));
	bitangent*=inversesqrt(max(dot(bitangent,bitangent),1e-16));
	return normalize(normal+tangent*slope.x+bitangent*slope.y);
}

float furniture_finish_lobe(vec3 light,vec3 view,vec3 normal,vec2 finish) {
	float nl=max(dot(normal,light),0.0);
	if(nl<=0.0 || finish.y<=0.0){return 0.0;}
	float nv=max(dot(normal,view),0.025);
	vec3 h=light+view;h*=inversesqrt(max(dot(h,h),0.000001));
	float nh=max(dot(normal,h),0.0);float vh=max(dot(view,h),0.0);
	float roughness=clamp(finish.x,0.38,1.0);
	if(material_filtered_normals_enabled){
		vec3 dx=dFdx(normal);vec3 dy=dFdy(normal);
		float variance=min(.5*(dot(dx,dx)+dot(dy,dy)),.12);
		roughness=sqrt(min(1.0,roughness*roughness+variance));
	}
	float a=roughness*roughness;float a2=a*a;
	float d=nh*nh*(a2-1.0)+1.0;
	float distribution=a2/max(PI*d*d,0.00001);
	float k=(roughness+1.0)*(roughness+1.0)*0.125;
	float visibility=(nv/(nv*(1.0-k)+k))*(nl/(nl*(1.0-k)+k));
	float fresnel=finish.y+(1.0-finish.y)*pow(1.0-vh,5.0);
	float specular=distribution*visibility*fresnel/max(4.0*nv,0.01);
	// A deliberately broad rough-surface shoulder keeps matte iron readable at
	// the game's steep camera angle. It still uses the real light and shadow.
	float shoulder=finish.y*nl*smoothstep(0.05,0.85,nh)*0.90;
	return min(specular+shoulder,1.05);
}
