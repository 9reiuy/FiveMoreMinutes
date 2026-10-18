class_name OfficeRoomLowPixelArt
extends RefCounted

## Shared, deliberately coarse 3D pixel art for the authored sample's non-office rooms.
## The open office keeps its own approved assets. Furniture physics never lives here.
const SHADER = preload("res://shaders/dream3d/office_low_pixel.gdshader")
const OFFICE_ART = preload("res://scripts/dream/office_low_pixel_art.gd")
## Diagnostic A/B switch; gameplay always uses the new room assets by default.
static var enabled := true
const TILE := 16
const COLUMNS := 8
const ATLAS_SIZE := Vector2i(128, 64)
const TILES := {
	"paper": 0, "light": 1, "side": 2, "dark": 3,
	"wood": 4, "wood_top": 5, "steel": 6, "fabric": 7,
	"file": 8, "rack": 9, "counter": 10, "kitchen": 11,
	"porcelain": 12, "tile": 13, "screen": 14, "plant": 15,
	"sofa": 16, "rug": 17, "whiteboard": 18, "reception": 19,
	"elevator": 20, "sign": 21, "water": 22, "mirror": 23,
	"metal_top": 24, "sink": 25, "drawer": 26, "mustard": 27,
	"black": 28, "port": 29, "door": 30, "wall": 31,
}
static var _texture: ImageTexture
static var _material: ShaderMaterial
static var _meshes: Dictionary = {}
static var _fixture_meshes: Dictionary = {}

static func supports(kind: String) -> bool:
	if kind == "water_dispenser": return true
	return kind in ["table", "dining_table", "coffee_table", "sofa", "cabinet", "cabinet_open", "shelf", "sorting_table", "server", "fridge", "counter", "appliance_counter", "sink", "toilet", "washbasin", "partition", "stall_door", "whiteboard", "reception", "plant"]

static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter("atlas", texture())
	return _material

