class_name OfficeLowPixelRefined
extends RefCounted

## Refined Low-Pixel 3D Office Furniture Prototype (TASK-021)
## Strictly isolated standalone asset prototype - does NOT replace live game assets.
## Complies with low-pixel 3D specifications and Reference Images 4 & 5:
## - Continuous 3D geometry with true volumetric depth
## - 8x8, 16x16, 16x32 effective face UV regions with 3-5 values per material
## - Dual-tone filing cabinet (Mustard/Teak top drawer + Charcoal lower drawers + Silver pulls)
## - Workstation with LCD/CRT monitor, sticky note accent, keyboard block, document, coffee mug
## - Ergonomic office chair with 5-star swivel base
## - Cubicle partition with memo accents and top aluminum trim
## - Low-contrast calm floor and wall trims

static var _texture: ImageTexture
static var _material: ShaderMaterial
static var _surfaces: Dictionary = {}
static var _meshes: Dictionary = {}

const SHADER = preload("res://shaders/dream3d/office_low_pixel_refined.gdshader")

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
	
	# 1. Solid swatches for structural parts
	for pair in [
		["light", "cbd3d1"],
		["side", "879291"],
		["steel", "546066"],
		["dark", "283236"],
		["paper", "deded0"],
		["mustard", "c49a45"],
		["coffee", "5a4232"],
		["screen_bezel", "939e9d"],
	]:
		image.fill_rect(REGIONS[pair[0]], Color(pair[1]))
		
	# ------------------------------------------------------------
	# 2. Desk Top (32x16): Light laminate, keyboard, mouse, document, coffee mug
	# ------------------------------------------------------------
	_p(image, "desk_top", 0, 0, 32, 16, "b8c3c2")   # Base surface
	_p(image, "desk_top", 0, 0, 32, 1, "c9d1cf")    # Top edge highlight
	_p(image, "desk_top", 0, 15, 32, 1, "96a3a3")   # Bottom edge shadow
	_p(image, "desk_top", 0, 0, 1, 16, "c0c9c7")    # Left edge
	_p(image, "desk_top", 31, 0, 1, 16, "9ca7a6")   # Right edge
	
	# Paper document on left (5x7)
	_p(image, "desk_top", 3, 4, 6, 7, "e2e4dc")
	_p(image, "desk_top", 4, 6, 4, 1, "a8b2b0")
	_p(image, "desk_top", 4, 8, 4, 1, "a8b2b0")
	
	# Keyboard (11x3) & keycaps
	_p(image, "desk_top", 11, 11, 11, 3, "323e44")
	_p(image, "desk_top", 12, 11, 4, 1, "748386")
	_p(image, "desk_top", 17, 11, 4, 1, "748386")
	_p(image, "desk_top", 13, 13, 6, 1, "506066") # Space bar
	
	# Mouse pad & mouse
	_p(image, "desk_top", 23, 11, 3, 3, "424e54")
	_p(image, "desk_top", 24, 12, 1, 2, "7d8c8f")
	
	# Coffee mug (3x3 with brown liquid center)
	_p(image, "desk_top", 26, 4, 3, 3, "dadfd9")
	_p(image, "desk_top", 27, 5, 1, 1, "5c4232")
	_p(image, "desk_top", 29, 5, 1, 1, "b5bdbb") # Handle
	
	# Desk Side & Pedestal (8x16)
	_p(image, "desk_side", 0, 0, 8, 16, "7e8b8c")
	_p(image, "desk_side", 0, 0, 8, 1, "95a1a1")
	_p(image, "desk_side", 0, 15, 8, 1, "606c6e")
	
	# Under-desk drawers (8x16, 3 drawers)
	_p(image, "drawer", 0, 0, 8, 16, "95a1a1")
	for y in [4, 9, 14]:
		_p(image, "drawer", 0, y, 8, 1, "697678")    # Drawer seam
		_p(image, "drawer", 2, y - 2, 4, 1, "d0d7d6") # Silver pull
		_p(image, "drawer", 2, y - 1, 4, 1, "4b5658") # Pull drop shadow
		
	# ------------------------------------------------------------
	# 3. Screen (16x12): Bevel, dark CRT/LCD, reflection, sticky note accent
	# ------------------------------------------------------------
	_p(image, "screen_front", 0, 0, 16, 12, "96a09e")  # Bezel
	_p(image, "screen_front", 1, 1, 14, 9, "20272b")   # Display area
	_p(image, "screen_front", 2, 2, 7, 2, "38464d")    # Top-left screen reflection
	_p(image, "screen_front", 2, 4, 4, 1, "2e3c42")
	_p(image, "screen_front", 14, 11, 1, 1, "80c058")  # Green power LED
	# Post-it sticky note accent on bottom-left bezel (Reference 5 feature)
	_p(image, "screen_front", 1, 10, 2, 2, "e5c742")
	_p(image, "screen_front", 3, 10, 2, 2, "50a5f0")   # Blue post-it
	
	# Screen back
	_p(image, "screen_back", 0, 0, 16, 4, "75807e")
	_p(image, "screen_back", 4, 1, 8, 2, "4f5857")     # Center vent
	
	# ------------------------------------------------------------
	# 4. Office Chair (8x8 seat & 8x8 back): Rich slate blue
	# ------------------------------------------------------------
	# Seat
	_p(image, "chair_seat", 0, 0, 8, 8, "4f6d80")
	_p(image, "chair_seat", 1, 1, 6, 5, "688aa0") # Center cushion highlight
	_p(image, "chair_seat", 1, 6, 6, 1, "3c5566") # Front edge fold
	_p(image, "chair_seat", 0, 7, 8, 1, "2e4250") # Bottom seam
	
	# Backrest
	_p(image, "chair_back", 0, 0, 8, 8, "4f6d80")
	_p(image, "chair_back", 1, 1, 6, 5, "688aa0") # Lumbar support curve
	_p(image, "chair_back", 2, 6, 4, 1, "3c5566")
	
	# ------------------------------------------------------------
	# 5. Filing Cabinet (16x32): Dual-tone! (Reference 4 feature)
	# Top drawer: Mustard yellow / Teak wood.
	# Lower 3 drawers: Charcoal dark gray.
	# ------------------------------------------------------------
	_p(image, "cabinet_front", 0, 0, 16, 32, "5c686e") # Cabinet frame
	
	# Drawer 1 (Top): Mustard-yellow / Teak (Reference 4)
	_p(image, "cabinet_front", 1, 2, 14, 6, "c49a45")
	_p(image, "cabinet_front", 1, 2, 14, 1, "d9b25f")  # Top lip
	_p(image, "cabinet_front", 1, 7, 14, 1, "9e782e")  # Bottom lip
	_p(image, "cabinet_front", 5, 4, 6, 1, "dedecc")  # Silver handle
	_p(image, "cabinet_front", 5, 5, 6, 1, "7a5a1e")  # Drop shadow
	_p(image, "cabinet_front", 12, 3, 2, 2, "f2f2e6") # Paper label tag
	
	# Drawers 2, 3, 4: Charcoal dark gray with silver handles
	var drawer_ys := [9, 16, 23]
	for dy in drawer_ys:
		_p(image, "cabinet_front", 1, dy, 14, 6, "424f54")
		_p(image, "cabinet_front", 1, dy, 14, 1, "556369") # Top lip highlight
		_p(image, "cabinet_front", 1, dy + 5, 14, 1, "303b3f") # Bottom shadow
		_p(image, "cabinet_front", 5, dy + 2, 6, 1, "d0d8d6") # Silver handle
		_p(image, "cabinet_front", 5, dy + 3, 6, 1, "283033") # Handle shadow
		_p(image, "cabinet_front", 12, dy + 1, 2, 2, "d8deda") # Label tag
		
	# Cabinet side (8x32)
	_p(image, "cabinet_side", 0, 0, 8, 32, "69767c")
	_p(image, "cabinet_side", 0, 0, 8, 1, "839197")
	_p(image, "cabinet_side", 7, 0, 1, 32, "505a60")
	
	# ------------------------------------------------------------
	# 6. Cubicle Partition (16x16): Gray fabric panel + Aluminum frame + Post-it notes
	# ------------------------------------------------------------
	_p(image, "partition", 0, 0, 16, 16, "8a9a9c")
	_p(image, "partition", 0, 0, 16, 1, "c5cbca")  # Top aluminum rail highlight
	_p(image, "partition", 0, 15, 16, 1, "5b6668") # Bottom rail
	_p(image, "partition", 0, 0, 1, 16, "9eb0b2")  # Side post
	_p(image, "partition", 15, 0, 1, 16, "6f7b7d") # Side post shadow
	# Tacked memo notes (Reference 5 feature)
	_p(image, "partition", 3, 3, 3, 3, "e5c742")  # Yellow memo
	_p(image, "partition", 8, 4, 3, 3, "e0e4dc")  # White note
	_p(image, "partition", 12, 6, 2, 3, "50a5f0") # Blue tag
	
	# ------------------------------------------------------------
	# 7. Floor (16x16) & Wall (8x16) & Frame (8x16)
	# ------------------------------------------------------------
	# 7. Floor (16x16): Modern quiet cool-gray carpet (Reference 5 feature)
	# Subtle 4-value micro-weave textile texture with ZERO harsh grid seams.
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
		var rect: Rect2i = REGIONS[kind]
		result.set_shader_parameter("world_surface", 1 if kind == "floor" else 2)
		result.set_shader_parameter("tile_rect", Vector4(rect.position.x, rect.position.y, rect.size.x, rect.size.y))
		_surfaces[kind] = result
	return _surfaces[kind]

