class_name ReceptionDesk3D
extends Node3D

## Low-poly 3D Reception Desk Prop (Option B: Modern Minimalist Pure White)
## Complies with the 10 Golden Art Rules from AGENTS.md:
## 1. Authentic low-poly 3D geometry using BoxMeshes.
## 2. Materials created via OfficePixelMaterials.make(color, kind, object_space, glow).
## 3. Nearest pixel filtering and 32px/m Texel Density.
## 4. Complete Front, Side, Back, and Top surfaces (Top Cap).
## 5. Real dynamic 3D lighting with cast_shadow = SHADOW_CASTING_SETTING_ON.
## 6. Harmonious local palette (pure white modern laminate, black recessed plinth, aluminum stand, phosphor screen).
## 7. Strong volumetric light/shadow relief.
## 8. Integrated 2D gameplay collision (layer 4 WORLD_WALL_LAYER).

const CELL_PIXELS: float = 32.0
const DESK_WIDTH: float = 3.4
const DESK_DEPTH: float = 1.1
const DESK_HEIGHT: float = 1.05
const INNER_DESK_HEIGHT: float = 0.75
const TOP_CAP_WIDTH: float = 3.4
const TOP_CAP_DEPTH: float = 0.40
const TOP_CAP_HEIGHT: float = 0.05
const PLINTH_HEIGHT: float = 0.10
const PLINTH_RECESS: float = 0.03
const WORLD_WALL_LAYER: int = 4

var collision_body_2d: StaticBody2D = null

# Materials
var mat_white_body: ShaderMaterial
var mat_base_plinth: ShaderMaterial
var mat_imac_white: ShaderMaterial
var mat_stand_metal: ShaderMaterial
var mat_screen_display: ShaderMaterial
var mat_dark_accents: ShaderMaterial
var mat_paper_white: ShaderMaterial

# Backward compatibility aliases
var mat_front_modesty: ShaderMaterial
var mat_top_cap: ShaderMaterial
var mat_inner_shelf: ShaderMaterial
var mat_end_caps: ShaderMaterial
var mat_base_trim: ShaderMaterial


func _init() -> void:
	name = "ReceptionDesk3D"
	_init_materials()
	_build_3d_geometry()


func _exit_tree() -> void:
	if has_meta(&"display_reparenting"):
		return
	if is_instance_valid(collision_body_2d) and not collision_body_2d.is_queued_for_deletion():
		collision_body_2d.queue_free()
		collision_body_2d = null


func _init_materials() -> void:
	# Pure white modern laminate/paint body (User Option B)
	mat_white_body = OfficePixelMaterials.make(Color(0.93, 0.94, 0.95), "paint")
	# Recessed black base trim / kickplate (plinth)
	mat_base_plinth = OfficePixelMaterials.make(Color(0.12, 0.12, 0.14), "paint")
	
	# Modern All-in-One iMac Display
	mat_imac_white = OfficePixelMaterials.make(Color(0.92, 0.92, 0.92), "paint")
	mat_stand_metal = OfficePixelMaterials.make(Color(0.80, 0.82, 0.84), "metal")
	mat_screen_display = OfficePixelMaterials.make(Color(0.16, 0.20, 0.24), "metal", false, true) # Glow enabled
	
	# Accessories & accents
	mat_dark_accents = OfficePixelMaterials.make(Color(0.18, 0.18, 0.20), "paint")
	mat_paper_white = OfficePixelMaterials.make(Color(0.96, 0.96, 0.94), "paint")
	
	# Backward compatibility aliases
	mat_front_modesty = mat_white_body
	mat_top_cap = mat_white_body
	mat_inner_shelf = mat_white_body
	mat_end_caps = mat_white_body
	mat_base_trim = mat_base_plinth


