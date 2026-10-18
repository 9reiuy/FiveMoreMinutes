extends RefCounted

## Authored office-specific pixel art. One shared atlas, one batched attachment
## mesh per furniture/room. Decorative geometry never participates in physics.
const SHADER = preload("res://shaders/dream3d/office_detail_atlas.gdshader")
static var atlas_material: ShaderMaterial
static var attachment_meshes: Dictionary = {}
const INK = Color("252d31")
const PAPER = Color("d4d0b9")

static func _rect(image: Image, slot: int, box: Rect2i, color: Color) -> void:
	var offset := Vector2i(slot % 4, slot / 4) * 32
	image.fill_rect(Rect2i(offset + box.position, box.size), color)

static func material() -> ShaderMaterial:
	if atlas_material != null:
		return atlas_material
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	# 0: printed memo, folded corner, header and ruled lines.
	_rect(image, 0, Rect2i(7, 5, 18, 24), INK)
	_rect(image, 0, Rect2i(8, 6, 16, 22), PAPER)
	_rect(image, 0, Rect2i(10, 9, 9, 2), Color("546870"))
	for y in [14, 17, 20, 23]: _rect(image, 0, Rect2i(10, y, 11 if y != 23 else 6, 1), Color("93968b"))
	_rect(image, 0, Rect2i(21, 6, 3, 3), Color("acae9f"))
	# 1: keyboard. Deliberate two-pixel keys and a space bar.
	_rect(image, 1, Rect2i(3, 10, 26, 12), INK)
	_rect(image, 1, Rect2i(4, 11, 24, 10), Color("9eaaa7"))
	for row in 3:
		for col in 7: _rect(image, 1, Rect2i(5 + col * 3, 12 + row * 2, 2, 1), Color("49565a"))
	_rect(image, 1, Rect2i(10, 19, 12, 1), Color("49565a"))
	# 2: mug top, coffee and right-hand handle.
	_rect(image, 2, Rect2i(12, 11, 9, 10), INK)
	_rect(image, 2, Rect2i(13, 10, 7, 12), PAPER)
	_rect(image, 2, Rect2i(11, 12, 11, 8), PAPER)
	_rect(image, 2, Rect2i(21, 14, 3, 4), PAPER)
	_rect(image, 2, Rect2i(13, 12, 7, 7), Color("665044"))
	_rect(image, 2, Rect2i(14, 12, 5, 2), Color("917864"))
	# 3: green file folder with label and exposed paper.
	_rect(image, 3, Rect2i(5, 7, 22, 20), INK)
	_rect(image, 3, Rect2i(7, 5, 8, 3), Color("6c8277"))
	_rect(image, 3, Rect2i(6, 8, 20, 18), Color("647b6d"))
	_rect(image, 3, Rect2i(7, 8, 18, 2), PAPER)
	_rect(image, 3, Rect2i(10, 14, 10, 5), PAPER)
	_rect(image, 3, Rect2i(12, 16, 6, 1), INK)
	# 4: CRT screen contents, window bars and a small spreadsheet.
	_rect(image, 4, Rect2i(6, 7, 20, 16), INK)
	_rect(image, 4, Rect2i(7, 8, 18, 14), Color("516d70"))
	_rect(image, 4, Rect2i(8, 9, 16, 2), Color("a1b1a6"))
	for y in [13, 16, 19]:
		_rect(image, 4, Rect2i(9, y, 6, 1), Color("93a59c"))
		_rect(image, 4, Rect2i(18, y, 4, 1), Color("bbc4ae"))
	# 5: water/coffee mark, clustered near its actual source, not noise.
	_rect(image, 5, Rect2i(7, 13, 17, 6), Color("5d7773"))
	_rect(image, 5, Rect2i(10, 10, 10, 12), Color("5d7773"))
	_rect(image, 5, Rect2i(10, 12, 11, 2), Color("819692"))
	_rect(image, 5, Rect2i(25, 20, 2, 2), Color("5d7773"))
	# 6: cabinet drawer front, inset border, index label and pull.
	_rect(image, 6, Rect2i(2, 9, 28, 15), INK)
	_rect(image, 6, Rect2i(3, 10, 26, 13), Color("89928b"))
	_rect(image, 6, Rect2i(4, 10, 24, 1), Color("b4b9a8"))
	_rect(image, 6, Rect2i(6, 13, 6, 3), PAPER)
	_rect(image, 6, Rect2i(18, 17, 7, 2), INK)
	# 7: whiteboard meeting diagram, reused only on the board, never floor.
	_rect(image, 7, Rect2i(2, 4, 28, 23), Color("c7cfbf"))
	_rect(image, 7, Rect2i(5, 7, 14, 2), Color("537578"))
	for x in [6, 14, 22]:
		_rect(image, 7, Rect2i(x, 14, 5, 5), Color("668184"))
	_rect(image, 7, Rect2i(8, 22, 16, 1), Color("97736a"))
	# 8: ceramic drain and separate blue soap bottle, only on washbasins.
	_rect(image, 8, Rect2i(6, 5, 20, 23), Color("a4b6b2"))
	_rect(image, 8, Rect2i(8, 7, 16, 18), Color("d2d7cb"))
	_rect(image, 8, Rect2i(13, 13, 6, 6), Color("6c8182"))
	_rect(image, 8, Rect2i(14, 14, 4, 4), INK)
	_rect(image, 8, Rect2i(20, 7, 4, 5), Color("577c80"))
	_rect(image, 8, Rect2i(21, 5, 2, 2), Color("c5d1c7"))
	# 9: indexed file spines for archive shelves.
	for x in [4, 9, 14, 19, 24]:
		_rect(image, 9, Rect2i(x, 5, 4, 22), INK)
		_rect(image, 9, Rect2i(x + 1, 6, 2, 18), Color("a2afa0") if x % 2 == 0 else Color("b9ae91"))
		_rect(image, 9, Rect2i(x + 1, 14, 2, 4), PAPER)
	# 10: low-energy server control panel; emissive lights are not added.
	_rect(image, 10, Rect2i(3, 4, 26, 24), INK)
	_rect(image, 10, Rect2i(4, 5, 24, 1), Color("a3b3ae"))
	_rect(image, 10, Rect2i(4, 26, 24, 1), Color("a3b3ae"))
	for y in [7, 12, 17, 22]:
		_rect(image, 10, Rect2i(5, y, 20, 3), Color("687d7d"))
		_rect(image, 10, Rect2i(6, y + 1, 9, 1), Color("a9b9b1"))
		_rect(image, 10, Rect2i(21, y + 1, 2, 1), Color("bdd3bc"))
	# 11: receptionist's check-in terminal and paper form.
	_rect(image, 11, Rect2i(4, 7, 14, 18), INK)
	_rect(image, 11, Rect2i(5, 8, 12, 15), Color("577b78"))
	_rect(image, 11, Rect2i(7, 11, 8, 2), PAPER)
	_rect(image, 11, Rect2i(20, 7, 9, 18), PAPER)
	for y in [12, 16, 20]: _rect(image, 11, Rect2i(21, y, 6, 1), Color("778581"))
	# 12: a left-open magazine, readable at table height.
	_rect(image, 12, Rect2i(4, 6, 24, 21), INK)
	_rect(image, 12, Rect2i(5, 7, 11, 19), PAPER)
	_rect(image, 12, Rect2i(17, 7, 10, 19), Color("a1aea2"))
	_rect(image, 12, Rect2i(8, 10, 6, 5), Color("687e81"))
	for y in [18, 21, 24]: _rect(image, 12, Rect2i(7, y, 17, 1), Color("677775"))
	# 13-14: quiet floor-level wayfinding and lift threshold, not exit arrows.
	_rect(image, 13, Rect2i(2, 11, 28, 2), Color("a6a691"))
	_rect(image, 13, Rect2i(2, 18, 28, 2), Color("a6a691"))
	_rect(image, 13, Rect2i(2, 11, 2, 9), Color("a6a691"))
	_rect(image, 13, Rect2i(28, 11, 2, 9), Color("a6a691"))
	_rect(image, 14, Rect2i(3, 5, 26, 22), INK)
	_rect(image, 14, Rect2i(5, 7, 22, 18), Color("697a77"))
	_rect(image, 14, Rect2i(9, 10, 2, 12), PAPER)
	_rect(image, 14, Rect2i(10, 10, 10, 2), PAPER)
	_rect(image, 14, Rect2i(18, 10, 2, 12), PAPER)
	# 15: maintenance cable bundle laid beside server racks.
	for x in [7, 11, 15, 19, 23]:
		_rect(image, 15, Rect2i(x, 3, 2, 26), INK)
		_rect(image, 15, Rect2i(x, 4, 1, 24), Color("5b7472"))
	atlas_material = ShaderMaterial.new()
	atlas_material.shader = SHADER
	atlas_material.set_shader_parameter("detail_atlas", ImageTexture.create_from_image(image))
	return atlas_material

