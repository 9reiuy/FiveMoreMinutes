extends RefCounted
## Model-space construction: continuous shoulder/arches, inset trim and glazing.
const SURFACE := preload("res://shaders/dream3d/dmc12_aged_surface.gdshader")
const AXLES := [Vector2(-1.36,.332),Vector2(1.05,.302)]
# X, half width, belt/shoulder height. Front is +X.
const PROFILE := [Vector3(-2.10,.81,.790),Vector3(-2.03,.90,.807),
	Vector3(-1.75,.925,.817),Vector3(-1.36,.930,.823),Vector3(-.90,.928,.819),
	Vector3(.10,.923,.812),Vector3(.72,.918,.775),Vector3(1.05,.910,.735),
	Vector3(1.55,.901,.710),Vector3(1.94,.878,.685),Vector3(2.09,.811,.674)]

class Builder:
	extends RefCounted
	var surfaces: Dictionary = {}

	func triangle(material: Material, a: Vector3, b: Vector3, c: Vector3, outward: Vector3,
			na := Vector3.ZERO, nb := Vector3.ZERO, nc := Vector3.ZERO) -> void:
		if (b-a).cross(c-a).length_squared() < .00000000001: return
		if na == Vector3.ZERO: na = outward.normalized(); nb = na; nc = na
		# Godot uses clockwise winding for front-facing triangles.
		if (c-a).cross(b-a).dot(outward) < 0.0:
			var swap := b; b = c; c = swap
			swap = nb; nb = nc; nc = swap
		if not surfaces.has(material):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tool.set_material(material)
			surfaces[material] = tool
		var tool: SurfaceTool = surfaces[material]
		for vertex: Array in [[a,na],[b,nb],[c,nc]]:
			var p: Vector3 = vertex[0]
			var n: Vector3 = vertex[1]
			var dominant := outward.abs()
			var uv := Vector2(p.z,p.y) if dominant.x > maxf(dominant.y,dominant.z) else (Vector2(p.x,p.z) if dominant.y > dominant.z else Vector2(p.x,p.y))
			tool.set_normal(n.normalized())
			tool.set_uv(uv)
			tool.add_vertex(p)

	func quad(material: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3,
			na := Vector3.ZERO, nb := Vector3.ZERO, nc := Vector3.ZERO, nd := Vector3.ZERO) -> void:
		triangle(material,a,b,c,outward,na,nb,nc)
		triangle(material,a,c,d,outward,na,nc,nd)

	func bake() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		for tool: SurfaceTool in surfaces.values():
			tool.generate_tangents()
			tool.index()
			tool.commit(mesh)
		return mesh


static func create() -> ArrayMesh:
	var steel := _finish("Aged brushed stainless",Color("b8bfc1"),0,.38,.86)
	var trim := _finish("Sun-faded mouldings",Color("101619"),1,.76,0.0)
	var rubber := _finish("Road-worn tyres",Color("101315"),2,.94,0.0)
	var glass := _finish("Smoked glass and window grime",Color("17252b"),3,.15,.45)
	var alloy := _finish("Turbine alloy with brake dust",Color("a3acaf"),4,.34,.83)
	var lamp := _finish("Fluted headlamp lenses",Color("d5d9c9"),5,.23,.25)
	var red := _finish("Aged red lenses",Color("a02c25"),5,.28,.12)
	var amber := _finish("Aged amber lenses",Color("bd762c"),5,.30,.10)
	var black := _finish("Deep recesses",Color("05090b"),1,.87,0.0)
	var mesh := Builder.new()
	_body(mesh,steel,trim,black)
	_canopy(mesh,steel,trim,glass,black)
	_details(mesh,steel,trim,glass,alloy,lamp,red,amber,black)
	for axle: Vector2 in AXLES:
		for side: float in [-1.0,1.0]: _wheel(mesh,Vector3(axle.x,axle.y,side*.842),axle.y,side,rubber,alloy,black)
	return mesh.bake()