static func texture() -> ImageTexture:
	if _texture != null:
		return _texture
	var image := Image.create(ATLAS_SIZE.x, ATLAS_SIZE.y, false, Image.FORMAT_RGBA8)
	var colors := [
		"dfe1d8", "bdc7c6", "829092", "283238", "98877b", "d0c6b3", "66777e", "728491",
		"aab8b5", "83959b", "c7d0ca", "b9c5c0", "d2d9d2", "879997", "27363e", "5b755d",
		"637c88", "625e5a", "dce0d6", "829098", "6b7c87", "b3bdb8", "9fc1ce", "9caeb1",
		"bac6c6", "a7babd", "a6b5b1", "b69b58", "101619", "69818a", "707e80", "778586"
	]
	for i in range(colors.size()):
		image.fill_rect(_rect(i), Color(colors[i]))
	# Large, readable marks; no fine noise or repeated high-frequency weave.
	for row in 4:
		_p(image, "file", 1, 1 + row * 4, 14, 1, "303b3e")
		_p(image, "file", 4, 2 + row * 4, 7, 2, "c4b790" if row % 2 == 0 else "a5b1ad")
		_p(image, "file", 12, 2 + row * 4, 2, 2, "d9ddd4")
	for row in 3:
		_p(image, "rack", 2, 2 + row * 5, 12, 3, "1e292e")
		_p(image, "rack", 4, 3 + row * 5, 5, 1, "71848a")
		_p(image, "rack", 11, 3 + row * 5, 2, 2, "82a38b" if row != 1 else "c49c56")
	_p(image, "rack", 0, 0, 1, 16, "76868d")
	_p(image, "rack", 15, 0, 1, 16, "243037")
	_p(image, "counter", 0, 0, 16, 2, "d5d7cb")
	_p(image, "counter", 2, 5, 5, 7, "849495")
	_p(image, "counter", 9, 5, 5, 7, "849495")
	_p(image, "counter", 7, 7, 2, 1, "38474b")
	_p(image, "kitchen", 1, 2, 14, 2, "ccd2c9")
	_p(image, "kitchen", 3, 8, 10, 1, "566569")
	_p(image, "screen", 1, 1, 14, 11, "17252d")
	_p(image, "screen", 2, 2, 6, 2, "425b65")
	_p(image, "screen", 12, 13, 2, 1, "86ad78")
	_p(image, "sofa", 1, 1, 14, 12, "8299a2")
	_p(image, "sofa", 1, 13, 14, 2, "4d6874")
	_p(image, "rug", 0, 0, 16, 1, "726d68")
	_p(image, "rug", 0, 15, 16, 1, "53514e")
	_p(image, "rug", 0, 0, 1, 16, "6c6864")
	_p(image, "rug", 15, 0, 1, 16, "585551")
	_p(image, "whiteboard", 1, 1, 14, 13, "e3e6db")
	_p(image, "whiteboard", 3, 4, 6, 1, "819e9e")
	_p(image, "whiteboard", 3, 7, 9, 1, "aabcb6")
	_p(image, "whiteboard", 10, 10, 3, 2, "c1a66e")
	_p(image, "reception", 0, 0, 16, 2, "abb7b5")
	_p(image, "reception", 2, 5, 12, 1, "bec8c1")
	_p(image, "reception", 3, 9, 10, 3, "617782")
	_p(image, "elevator", 1, 0, 14, 16, "81919c")
	_p(image, "elevator", 7, 0, 2, 16, "3d5059")
	_p(image, "sign", 1, 1, 14, 14, "d5d9cc")
	_p(image, "sign", 3, 3, 10, 2, "34464d")
	_p(image, "sign", 4, 8, 8, 2, "809796")
	_p(image, "sink", 2, 2, 12, 11, "c9d4d0")
	_p(image, "sink", 4, 4, 8, 7, "718d99")
	_p(image, "sink", 7, 5, 2, 4, "506977")
	_p(image, "drawer", 1, 2, 14, 5, "b1bcba")
	_p(image, "drawer", 1, 9, 14, 5, "9ca9a8")
	_p(image, "drawer", 6, 4, 4, 1, "4c5b60")
	_p(image, "drawer", 6, 11, 4, 1, "4c5b60")
	_p(image, "port", 2, 2, 12, 3, "26343a")
	_p(image, "port", 3, 3, 4, 1, "778b91")
	_p(image, "port", 11, 3, 2, 1, "89a977")
	_p(image, "door", 1, 1, 14, 14, "859594")
	_p(image, "door", 11, 7, 2, 2, "354449")
	_p(image, "wood_top", 0, 0, 16, 1, "b19876")
	_p(image, "wood_top", 0, 15, 16, 1, "685347")
	# Archive drawers and other small faces can minify to a subpixel texel at
	# the formal 45-degree projection. Keep the authored 16x16 level intact and
	# prefilter only the smaller levels to prevent moving-camera interference.
	image.generate_mipmaps()
	_texture = ImageTexture.create_from_image(image)
	return _texture

static func _rect(index: int) -> Rect2i:
	return Rect2i((index % COLUMNS) * TILE, int(index / COLUMNS) * TILE, TILE, TILE)

static func _p(image: Image, tile: String, x: int, y: int, width: int, height: int, color: String) -> void:
	var rect := _rect(int(TILES[tile]))
	image.fill_rect(Rect2i(rect.position + Vector2i(x, y), Vector2i(width, height)), Color(color))

static func make_visual(kind: String) -> Node3D:
	# These two are the player's approved open-office assets, reused unchanged.
	if kind in ["workstation", "chair"]:
		return OFFICE_ART.make_visual(kind)
	var root := Node3D.new()
	root.name = "RoomLowPixel_" + kind
	if not _meshes.has(kind):
		_meshes[kind] = _build_mesh(kind)
	var display := MeshInstance3D.new()
	display.name = "AuthoredSurfaceMesh"
	display.mesh = _meshes[kind]
	display.material_override = material()
	root.add_child(display)
	return root

