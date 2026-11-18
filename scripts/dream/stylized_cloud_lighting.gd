extends Node3D
## One calibrated cloud key per world; leases survive staged-floor rollback.
const LAYER:=1<<11
var world:Node3D
var owners:Dictionary={}
var lights:Dictionary={}
var camera:Camera3D
var camera_had_layer:=false
var key:DirectionalLight3D

static func acquire(owner_world:Node3D,owner:Node)->Node3D:
	var shared:Node3D=owner_world.get_node_or_null("StylizedCloudLighting")
	if shared==null:
		shared=load("res://scripts/dream/stylized_cloud_lighting.gd").new()
		shared.name="StylizedCloudLighting"
		owner_world.add_child(shared)
		shared.configure(owner_world)
	shared.attach(owner)
	return shared

func configure(owner_world:Node3D)->void:
	world=owner_world
	key=DirectionalLight3D.new()
	key.name="SmokeStyleKey"
	key.set_meta(&"stylized_cloud_key",true)
	key.light_energy=preload("res://scripts/dream/stylized_cloud_assets.gd").LIGHT_GAIN/PI
	key.light_cull_mask=LAYER
	key.shadow_enabled=false
	add_child(key)
	key.rotation_degrees=Vector3(-50,-30,0)
	key.hide()
	_prepare_silhouette_pipeline()

func _prepare_silhouette_pipeline()->void:
	# Prepare the actual Sprite3D overlay variant during level loading. It
	# draws no pixels and is removed after its first submitted Camera frame.
	var view:Camera3D=world.get("camera_3d")
	if not is_instance_valid(view):return
	var sprite:=Sprite3D.new()
	sprite.name="CloudSilhouettePipelineWarmup"
	sprite.texture=preload("res://scripts/dream/stylized_cloud_assets.gd").NOISE
	sprite.pixel_size=.0001
	sprite.position=Vector3(0,0,-1)
	sprite.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material:=ShaderMaterial.new()
	material.shader=preload("res://shaders/dream3d/stylized_cloud_silhouette.gdshader")
	material.render_priority=8
	material.set_shader_parameter("warmup_only",true)
	material.set_shader_parameter("capture_texture",sprite.texture)
	sprite.material_override=material
	sprite.material_overlay=material
	view.add_child(sprite)
	RenderingServer.frame_post_draw.connect(sprite.queue_free,CONNECT_ONE_SHOT|CONNECT_DEFERRED)

func attach(owner:Node)->void:
	for id in owners.keys():
		if owners[id].get_ref()==null:owners.erase(id)
	if owners.is_empty():
		camera=world.get("camera_3d")
		if is_instance_valid(camera):
			camera_had_layer=(camera.cull_mask & LAYER)!=0
			camera.cull_mask|=LAYER
	owners[owner.get_instance_id()]=weakref(owner)
	for node in world.find_children("*","Light3D",true,false):
		var light:Light3D=node
		if light==key or light.name=="SmokeStyleKey":continue
		var id:=light.get_instance_id()
		if not lights.has(id):lights[id]={"ref":weakref(light),"receive":(light.light_cull_mask & LAYER)!=0,"cast":(light.shadow_caster_mask & LAYER)!=0}
		light.light_cull_mask&=~LAYER
		light.shadow_caster_mask|=LAYER
	key.show()

func release(owner:Node)->void:
	owners.erase(owner.get_instance_id())
	if not owners.is_empty():return
	_restore()

func _restore()->void:
	for record:Dictionary in lights.values():
		var light:Light3D=record.ref.get_ref()
		if not is_instance_valid(light):continue
		light.light_cull_mask=(light.light_cull_mask & ~LAYER) | (LAYER if record.receive else 0)
		light.shadow_caster_mask=(light.shadow_caster_mask & ~LAYER) | (LAYER if record.cast else 0)
	lights.clear()
	if is_instance_valid(camera) and not camera_had_layer:camera.cull_mask&=~LAYER
	if is_instance_valid(key):key.hide()

func _exit_tree()->void:_restore()