func _build_3d_geometry() -> void:
	if has_node("Structure"):
		return
	
	var structure_root := Node3D.new()
	structure_root.name = "Structure"
	add_child(structure_root)
	
	var desktop_details_root := Node3D.new()
	desktop_details_root.name = "DesktopDetails"
	add_child(desktop_details_root)
	
	# -------------------------------------------------------------------------
	# 1. Recessed Black Base Plinth / Kickplate
	# -------------------------------------------------------------------------
	# Height ~0.10m, recessed by 0.03m all around
	# Width: 3.4 - 0.06 = 3.34m, Depth: 1.1 - 0.06 = 1.04m, Y: 0.0 to 0.10
	var plinth_size := Vector3(DESK_WIDTH - 2.0 * PLINTH_RECESS, PLINTH_HEIGHT, DESK_DEPTH - 2.0 * PLINTH_RECESS)
	_add_box(structure_root, "BasePlinth", plinth_size, Vector3(0.0, PLINTH_HEIGHT * 0.5, 0.0), mat_base_plinth)
	
	# -------------------------------------------------------------------------
	# 2. Unified Counter Top (Top Cap Counter)
	# -------------------------------------------------------------------------
	# Continuous sleek top surface at Y = 1.05m, depth ~0.40m at front
	# Spans local X: -1.7 to +1.7 (3.4m), Z: +0.15 to +0.55 (center +0.35m)
	_add_box(
		structure_root,
		"TopCapCounter",
		Vector3(TOP_CAP_WIDTH, TOP_CAP_HEIGHT, TOP_CAP_DEPTH),
		Vector3(0.0, DESK_HEIGHT - TOP_CAP_HEIGHT * 0.5, 0.35),
		mat_white_body
	)
	
	# -------------------------------------------------------------------------
	# 3. Front Modesty Panel (facing South/+Z)
	# -------------------------------------------------------------------------
	# Pure white monolithic front slab from plinth (Y=0.10) to top cap (Y=1.00)
	# Width: 3.4m, Height: 0.90m, Depth: 0.06m at Z = 0.52 (outer face flush at Z = +0.55)
	var front_height: float = DESK_HEIGHT - TOP_CAP_HEIGHT - PLINTH_HEIGHT
	_add_box(
		structure_root,
		"FrontModestyPanel",
		Vector3(DESK_WIDTH, front_height, 0.06),
		Vector3(0.0, PLINTH_HEIGHT + front_height * 0.5, 0.52),
		mat_white_body
	)
	
	# -------------------------------------------------------------------------
	# 4. End Caps (East & West sides closing the desk cleanly in matched white)
	# -------------------------------------------------------------------------
	# Stepped architectural side profile:
	# - Full depth base panel up to inner desk height (Y=0.75m)
	# - Upper side return panel under top cap (Y: 0.75m to 1.00m)
	var cap_thickness: float = 0.05
	var cap_half_x: float = DESK_WIDTH * 0.5 - cap_thickness * 0.5
	var base_side_h: float = INNER_DESK_HEIGHT - PLINTH_HEIGHT # 0.65m
	var upper_side_h: float = (DESK_HEIGHT - TOP_CAP_HEIGHT) - INNER_DESK_HEIGHT # 0.25m
	
	# West End Cap
	_add_box(
		structure_root,
		"WestEndCap",
		Vector3(cap_thickness, base_side_h, DESK_DEPTH),
		Vector3(-cap_half_x, PLINTH_HEIGHT + base_side_h * 0.5, 0.0),
		mat_white_body
	)
	_add_box(
		structure_root,
		"WestUpperCap",
		Vector3(cap_thickness, upper_side_h, TOP_CAP_DEPTH),
		Vector3(-cap_half_x, INNER_DESK_HEIGHT + upper_side_h * 0.5, 0.35),
		mat_white_body
	)
	
	# East End Cap
	_add_box(
		structure_root,
		"EastEndCap",
		Vector3(cap_thickness, base_side_h, DESK_DEPTH),
		Vector3(cap_half_x, PLINTH_HEIGHT + base_side_h * 0.5, 0.0),
		mat_white_body
	)
	_add_box(
		structure_root,
		"EastUpperCap",
		Vector3(cap_thickness, upper_side_h, TOP_CAP_DEPTH),
		Vector3(cap_half_x, INNER_DESK_HEIGHT + upper_side_h * 0.5, 0.35),
		mat_white_body
	)
	
	# -------------------------------------------------------------------------
	# 5. Inner Work Surface (Y = 0.75m)
	# -------------------------------------------------------------------------
	# Desk shelf where keyboard and computer rest.
	# Width: 3.30m (between end caps), Depth: 0.70m (Z: -0.55 to +0.15, center -0.20m)
	var inner_width: float = DESK_WIDTH - 2.0 * cap_thickness
	var inner_thickness: float = 0.04
	_add_box(
		structure_root,
		"InnerWorkSurface",
		Vector3(inner_width, inner_thickness, 0.70),
		Vector3(0.0, INNER_DESK_HEIGHT - inner_thickness * 0.5, -0.20),
		mat_white_body
	)
	
	# Intermediate divider / riser between inner shelf (0.75m) and upper counter (1.00m)
	_add_box(
		structure_root,
		"IntermediateRiser",
		Vector3(inner_width, upper_side_h, 0.05),
		Vector3(0.0, INNER_DESK_HEIGHT + upper_side_h * 0.5, 0.15),
		mat_white_body
	)
	
	# Kneewell backboard under work surface (modesty wall facing receptionist)
	var kneewell_height: float = INNER_DESK_HEIGHT - inner_thickness - PLINTH_HEIGHT
	_add_box(
		structure_root,
		"KneewellBackboard",
		Vector3(inner_width, kneewell_height, 0.05),
		Vector3(0.0, PLINTH_HEIGHT + kneewell_height * 0.5, 0.15),
		mat_white_body
	)
	
	# -------------------------------------------------------------------------
	# 6. Under-Desk Pedestal Storage (West side)
	# -------------------------------------------------------------------------
	var ped_w: float = 0.45
	var ped_x: float = -DESK_WIDTH * 0.5 + cap_thickness + ped_w * 0.5
	_add_box(
		structure_root,
		"WestPedestal",
		Vector3(ped_w, kneewell_height, 0.60),
		Vector3(ped_x, PLINTH_HEIGHT + kneewell_height * 0.5, -0.20),
		mat_white_body
	)
	for d in range(3):
		var dy: float = PLINTH_HEIGHT + 0.10 + float(d) * 0.18
		_add_box(structure_root, "WestDrawer_%d" % d, Vector3(ped_w - 0.04, 0.15, 0.015), Vector3(ped_x, dy, -0.505), mat_white_body)
		_add_box(structure_root, "WestHandle_%d" % d, Vector3(0.12, 0.015, 0.015), Vector3(ped_x, dy, -0.518), mat_dark_accents)
	
	# -------------------------------------------------------------------------
	# 7. Desktop Details: Modern All-In-One Computer & Visitor Sign-In
	# -------------------------------------------------------------------------
	_build_modern_all_in_one(desktop_details_root)
	_build_visitor_clipboard(desktop_details_root)


