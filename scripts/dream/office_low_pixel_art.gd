class_name OfficeLowPixelArt
extends RefCounted

## Open-office display assets only. Physics/footprint stay in the catalog.
## Explicit face UVs, shared 128x96 atlas, continuous geometry and rotation.
## enabled is an A/B preview switch, never a player/profile setting.
static var enabled := true
static var _texture: ImageTexture
static var _material: ShaderMaterial
static var _surfaces: Dictionary = {}
static var _meshes: Dictionary = {}

const SHADER = preload("res://shaders/dream3d/office_low_pixel.gdshader")

## Atlas layout: 128 x 96 (clean grid arrangement)
const ATLAS_WIDTH := 128
const ATLAS_HEIGHT := 96

const REGIONS := {
	"desk_top": Rect2i(0, 0, 32, 16),
	"desk_side": Rect2i(0, 16, 8, 16),
	"drawer": Rect2i(8, 16, 8, 16),
	"screen_front": Rect2i(32, 0, 16, 12),
	"screen_back": Rect2i(32, 12, 16, 4),
	"chair_seat": Rect2i(48, 0, 8, 8),
	"chair_back": Rect2i(48, 8, 8, 8),
	"cabinet_front": Rect2i(56, 0, 16, 32),
	"cabinet_side": Rect2i(72, 0, 8, 32),
	"partition": Rect2i(80, 0, 16, 16),
	"wall": Rect2i(96, 0, 8, 16),
	"floor": Rect2i(104, 0, 16, 16),
	"frame": Rect2i(96, 16, 8, 16),
	"document": Rect2i(16, 24, 4, 4),
	"tray": Rect2i(24, 24, 8, 8),
	
	# Solid swatches for structural elements
	"light": Rect2i(0, 48, 2, 2),
	"side": Rect2i(4, 48, 2, 2),
	"steel": Rect2i(8, 48, 2, 2),
	"dark": Rect2i(12, 48, 2, 2),
	"paper": Rect2i(16, 48, 2, 2),
	"mustard": Rect2i(20, 48, 2, 2),
	"coffee": Rect2i(24, 48, 2, 2),
	"screen_bezel": Rect2i(28, 48, 2, 2),
}

