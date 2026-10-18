extends RefCounted
## Review-only face rebake: preserve vertices/normals, allocate texels from metres.
const DENSITY := 32.0
const VARIANT_COUNT := 4
const OFFICE = preload("res://scripts/dream/office_low_pixel_art.gd")
const ROOM = preload("res://scripts/dream/office_room_low_pixel_art.gd")
static var cache: Dictionary = {}

static func build(source: Mesh, texture: Texture2D, kind: String, variant: int = 0) -> Dictionary:
	variant=posmod(variant,VARIANT_COUNT)
	var key := str(source.get_instance_id())+":"+str(texture.get_instance_id())+":"+kind+":"+str(variant)
	if cache.has(key): return cache[key]
	var original := texture.get_image()
	var faces: Array = []
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		var count := indices.size() if not indices.is_empty() else vertices.size()
		assert(count%6==0,"Review expects the approved quad-based meshes")
		for offset in range(0,count,6):
			var points: Array[Vector3]=[]
			var old_uv: Array[Vector2]=[]
			for n in 6:
				var index := indices[offset+n] if not indices.is_empty() else offset+n
				points.append(vertices[index]); old_uv.append(uv[index])
			var index0 := indices[offset] if not indices.is_empty() else offset
			# Sample water barrel is replaced by an independent 8-sided display.
			if kind=="water_dispenser" and points.all(func(p: Vector3) -> bool: return p.y>.90): continue
			var horizontal := points[2]-points[1]
			var vertical := points[0]-points[1]
			var size := Vector2i(maxi(1,roundi(horizontal.length()*DENSITY)),maxi(1,roundi(vertical.length()*DENSITY)))
			var uv_min := old_uv[0]; var uv_max := old_uv[0]
			for v in old_uv: uv_min=uv_min.min(v); uv_max=uv_max.max(v)
			var tile := _tile(original.get_size(),(uv_min+uv_max)*.5)
			var color := _base_color(original,uv_min,uv_max)
			var paper_background := Color.TRANSPARENT
			if tile in ["paper","document"] and kind in ["workstation","table","dining_table","coffee_table","sorting_table","reception"]:
				var backing_rect: Rect2i=OFFICE.REGIONS["desk_top"] if original.get_size()==Vector2i(OFFICE.ATLAS_WIDTH,OFFICE.ATLAS_HEIGHT) else ROOM._rect(ROOM.TILES["wood_top"])
				paper_background=_base_color(original,Vector2(backing_rect.position)/Vector2(original.get_size()),Vector2(backing_rect.end)/Vector2(original.get_size()))
			var paint := _paint(size,color,tile,kind,normals[index0],variant,paper_background)
			faces.append({"points":points,"normal":normals[index0],"horizontal":horizontal,"vertical":vertical,"size":size,"world_size":Vector2(horizontal.length(),vertical.length()),"tile":tile,"image":paint})
	# Two-pixel extrusion isolates neighbour faces; no per-object UV stretching.
	var atlas_w := 256; var x := 2; var y := 2; var row_h := 0
	for face in faces:
		if x+face.size.x+2>atlas_w: x=2; y+=row_h+4; row_h=0
		face["rect"]=Rect2i(Vector2i(x,y),face.size)
		x+=face.size.x+4; row_h=maxi(row_h,face.size.y)
	var atlas_h := 32
	while atlas_h<y+row_h+2: atlas_h*=2
	var atlas := Image.create(atlas_w,atlas_h,false,Image.FORMAT_RGBA8)
	atlas.fill(Color("283238"))
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		var rect: Rect2i=face.rect
		atlas.blit_rect(face.image,Rect2i(Vector2i.ZERO,face.size),rect.position)
		for py in range(-2,face.size.y+2):
			for px in range(-2,face.size.x+2):
				if px>=0 and px<face.size.x and py>=0 and py<face.size.y: continue
				atlas.set_pixel(rect.position.x+px,rect.position.y+py,face.image.get_pixel(clampi(px,0,face.size.x-1),clampi(py,0,face.size.y-1)))
		var h: Vector3=face.horizontal; var v: Vector3=face.vertical
		for point in face.points:
			var relative: Vector3=point-face.points[1]
			var face_uv := Vector2(relative.dot(h)/h.length_squared(),relative.dot(v)/v.length_squared())
			st.set_uv((Vector2(rect.position)+face_uv*Vector2(face.size))/Vector2(atlas_w,atlas_h))
			st.set_normal(face.normal); st.add_vertex(point)
	st.index()
	var result := {"mesh":st.commit(),"texture":ImageTexture.create_from_image(atlas),"faces":faces,"image":atlas,"kind":kind,"variant":variant}
	cache[key]=result
	return result