func _build_modern_all_in_one(parent: Node3D) -> void:
	var comp_root := Node3D.new()
	comp_root.name = "AllInOneComputer"
	comp_root.position = Vector3(-0.35, INNER_DESK_HEIGHT, -0.05)
	# Angled 15-degrees for dynamic 3D depth, screen faces North toward receptionist, back faces South toward visitor
	comp_root.rotation.y = deg_to_rad(15.0)
	parent.add_child(comp_root)
	
	# Sleek aluminum L-shaped foot/stand
	_add_box(comp_root, "StandFoot", Vector3(0.18, 0.006, 0.18), Vector3(0.0, 0.003, -0.01), mat_stand_metal)
	_add_box(comp_root, "StandStem", Vector3(0.07, 0.16, 0.018), Vector3(0.0, 0.08, -0.045), mat_stand_metal, Vector3(deg_to_rad(-8.0), 0.0, 0.0))
	_add_box(comp_root, "StandHinge", Vector3(0.05, 0.03, 0.025), Vector3(0.0, 0.16, -0.055), mat_stand_metal)
	
	# Ultra-thin rectangular screen: width ~0.55m, height ~0.36m, depth ~0.025m
	var screen_center_y: float = 0.28
	_add_box(comp_root, "ScreenHousing", Vector3(0.55, 0.36, 0.025), Vector3(0.0, screen_center_y, 0.0), mat_imac_white)
	
	# Stand Logo on back of housing (facing room/visitor side)
	_add_box(comp_root, "StandLogo", Vector3(0.05, 0.05, 0.002), Vector3(0.0, screen_center_y, 0.0135), mat_stand_metal)
	
	# Modern iMac lower chin bar (white, facing receptionist)
	_add_box(comp_root, "ScreenChin", Vector3(0.55, 0.06, 0.002), Vector3(0.0, screen_center_y - 0.15, -0.0135), mat_imac_white)
	
	# Dark front display with soft phosphor glow (facing receptionist)
	_add_box(comp_root, "PhosphorScreen", Vector3(0.51, 0.28, 0.003), Vector3(0.0, screen_center_y + 0.025, -0.0135), mat_screen_display)
	
	# Sleek thin white chiclet keyboard in front (facing receptionist)
	_add_box(comp_root, "KeyboardBody", Vector3(0.32, 0.01, 0.12), Vector3(0.0, 0.005, -0.22), mat_imac_white)
	_add_box(comp_root, "KeyboardKeys", Vector3(0.30, 0.005, 0.10), Vector3(0.0, 0.011, -0.22), mat_dark_accents)
	
	# Mouse pad & sleek white mouse (to the right of keyboard from receptionist perspective)
	_add_box(comp_root, "MousePad", Vector3(0.18, 0.003, 0.20), Vector3(-0.26, 0.0015, -0.22), mat_dark_accents)
	_add_box(comp_root, "MouseBody", Vector3(0.06, 0.015, 0.10), Vector3(-0.26, 0.010, -0.22), mat_imac_white)