static func room_fixtures(key: String, origin: Vector2) -> Node3D:
	# Wall-mounted, presentation-only details. Never consume passage width or alter LOS.
	var placements: Array = []
	match key:
		"conference": placements = [["sign", 9.9, 1.9, .56, 0.7, .4, 0.0]]
		"manager": placements = [["sign", 6.0, 1.95, .56, .7, .45, 0.0]]
		"archive": placements = [["sign", 5.5, 2.05, .56, .7, .4, 0.0]]
		"server": placements = [["sign", 5.5, 2.05, .56, .7, .4, 0.0], ["port", 5.5, 1.55, .57, .65, .2, 0.0]]
		"pantry": placements = [["kitchen", 3.1, 1.45, .56, .58, .4, 0.0], ["water", 7.7, 1.15, .56, .35, .7, 0.0]]
		"restroom": placements = [["mirror", 9.44, 1.55, 5.5, .65, .8, PI * .5], ["paper", 5.55, .85, 2.1, .25, .2, 0.0]]
		"lounge": placements = [["sign", 7.2, 1.85, .56, .6, .4, 0.0]]
		"reception": placements = [["sign", 6.9, 2.0, .56, 1.0, .45, 0.0]]
		"lift": placements = [["sign", 1.0, 2.0, .56, .8, .5, 0.0], ["port", 8.9, 1.25, .56, .28, .42, 0.0]]
		"north", "south": placements = [["sign", 0.9, 2.0, .56, .65, .4, 0.0], ["door", 20.9, 1.4, 3.44, .35, .55, PI]]
		"east", "west": placements = [["sign", .56, 2.0, 1.0, .65, .4, PI * .5], ["door", 3.44, 1.4, 15.0, .35, .55, -PI * .5]]
	if placements.is_empty():
		return null
	var root := Node3D.new()
	root.name = "RoomLowPixelFixtures_" + key
	for entry in placements:
		var display := MeshInstance3D.new()
		display.mesh = _fixture_mesh(String(entry[0]), Vector2(float(entry[4]), float(entry[5])))
		display.material_override = material()
		display.position = Vector3(origin.x + float(entry[1]), float(entry[2]), origin.y + float(entry[3]))
		display.rotation.y = float(entry[6])
		display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(display)
	if key == "lounge":
		var rug := MeshInstance3D.new()
		rug.name = "LowContrastSeatRug"
		rug.mesh = _floor_patch_mesh("rug", Vector2(3.6, 3.2))
		rug.material_override = material()
		rug.position = Vector3(origin.x + 5.1, .018, origin.y + 4.6)
		rug.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(rug)
	return root