static func texture() -> ImageTexture:
	if _texture != null:
		return _texture
		
	var image := Image.create(ATLAS_WIDTH, ATLAS_HEIGHT, false, Image.FORMAT_RGBA8)
	# Base neutral slate tone
	image.fill(Color("6f7c82"))
	
	# Solid color swatches
	var swatches := [
		["light", "c8d0cd"],        # Top highlights, rim metal
		["side", "828f92"],         # Mid-tone structural panels
		["steel", "546268"],        # Structural legs, monitor column
		["dark", "283236"],         # Dark shadows, desk mat, chassis
		["paper", "e2e4dc"],        # Blank printer paper
		["mustard", "c98f32"],      # Warm mustard/teak accent drawer
		["coffee", "543d2b"],       # Dark roast coffee liquid
		["screen_bezel", "364246"]  # Monitor frame / housing
	]
	for pair in swatches:
		image.fill_rect(REGIONS[pair[0]], Color(pair[1]))
		
	# ------------------------------------------------------------
	# 1. Desktop & Pedestal Textures (32x16, 8x16, 8x16)
	# ------------------------------------------------------------
	# Desk top surface (32x16)
	_p(image, "desk_top", 0, 0, 32, 16, "b2bcba")
	_p(image, "desk_top", 0, 0, 32, 1, "c8d1cf")
	_p(image, "desk_top", 0, 15, 32, 1, "96a2a0")
	# Integrated corner paperwork and coffee mug ring
	_p(image, "desk_top", 3, 3, 5, 7, "dedfd7")
	_p(image, "desk_top", 4, 4, 3, 5, "e8ebe3")
	_p(image, "desk_top", 27, 4, 3, 3, "9ea9a7")
	_p(image, "desk_top", 28, 5, 1, 1, "543d2b")
	
	# Desk side panel (8x16)
	_p(image, "desk_side", 0, 0, 8, 16, "8a989b")
	_p(image, "desk_side", 0, 0, 8, 1, "a2b0b2")
	_p(image, "desk_side", 0, 15, 8, 1, "6a7779")
	
	# Under-desk drawer front (8x16)
	_p(image, "drawer", 0, 0, 8, 16, "829194")
	for y in [4, 9, 14]:
		_p(image, "drawer", 0, y, 8, 1, "647274")
		_p(image, "drawer", 2, y - 2, 4, 1, "c5cbca")
		_p(image, "drawer", 2, y - 1, 4, 1, "3b474a")
		
	# ------------------------------------------------------------
	# 2. LCD / CRT Monitor Face & Rear (16x12, 16x4)
	# ------------------------------------------------------------
	# Monitor Front: Bezel + Active Screen Content
	_p(image, "screen_front", 0, 0, 16, 12, "384347")
	_p(image, "screen_front", 1, 1, 14, 10, "20282b")
	_p(image, "screen_front", 2, 2, 12, 8, "2e4448")
	_p(image, "screen_front", 3, 3, 10, 1, "628285")
	_p(image, "screen_front", 3, 5, 6, 1, "4e686b")
	_p(image, "screen_front", 3, 7, 8, 1, "4e686b")
	_p(image, "screen_front", 11, 7, 2, 2, "50a5f0")
	_p(image, "screen_front", 14, 11, 1, 1, "62d476")
	
	# Monitor Rear: Dark ventilated housing
	_p(image, "screen_back", 0, 0, 16, 4, "343f42")
	_p(image, "screen_back", 2, 1, 12, 1, "232c2e")
	_p(image, "screen_back", 2, 2, 12, 1, "232c2e")
	
	# ------------------------------------------------------------
	# 3. Ergonomic Office Chair (8x8 Seat, 8x8 Backrest)
	# ------------------------------------------------------------
	# Slate blue fabric cushion (8x8)
	_p(image, "chair_seat", 0, 0, 8, 8, "557082")
	_p(image, "chair_seat", 1, 1, 6, 5, "6e8c9f")
	_p(image, "chair_seat", 2, 2, 4, 3, "7e9bb0")
	_p(image, "chair_seat", 0, 7, 8, 1, "435b6c")
	
	# Ergonomic backrest (8x8)
	_p(image, "chair_back", 0, 0, 8, 8, "557082")
	_p(image, "chair_back", 1, 1, 6, 5, "6e8c9f")
	_p(image, "chair_back", 2, 2, 4, 2, "7e9bb0")
	_p(image, "chair_back", 2, 6, 4, 1, "435b6c")
	
	# ------------------------------------------------------------
	# 4. Two-Tone Filing Cabinet (16x32 Front, 8x32 Side)
	# ------------------------------------------------------------
	# Cabinet front (16x32)
	_p(image, "cabinet_front", 0, 0, 16, 32, "475258")
	_p(image, "cabinet_front", 0, 0, 16, 1, "647278")
	_p(image, "cabinet_front", 0, 31, 16, 1, "283034")
	# Top drawer: Mustard/Teak wood accent
	_p(image, "cabinet_front", 1, 2, 14, 8, "c98f32")
	_p(image, "cabinet_front", 1, 2, 14, 1, "e0ab4f")
	_p(image, "cabinet_front", 1, 9, 14, 1, "a37021")
	_p(image, "cabinet_front", 6, 5, 4, 1, "f0f4f4")
	_p(image, "cabinet_front", 6, 6, 4, 1, "7a5214")
	# Lower drawers: Charcoal base drawers
	for y in [12, 22]:
		_p(image, "cabinet_front", 1, y, 14, 8, "59666d")
		_p(image, "cabinet_front", 1, y, 14, 1, "717f86")
		_p(image, "cabinet_front", 1, y + 7, 14, 1, "404a4f")
		_p(image, "cabinet_front", 6, y + 3, 4, 1, "e2e8e8")
		_p(image, "cabinet_front", 6, y + 4, 4, 1, "343c40")
		
	# Cabinet side (8x32)
	_p(image, "cabinet_side", 0, 0, 8, 32, "69767c")
	_p(image, "cabinet_side", 0, 0, 8, 1, "839197")
	_p(image, "cabinet_side", 7, 0, 1, 32, "505a60")
	
	# ------------------------------------------------------------
	# 5. Cubicle Partition (16x16): Gray fabric panel + Aluminum frame + Post-it notes
	# ------------------------------------------------------------
	_p(image, "partition", 0, 0, 16, 16, "8a9a9c")
	_p(image, "partition", 0, 0, 16, 1, "c5cbca")  # Top aluminum rail highlight
	_p(image, "partition", 0, 15, 16, 1, "5b6668") # Bottom rail
	_p(image, "partition", 0, 0, 1, 16, "9eb0b2")  # Side post
	_p(image, "partition", 15, 0, 1, 16, "6f7b7d") # Side post shadow
	# Tacked memo notes
	_p(image, "partition", 3, 3, 3, 3, "e5c742")  # Yellow memo
	_p(image, "partition", 8, 4, 3, 3, "e0e4dc")  # White note
	_p(image, "partition", 12, 6, 2, 3, "50a5f0") # Blue tag
	
	# ------------------------------------------------------------
	# 6. Floor (16x16): Modern quiet cool-gray micro-weave carpet
	# Subtle 4-value micro-weave textile texture with ZERO harsh grid seams.
	# ------------------------------------------------------------
	_p(image, "floor", 0, 0, 16, 16, "6e7c84")     # Base neutral cool gray
	var floor_rect: Rect2i = REGIONS["floor"]
	var floor_colors := [
		Color("738189"), # Light weave (+2.5%)
		Color("6e7c84"), # Base
		Color("69777f"), # Shade weave (-2.5%)
		Color("707e86")  # Mid weave (+1%)
	]
	var floor_pattern: Array = [
		[1, 0, 1, 3, 1, 2, 1, 0, 1, 3, 1, 2, 0, 1, 3, 1],
		[0, 2, 0, 1, 3, 0, 2, 1, 0, 2, 0, 1, 2, 0, 1, 3],
		[1, 0, 3, 2, 1, 1, 0, 3, 1, 1, 3, 2, 1, 3, 0, 2],
		[3, 1, 1, 0, 2, 3, 1, 0, 2, 3, 1, 0, 3, 1, 2, 0],
		[1, 2, 0, 3, 1, 0, 3, 2, 1, 0, 2, 3, 1, 2, 0, 1],
		[0, 1, 3, 1, 2, 1, 1, 0, 3, 2, 1, 1, 0, 1, 3, 2],
		[2, 3, 1, 0, 1, 3, 0, 2, 1, 3, 0, 2, 3, 0, 1, 1],
		[1, 0, 2, 3, 0, 1, 2, 1, 0, 1, 3, 1, 1, 2, 3, 0],
		[3, 1, 0, 1, 3, 2, 1, 0, 3, 2, 1, 0, 2, 1, 0, 3],
		[1, 2, 1, 3, 0, 1, 3, 2, 1, 0, 2, 3, 1, 3, 2, 1],
		[0, 3, 2, 0, 2, 3, 0, 1, 2, 3, 1, 1, 0, 2, 1, 0],
		[2, 1, 0, 1, 1, 0, 2, 3, 0, 1, 3, 2, 1, 0, 3, 2],
		[1, 0, 3, 2, 3, 1, 1, 0, 3, 2, 0, 1, 3, 1, 0, 1],
		[3, 2, 1, 0, 0, 2, 3, 1, 1, 0, 2, 3, 0, 2, 1, 3],
		[0, 1, 2, 3, 1, 3, 0, 2, 0, 3, 1, 0, 2, 1, 3, 0],
		[2, 0, 1, 1, 2, 0, 1, 3, 2, 1, 0, 2, 1, 3, 0, 2]
	]
	for fy in range(16):
		var row: Array = floor_pattern[fy]
		for fx in range(16):
			var c_idx: int = row[fx]
			image.set_pixel(floor_rect.position.x + fx, floor_rect.position.y + fy, floor_colors[c_idx])
	
	_p(image, "wall", 0, 0, 8, 16, "a6b1af")
	_p(image, "wall", 0, 0, 8, 1, "c6cdc9")
	_p(image, "wall", 0, 12, 8, 3, "7c8b8a")       # Baseboard
	_p(image, "wall", 0, 15, 8, 1, "4e5857")       # Baseboard ground edge
	
	_p(image, "frame", 0, 0, 8, 16, "64747d")
	_p(image, "frame", 0, 0, 1, 16, "9baab0")
	_p(image, "frame", 6, 0, 2, 16, "455259")
	
	_p(image, "document", 0, 0, 4, 4, "d8dad0")
	_p(image, "document", 1, 1, 2, 1, "8a9696")
	
	# Double-tier letter tray (8x8): Wire basket rim + white paperwork
	_p(image, "tray", 0, 0, 8, 8, "546066")
	_p(image, "tray", 1, 1, 6, 6, "deded0")
	_p(image, "tray", 2, 3, 4, 1, "96a09e")
	_p(image, "tray", 2, 5, 4, 1, "96a09e")
	
	_texture = ImageTexture.create_from_image(image)
	return _texture

