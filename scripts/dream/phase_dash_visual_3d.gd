extends Node3D
## One reusable strip + six passive silhouettes. No extra capture Viewports.
const GHOST_COUNT := 6
const AFTERIMAGE := preload("res://shaders/dream3d/phase_dash_afterimage.gdshader")
var mesh := MeshInstance3D.new()
var material := ShaderMaterial.new()
var ghosts: Array[Sprite3D] = []
var ghost_materials: Array[ShaderMaterial] = []
var emitted := 0
var origin := Vector2.ZERO
var endpoint := Vector2.ZERO
var owner_world: Node3D
func _init() -> void:
	material.shader = preload("res://shaders/dream3d/phase_dash_pixel_trail.gdshader")
	material.set_meta(&"runtime_uniform_owner",true)
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	for i in GHOST_COUNT:
		var ghost := Sprite3D.new()
		ghost.name = "PassiveGhost_%d" % i
		ghost.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ink := ShaderMaterial.new()
		ink.shader = AFTERIMAGE
		ink.set_meta(&"runtime_uniform_owner",true)
		ghost.material_override = ink
		ghost_materials.append(ink)
		ghosts.append(ghost)
		add_child(ghost)
	hide()
func begin(world: Node3D, player: Node2D, start: Vector2, end: Vector2) -> void:
	owner_world = world
	origin = start
	endpoint = end
	emitted = 0
	for ghost in ghosts:
		ghost.hide()
		ghost.texture = null
	var plane := PlaneMesh.new()
	plane.size = Vector2(start.distance_to(end)+56.0,56.0)/32.0
	mesh.mesh = plane
	var center := start.lerp(end,.5)
	global_transform = world.global_transform*Transform3D(Basis(Vector3.UP,-(end-start).angle()),Vector3(center.x/32.0,.12,center.y/32.0))
	material.set_shader_parameter("half_length",start.distance_to(end)*.5)
	material.set_shader_parameter("refreshed",false)
	show()
	sync_pose(world,player,0.0,1.0,false)
func sync_pose(world: Node3D, player: Node2D, progress: float, alpha: float, refreshed: bool) -> void:
	material.set_shader_parameter("progress",progress)
	material.set_shader_parameter("opacity",alpha)
	material.set_shader_parameter("refreshed",refreshed)
	material.set_shader_parameter("color_phase",floor(progress*3.0))
	material.set_shader_parameter("pulse",maxf(0.0,1.0-progress*4.0))
	if not player.has_meta(&"depth_visual_bridge"): return
	var bridge_ref: Variant = player.get_meta(&"depth_visual_bridge")
	var bridge: Node = bridge_ref.get_ref() if bridge_ref is WeakRef else null
	if not is_instance_valid(bridge): return
	while emitted<GHOST_COUNT and progress >= .10+float(emitted)*.14:
		var ghost := ghosts[emitted]
		ghost.texture = bridge.actor_sprite.texture
		ghost.pixel_size = bridge.actor_sprite.pixel_size
		ghost.global_transform = bridge.actor_sprite.global_transform
		var point := origin.lerp(endpoint,.10+float(emitted)*.14)
		var sideways := (endpoint-origin).normalized().orthogonal()*(-3.0 if emitted%2==0 else 3.0)
		var offset := world.global_basis*Vector3(point.x+sideways.x-player.global_position.x,0,point.y+sideways.y-player.global_position.y)/32.0
		ghost.global_position += offset
		var ink := ghost_materials[emitted]
		ink.set_shader_parameter("capture_texture",ghost.texture)
		ink.set_shader_parameter("band",float(emitted))
		ink.set_shader_parameter("opacity",.92)
		var source := bridge.actor_sprite.material_override as ShaderMaterial
		if source != null:
			for key in [&"reference_depth_enabled",&"reference_plane_normal"]:
				ink.set_shader_parameter(key,source.get_shader_parameter(key))
			var plane_origin: Vector3 = source.get_shader_parameter("reference_plane_origin")
			ink.set_shader_parameter("reference_plane_origin",plane_origin+offset)
		ghost.show()
		emitted += 1
func finish(end: Vector2, killed: bool) -> void:
	# Endpoint may have backed off from a moving blocker. Keep the strip on the
	# actual route rather than leaving a slash beyond the authoritative landing.
	endpoint = end
	var plane := mesh.mesh as PlaneMesh
	var pulse_size := 72.0 if killed else 56.0
	plane.size = Vector2(origin.distance_to(end)+pulse_size,pulse_size)/32.0
	var center := origin.lerp(end,.5)
	global_transform = owner_world.global_transform*Transform3D(Basis(Vector3.UP,-(end-origin).angle()),Vector3(center.x/32.0,.12,center.y/32.0))
	material.set_shader_parameter("half_length",origin.distance_to(end)*.5)
	material.set_shader_parameter("progress",1.0)
	material.set_shader_parameter("refreshed",killed)
	material.set_shader_parameter("pulse",1.0)
func fade(alpha: float) -> void:
	material.set_shader_parameter("opacity",alpha)
	material.set_shader_parameter("pulse",alpha)
	material.set_shader_parameter("color_phase",floor((1.0-alpha)*3.0)+3.0)
	for i in GHOST_COUNT:
		ghost_materials[i].set_shader_parameter("opacity",maxf(0.0,alpha-float(GHOST_COUNT-1-i)*.045)*.94)
		ghost_materials[i].set_shader_parameter("band",float(i)+floor((1.0-alpha)*2.0))
		if alpha<=.001:
			ghosts[i].texture = null
			ghost_materials[i].set_shader_parameter("capture_texture",null)
	visible = alpha>.001
