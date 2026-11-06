extends StaticBody2D
var world: Node
var interaction_radius := 38.0
var broken := false
var powered := true
var lights: Array[Dictionary]=[]
var displays: Array[Dictionary]=[]
var indicator: MeshInstance3D
var captured := false
var native_office := false
var supplemental_lights: Array[Dictionary] = []

func _ready() -> void:
	native_office = world.has_method("uses_office_night_lighting") and world.uses_office_night_lighting()
	add_to_group(&"floor_power_switches")
	add_to_group(&"damageable_props")
	collision_layer=8
	collision_mask=0
	var collision := CollisionShape2D.new()
	collision.name="CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size=Vector2(18,12)
	collision.shape=shape
	add_child(collision)
	call_deferred("build_visual")

func build_visual() -> void:
	if not is_instance_valid(world) or is_queued_for_deletion() or not is_inside_tree(): return
	if has_meta(&"wall_attachment_floor") and int(get_meta(&"wall_attachment_floor")) != world.get_current_floor_token(): return
	if is_instance_valid(indicator): return
	var visual := Node3D.new()
	visual.name="FloorPowerCabinet"
	world.floor_root.add_child(visual)
	if world.has_method("register_wall_attachment"):
		world.register_wall_attachment(visual, get_meta(&"wall_fixture_edge", {}))
	visual.position=Vector3(global_position.x/32.0,0,global_position.y/32.0)
	var inward: Vector2=get_meta(&"wall_inward",Vector2.DOWN)
	visual.rotation.y=atan2(inward.x,inward.y)
	for part in [{"size":Vector3(.62,.9,.22),"pos":Vector3(0,1.15,0),"color":Color(.25,.31,.34)}, {"size":Vector3(.48,.72,.04),"pos":Vector3(0,1.15,.13),"color":Color(.48,.54,.55)}, {"size":Vector3(.12,.26,.06),"pos":Vector3(.1,1.12,.17),"color":Color(.75,.26,.1)}]:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size=part.size
		mesh.mesh=box
		mesh.position=part.pos
		mesh.material_override=preload("res://scripts/dream/office_pixel_materials.gd").make(part.color,"metal")
		visual.add_child(mesh)
	indicator=MeshInstance3D.new()
	var dot := BoxMesh.new()
	dot.size=Vector3(.06,.06,.025)
	indicator.mesh=dot
	indicator.position=Vector3(-.13,1.38,.17)
	visual.add_child(indicator)
	update_indicator()

func refresh_floor_token() -> void:
	if not is_instance_valid(world): return
	set_meta(&"wall_attachment_floor", world.get_current_floor_token())
	if not is_instance_valid(indicator): call_deferred("build_visual")

func is_interaction_available(_actor: Node2D) -> bool: return not broken
func is_damage_runtime_active() -> bool: return not broken
func get_projectile_blocking_height() -> float: return 2.6
func get_projectile_blocking_rect(_height: float) -> Rect2: return Rect2(-9,-6,18,12)
func get_interaction_prompt_state() -> Dictionary: return {"position":global_position,"text":"断电" if powered else "送电"} if not broken else {}
func take_damage(amount: float,_direction: Vector2=Vector2.ZERO,_force: float=1.0) -> void:
	if broken or amount<=0: return
	broken=true
	set_power(false)
func interact() -> void:
	if not broken: set_power(not powered)
func set_power(enabled: bool) -> void:
	if broken and enabled: return
	if not captured:
		captured=true
		if native_office: _capture_office_emitters()
		for light in world.ceiling_light_root.find_children("*","Light3D",true,false): lights.append({"node":weakref(light),"energy":light.light_energy})
		for mesh in world.ceiling_light_root.find_children("*","MeshInstance3D",true,false):
			if mesh.material_override is StandardMaterial3D:
				mesh.material_override=mesh.material_override.duplicate()
				displays.append({"node":weakref(mesh),"emission":mesh.material_override.emission_enabled,"shading":mesh.material_override.shading_mode})
	powered=enabled
	for record in lights:
		var light: Light3D=record.node.get_ref()
		if is_instance_valid(light): light.light_energy=record.energy if powered else 0.0
	for record in displays:
		var mesh: MeshInstance3D=record.node.get_ref()
		if is_instance_valid(mesh):
			mesh.material_override.emission_enabled=record.emission and powered
			if native_office and record.emission:
				mesh.material_override.shading_mode = record.shading if powered else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if native_office:
		for record in supplemental_lights:
			var light := record.node.get_ref() as Light3D
			if is_instance_valid(light): light.layers = int(record.layers) if powered else 0
		var drone_root := world.get_node_or_null("ExteriorPatrolDrones")
		if is_instance_valid(drone_root):
			for drone in drone_root.get_children():
				drone.set_searchlight_powered(powered)
		for bridge in world.actor_depth_bridges_root.get_children():
			if bridge.has_method("set_office_power_cut"): bridge.set_office_power_cut(not powered)
		if is_instance_valid(world.player_depth_bridge):
			world.player_depth_bridge.set_office_power_cut(not powered)
	update_indicator()
func _capture_office_emitters() -> void:
	# The independent cab, portable muzzle lights, and exterior moon do not
	# belong to the floor circuit. Capture only fixed architectural emitters.
	for root_path in ["GeneratedBuildingRoot/OfficeArtRoot", "GeneratedBuildingRoot/WakeExitRoot", "ExteriorPatrolDrones"]:
		var branch: Node = world.get_node_or_null(root_path)
		if branch == null: continue
		for light: Light3D in branch.find_children("*", "Light3D", true, false):
			supplemental_lights.append({"node":weakref(light), "layers":light.layers})

func update_indicator() -> void:
	if not is_instance_valid(indicator): return
	var mat := StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color=Color(.35,.9,.45) if powered else Color(.8,.12,.08)
	indicator.material_override=mat
