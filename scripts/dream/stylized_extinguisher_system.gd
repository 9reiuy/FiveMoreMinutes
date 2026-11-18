extends "res://scripts/dream/fire_extinguisher_system.gd"
## Reachable release mask plus shared visible-parcel occupancy for gameplay.
var cloud_renderer:Node3D
const SILHOUETTE:=preload("res://shaders/dream3d/stylized_cloud_silhouette.gdshader")

func configure_visuals()->void:
	# Sample actors after their movement, then apply this tick's occupancy.
	# A controller installed before the player otherwise leaves edge states
	# one physics tick behind the position shown by the actor bridge.
	process_physics_priority=10
	cloud_renderer=preload("res://scripts/dream/extinguisher_cloud_renderer.gd").new()
	cloud_renderer.name="StylizedExtinguisherCloud"
	add_child(cloud_renderer)
	cloud_renderer.configure(self)

func advance_presentation(_delta:float,immediate_present:bool)->void:
	_presentation_pending=true
	if immediate_present:upload_puffs()

func upload_puffs()->void:
	_presentation_pending=false
	cloud_renderer.flush_motion()

func prepare_coverage(delta:float)->bool:
	for index in range(puffs.size()-1,-1,-1):
		puffs[index].age+=delta
		if float(puffs[index].age)>=float(puffs[index].life):puffs.remove_at(index)
	cloud_renderer.sync_field()
	cloud_renderer.collect_motion(delta)
	cloud_renderer.advance_field(delta)
	return true

func contains(point:Vector2)->bool:
	return super.contains(point) and is_instance_valid(cloud_renderer) and cloud_renderer.field.contains(point)

func blocks_sight(from:Vector2,to:Vector2)->bool:
	return super.blocks_sight(from,to) and is_instance_valid(cloud_renderer) and cloud_renderer.field.blocks_sight(from,to)

func disperse_segment(from:Vector2,to:Vector2)->void:
	cloud_renderer.push_shot(from,to)
	super.disperse_segment(from,to)

func set_silhouette(actor:Node2D,enabled:bool)->void:
	super.set_silhouette(actor,enabled)
	if not enabled or not actor.has_meta(&"depth_visual_bridge"):return
	var reference:Variant=actor.get_meta(&"depth_visual_bridge")
	var bridge:Node=reference.get_ref() if reference is WeakRef else reference
	if not is_instance_valid(bridge):return
	for sprite in [bridge.get("actor_sprite"),bridge.get("weapon_sprite"),bridge.get("attachment_sprite")]:
		if not is_instance_valid(sprite) or not sprite.has_meta(&"smoke_overlay"):continue
		var overlay:ShaderMaterial=sprite.get_meta(&"smoke_overlay")
		if overlay.shader==SILHOUETTE:continue
		var parameters:Dictionary={}
		for key in ["capture_texture","reference_depth_enabled","reference_plane_origin","reference_plane_normal"]:parameters[key]=overlay.get_shader_parameter(key)
		overlay.shader=SILHOUETTE
		for key in parameters:overlay.set_shader_parameter(key,parameters[key])