static func make_visual(kind: String) -> Node3D:
	var root := Node3D.new()
	root.name = "RefinedOfficeVisual_" + kind
	var mesh := MeshInstance3D.new()
	mesh.name = "MeshInstance3D"
	if not _meshes.has(kind):
		_meshes[kind] = _build_mesh(kind)
	mesh.mesh = _meshes[kind]
	mesh.material_override = material()
	root.add_child(mesh)
	return root

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
				# Screen front faces worker (-Z), screen back faces partition (+Z)
				_box(st, Vector3(0.36, 0.03, 0.22), Vector3(-0.08, 0.755, 0.26), "dark")
				_box(st, Vector3(0.08, 0.14, 0.08), Vector3(-0.08, 0.84, 0.28), "steel")
				_box_faces(st, Vector3(0.68, 0.44, 0.16), Vector3(-0.08, 1.10, 0.26), "screen_back", "screen_front", "screen_bezel", "screen_bezel", "screen_bezel", "screen_bezel")
				
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
				
		"chair":
			# Front is +Z, matching character & catalog authority
			# Seat cushion: 0.58m x 0.09m x 0.54m at y=0.435
			_box(st, Vector3(0.58, 0.09, 0.54), Vector3(0, 0.435, 0.02), "dark", "dark", "chair_seat")
			# Ergonomic backrest: 0.56m x 0.42m x 0.09m at y=0.72
			_box(st, Vector3(0.56, 0.42, 0.09), Vector3(0, 0.72, -0.285), "dark", "chair_back", "chair_seat")
			# Backrest support spine bracket
			_box(st, Vector3(0.08, 0.38, 0.08), Vector3(0, 0.58, -0.31), "dark")
			# Central gas lift cylinder
			_box(st, Vector3(0.08, 0.28, 0.08), Vector3(0, 0.23, 0), "steel")
			# Central star hub
			_box(st, Vector3(0.12, 0.05, 0.12), Vector3(0, 0.085, 0), "dark")
			# 4-Star X-shaped radiating spokes (rotated 45 deg)
			var diag1 := Basis(Vector3.UP, PI * 0.25)
			var diag2 := Basis(Vector3.UP, -PI * 0.25)
			_box_rotated(st, Vector3(0.48, 0.04, 0.06), Vector3(0, 0.075, 0), diag1, "dark")
			_box_rotated(st, Vector3(0.48, 0.04, 0.06), Vector3(0, 0.075, 0), diag2, "dark")
			# 4 Grounded caster wheel blocks (touching floor at y=0.0):
			for sign_x in [-1.0, 1.0]:
				for sign_z in [-1.0, 1.0]:
					_box(st, Vector3(0.07, 0.07, 0.07), Vector3(sign_x * 0.17, 0.035, sign_z * 0.17), "dark")
			
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
			# Floor stabilizer T-feet on both ends
			for z in [-0.75, 0.75]:
				_box(st, Vector3(0.42, 0.04, 0.06), Vector3(0, 0.02, z), "steel")
				
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