func _build_visitor_clipboard(parent: Node3D) -> void:
	var clip_root := Node3D.new()
	clip_root.name = "VisitorClipboard"
	clip_root.position = Vector3(0.85, DESK_HEIGHT, 0.35)
	clip_root.rotation.y = deg_to_rad(-10.0)
	parent.add_child(clip_root)
	
	# Clipboard board
	_add_box(clip_root, "ClipboardBoard", Vector3(0.24, 0.012, 0.32), Vector3(0.0, 0.006, 0.0), mat_dark_accents)
	# Paper form
	_add_box(clip_root, "ClipboardPaper", Vector3(0.21, 0.004, 0.28), Vector3(0.0, 0.014, 0.0), mat_paper_white)
	# Sleek metal clip
	_add_box(clip_root, "ClipboardClip", Vector3(0.08, 0.012, 0.03), Vector3(0.0, 0.018, -0.13), mat_stand_metal)
	
	# Modern minimalist pen stand
	_add_box(clip_root, "PenStand", Vector3(0.045, 0.035, 0.045), Vector3(0.20, 0.0175, -0.02), mat_stand_metal)
	_add_box(clip_root, "PenStylus", Vector3(0.01, 0.12, 0.01), Vector3(0.20, 0.07, -0.02), mat_dark_accents, Vector3(deg_to_rad(15.0), 0.0, deg_to_rad(-10.0)))


func _add_box(parent: Node, node_name: String, size: Vector3, local_pos: Vector3, material: Material, local_rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.position = local_pos
	instance.rotation = local_rot
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	return instance


## Physics / 2D Gameplay Collision setup
## Creates StaticBody2D named "ReceptionDeskCollider2D", collision_layer = 4 (WORLD_WALL_LAYER), collision_mask = 0.
## Shape: RectangleShape2D with size Vector2(3.4 * 32.0, 1.1 * 32.0).
## Adds to p_collision_parent at desk_pos_2d.
func setup_gameplay_2d(p_collision_parent: Node, desk_pos_2d: Vector2) -> StaticBody2D:
	if collision_body_2d != null and is_instance_valid(collision_body_2d):
		collision_body_2d.queue_free()
		collision_body_2d = null

	if p_collision_parent == null:
		return null

	collision_body_2d = StaticBody2D.new()
	collision_body_2d.name = "ReceptionDeskCollider2D"
	collision_body_2d.position = desk_pos_2d
	collision_body_2d.collision_layer = WORLD_WALL_LAYER
	collision_body_2d.collision_mask = 0

	var shape_owner := CollisionShape2D.new()
	shape_owner.name = "CollisionShape2D"
	var box := RectangleShape2D.new()
	box.size = Vector2(DESK_WIDTH * CELL_PIXELS, DESK_DEPTH * CELL_PIXELS)
	shape_owner.shape = box
	collision_body_2d.add_child(shape_owner)

	p_collision_parent.add_child(collision_body_2d)
	return collision_body_2d


func get_desk_size_3d() -> Vector3:
	return Vector3(DESK_WIDTH, DESK_HEIGHT, DESK_DEPTH)


func get_desk_size_2d() -> Vector2:
	return Vector2(DESK_WIDTH * CELL_PIXELS, DESK_DEPTH * CELL_PIXELS)
