extends RefCounted
## Small closed chamfers catch room light without an added outline pass.
static func face(st:SurfaceTool,p:Array)->void:
	var normal:Vector3=(p[1]-p[0]).cross(p[2]-p[0]).normalized()
	for i in [0,2,1,0,3,2]:
		st.set_normal(normal);st.set_uv(Vector2(p[i].x,p[i].z));st.add_vertex(p[i])

static func slab(size:Vector3)->ArrayMesh:
	var x:=size.x*.5;var z:=size.z*.5;var y:=size.y*.5;var b:=.028
	var outer:PackedVector2Array=[Vector2(-x+b,-z),Vector2(x-b,-z),Vector2(x,-z+b),Vector2(x,z-b),Vector2(x-b,z),Vector2(-x+b,z),Vector2(-x,z-b),Vector2(-x,-z+b)]
	var inner:PackedVector2Array=[]
	for p in outer:inner.append(p-Vector2(signf(p.x)*b,signf(p.y)*b))
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outer.size():
		var j:=(i+1)%outer.size();var a:=outer[i];var c:=outer[j];var ia:=inner[i];var ic:=inner[j]
		face(st,[Vector3(a.x,-y+.018,a.y),Vector3(a.x,y-.025,a.y),Vector3(c.x,y-.025,c.y),Vector3(c.x,-y+.018,c.y)])
		face(st,[Vector3(a.x,y-.025,a.y),Vector3(ia.x,y,ia.y),Vector3(ic.x,y,ic.y),Vector3(c.x,y-.025,c.y)])
		face(st,[Vector3(ia.x,-y,ia.y),Vector3(a.x,-y+.018,a.y),Vector3(c.x,-y+.018,c.y),Vector3(ic.x,-y,ic.y)])
		st.set_normal(Vector3.UP)
		for p in [Vector3.ZERO+Vector3.UP*y,Vector3(ia.x,y,ia.y),Vector3(ic.x,y,ic.y)]:st.set_uv(Vector2(p.x,p.z));st.add_vertex(p)
		st.set_normal(Vector3.DOWN)
		for p in [Vector3.DOWN*y,Vector3(ic.x,-y,ic.y),Vector3(ia.x,-y,ia.y)]:st.set_uv(Vector2(p.x,p.z));st.add_vertex(p)
	return st.commit()
