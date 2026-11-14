uniform bool comparison_filter_enabled=true;
uniform bool comparison_brush_enabled=true;
// Replace the accepted metal lobe only; plastic, wood and paper return exactly
// the accepted function. The same finish masks, light colours and shadows apply.
float comparison_finish_lobe(vec3 light,vec3 view,vec3 normal,vec2 finish) {
    if(!comparison_brush_enabled || material_family(finish).x<.5){
        return furniture_finish_lobe(light,view,normal,finish);
    }
    vec3 n=normalize(normal);
    float nl=max(dot(n,light),0.0);
    if(nl<=0.0 || finish.y<=0.0){return 0.0;}
    float nv=max(dot(n,view),.025);
    vec3 h=normalize(light+view);
    vec3 tangent=abs(material_local_normal.x)>.6?material_axis_z:material_axis_x;
    tangent=normalize(tangent-n*dot(tangent,n));
    vec3 bitangent=normalize(cross(n,tangent));
    float ax=clamp(finish.x*1.35,.45,.95);
    float ay=clamp(finish.x*.35,.12,.28);
    if(comparison_filter_enabled){
        vec3 dx=dFdx(n);vec3 dy=dFdy(n);
        float variance=min(.5*(dot(dx,dx)+dot(dy,dy)),.12);
        ax=sqrt(ax*ax+variance);ay=sqrt(ay*ay+variance);
    }
    float nh=max(dot(n,h),.001);
    float th=dot(tangent,h)/ax;
    float bh=dot(bitangent,h)/ay;
    float denominator=th*th+bh*bh+nh*nh;
    float distribution=1.0/max(PI*ax*ay*denominator*denominator,.00001);
    float k=pow(finish.x+1.0,2.0)*.125;
    float visibility=(nv/(nv*(1.0-k)+k))*(nl/(nl*(1.0-k)+k));
    float fresnel=finish.y+(1.0-finish.y)*pow(1.0-max(dot(view,h),0.0),5.0);
    float specular=distribution*visibility*fresnel/max(4.0*nv,.01);
    float grain=.90+.10*sin(floor(material_local_point.y*material_axis_scale.y*32.0)*1.9634954);
    if(comparison_filter_enabled){
        float phase=material_local_point.y*material_axis_scale.y*32.0*1.9634954;
        float dx=dFdx(phase);float dy=dFdy(phase);
        grain=.90+.10*sin(phase)*exp(-(dx*dx+dy*dy)/24.0);
    }
    float shoulder=finish.y*nl*smoothstep(.55,.98,nh)*.15;
    return min(specular*grain+shoulder,1.8);
}