static func _fixture_mesh(tile: String, size: Vector2) -> ArrayMesh:
	var cache_key := "%s:%s:%s" % [tile, size.x, size.y]
	if not _fixture_meshes.has(cache_key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_box(st, Vector3(size.x, size.y, .045), Vector3.ZERO, "steel", tile)
		_fixture_meshes[cache_key] = st.commit()
	return _fixture_meshes[cache_key]

static func _floor_patch_mesh(tile: String, size: Vector2) -> ArrayMesh:
	var cache_key := "floor:%s:%s:%s" % [tile, size.x, size.y]
	if not _fixture_meshes.has(cache_key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_box(st, Vector3(size.x, .012, size.y), Vector3.ZERO, tile)
		_fixture_meshes[cache_key] = st.commit()
	return _fixture_meshes[cache_key]

static func _build_mesh(kind: String) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"table", "dining_table", "sorting_table":
			var width := 4.5 if kind == "table" else 1.5
			var depth := 1.3 if kind != "sorting_table" else .75
			_box(st, Vector3(width, .09, depth), Vector3(0, .715, 0), "wood", "wood_top")
			for x in [-1.0, 1.0]:
				for z in [-1.0, 1.0]:
					_box(st, Vector3(.09, .70, .09), Vector3(x * (width * .5 - .16), .35, z * (depth * .5 - .13)), "steel")
			if kind == "table":
				for x in [-1.35, -.45, .45, 1.35]:
					_box(st, Vector3(.22, .012, .28), Vector3(x, .767, -.22), "paper")
				for x in [-1.0, 1.0]:
					_box(st, Vector3(.47, .025, .30), Vector3(x, .773, .23), "dark", "steel")
					_box(st, Vector3(.47, .25, .045), Vector3(x, .91, .06), "steel", "screen")
			elif kind == "sorting_table":
				_box(st, Vector3(.38, .06, .30), Vector3(-.35, .79, 0), "file")
		"coffee_table":
			_box(st, Vector3(1.3, .08, .75), Vector3(0, .38, 0), "wood", "wood_top")
			for x in [-.5, .5]:
				for z in [-.24, .24]:
					_box(st, Vector3(.07, .38, .07), Vector3(x, .19, z), "dark")
		"sofa":
			_box(st, Vector3(2.1, .37, .73), Vector3(0, .33, .05), "fabric", "sofa")
			for x in [-.49, .49]:
				_box(st, Vector3(.94, .055, .62), Vector3(x, .54, .06), "side", "sofa")
			_box(st, Vector3(2.1, .72, .19), Vector3(0, .50, -.35), "side", "sofa")
			for x in [-.99, .99]:
				_box(st, Vector3(.12, .55, .85), Vector3(x, .39, 0), "side", "fabric")
		"cabinet", "cabinet_open":
			_box(st, Vector3(1.3, 1.85, .65), Vector3(0, .925, 0), "side", "drawer")
			if kind == "cabinet_open":
				_box(st, Vector3(1.0, .16, .58), Vector3(0, .55, .45), "dark", "paper")
		"shelf":
			_box(st, Vector3(1.5, 1.9, .7), Vector3(0, .95, 0), "steel", "file")
			_box(st, Vector3(1.45, .08, .73), Vector3(0, .04, 0), "dark")
		"server":
			_box(st, Vector3(1.0, 1.95, .85), Vector3(0, .975, 0), "steel", "rack", "metal_top")
			_box(st, Vector3(.76, .20, .025), Vector3(0, 1.72, .435), "port")
			_box(st, Vector3(.96, .08, .88), Vector3(0, .04, 0), "dark")
		"fridge":
			_box(st, Vector3(.9, 1.85, .8), Vector3(0, .925, 0), "side", "kitchen", "light")
			_box(st, Vector3(.06, .35, .04), Vector3(.31, 1.14, .425), "steel")
		"counter", "appliance_counter", "sink":
			var width := 1.2 if kind == "sink" else 1.5
			_box(st, Vector3(width, .83, .7), Vector3(0, .415, 0), "side", "counter")
			_box(st, Vector3(width, .05, .74), Vector3(0, .855, 0), "metal_top", "sink" if kind == "sink" else "kitchen")
			if kind == "sink":
				_box(st, Vector3(.07, .18, .05), Vector3(0, 1.0, -.13), "steel")
			elif kind == "appliance_counter":
				_box(st, Vector3(.64, .38, .42), Vector3(.20, 1.09, -.04), "side", "kitchen")
				_box(st, Vector3(.44, .21, .025), Vector3(.19, 1.10, .18), "dark", "screen")
		"toilet":
			_box(st, Vector3(.58, .45, .72), Vector3(0, .32, .07), "porcelain", "porcelain")
			_box(st, Vector3(.56, .48, .18), Vector3(0, .56, -.34), "porcelain", "light")
		"washbasin":
			_box(st, Vector3(.8, .16, .6), Vector3(0, .77, 0), "porcelain", "sink")
			_box(st, Vector3(.25, .7, .24), Vector3(0, .35, -.12), "side")
		"partition":
			_box(st, Vector3(.08, 1.8, 1.65), Vector3(0, .9, 0), "side", "tile", "metal_top")
		"stall_door":
			_box(st, Vector3(.82, 1.55, .08), Vector3(0, .775, 0), "side", "door", "metal_top")
		"whiteboard":
			_box(st, Vector3(2.0, 1.65, .15), Vector3(0, .825, 0), "steel", "whiteboard")
		"reception":
			# The body used to end exactly at the cap's upper face (1.05m),
			# leaving two coplanar tops that fought for the depth buffer.
			_box(st, Vector3(2.8, .97, .9), Vector3(0, .485, 0), "side", "reception", "wood_top")
			_box(st, Vector3(2.8, .08, 1.0), Vector3(0, 1.01, 0), "steel", "counter")
			_box(st, Vector3(.42, .30, .065), Vector3(-.55, 1.28, -.19), "steel", "screen")
			_box(st, Vector3(.52, .025, .32), Vector3(-.55, 1.055, .04), "dark")
			_box(st, Vector3(.30, .02, .34), Vector3(.62, 1.055, -.06), "paper")
		"plant":
			_box(st, Vector3(.42, .52, .42), Vector3(0, .26, 0), "wood", "wood_top")
			_box(st, Vector3(.38, .74, .38), Vector3(0, .92, 0), "plant", "plant")
		"water_dispenser":
			_box(st,Vector3(.55,.90,.55),Vector3(0,.45,0),"side","counter","metal_top")
			_box(st,Vector3(.34,.46,.34),Vector3(0,1.15,0),"steel","steel","metal_top")
			_box(st,Vector3(.38,.04,.38),Vector3(0,1.38,0),"dark")
			_box(st,Vector3(.28,.22,.04),Vector3(0,.61,.29),"dark")
			for x in [-.08,.08]: _box(st,Vector3(.04,.04,.07),Vector3(x,.72,.325),"paper")
			_box(st,Vector3(.30,.04,.09),Vector3(0,.46,.30),"steel")
	return st.commit()

static func _box(st: SurfaceTool, size: Vector3, center: Vector3, side: String, front: String = "", top: String = "") -> void:
	var h := size * .5
	var f := front if not front.is_empty() else side
	var t := top if not top.is_empty() else side
	_face(st, [Vector3(-h.x,-h.y,h.z),Vector3(-h.x,h.y,h.z),Vector3(h.x,h.y,h.z),Vector3(h.x,-h.y,h.z)], Vector3.BACK, center, f)
	_face(st, [Vector3(h.x,-h.y,-h.z),Vector3(h.x,h.y,-h.z),Vector3(-h.x,h.y,-h.z),Vector3(-h.x,-h.y,-h.z)], Vector3.FORWARD, center, side)
	_face(st, [Vector3(h.x,-h.y,h.z),Vector3(h.x,h.y,h.z),Vector3(h.x,h.y,-h.z),Vector3(h.x,-h.y,-h.z)], Vector3.RIGHT, center, side)
	_face(st, [Vector3(-h.x,-h.y,-h.z),Vector3(-h.x,h.y,-h.z),Vector3(-h.x,h.y,h.z),Vector3(-h.x,-h.y,h.z)], Vector3.LEFT, center, side)
	_face(st, [Vector3(-h.x,h.y,h.z),Vector3(-h.x,h.y,-h.z),Vector3(h.x,h.y,-h.z),Vector3(h.x,h.y,h.z)], Vector3.UP, center, t)
	_face(st, [Vector3(-h.x,-h.y,-h.z),Vector3(-h.x,-h.y,h.z),Vector3(h.x,-h.y,h.z),Vector3(h.x,-h.y,-h.z)], Vector3.DOWN, center, side)

static func _face(st: SurfaceTool, corners: Array, normal: Vector3, center: Vector3, tile: String) -> void:
	var rect := _rect(int(TILES[tile]))
	var uv := [Vector2(.5,15.5),Vector2(.5,.5),Vector2(15.5,.5),Vector2(15.5,15.5)]
	for index in [0, 1, 2, 0, 2, 3]:
		st.set_normal(normal)
		st.set_uv((Vector2(rect.position) + uv[index]) / Vector2(ATLAS_SIZE))
		st.add_vertex(corners[index] + center)