static func _finish(title: String, colour: Color, kind: int, roughness: float, metallic: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.resource_name = title
	material.shader = SURFACE
	material.set_shader_parameter("finish_colour",colour)
	material.set_shader_parameter("finish_kind",kind)
	material.set_shader_parameter("base_roughness",roughness)
	material.set_shader_parameter("base_metallic",metallic)
	material.set_shader_parameter("age",.78)
	if kind == 0:
		material.set_shader_parameter("steel_colour",preload("res://art/Dream/ReceptionLobby/brushed_iron_01/BrushedIron01_1K_BaseColor.png"))
		material.set_shader_parameter("steel_normal",preload("res://art/Dream/ReceptionLobby/brushed_iron_01/BrushedIron01_1K_Normal.png"))
		material.set_shader_parameter("steel_roughness",preload("res://art/Dream/ReceptionLobby/brushed_iron_01/BrushedIron01_1K_Roughness.png"))
	return material


static func _profile(x: float) -> Vector2:
	for i in range(1,PROFILE.size()):
		var a: Vector3 = PROFILE[i-1]
		var b: Vector3 = PROFILE[i]
		if x <= b.x: return Vector2(lerpf(a.y,b.y,inverse_lerp(a.x,b.x,x)),lerpf(a.z,b.z,inverse_lerp(a.x,b.x,x)))
	return Vector2(PROFILE[-1].y,PROFILE[-1].z)


static func _arch(x: float) -> float:
	var low := .248
	for axle: Vector2 in AXLES:
		var r := axle.y+.065
		var dx := x-axle.x
		if absf(dx) < r: low = maxf(low,axle.y+sqrt(maxf(0.0,r*r-dx*dx)))
	return low


static func _side_point(x: float, row: float, side: float) -> Vector3:
	var profile := _profile(x)
	var y := lerpf(_arch(x),profile.y-.036,row)
	var fullness := .011*sin(row*PI)
	var width := profile.x-.035*(1.0-row)+fullness
	return Vector3(x,y,width*side)


static func _side_normal(x: float, row: float, side: float) -> Vector3:
	var along := _side_point(minf(x+.001,2.09),row,side)-_side_point(maxf(x-.001,-2.1),row,side)
	var up := _side_point(x,minf(row+.001,1.0),side)-_side_point(x,maxf(row-.001,0.0),side)
	return (along.cross(up)*side).normalized()


static func _deck(x: float, u: float) -> Vector3:
	var profile := _profile(x)
	var y := profile.y+.009*(1.0-u*u)
	# A shallow old ding, not a separate overlay or a displaced cube.
	y -= .005*exp(-pow((x-1.38)/.13,2.0)-pow((u+.36)/.16,2.0))
	return Vector3(x,y,u*(profile.x-.04))


static func _body(mesh: Builder, steel: Material, trim: Material, black: Material) -> void:
	var xs: Array[float] = []
	for i in 81: xs.append(lerpf(-2.1,2.09,i/80.0))
	for axle: Vector2 in AXLES:
		var r := axle.y+.065
		xs.append(axle.x-r-.001); xs.append(axle.x+r+.001)
		for i in 25: xs.append(axle.x+cos(PI*i/24.0)*r)
	xs.sort()
	for i in range(1,xs.size()):
		var xa := xs[i-1]
		var xb := xs[i]
		if xb-xa < .00001: continue
		for side: float in [-1.0,1.0]:
			for row in 4:
				var u := row/4.0
				var v := (row+1)/4.0
				mesh.quad(steel,_side_point(xa,u,side),_side_point(xb,u,side),_side_point(xb,v,side),_side_point(xa,v,side),Vector3(0,0,side),
					_side_normal(xa,u,side),_side_normal(xb,u,side),_side_normal(xb,v,side),_side_normal(xa,v,side))
			# Five radiused strips round the shoulder into the crown of the deck.
			for ring in 5:
				var points: Array[Vector3] = []
				var normals: Array[Vector3] = []
				for pair: Vector2 in [Vector2(xa,ring),Vector2(xb,ring),Vector2(xb,ring+1),Vector2(xa,ring+1)]:
					var angle := pair.y/5.0*PI*.5
					var profile := _profile(pair.x)
					points.append(Vector3(pair.x,profile.y-.036+.036*sin(angle),side*(profile.x-.04+.04*cos(angle))))
					normals.append(Vector3(0,sin(angle),side*cos(angle)))
				mesh.quad(steel,points[0],points[1],points[2],points[3],Vector3(0,1,side),normals[0],normals[1],normals[2],normals[3])
		for across in 10:
			var u := -1.0+across*.2
			var v := u+.2
			var a := _deck(xa,u)
			var b := _deck(xb,u)
			var c := _deck(xb,v)
			var d := _deck(xa,v)
			var normal := (d-a).cross(b-a).normalized()
			if normal.y < 0: normal = -normal
			mesh.quad(steel,a,b,c,d,Vector3.UP,normal,normal,normal,normal)
	# Rolled arch lips and dark inner returns have actual depth.
	for axle: Vector2 in AXLES:
		for side: float in [-1.0,1.0]:
			for i in 32:
				var aa := PI*i/32.0
				var ab := PI*(i+1)/32.0
				var r := axle.y+.065
				var a := Vector3(axle.x+cos(aa)*r,axle.y+sin(aa)*r,side*(_profile(axle.x+cos(aa)*r).x-.028))
				var b := Vector3(axle.x+cos(ab)*r,axle.y+sin(ab)*r,side*(_profile(axle.x+cos(ab)*r).x-.028))
				mesh.quad(steel,a,b,b+Vector3(cos(ab),sin(ab),0)*.018,a+Vector3(cos(aa),sin(aa),0)*.018,Vector3(0,0,side))
				mesh.quad(black,a,b,b-Vector3(0,0,side*.12),a-Vector3(0,0,side*.12),Vector3(-cos(aa),-sin(aa),0))
	_bevel_box(mesh,trim,Vector3(0,.24,0),Vector3(3.9,.09,1.58),.025)


static func _roof(x: float,z: float) -> Vector3:
	return Vector3(x,1.162+.019*(1.0-pow(z/.747,4.0))-.010*pow((x+.17)/.43,2.0),z)


static func _windshield(t: float,u: float) -> Vector3:
	return Vector3(lerpf(.255,.880,t)+.011*(1.0-u*u),lerpf(1.127,.784,t)+.006*(1.0-u*u),u*lerpf(.713,.873,t))


static func _canopy(mesh: Builder, steel: Material, trim: Material, glass: Material, black: Material) -> void:
	for i in 12:
		for j in 20:
			var xa := lerpf(-.65,.255,i/12.0)
			var xb := lerpf(-.65,.255,(i+1)/12.0)
			var za := lerpf(-.747,.747,j/20.0)
			var zb := lerpf(-.747,.747,(j+1)/20.0)
			var a := _roof(xa,za)
			var b := _roof(xb,za)
			var c := _roof(xb,zb)
			var d := _roof(xa,zb)
			var n := (d-a).cross(b-a).normalized()
			mesh.quad(steel,a,b,c,d,Vector3.UP,n,n,n,n)
	for i in 8:
		for j in 20:
			var ta := i/8.0
			var tb := (i+1)/8.0
			var ua := -1.0+j*.1
			var ub := ua+.1
			var a := _windshield(ta,ua)
			var b := _windshield(tb,ua)
			var c := _windshield(tb,ub)
			var d := _windshield(ta,ub)
			var n := (d-a).cross(b-a).normalized()
			mesh.quad(glass,a,b,c,d,Vector3(1,1,0),n,n,n,n)
	_bar(mesh,trim,_windshield(0,-1),_windshield(0,1),.026,.022)
	_bar(mesh,trim,_windshield(1,-1),_windshield(1,1),.024,.019)
	for side: float in [-1.0,1.0]:
		var a := Vector3(-.80,.846,side*.875)
		var b := Vector3(-.59,1.145,side*.738)
		var c := Vector3(.235,1.145,side*.738)
		var d := Vector3(.842,.789,side*.877)
		mesh.quad(glass,a,b,c,d,Vector3(0,.2,side))
		_bar(mesh,trim,a,b,.029,.023)
		_bar(mesh,steel,b,c,.041,.025)
		_bar(mesh,steel,c,d,.051,.032)
		_bar(mesh,trim,d,a,.023,.025)
		# Stainless sail panel and separately glazed rear quarter.
		var rear := Vector3(-1.46,.831,side*.879)
		mesh.quad(steel,rear,Vector3(-.65,1.15,side*.744),b,a,Vector3(0,.3,side))
		mesh.triangle(glass,Vector3(-1.29,.854,side*.889),Vector3(-.688,1.105,side*.773),Vector3(-.857,.85,side*.891),Vector3(0,.2,side))
		_bar(mesh,trim,Vector3(-1.29,.854,side*.893),Vector3(-.688,1.105,side*.777),.014,.012)
		_bar(mesh,trim,Vector3(-.688,1.105,side*.777),Vector3(-.857,.85,side*.895),.014,.012)
		# The characteristic small opening pane sits within the larger side glass.
		var pane := [Vector3(-.56,.876,side*.873),Vector3(-.44,1.016,side*.812),Vector3(.34,1.016,side*.812),Vector3(.57,.86,side*.881)]
		for i in 4: _bar(mesh,trim,pane[i],pane[(i+1)%4],.012,.011)
		# Gull-wing door perimeter is narrow and follows the skin.
		var seam := [Vector3(-.824,.814,side*.938),Vector3(-.907,.321,side*.913),Vector3(.685,.321,side*.910),Vector3(.84,.757,side*.932)]
		for i in 3: _bar(mesh,trim,seam[i],seam[i+1],.008,.006)
		_bar(mesh,trim,_roof(-.63,side*.585)+Vector3(0,.004,0),_roof(.245,side*.585)+Vector3(0,.004,0),.007,.006)
		# Rear buttresses narrow towards the tail instead of a square deck block.
		mesh.quad(steel,Vector3(-2.02,.808,side*.81),Vector3(-.67,1.146,side*.716),Vector3(-.65,1.146,side*.76),Vector3(-1.90,.819,side*.899),Vector3(0,1,side))
	# Louvres: open angled fins over a dark recessed engine deck.
	mesh.quad(black,Vector3(-2.015,.798,-.79),Vector3(-2.015,.798,.79),Vector3(-.65,1.113,.696),Vector3(-.65,1.113,-.696),Vector3.UP)
	for i in 12:
		var x := -1.986+i*.108
		var y := .825+(x+1.986)*.242
		var width := lerpf(.79,.70,i/11.0)
		mesh.quad(trim,Vector3(x,y,-width),Vector3(x,y,width),Vector3(x+.082,y+.006,width-.005),Vector3(x+.082,y+.006,-width+.005),Vector3.UP)
		mesh.quad(trim,Vector3(x,y,-width),Vector3(x,y,width),Vector3(x,y-.028,width),Vector3(x,y-.028,-width),Vector3.LEFT)
	for side: float in [-1.0,1.0]:
		_bar(mesh,trim,_windshield(.85,side*.73)+Vector3(.005,.009,0),_windshield(.92,side*.11)+Vector3(.005,.009,0),.014,.012)
		_bar(mesh,trim,_windshield(.94,side*.82)+Vector3(.005,.008,0),_windshield(.86,side*.44)+Vector3(.005,.008,0),.012,.010)


static func _details(mesh: Builder, steel: Material, trim: Material, glass: Material, alloy: Material, lamp: Material, red: Material, amber: Material, black: Material) -> void:
	# Rounded corner bumpers and recessed fascia, not boxes on a flat hood.
	_bevel_box(mesh,trim,Vector3(2.07,.407,0),Vector3(.205,.213,1.795),.044)
	_bevel_box(mesh,trim,Vector3(-2.075,.405,0),Vector3(.18,.225,1.807),.035)
	_bevel_box(mesh,trim,Vector3(2.082,.590,0),Vector3(.064,.165,1.667),.012)
	_bevel_box(mesh,steel,Vector3(2.077,.679,0),Vector3(.064,.021,1.668),.008)
	_bevel_box(mesh,black,Vector3(2.119,.605,0),Vector3(.019,.136,.452),.008)
	for i in 5: _bar(mesh,trim,Vector3(2.136,.552+i*.025,-.224),Vector3(2.136,.552+i*.025,.224),.008,.008)
	# Small DMC-like grille badge, formed from narrow metal strokes.
	for stroke: Vector4 in [Vector4(-.086,.623,-.086,.584),Vector4(-.086,.623,-.048,.616),Vector4(-.048,.616,-.048,.59),Vector4(-.048,.59,-.086,.584),Vector4(-.024,.584,-.024,.623),Vector4(-.024,.623,0,.599),Vector4(0,.599,.024,.623),Vector4(.024,.623,.024,.584),Vector4(.088,.622,.049,.622),Vector4(.049,.622,.049,.584),Vector4(.049,.584,.088,.584)]:
		_bar(mesh,alloy,Vector3(2.146,stroke.y,stroke.x),Vector3(2.146,stroke.w,stroke.z),.005,.004)
	for side: float in [-1.0,1.0]:
		for z: float in [.401,.654]:
			_inset_headlamp(mesh,Vector3(2.135,.595,side*z),alloy,trim,lamp)
		_bevel_box(mesh,amber,Vector3(2.174,.409,side*.64),Vector3(.018,.046,.225),.009)
		_bevel_box(mesh,amber,Vector3(1.805,.536,side*.909),Vector3(.166,.033,.017),.007)
		# The rub strip and sill stop before both wheel openings.
		for interval: Vector2 in [Vector2(-2.02,-1.77),Vector2(-.945,.661),Vector2(1.44,1.99)]:
			_bevel_box(mesh,trim,Vector3((interval.x+interval.y)*.5,.490,side*.939),Vector3(interval.y-interval.x,.043,.031),.008)
		_bevel_box(mesh,trim,Vector3(-.14,.282,side*.914),Vector3(1.56,.057,.061),.013)
		_bevel_box(mesh,black,Vector3(-.465,.758,side*.940),Vector3(.207,.053,.019),.010)
		_bevel_box(mesh,trim,Vector3(-.465,.762,side*.952),Vector3(.148,.023,.015),.005)
		_bevel_box(mesh,alloy,Vector3(-.625,.759,side*.948),Vector3(.018,.018,.011),.005)
		_bar(mesh,trim,Vector3(.715,.802,side*.889),Vector3(.689,.842,side*.992),.029,.026)
		_bevel_box(mesh,trim,Vector3(.701,.868,side*1.018),Vector3(.192,.095,.145),.024)
		_bevel_box(mesh,glass,Vector3(.605,.868,side*1.018),Vector3(.008,.064,.106),.005)
		for i in 6:
			var x := -1.27+i*.056
			_bar(mesh,trim,Vector3(x,.836,side*.902),Vector3(x+.13,.902,side*.863),.016,.013)
	# Hood perimeter, split shut lines, rear fascia and individually divided lenses.
	for side: float in [-1.0,1.0]:
		for i in 12:
			var a := _deck(lerpf(.924,1.986,i/12.0),side*.864)+Vector3(0,.004,0)
			var b := _deck(lerpf(.924,1.986,(i+1)/12.0),side*.864)+Vector3(0,.004,0)
			_bar(mesh,trim,a,b,.005,.004)
	_bar(mesh,trim,_deck(1.986,-.864)+Vector3(0,.004,0),_deck(1.986,.864)+Vector3(0,.004,0),.005,.004)
	_bevel_box(mesh,black,Vector3(-2.114,.653,0),Vector3(.047,.226,1.651),.016)
	for side: float in [-1.0,1.0]:
		for i in 4:
			var z := side*(.360+i*.133)
			_bevel_box(mesh,amber if i == 3 else red,Vector3(-2.143,.666,z),Vector3(.018,.151,.123),.006)
			_bar(mesh,trim,Vector3(-2.155,.666,z-.057),Vector3(-2.155,.666,z+.057),.005,.004)
		_tube(mesh,alloy,Vector3(-2.07,.267,side*.56),Vector3(-2.245,.259,side*.56),.040,16)
		_tube(mesh,black,Vector3(-2.246,.259,side*.56),Vector3(-2.252,.259,side*.56),.030,16)
	_bevel_box(mesh,alloy,Vector3(-2.15,.644,0),Vector3(.018,.158,.324),.009)
	_bevel_box(mesh,black,Vector3(-2.164,.644,0),Vector3(.013,.126,.285),.006)
	for i in 12: _bevel_box(mesh,black,Vector3(-2.178,.391,-.70+i*.128),Vector3(.011,.058,.072),.006)


static func _inset_headlamp(mesh: Builder, at: Vector3, alloy: Material, trim: Material, lens: Material) -> void:
	var outer := [Vector2(-.118,-.071),Vector2(.118,-.071),Vector2(.118,.071),Vector2(-.118,.071)]
	var inner := [Vector2(-.104,-.060),Vector2(.104,-.060),Vector2(.104,.060),Vector2(-.104,.060)]
	for i in 4:
		var j := (i+1)%4
		var a := at+Vector3(.004,outer[i].y,outer[i].x)
		var b := at+Vector3(.004,outer[j].y,outer[j].x)
		var c := at+Vector3(-.008,inner[j].y,inner[j].x)
		var d := at+Vector3(-.008,inner[i].y,inner[i].x)
		mesh.quad(alloy,a,b,c,d,Vector3.RIGHT)
		_bar(mesh,trim,a,b,.003,.003)
	_bevel_box(mesh,lens,at+Vector3(-.014,0,0),Vector3(.008,.116,.199),.003)
	for i in 6:
		_bar(mesh,alloy,at+Vector3(-.008,-.052,-.081+i*.0324),at+Vector3(-.008,.052,-.081+i*.0324),.002,.002)


static func _bar(mesh: Builder, material: Material, a: Vector3, b: Vector3, width: float, depth: float) -> void:
	var axis := (b-a).normalized()
	var other := Vector3.UP if absf(axis.y) < .95 else Vector3.FORWARD
	var u := axis.cross(other).normalized()*width*.5
	var v := axis.cross(u).normalized()*depth*.5
	var points := [a-u-v,a+u-v,a+u+v,a-u+v,b-u-v,b+u-v,b+u+v,b-u+v]
	var centre := (a+b)*.5
	for face: Array in [[0,1,2,3],[4,7,6,5],[0,4,5,1],[1,5,6,2],[2,6,7,3],[3,7,4,0]]:
		var normal: Vector3 = ((points[face[0]]+points[face[1]]+points[face[2]]+points[face[3]])*.25-centre).normalized()
		mesh.quad(material,points[face[0]],points[face[1]],points[face[2]],points[face[3]],normal)


static func _bevel_box(mesh: Builder, material: Material, centre: Vector3, size: Vector3, bevel: float) -> void:
	var half := size*.5
	var radius := minf(bevel,minf(half.x,minf(half.y,half.z))*.90)
	var core := half-Vector3.ONE*radius
	for axis in 3:
		var u := (axis+1)%3
		var v := (axis+2)%3
		for side: float in [-1.0,1.0]:
			for i in 3:
				for j in 3:
					var points: Array[Vector3] = []
					var normals: Array[Vector3] = []
					for pair: Vector2i in [Vector2i(i,j),Vector2i(i+1,j),Vector2i(i+1,j+1),Vector2i(i,j+1)]:
						var p := Vector3.ZERO
						p[axis] = half[axis]*side
						# Inner samples sit at the tangency, retaining a broad flat centre.
						var grid_u := [-half[u],-core[u],core[u],half[u]]
						var grid_v := [-half[v],-core[v],core[v],half[v]]
						p[u] = grid_u[pair.x]; p[v] = grid_v[pair.y]
						var anchor := p.clamp(-core,core)
						var normal := (p-anchor).normalized()
						points.append(centre+anchor+normal*radius)
						normals.append(normal)
					var outward := Vector3.ZERO
					outward[axis] = side
					mesh.quad(material,points[0],points[1],points[2],points[3],outward,normals[0],normals[1],normals[2],normals[3])


static func _tube(mesh: Builder, material: Material, a: Vector3, b: Vector3, radius: float, sectors: int) -> void:
	var axis := (b-a).normalized()
	var u := axis.cross(Vector3.UP).normalized()
	var v := axis.cross(u).normalized()
	for i in sectors:
		var aa := TAU*i/sectors
		var ab := TAU*(i+1)/sectors
		var p := u*cos(aa)+v*sin(aa)
		var q := u*cos(ab)+v*sin(ab)
		mesh.quad(material,a+p*radius,a+q*radius,b+q*radius,b+p*radius,(p+q).normalized(),p,q,q,p)


static func _wheel(mesh: Builder, centre: Vector3, radius: float, side: float, rubber: Material, alloy: Material, black: Material) -> void:
	var sectors := 48
	var half_width := .148 if centre.x < 0 else .128
	var section := [Vector2(-1.0,.75),Vector2(-1.02,.87),Vector2(-.83,.97),Vector2(-.55,1.0),Vector2(.55,1.0),Vector2(.83,.97),Vector2(1.02,.87),Vector2(.96,.75)]
	for i in sectors:
		var aa := TAU*i/sectors
		var ab := TAU*(i+1)/sectors
		var p := Vector3(cos(aa),sin(aa),0)
		var q := Vector3(cos(ab),sin(ab),0)
		for j in range(section.size()-1):
			var s: Vector2 = section[j]
			var t: Vector2 = section[j+1]
			var ds: Vector2 = section[mini(j+1,section.size()-1)]-section[maxi(j-1,0)]
			var dt: Vector2 = section[mini(j+2,section.size()-1)]-section[j]
			var ns := (p*ds.x*half_width-Vector3(0,0,side*ds.y*radius)).normalized()
			var nt := (p*dt.x*half_width-Vector3(0,0,side*dt.y*radius)).normalized()
			var ms := (q*ds.x*half_width-Vector3(0,0,side*ds.y*radius)).normalized()
			var mt := (q*dt.x*half_width-Vector3(0,0,side*dt.y*radius)).normalized()
			mesh.quad(rubber,centre+p*radius*s.y+Vector3(0,0,side*s.x*half_width),centre+q*radius*s.y+Vector3(0,0,side*s.x*half_width),
				centre+q*radius*t.y+Vector3(0,0,side*t.x*half_width),centre+p*radius*t.y+Vector3(0,0,side*t.x*half_width),ns+ms+nt+mt,ns,ms,mt,nt)
	var face := centre+Vector3(0,0,side*(half_width*.975))
	var outward := Vector3(0,0,side)
	for i in sectors:
		var aa := TAU*i/sectors
		var ab := TAU*(i+1)/sectors
		var p := Vector3(cos(aa),sin(aa),0)
		var q := Vector3(cos(ab),sin(ab),0)
		mesh.quad(alloy,face+p*radius*.752,face+q*radius*.752,face+q*radius*.694-Vector3(0,0,side*.013),face+p*radius*.694-Vector3(0,0,side*.013),outward)
		mesh.triangle(black,face-Vector3(0,0,side*.022),face+p*radius*.695-Vector3(0,0,side*.022),face+q*radius*.695-Vector3(0,0,side*.022),outward)
	# Swept turbine blades have thickness and a recessed dish behind them.
	for i in 28:
		var angle := TAU*i/28.0
		var points: Array[Vector3] = []
		for polar: Vector2 in [Vector2(angle,.18),Vector2(angle+.052,.687),Vector2(angle+.142,.687),Vector2(angle+.155,.18)]:
			points.append(face+Vector3(cos(polar.x),sin(polar.x),0)*radius*polar.y)
		mesh.quad(alloy,points[0],points[1],points[2],points[3],outward)
		mesh.quad(alloy,points[1],points[2],points[2]-outward*.014,points[1]-outward*.014,Vector3(cos(angle),sin(angle),0))
	for i in 24:
		var aa := TAU*i/24.0
		var ab := TAU*(i+1)/24.0
		mesh.triangle(alloy,face+outward*.009,face+Vector3(cos(aa),sin(aa),0)*radius*.18+outward*.009,face+Vector3(cos(ab),sin(ab),0)*radius*.18+outward*.009,outward)
	for i in 4:
		var angle := TAU*i/4.0+.4
		_bevel_box(mesh,alloy,face+Vector3(cos(angle),sin(angle),0)*radius*.27+outward*.005,Vector3(.020,.020,.015),.005)
	# Circumferential grooves and short diagonal tread cuts remain on the tyre.
	for offset: float in [-.39,0.0,.39]:
		for i in sectors:
			var aa := TAU*i/sectors
			var ab := TAU*(i+1)/sectors
			var p := Vector3(cos(aa),sin(aa),0)
			var q := Vector3(cos(ab),sin(ab),0)
			mesh.quad(black,centre+p*(radius+.0007)+Vector3(0,0,offset*half_width-.004),centre+q*(radius+.0007)+Vector3(0,0,offset*half_width-.004),
				centre+q*(radius+.0007)+Vector3(0,0,offset*half_width+.004),centre+p*(radius+.0007)+Vector3(0,0,offset*half_width+.004),p+q)
	for i in 36:
		var angle := TAU*i/36.0
		for tread_side: float in [-1.0,1.0]:
			var p := Vector3(cos(angle),sin(angle),0)
			var q := Vector3(cos(angle+.04),sin(angle+.04),0)
			mesh.quad(black,centre+p*(radius+.001)+Vector3(0,0,tread_side*half_width*.70),centre+q*(radius+.001)+Vector3(0,0,tread_side*half_width*.12),
				centre+Vector3(cos(angle+.06),sin(angle+.06),0)*(radius+.001)+Vector3(0,0,tread_side*half_width*.12),centre+Vector3(cos(angle+.02),sin(angle+.02),0)*(radius+.001)+Vector3(0,0,tread_side*half_width*.70),p+q)