static func _quad(st: SurfaceTool, slot: int, center: Vector3, upright := false, angle := 0.0, size := Vector2.ONE) -> void:
	var offset := Vector2(slot % 4, slot / 4)
	var corners := [Vector2(-.5, -.5), Vector2(.5, -.5), Vector2(.5, .5), Vector2(-.5, .5)]
	for index in [0, 2, 1, 0, 3, 2]:
		var p: Vector2 = corners[index].rotated(angle)
		st.set_normal(Vector3.BACK if upright else Vector3.UP)
		st.set_uv((offset + corners[index] + Vector2(.5, .5)) / Vector2(4, 4))
		st.add_vertex(center + (Vector3(p.x * size.x, -p.y * size.y, 0) if upright else Vector3(p.x * size.x, 0, p.y * size.y)))

static func furniture(kind: String) -> MeshInstance3D:
	if not attachment_meshes.has(kind):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		match kind:
			"workstation":
				_quad(st, 1, Vector3(0, .749, .20))
				_quad(st, 0, Vector3(-.60, .751, -.02), false, -.16)
				_quad(st, 2, Vector3(.62, .753, .08))
				_quad(st, 4, Vector3(0, 1.02, -.10), true, 0.0, Vector2(.64, .56))
				_quad(st, 6, Vector3(.48, .51, .455), true, 0.0, Vector2(.8, .18))
			"table":
				for x in [-1.5, -.6, .7, 1.5]:
					_quad(st, 3 if x == .7 else 0, Vector3(x, .771, -.1), false, x * .1)
				for x in [-1.1, 1.1]: _quad(st, 2, Vector3(x, .775, .28))
			"dining_table":
				_quad(st, 2, Vector3(-.35, .775, 0))
				_quad(st, 3, Vector3(.30, .777, -.18), false, .18)
			"counter", "sink": _quad(st, 2, Vector3(.35, .89, .08))
			"coffee_table":
				_quad(st, 12, Vector3(-.24, .431, -.08), false, .16, Vector2(.62, .54))
				_quad(st, 2, Vector3(.38, .433, .12), false, 0.0, Vector2(.42, .42))
			"cabinet":
				for y in [.35, .9, 1.45]: _quad(st, 6, Vector3(0, y, .335), true, 0.0, Vector2(1.0, .20))
			"cabinet_open":
				for y in [.35, 1.45]: _quad(st, 6, Vector3(0, y, .335), true, 0.0, Vector2(1.0, .20))
				_quad(st, 6, Vector3(0, .55, .704), true, 0.0, Vector2(1.0, .16))
			"whiteboard":
				_quad(st, 7, Vector3(-.42, 1.05, .109), true)
				_quad(st, 7, Vector3(.42, 1.05, .109), true)
			"washbasin": _quad(st, 8, Vector3(0, .865, 0))
			"shelf":
				for y in [.42, .96, 1.49]:
					_quad(st, 9, Vector3(-.37, y, .36), true, 0.0, Vector2(.65, .34))
					_quad(st, 9, Vector3(.37, y, .36), true, 0.0, Vector2(.65, .34))
			"server":
				_quad(st, 10, Vector3(0, 1.08, .48), true, 0.0, Vector2(.78, 1.38))
			"reception":
				_quad(st, 11, Vector3(-.64, 1.055, -.08), false, 0.0, Vector2(.9, .72))
				_quad(st, 3, Vector3(.71, 1.056, .03), false, -.14, Vector2(.55, .55))
			_: return null
		attachment_meshes[kind] = st.commit()
	var visual := MeshInstance3D.new()
	visual.name = "OfficeDetailAttachments"
	visual.mesh = attachment_meshes[kind]
	visual.material_override = material()
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return visual

static func room_decorations(specs: Array, origin: Vector2) -> MeshInstance3D:
	if specs.is_empty(): return null
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for entry in specs:
		var size := Vector2(float(entry[4]), float(entry[5])) if entry.size() > 5 else Vector2.ONE
		var height := float(entry[6]) if entry.size() > 6 else .026
		_quad(st, int(entry[0]), Vector3(origin.x + entry[1], height, origin.y + entry[2]), false, float(entry[3]), size)
	var visual := MeshInstance3D.new()
	visual.name = "AuthoredOfficeDecorations"
	visual.mesh = st.commit()
	visual.material_override = material()
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return visual
