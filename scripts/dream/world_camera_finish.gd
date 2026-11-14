extends Node
## One world-only camera finish. HUD, menus and phone render on the root canvas.
const NODE_NAME := &"WorldCameraFinish"
const META := &"world_camera_finish"
const SHADER = preload("res://shaders/dream3d/world_camera_finish.gdshader")
const BASE_STRENGTH := 0.16
const VIGNETTE_STRENGTH := 0.24
var world: Node3D
var layer: CanvasLayer
var screen_copy: BackBufferCopy
var surface: ColorRect
var material: ShaderMaterial
var enabled := true
var restored := false
var previous_meta: Variant
var had_meta := false

static func install(display: Node, force := false) -> Node:
	var target: Node = display.get("world")
	if not is_instance_valid(target): return null
	# Reception and the separate sea/portrait screens retain their own look.
	if not force and not target.has_method("get_current_floor_token"): return null
	var existing := target.get_node_or_null(NodePath(NODE_NAME))
	if existing != null: return existing
	var component: Node = load("res://scripts/dream/world_camera_finish.gd").new()
	component.name = NODE_NAME
	target.add_child(component)
	component.configure(target)
	return component

func configure(owner_world: Node3D) -> void:
	world = owner_world
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 900
	had_meta = world.has_meta(META)
	previous_meta = world.get_meta(META) if had_meta else null
	world.set_meta(META, weakref(self))
	layer = CanvasLayer.new()
	layer.name = "WorldCameraFinishLayer"
	layer.layer = 20
	layer.set_meta(&"world_post_effect", true)
	add_child(layer)
	screen_copy = BackBufferCopy.new()
	screen_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	layer.add_child(screen_copy)
	surface = ColorRect.new()
	surface.name = "CameraFinish"
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	material = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("base_strength", BASE_STRENGTH)
	material.set_shader_parameter("vignette_strength", VIGNETTE_STRENGTH)
	surface.material = material
	refresh_damage_owner()
	sync()

func damage_owner() -> Node:
	if not is_instance_valid(world): return null
	var player: Node = world.get("player")
	if not is_instance_valid(player): return null
	if not player.has_meta(&"stylized_player_hurt"): return null
	var reference: Variant = player.get_meta(&"stylized_player_hurt")
	if not reference is WeakRef: return null
	var owner: Node = reference.get_ref()
	if not is_instance_valid(owner) or not world.is_ancestor_of(owner): return null
	return owner

func refresh_damage_owner() -> void:
	var owner := damage_owner()
	if owner != null and owner.has_method("_update_pose"): owner._update_pose()

func _process(_delta: float) -> void:
	sync()

func sync() -> void:
	if restored or not is_instance_valid(surface): return
	surface.visible = enabled
	screen_copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if enabled else BackBufferCopy.COPY_MODE_DISABLED
	if not enabled: return
	var strength := 0.0
	var owner := damage_owner()
	if owner != null and float(owner.age) < float(owner.SHOCK_SECONDS):
		strength = float(owner.shock.get_shader_parameter("strength"))
		for key in [&"phase", &"hit_center", &"distort_strength"]:
			material.set_shader_parameter(key, owner.shock.get_shader_parameter(key))
	material.set_shader_parameter("shock_strength", strength)

func set_enabled(value: bool) -> void:
	enabled = value
	refresh_damage_owner()
	sync()

func restore() -> void:
	if restored: return
	restored = true
	if is_instance_valid(world):
		var reference: Variant = world.get_meta(META) if world.has_meta(META) else null
		if reference is WeakRef and reference.get_ref() == self:
			if had_meta: world.set_meta(META, previous_meta)
			else: world.remove_meta(META)
		refresh_damage_owner()
	if is_instance_valid(surface): surface.hide()
	if is_instance_valid(screen_copy): screen_copy.copy_mode = BackBufferCopy.COPY_MODE_DISABLED

func _exit_tree() -> void:
	restore()