static func _tile(dimensions: Vector2i, uv: Vector2) -> String:
	var pixel := Vector2i(uv*Vector2(dimensions))
	if dimensions==Vector2i(OFFICE.ATLAS_WIDTH,OFFICE.ATLAS_HEIGHT):
		for tile in OFFICE.REGIONS:
			if OFFICE.REGIONS[tile].has_point(pixel): return tile
	else:
		for tile in ROOM.TILES:
			if ROOM._rect(ROOM.TILES[tile]).has_point(pixel): return tile
	return "side"

static func _base_color(image: Image, uv_min: Vector2, uv_max: Vector2) -> Color:
	var start := Vector2i(uv_min*Vector2(image.get_size()))+Vector2i.ONE
	var end := Vector2i(uv_max*Vector2(image.get_size()))
	var histogram: Dictionary={}
	for y in range(start.y,maxi(start.y+1,end.y)):
		for x in range(start.x,maxi(start.x+1,end.x)):
			var color := image.get_pixel(clampi(x,0,image.get_width()-1),clampi(y,0,image.get_height()-1))
			histogram[color]=int(histogram.get(color,0))+1
	var dominant := Color.WHITE; var count := 0
	for color in histogram:
		if histogram[color]>count: dominant=color; count=histogram[color]
	return dominant

static func _rect(image: Image, box: Rect2i, color: Color) -> void:
	var clipped := box.intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	if clipped.has_area(): image.fill_rect(clipped,color)

static func _polygon(image: Image, points: PackedVector2Array, color: Color) -> void:
	for y in image.get_height():
		for x in image.get_width():
			if Geometry2D.is_point_in_polygon(Vector2(x+.5,y+.5),points): image.set_pixel(x,y,color)

static func _paper_stack(image: Image, origin: Vector2, variant: int) -> void:
	# Hand-authored pixel polygons: staggered sheets, sloping edges and writing.
	var sheets := 2+variant%3
	for layer in sheets:
		var at := origin+Vector2((layer%2)*3-layer,layer*2)
		var slope := -2.0 if (variant+layer)%2==0 else 2.0
		var corners := PackedVector2Array([at+Vector2(0,2),at+Vector2(10,2+slope),at+Vector2(11,10+slope),at+Vector2(1,10)])
		_polygon(image,corners,Color("aab2ad"))
		var inner := PackedVector2Array([at+Vector2(1,3),at+Vector2(9,3+slope),at+Vector2(10,9+slope),at+Vector2(2,9)])
		_polygon(image,inner,Color("dfe1d8") if layer%2==0 else Color("cbd1c7"))
		for line in 2:
			for x in range(3,8-line):
				var y := 5+line*2+roundi(slope*float(x)/10.0)
				_rect(image,Rect2i(roundi(at.x)+x,roundi(at.y)+y,1,1),Color("829092"))