static func _p(image: Image, tile: String, x: int, y: int, w: int, h: int, hex: String) -> void:
	var region: Rect2i = REGIONS[tile]
	image.fill_rect(Rect2i(region.position + Vector2i(x, y), Vector2i(w, h)), Color(hex))

static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_material.set_shader_parameter("atlas", texture())
	return _material

static func surface(kind: String) -> ShaderMaterial:
	if not _surfaces.has(kind):
		var result := material().duplicate() as ShaderMaterial
		if kind == "floor":
			result.shader = preload("res://shaders/dream3d/office_floor_opaque.gdshader")
		var rect: Rect2i = REGIONS[kind]
		result.set_shader_parameter("world_surface", 1 if kind == "floor" else 2)
		result.set_shader_parameter("tile_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
		_surfaces[kind] = result
	return _surfaces[kind]

static func supports(kind: String) -> bool:
	return kind in ["desk", "workstation", "chair", "cabinet", "cabinet_open", "partition"]

static func make_visual(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "LowPixelOfficeVisual_" + kind
	# One material per visual: material() is shared across every owner, and the
	# dither pass would otherwise write occlusion_cutout_enabled onto it for a
	# non-furniture mesh, clobbering the furniture's hole.
	root.set_meta(&"occlusion_cutout_occluder", supports(kind))
	if kind == "chair":
		var base_mesh := MeshInstance3D.new()
		base_mesh.name = "BaseMesh"
		if not _meshes.has("chair_base"):
			_meshes["chair_base"] = _build_mesh("chair_base")
		base_mesh.mesh = _meshes["chair_base"]
		base_mesh.material_override = material().duplicate()
		root.add_child(base_mesh)

		var seat_root := Node3D.new()
		seat_root.name = "SeatRoot"
		var seat_mesh := MeshInstance3D.new()
		seat_mesh.name = "SeatMesh"
		if not _meshes.has("chair_seat_mesh"):
			_meshes["chair_seat_mesh"] = _build_mesh("chair_seat_mesh")
		seat_mesh.mesh = _meshes["chair_seat_mesh"]
		seat_mesh.material_override = material().duplicate()
		seat_root.add_child(seat_mesh)
		root.add_child(seat_root)
		return root

	var mesh := MeshInstance3D.new()
	mesh.name = "AuthoredSurfaceMesh"
	if not _meshes.has(kind):
		_meshes[kind] = _build_mesh(kind)
	mesh.mesh = _meshes[kind]
	mesh.material_override = material().duplicate()
	root.add_child(mesh)
	return root

static func room_decorations(specs: Array, origin: Vector2) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for entry in specs:
		var center := Vector3(origin.x + entry[1], .027, origin.y + entry[2])
		var turn := Basis(Vector3.UP, float(entry[3]))
		var points: Array = []
		for point in [Vector3(-.16,0,.21),Vector3(-.16,0,-.21),Vector3(.16,0,-.21),Vector3(.16,0,.21)]:
			points.append(turn * point)
		_face(st, points, Vector3.UP, center, "document")
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = material()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh

static func opening_mesh(width: float, height: float, thickness: float) -> ArrayMesh:
	var key := "frame:%s:%s:%s" % [width, height, thickness]
	if not _meshes.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for sign_x in [-1.0, 1.0]:
			_box(st, Vector3(.0625, height, thickness), Vector3(sign_x * (width * .5 + .03125), height * .5, 0), "frame", "frame", "dark")
		_meshes[key] = st.commit()
	return _meshes[key]

static func _build_mesh(kind: String) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	match kind:
		"desk", "workstation":
			# Tabletop slab: 2.2m wide, 0.07m thick, 1.1m deep at y=0.705 (surface at y=0.74)
			_box_faces(st, Vector3(2.2, 0.07, 1.1), Vector3(0, 0.705, 0), "desk_side", "desk_side", "desk_side", "desk_side", "desk_top", "desk_side")
			# Under-desk 3-drawer pedestal on worker's right (0.52m wide x 0.63m tall x 0.90m deep)
			# Front face (-Z) faces the worker/chair with 3 horizontal drawers
			_box_faces(st, Vector3(0.52, 0.63, 0.90), Vector3(0.76, 0.335, 0.05), "desk_side", "drawer", "desk_side", "desk_side", "desk_side", "dark")
			# Structural steel tubular legs on worker's left (front & rear tubular legs)
			for z in [-0.44, 0.44]:
				_box(st, Vector3(0.08, 0.65, 0.08), Vector3(-0.96, 0.325, z), "steel")
			# Bottom horizontal floor stabilizer rail connecting left legs
			_box(st, Vector3(0.08, 0.06, 0.96), Vector3(-0.96, 0.03, 0), "dark")
			
			if kind == "workstation":
				# 1. L-Shaped Desktop Partition (Back Panel + Left Side Wing)
				# Back panel along rear meeting edge z = +0.525 (spans z: 0.50..0.55), width 2.2m, height 0.44m (y: 0.74..1.18)
				# Meets flush with the opposite back-to-back desk at z = +0.55 to merge seamlessly into a single central spine!
				_box_faces(st, Vector3(2.2, 0.44, 0.05), Vector3(0, 0.96, 0.525), "partition", "partition", "steel", "steel", "light", "steel")
				# Left wing panel along left edge x = -1.075 (spans z: -0.30..0.55, meeting flush with back panel)
				_box_faces(st, Vector3(0.05, 0.44, 0.85), Vector3(-1.075, 0.96, 0.125), "steel", "steel", "partition", "partition", "light", "steel")
				
				# 2. Monitor: Stand baseplate, column, and screen chassis
				# Screen front faces worker (-Z), screen back faces partition (+Z), max height <= 1.30m
				_box(st, Vector3(0.36, 0.03, 0.22), Vector3(-0.08, 0.755, 0.26), "dark")
				_box(st, Vector3(0.08, 0.14, 0.08), Vector3(-0.08, 0.84, 0.28), "steel")
				_box_faces(st, Vector3(0.68, 0.40, 0.16), Vector3(-0.08, 1.08, 0.26), "screen_back", "screen_front", "screen_bezel", "screen_bezel", "screen_bezel", "screen_bezel")
				
				# 3. Double-tier In-Tray Document Organizer Rack on worker's right
				_box(st, Vector3(0.34, 0.04, 0.44), Vector3(0.70, 0.76, 0.18), "steel", "steel", "tray")
				_box(st, Vector3(0.34, 0.04, 0.44), Vector3(0.70, 0.84, 0.18), "steel", "steel", "document")
				_box(st, Vector3(0.02, 0.12, 0.40), Vector3(0.52, 0.80, 0.18), "steel")
				_box(st, Vector3(0.02, 0.12, 0.40), Vector3(0.88, 0.80, 0.18), "steel")
				
				# 4. Document / Paper Stacks near left partition
				_box(st, Vector3(0.26, 0.025, 0.34), Vector3(-0.70, 0.7525, -0.05), "paper", "paper", "document")
				_box(st, Vector3(0.24, 0.02, 0.30), Vector3(-0.66, 0.7725, -0.08), "paper", "paper", "paper")
				
				# 5. Desk mat / Keyboard area in front of monitor
				_box(st, Vector3(0.72, 0.015, 0.34), Vector3(-0.08, 0.7475, -0.22), "dark")
				
				# 6. Coffee mug
				_box(st, Vector3(0.09, 0.10, 0.09), Vector3(0.34, 0.79, -0.15), "light", "light", "coffee")
				
		"chair_seat_mesh":
			# Front is +Z, matching character & catalog authority
			# Seat cushion: 0.58m x 0.09m x 0.54m at y=0.435
			_box(st, Vector3(0.58, 0.09, 0.54), Vector3(0, 0.435, 0.02), "dark", "dark", "chair_seat")
			# Ergonomic backrest: 0.56m x 0.40m x 0.08m at y=0.70 (top at y=0.90)
			_box(st, Vector3(0.56, 0.40, 0.08), Vector3(0, 0.70, -0.28), "dark", "chair_back", "chair_seat")
			# Backrest support spine bracket
			_box(st, Vector3(0.08, 0.36, 0.06), Vector3(0, 0.51, -0.28), "dark")

		"chair_base":
			# Central gas lift cylinder
			_box(st, Vector3(0.08, 0.28, 0.08), Vector3(0, 0.23, 0), "steel")
			# Central star hub
			_box(st, Vector3(0.12, 0.05, 0.12), Vector3(0, 0.085, 0), "dark")
			# 4-Star X-shaped radiating spokes (rotated 45 deg)
			var diag1 := Basis(Vector3.UP, PI * 0.25)
			var diag2 := Basis(Vector3.UP, -PI * 0.25)
			_box_rotated(st, Vector3(0.44, 0.04, 0.06), Vector3(0, 0.075, 0), diag1, "dark")
			_box_rotated(st, Vector3(0.44, 0.04, 0.06), Vector3(0, 0.075, 0), diag2, "dark")
			# 4 Grounded caster wheel blocks (touching floor at y=0.0):
			for sign_x in [-1.0, 1.0]:
				for sign_z in [-1.0, 1.0]:
					_box(st, Vector3(0.07, 0.07, 0.07), Vector3(sign_x * 0.16, 0.035, sign_z * 0.16), "dark")

		"chair":
			# Front is +Z, matching character & catalog authority
			# Seat cushion: 0.58m x 0.09m x 0.54m at y=0.435
			_box(st, Vector3(0.58, 0.09, 0.54), Vector3(0, 0.435, 0.02), "dark", "dark", "chair_seat")
			# Ergonomic backrest: 0.56m x 0.40m x 0.08m at y=0.70 (top at y=0.90)
			_box(st, Vector3(0.56, 0.40, 0.08), Vector3(0, 0.70, -0.28), "dark", "chair_back", "chair_seat")
			# Backrest support spine bracket
			_box(st, Vector3(0.08, 0.36, 0.06), Vector3(0, 0.51, -0.28), "dark")
			# Central gas lift cylinder
			_box(st, Vector3(0.08, 0.28, 0.08), Vector3(0, 0.23, 0), "steel")
			# Central star hub
			_box(st, Vector3(0.12, 0.05, 0.12), Vector3(0, 0.085, 0), "dark")
			# 4-Star X-shaped radiating spokes (rotated 45 deg)
			var diag1 := Basis(Vector3.UP, PI * 0.25)
			var diag2 := Basis(Vector3.UP, -PI * 0.25)
			_box_rotated(st, Vector3(0.44, 0.04, 0.06), Vector3(0, 0.075, 0), diag1, "dark")
			_box_rotated(st, Vector3(0.44, 0.04, 0.06), Vector3(0, 0.075, 0), diag2, "dark")
			# 4 Grounded caster wheel blocks (touching floor at y=0.0):
			for sign_x in [-1.0, 1.0]:
				for sign_z in [-1.0, 1.0]:
					_box(st, Vector3(0.07, 0.07, 0.07), Vector3(sign_x * 0.16, 0.035, sign_z * 0.16), "dark")
			
		"cabinet", "cabinet_open":
			# Main cabinet body: 1.3m wide x 1.78m tall x 0.65m deep
			_box(st, Vector3(1.3, 1.78, 0.65), Vector3(0, 0.96, 0), "cabinet_side", "cabinet_front", "cabinet_side")
			# Recessed kick base
			_box(st, Vector3(1.22, 0.07, 0.58), Vector3(0, 0.035, 0), "dark")
			if kind == "cabinet_open":
				# One pulled-out drawer with open document folder
				_box(st, Vector3(1.12, 0.16, 0.34), Vector3(0, 0.55, 0.56), "cabinet_side", "drawer", "paper")
				_box(st, Vector3(0.3, 0.02, 0.22), Vector3(-0.2, 0.64, 0.56), "document")
				
		"partition":
			# Cubicle acoustic divider: 0.08m thick, 1.8m tall, 1.65m wide
			_box(st, Vector3(0.08, 1.8, 1.65), Vector3(0, 0.9, 0), "partition", "partition", "light")
			# Floor stabilizer feet along Z (keeping within 0.08m width in X)
			for z in [-0.75, 0.75]:
				_box(st, Vector3(0.08, 0.04, 0.12), Vector3(0, 0.02, z), "steel")
				
	st.index()
	return st.commit()

static func _box_faces(st: SurfaceTool, size: Vector3, center: Vector3, pos_z: String, neg_z: String, pos_x: String, neg_x: String, pos_y: String, neg_y: String) -> void:
	var h := size * 0.5
	_face(st, [Vector3(-h.x,-h.y,h.z), Vector3(-h.x,h.y,h.z), Vector3(h.x,h.y,h.z), Vector3(h.x,-h.y,h.z)], Vector3.BACK, center, pos_z)
	_face(st, [Vector3(h.x,-h.y,-h.z), Vector3(h.x,h.y,-h.z), Vector3(-h.x,h.y,-h.z), Vector3(-h.x,-h.y,-h.z)], Vector3.FORWARD, center, neg_z)
	_face(st, [Vector3(h.x,-h.y,h.z), Vector3(h.x,h.y,h.z), Vector3(h.x,h.y,-h.z), Vector3(h.x,-h.y,-h.z)], Vector3.RIGHT, center, pos_x)
	_face(st, [Vector3(-h.x,-h.y,-h.z), Vector3(-h.x,h.y,-h.z), Vector3(-h.x,h.y,h.z), Vector3(-h.x,-h.y,h.z)], Vector3.LEFT, center, neg_x)
	_face(st, [Vector3(-h.x,h.y,h.z), Vector3(-h.x,h.y,-h.z), Vector3(h.x,h.y,-h.z), Vector3(h.x,h.y,h.z)], Vector3.UP, center, pos_y)
	_face(st, [Vector3(-h.x,-h.y,-h.z), Vector3(-h.x,-h.y,h.z), Vector3(h.x,-h.y,h.z), Vector3(h.x,-h.y,-h.z)], Vector3.DOWN, center, neg_y)

static func _box(st: SurfaceTool, size: Vector3, center: Vector3, side: String, front: String = "", top: String = "") -> void:
	var h := size * 0.5
	front = side if front.is_empty() else front
	top = side if top.is_empty() else top
	_face(st, [Vector3(-h.x,-h.y,h.z), Vector3(-h.x,h.y,h.z), Vector3(h.x,h.y,h.z), Vector3(h.x,-h.y,h.z)], Vector3.BACK, center, front)
	_face(st, [Vector3(h.x,-h.y,-h.z), Vector3(h.x,h.y,-h.z), Vector3(-h.x,h.y,-h.z), Vector3(-h.x,-h.y,-h.z)], Vector3.FORWARD, center, side)
	_face(st, [Vector3(h.x,-h.y,h.z), Vector3(h.x,h.y,h.z), Vector3(h.x,h.y,-h.z), Vector3(h.x,-h.y,-h.z)], Vector3.RIGHT, center, side)
	_face(st, [Vector3(-h.x,-h.y,-h.z), Vector3(-h.x,h.y,-h.z), Vector3(-h.x,h.y,h.z), Vector3(-h.x,-h.y,h.z)], Vector3.LEFT, center, side)
	_face(st, [Vector3(-h.x,h.y,h.z), Vector3(-h.x,h.y,-h.z), Vector3(h.x,h.y,-h.z), Vector3(h.x,h.y,h.z)], Vector3.UP, center, top)
	_face(st, [Vector3(-h.x,-h.y,-h.z), Vector3(-h.x,-h.y,h.z), Vector3(h.x,-h.y,h.z), Vector3(h.x,-h.y,-h.z)], Vector3.DOWN, center, side)

static func _box_rotated(st: SurfaceTool, size: Vector3, center: Vector3, rot: Basis, tile: String) -> void:
	var h := size * 0.5
	var faces := [
		[[Vector3(-h.x,-h.y,h.z), Vector3(-h.x,h.y,h.z), Vector3(h.x,h.y,h.z), Vector3(h.x,-h.y,h.z)], Vector3.BACK],
		[[Vector3(h.x,-h.y,-h.z), Vector3(h.x,h.y,-h.z), Vector3(-h.x,h.y,-h.z), Vector3(-h.x,-h.y,-h.z)], Vector3.FORWARD],
		[[Vector3(h.x,-h.y,h.z), Vector3(h.x,h.y,h.z), Vector3(h.x,h.y,-h.z), Vector3(h.x,-h.y,-h.z)], Vector3.RIGHT],
		[[Vector3(-h.x,-h.y,-h.z), Vector3(-h.x,h.y,-h.z), Vector3(-h.x,h.y,h.z), Vector3(-h.x,-h.y,h.z)], Vector3.LEFT],
		[[Vector3(-h.x,h.y,h.z), Vector3(-h.x,h.y,-h.z), Vector3(h.x,h.y,-h.z), Vector3(h.x,h.y,h.z)], Vector3.UP],
		[[Vector3(-h.x,-h.y,-h.z), Vector3(-h.x,-h.y,h.z), Vector3(h.x,-h.y,h.z), Vector3(h.x,-h.y,-h.z)], Vector3.DOWN]
	]
	for f in faces:
		var pts: Array = []
		for p in (f[0] as Array):
			pts.append(rot * (p as Vector3))
		var norm: Vector3 = rot * (f[1] as Vector3)
		_face(st, pts, norm, center, tile)

static func _face(st: SurfaceTool, points: Array, normal: Vector3, center: Vector3, tile: String) -> void:
	var rect: Rect2i = REGIONS[tile]
	var lo := (Vector2(rect.position) + Vector2.ONE * 0.05) / Vector2(ATLAS_WIDTH, ATLAS_HEIGHT)
	var hi := (Vector2(rect.end) - Vector2.ONE * 0.05) / Vector2(ATLAS_WIDTH, ATLAS_HEIGHT)
	var uvs := [Vector2(lo.x, hi.y), lo, Vector2(hi.x, lo.y), hi]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(normal)
		st.set_uv(uvs[i])
		st.add_vertex(points[i] + center)