static func _paint(size: Vector2i, base: Color, tile: String, kind: String, normal: Vector3, variant: int = 0, paper_background: Color = Color.TRANSPARENT) -> Image:
	if kind=="sofa" and tile in ["sofa","fabric","side"]:
		# Stay within the established upholstery palette, never paper/label decals.
		if variant==1: base=base.darkened(.09)
		elif variant==2: base=base.lerp(Color("72847c"),.25)
		elif variant==3: base=base.lightened(.07)
	var image := Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
	image.fill(base)
	var shadow := base.darkened(.27); var light := base.lightened(.13)
	var ink := Color("283238"); var paper := Color("dfe1d8")
	if size.x>=6 and size.y>=6:
		_rect(image,Rect2i(0,0,size.x,1),light)
		_rect(image,Rect2i(size.x-1,1,1,size.y-1),shadow)
		_rect(image,Rect2i(1,size.y-1,size.x-2,1),shadow)
	if tile=="whiteboard" and size.x>=18 and size.y>=14:
		_rect(image,Rect2i(2,2,size.x-4,size.y-4),paper)
		# Four legible layouts: agenda, diagram, columns, clean board with note.
		var board_ink := Color("819e9e")
		if variant==0:
			for row in 3: _rect(image,Rect2i(6,7+row*6,size.x/2-row*3,2),board_ink)
		elif variant==1:
			_rect(image,Rect2i(6,7,12,8),board_ink)
			_rect(image,Rect2i(8,9,8,4),paper)
			_rect(image,Rect2i(18,11,10,1),board_ink)
			_rect(image,Rect2i(28,8,12,8),board_ink)
			_rect(image,Rect2i(30,10,8,4),paper)
		elif variant==2:
			_rect(image,Rect2i(size.x/2,6,1,size.y-12),board_ink)
			for row in 3:
				_rect(image,Rect2i(6,8+row*5,size.x/3,1),board_ink)
				_rect(image,Rect2i(size.x/2+4,8+row*5,size.x/3-4,1),board_ink)
		_rect(image,Rect2i(size.x-13,5+variant*2,7,5),Color("c1a66e"))
	elif tile=="reception" and size.x>=20 and size.y>=12:
		_rect(image,Rect2i(3,4,size.x-6,2),light)
		var panel_x := 5+variant*3
		_rect(image,Rect2i(panel_x,9,size.x/2,6),base.darkened(.18))
		_rect(image,Rect2i(panel_x+3,11,size.x/3,2),light)
		if variant==1 or variant==2:
			_rect(image,Rect2i(size.x-14,size.y-9,8,4),paper)
	elif kind=="fridge" and tile=="kitchen" and size.x>=16 and size.y>=20:
		var divider := roundi(size.y*.32)
		_rect(image,Rect2i(2,divider,size.x-4,1),shadow)
		# Physical handle is retained; only labels and broad door joints are painted.
		var note_x := 4 if variant%2==0 else size.x-12
		if variant!=3:
			_rect(image,Rect2i(note_x,divider+5,7,7),paper)
			_rect(image,Rect2i(note_x+1,divider+7,4,1),shadow)
		_rect(image,Rect2i(4+variant,4,6,2),light)
	elif tile=="sink" and size.x>=12 and size.y>=10:
		var inset := 3+variant%2
		_rect(image,Rect2i(inset,3,size.x-2*inset,size.y-6),Color("718d99"))
		_rect(image,Rect2i(inset+1,4,size.x-2*inset-2,size.y-8),base)
		_rect(image,Rect2i(size.x/2-1,size.y/2-1,2,2),ink)
		_rect(image,Rect2i(3,2+variant,3,1),light)
	elif tile=="porcelain" and size.x>=12 and size.y>=12:
		if normal.y>.5:
			# Stepped pixel oval gives the existing box bowl a readable rim.
			for row in range(3,size.y-3):
				var edge := 5 if row<5 or row>=size.y-5 else 3
				_rect(image,Rect2i(edge,row,size.x-edge*2,1),shadow)
				_rect(image,Rect2i(edge+2,row+1,size.x-edge*2-4,1),base.lightened(.08))
			_rect(image,Rect2i(size.x/2-1,5+variant,2,2),light)
		else:
			_rect(image,Rect2i(3,3,size.x-6,1),light)
			_rect(image,Rect2i(3,size.y-5-variant,size.x-6,1),shadow.lightened(.18))
	elif tile in ["tile","door"] and kind in ["partition","stall_door"] and size.x>=8 and size.y>=12:
		_rect(image,Rect2i(2,3,1,size.y-6),shadow)
		_rect(image,Rect2i(size.x-3,3,1,size.y-6),shadow)
		var sign_x := maxi(2,size.x/2-3+variant%2)
		_rect(image,Rect2i(sign_x,6+variant*2,5,4),paper)
		_rect(image,Rect2i(sign_x+1,7+variant*2,3,1),shadow)
		if tile=="door":
			_rect(image,Rect2i(size.x-6,size.y/2,3,2),ink)
	elif tile=="plant" and size.x>=8 and size.y>=8:
		# Small deliberate leaf clusters, not a speckled noise texture.
		for cluster in 3:
			var px := 2+(cluster*3+variant)%maxi(1,size.x-6)
			var py := 2+(cluster*5+variant*2)%maxi(1,size.y-5)
			_rect(image,Rect2i(px,py,4,3),light if cluster%2==0 else shadow)
			_rect(image,Rect2i(px+1,py+2,2,2),base)
	elif kind=="plant" and tile in ["wood","wood_top"] and size.x>=8 and size.y>=8:
		_rect(image,Rect2i(2,2,size.x-4,2),shadow)
		if normal.y>.5:
			_rect(image,Rect2i(3,4,size.x-6,size.y-7),Color("543d2b"))
		else:
			_rect(image,Rect2i(3+variant,5,2,size.y-8),light)
	elif tile in ["cabinet_front","drawer"] and normal.y<.5:
		var rows := (3 if tile=="cabinet_front" else 2) if kind=="cabinet" else 3
		for row in rows:
			var top := roundi(float(size.y)*row/rows)
			var bottom := roundi(float(size.y)*(row+1)/rows)
			if tile=="cabinet_front" and row==0:
				_rect(image,Rect2i(1,top+2,size.x-2,bottom-top-3),Color("c98f32"))
				_rect(image,Rect2i(1,top+2,size.x-2,1),Color("e0ab4f"))
			_rect(image,Rect2i(1,bottom-1,size.x-2,1),ink)
			var middle := (top+bottom)/2
			var handle_w := maxi(3,roundi(size.x*.27))
			_rect(image,Rect2i((size.x-handle_w)/2,middle+1,handle_w,2),ink)
			_rect(image,Rect2i((size.x-handle_w)/2,middle,handle_w,1),light)
			if size.x>=20:
				var label_x := 4 if variant%2==0 else size.x-12
				if variant!=3 or row==0:
					_rect(image,Rect2i(label_x,top+3,8,3),paper)
					_rect(image,Rect2i(label_x+1,top+4,3+variant%3,1),shadow)
	elif tile=="desk_top" and normal.y>.5:
		# A few authored scuffs and an inset lip, not procedural noise/grain.
		_rect(image,Rect2i(2,2,size.x-4,1),shadow.lightened(.10))
		if variant!=3:
			_rect(image,Rect2i(3+variant*3,size.y-4,6,1),light)
			_rect(image,Rect2i(size.x-10,3+variant*2,4,1),light)
		var px := 5 if variant%2==0 else size.x-23
		_paper_stack(image,Vector2(px,4+variant%2),variant)
		if variant==2:
			# Deliberate cup ring, not scattered random noise.
			_rect(image,Rect2i(size.x-15,size.y-12,6,5),shadow.lightened(.12))
			_rect(image,Rect2i(size.x-14,size.y-11,4,3),base)
	elif tile=="partition" and size.x>=12 and size.y>=6:
		var notes := [[.20,.23,"e5c742"],[.52,.30,"e0e4dc"],[.80,.42,"50a5f0"]]
		for index in notes.size():
			if variant==3 and index>0: continue
			var note: Array=notes[index]
			var nx := roundi(size.x*(float(note[0]) if variant%2==0 else 1.0-float(note[0])))
			var ny := roundi(size.y*float(note[1]))+variant%3
			var width := mini(6,size.x-nx-2); var height := mini(4,size.y-ny-2)
			_rect(image,Rect2i(nx,ny,width,height),Color(note[2]))
			if width>=4 and height>=3: _rect(image,Rect2i(nx+1,ny+1,width-2,1),shadow)
	elif tile=="screen_front" and size.x>=10 and size.y>=6:
		_rect(image,Rect2i(2,2,size.x-4,size.y-4),Color("203b40"))
		for row in 2: _rect(image,Rect2i(3,3+row*2,size.x-7,1),Color("4e686b"))
		_rect(image,Rect2i(size.x-5,3,2,2),Color("50a5f0"))
		_rect(image,Rect2i(size.x-2,size.y-2,1,1),Color("62d476"))
	elif tile in ["document","paper"] and size.x>=6 and size.y>=6:
		if normal.y>.5 and paper_background.a>.5:
			# Existing thin paper meshes stay in place; the visible sheet silhouette
			# tilts inside its face, backed by the matching tabletop colour.
			image.fill(paper_background)
			var corners := PackedVector2Array([Vector2(1,1),Vector2(size.x-2,2),Vector2(size.x-1,size.y-2),Vector2(2,size.y-1)])
			if variant%2==1:
				corners=PackedVector2Array([Vector2(2,2),Vector2(size.x-1,0),Vector2(size.x-2,size.y-1),Vector2(0,size.y-2)])
			_polygon(image,corners,paper)
			for x in range(2,size.x-2):
				_rect(image,Rect2i(x,3+roundi(float(x)/(size.x-2)*(1 if variant%2==0 else -1)),1,1),shadow)
			_rect(image,Rect2i(size.x-3,size.y-3,1,1),paper.darkened(.13))
		else:
			_rect(image,Rect2i(2,2,size.x-4,1),shadow)
			_rect(image,Rect2i(2,4,size.x-5,1),shadow.lightened(.15))
	elif tile=="screen_back" and size.x>=8:
		_rect(image,Rect2i(2,1,size.x-4,1),shadow)
	elif tile in ["chair_seat","chair_back","sofa","fabric"] and size.x>=8 and size.y>=6:
		# Sparse upholstery seams, never a high-frequency weave or checkerboard.
		_rect(image,Rect2i(2,2,size.x-4,1),shadow)
		_rect(image,Rect2i(2,3,1,size.y-5),shadow)
		_rect(image,Rect2i(3,size.y-3,size.x-6,1),shadow)
		_rect(image,Rect2i(3,3,size.x-6,1),light)
		if tile=="sofa" and size.x>=48:
			var panels := 3 if variant==1 else 2
			for panel in range(1,panels): _rect(image,Rect2i(size.x*panel/panels,3,1,size.y-6),shadow)
		if variant==1 and tile!="sofa":
			_rect(image,Rect2i(size.x/2,4,1,size.y-8),shadow)
		elif variant==2:
			_rect(image,Rect2i(size.x-7,size.y-5,4,1),light)
		elif variant==3:
			_rect(image,Rect2i(4,4,size.x-8,1),base.lightened(.06))
		if kind=="sofa": _sofa_wear(image,base,variant)
	elif tile=="file" and size.x>=12 and size.y>=12:
		# Four readable archive shelves with grouped binders and label tabs.
		for row in 4:
			var top := roundi(size.y*float(row)/4)+2
			var bottom := roundi(size.y*float(row+1)/4)-1
			_rect(image,Rect2i(2,bottom,size.x-4,1),ink)
			var x := 3
			var index := variant+row
			while x<size.x-5:
				var width := mini(6+(index%3)*2+variant%2,size.x-3-x)
				var color := base.darkened(.12) if index%2==0 else base.lightened(.12)
				_rect(image,Rect2i(x,top,width-1,bottom-top),color)
				_rect(image,Rect2i(x+1,top+3+variant%2,maxi(1,width-3),2),paper)
				_rect(image,Rect2i(x+1,bottom-3,maxi(1,width-3),1),shadow)
				x+=width; index+=1
	elif tile in ["rack","port"] and size.x>=10 and size.y>=6:
		var rows := 4+variant%3 if tile=="rack" else 1
		for row in rows:
			var top := roundi(size.y*float(row)/rows)+2
			var bottom := roundi(size.y*float(row+1)/rows)-1
			_rect(image,Rect2i(2,top,size.x-4,maxi(1,bottom-top)),ink)
			_rect(image,Rect2i(4,top+2,maxi(1,size.x-12),1),base)
			var led_x := size.x-6 if variant%2==0 else 4
			_rect(image,Rect2i(led_x,top+2,2,2),Color("82a38b") if (row+variant)%2==0 else Color("c49c56"))
	elif tile=="counter" and kind!="water_dispenser" and size.x>=16 and size.y>=10:
		var doors := 3 if variant==1 else 2
		for door in range(1,doors): _rect(image,Rect2i(size.x*door/doors,2,1,size.y-4),ink)
		for side in 2:
			var x := roundi(size.x*(.25+.5*side))
			_rect(image,Rect2i(x-3,6,6,1),light)
			_rect(image,Rect2i(x-3,7,6,2),ink)
		if variant==2: _rect(image,Rect2i(size.x-12,size.y-7,8,3),paper)
	elif tile in ["wood_top","kitchen","metal_top"] and normal.y>.5 and size.x>=12 and size.y>=8:
		# Broad inset and a few authored marks: preserve clean usable tabletops.
		_rect(image,Rect2i(2,2,size.x-4,1),shadow)
		_rect(image,Rect2i(2,3,1,size.y-5),shadow)
		_rect(image,Rect2i(3,size.y-3,size.x-6,1),light)
		if variant!=3: _rect(image,Rect2i(size.x-9-variant*2,4+variant,4,1),light)
		if kind in ["coffee_table","table","dining_table","sorting_table"]:
			var px := 4 if variant%2==0 else size.x-23
			_paper_stack(image,Vector2(px,3),variant)
		if tile=="metal_top" and kind=="server":
			for row in 3+variant%2:
				_rect(image,Rect2i(5,5+row*3,size.x-10-variant,1),shadow)
	elif tile=="screen" and size.x>=8 and size.y>=6:
		_rect(image,Rect2i(2,2,size.x-4,size.y-4),Color("17252d"))
		_rect(image,Rect2i(3,3,maxi(1,size.x-7),1),Color("425b65"))
		_rect(image,Rect2i(size.x-3,size.y-2,1,1),Color("86ad78"))
	elif tile in ["cabinet_side","desk_side","side","steel","wood"] and size.x>=12 and size.y>=12:
		_rect(image,Rect2i(2,2,1,size.y-4),shadow.lightened(.08))
		_rect(image,Rect2i(3,2,size.x-6,1),light)
		_rect(image,Rect2i(3,size.y-4,3,1),light)
		if variant==1: _rect(image,Rect2i(size.x-5,4,1,size.y-8),shadow)
		elif variant==2: _rect(image,Rect2i(size.x-10,size.y-6,5,1),light)
		elif variant==3 and kind!="sofa": _rect(image,Rect2i(5,5,7,3),paper.darkened(.12))
		if kind=="sofa": _sofa_wear(image,base,variant)
		if kind=="cabinet" and normal.z<-.5:
			_rect(image,Rect2i(size.x/2,2,1,size.y-4),shadow)
			_rect(image,Rect2i(4,5,7,3),paper.darkened(.12))
	elif kind=="water_dispenser" and tile=="counter" and size.x>=12:
		_rect(image,Rect2i(3,4,size.x-6,4),paper)
		_rect(image,Rect2i(5,5,size.x-10,1),shadow)
		for row in 3: _rect(image,Rect2i(4,size.y-8+row*2,size.x-8,1),shadow)
	elif kind=="water_dispenser" and tile=="steel" and size.y>=10:
		_rect(image,Rect2i(2,3,2,size.y-6),light)
		_rect(image,Rect2i(size.x-3,3,1,size.y-6),shadow)
		_rect(image,Rect2i(3,size.y-4,size.x-6,1),shadow)
	return image

static func _sofa_wear(image: Image, base: Color, variant: int) -> void:
	var size := image.get_size()
	if variant==0 or size.x<12 or size.y<10: return
	var x := size.x/2-3
	var y := size.y/2
	if variant==1 or variant==3:
		# Irregular, restrained stains in the upholstery's own colour family.
		_rect(image,Rect2i(x,y,5,3),base.darkened(.14))
		_rect(image,Rect2i(x+2,y-1,5,2),base.darkened(.11))
		_rect(image,Rect2i(x+1,y+3,3,1),base.darkened(.10))
	if variant==2 or variant==3:
		# A short jagged tear; no large white patch or rectangular sticker.
		for step in 5:
			_rect(image,Rect2i(4+step,4+step/2,2,1),base.darkened(.42))
			if step%2==0: _rect(image,Rect2i(4+step,3+step/2,1,1),base.lightened(.10))
