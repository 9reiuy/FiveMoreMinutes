extends Node3D
## One bounded, persistent native cloud pool for a floor's extinguisher releases.
const ASSETS:=preload("res://scripts/dream/stylized_cloud_assets.gd")
const LIGHTING:=preload("res://scripts/dream/stylized_cloud_lighting.gd")
const PROCESS:=preload("res://shaders/dream3d/extinguisher_cloud_particles.gdshader")
const FIELD:=preload("res://scripts/dream/extinguisher_cloud_field.gd")
const MAIN_COUNT:=256
const CAPACITY:=280
var controller:Node3D
var world:Node3D
var particles:GPUParticles3D
var shadow_particles:GPUParticles3D
var surface:ShaderMaterial
var motion:ShaderMaterial
var lighting:Node3D
var anchors:Image
var metadata:Image
var metadata_texture:ImageTexture
var pose_texture:ImageTexture
var field:RefCounted
var slots:Dictionary={}
var generation:=0
var last_revision:=-1
var jet_serial:=0
var live_count:=0
var serial:=0
var last_positions:Dictionary={}
var paused:=false
var had_jets:=false
var poses_dirty:=false

func configure(owner:Node3D)->void:
	controller=owner
	world=controller.world
	process_mode=Node.PROCESS_MODE_ALWAYS
	anchors=Image.create(CAPACITY,1,false,Image.FORMAT_RGBAF)
	metadata=Image.create(CAPACITY,1,false,Image.FORMAT_RGBAF)
	anchors.fill(Color(0,0,0,0))
	metadata.fill(Color(0,0,0,0))
	metadata_texture=ImageTexture.create_from_image(metadata)
	field=FIELD.new()
	field.configure(controller,anchors,metadata)
	pose_texture=ImageTexture.create_from_image(field.poses)
	surface=ASSETS.make_material()
	surface.set_shader_parameter("floor_field_enabled",true)
	surface.set_shader_parameter("smoke_mask",controller.mask_texture)
	surface.set_shader_parameter("world_to_floor",world.global_transform.affine_inverse())
	surface.set_shader_parameter("mask_origin",Vector2(controller.mask_origin))
	surface.set_shader_parameter("mask_size",Vector2(controller.mask_size))
	motion=ShaderMaterial.new()
	motion.shader=PROCESS
	motion.set_shader_parameter("cloud_poses",pose_texture)
	motion.set_shader_parameter("cloud_metadata",metadata_texture)
	motion.set_shader_parameter("floor_to_world",world.global_transform)
	particles=GPUParticles3D.new()
	particles.name="PersistentExtinguisherCloud"
	particles.amount=CAPACITY
	particles.lifetime=5.0
	particles.explosiveness=1.0
	particles.fixed_fps=0
	particles.local_coords=false
	particles.use_fixed_seed=true
	particles.seed=28711
	particles.layers=LIGHTING.LAYER
	particles.draw_pass_1=ASSETS.INDEXED_MESH
	particles.material_override=surface
	particles.process_material=motion
	particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb=AABB(Vector3(controller.mask_origin.x-.5,0,controller.mask_origin.y-.5),Vector3(controller.mask_size.x,3.0,controller.mask_size.y))
	add_child(particles)
	particles.hide()
	particles.speed_scale=0.0
	# The exact visible mesh stays intact. A synchronized low-detail copy
	# casts real shadows without resubmitting 3,968 triangles per puff/light.
	shadow_particles=particles.duplicate() as GPUParticles3D
	shadow_particles.name="ExtinguisherCloudShadow"
	shadow_particles.draw_pass_1=ASSETS.SHADOW_MESH
	shadow_particles.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	shadow_particles.process_material=motion
	add_child(shadow_particles)
	lighting=LIGHTING.acquire(world,self)

func _enter_tree()->void:
	if is_instance_valid(world):lighting=LIGHTING.acquire(world,self)

func _process(_delta:float)->void:
	if not is_instance_valid(particles) or not is_instance_valid(controller):return
	paused=get_tree().paused or not controller.can_process() or world.floor_transition_in_progress
	particles.speed_scale=0.0 if paused or live_count==0 else 1.0
	shadow_particles.speed_scale=particles.speed_scale

func sync_field()->void:
	if controller.visual_revision==last_revision and controller.puffs.is_empty() and not had_jets:return
	had_jets=not controller.puffs.is_empty()
	last_revision=controller.visual_revision
	var wanted:Dictionary={}
	var total:=mini(MAIN_COUNT,maxi(0,controller.clouds.size()*2))
	var duplicates:Dictionary={}
	for index in total:
		var cloud:Dictionary=controller.clouds[floori(float(index*controller.clouds.size())/total)]
		var base_key:="%d:%d:%d"%[cloud.cell.x,cloud.cell.y,int(cloud.layer)]
		var duplicate_index:int=duplicates.get(base_key,0)
		duplicates[base_key]=duplicate_index+1
		var key:=base_key+":"+str(duplicate_index)
		var seed:float=float(cloud.seed)+duplicate_index*811.0
		var offset:=Vector2(sin(seed)*.10,cos(seed*.7)*.10)
		var clearance:=maxf(.0,float(cloud.clearance)-offset.length()-.025)
		var point:=Vector2(cloud.center)+offset
		var size:=lerpf(1.20,1.65,fposmod(seed*.573,1.0))
		var height:=lerpf(.72,1.37,fposmod(seed*.371,1.0))
		wanted[key]={"point":Vector3(point.x,height,point.y),"size":size,"clearance":clearance,"seed":seed,"jet":false}
	for puff:Dictionary in controller.puffs:
		if not puff.has("native_cloud_key"):
			jet_serial+=1
			puff.native_cloud_key="jet:"+str(jet_serial)
		var t:float=clampf(float(puff.age)/float(puff.life),0,1)
		var point:=Vector2(puff.cell)+Vector2(puff.offset)+Vector2(puff.get("jet",Vector2.ZERO))*t*.45
		var clearance:float=controller.card_clearance(point,Vector2i(point.round()))
		wanted[puff.native_cloud_key]={"point":Vector3(point.x,float(puff.height)+t*.25,point.y),"size":float(puff.size)*(1.0-t),"clearance":clearance,"seed":float(puff.kind)*117.0,"jet":true}
	for key in slots.keys():
		if wanted.has(key):continue
		anchors.set_pixel(slots[key].index,0,Color(0,0,0,0))
		slots.erase(key)
	var used:Dictionary={}
	for record:Dictionary in slots.values():used[record.index]=true
	for key in wanted:
		var parcel:Dictionary=wanted[key]
		if not slots.has(key):
			var begin:=MAIN_COUNT if parcel.jet else 0
			var end:=CAPACITY if parcel.jet else MAIN_COUNT
			var free_index:=-1
			for index in range(begin,end):
				if not used.has(index):free_index=index;break
			if free_index<0:continue
			generation+=1
			slots[key]={"index":free_index,"generation":generation}
			used[free_index]=true
		var record:Dictionary=slots[key]
		var point:Vector3=parcel.point
		anchors.set_pixel(record.index,0,Color(point.x,point.y,point.z,parcel.size))
		metadata.set_pixel(record.index,0,Color(fposmod(float(parcel.seed)*.37,1.0)*TAU,lerpf(.20,.52,fposmod(float(parcel.seed)*.29,1.0)),float(record.generation),parcel.clearance))
	metadata_texture.update(metadata)
	field.sync_slots()
	live_count=slots.size()
	particles.visible=live_count>0
	particles.speed_scale=0.0 if paused or live_count==0 else 1.0
	shadow_particles.visible=particles.visible
	shadow_particles.speed_scale=particles.speed_scale

func collect_motion(delta:float)->void:
	if live_count==0:
		last_positions.clear()
		return
	var actors:Array=[]
	var player:Variant=world.get("player")
	if is_instance_valid(player):actors.append(player)
	var enemy_root:Node=world.get("enemy_root")
	if is_instance_valid(enemy_root):
		for enemy in enemy_root.get_children():
			if enemy is CharacterBody2D and enemy.can_process() and enemy.get("dead")!=true and enemy.get("drone")==null:actors.append(enemy)
	var present:Dictionary={}
	for actor:Node2D in actors:
		var id:=actor.get_instance_id()
		var point:=actor.global_position
		present[id]=true
		if last_positions.has(id):
			var from:Vector2=last_positions[id]
			var distance:=point.distance_to(from)
			if distance>.02 and distance<96 and (controller.cells.has(world._cell_for_gameplay_position(point)) or controller.cells.has(world._cell_for_gameplay_position(from))):
				var rolling:bool=actor.get("dashing")==true
				var velocity:=Vector3(point.x-from.x,0,point.y-from.y)/32.0/maxf(.001,delta)
				push_impulse(from,point,1.15 if rolling else .8,0.0,velocity*(.65 if rolling else .28),true)
		last_positions[id]=point
	for id in last_positions.keys():
		if not present.has(id):last_positions.erase(id)

func push_shot(from:Vector2,to:Vector2)->void:
	var direction:=from.direction_to(to)
	push_impulse(from,to,.55,4.6,Vector3(direction.x,0,direction.y)*2.8)

func push_impulse(from:Vector2,to:Vector2,radius:float,clearing:float,velocity:Vector3,body_wake:=false)->void:
	if live_count==0:return
	serial+=1
	field.push_impulse(from,to,radius,clearing,velocity,serial,body_wake)

func advance_field(delta:float)->void:
	field.advance(delta)
	poses_dirty=true

func flush_motion()->void:
	if not poses_dirty:return
	poses_dirty=false
	pose_texture.update(field.poses)

func _exit_tree()->void:
	if is_instance_valid(particles):particles.speed_scale=0.0
	if is_instance_valid(shadow_particles):shadow_particles.speed_scale=0.0
	if is_instance_valid(lighting):lighting.release(self)

func _notification(what:int)->void:
	if what==NOTIFICATION_PREDELETE and is_instance_valid(particles):
		particles.emitting=false
		particles.process_material=null
		particles.material_override=null
		if is_instance_valid(shadow_particles):
			shadow_particles.emitting=false
			shadow_particles.process_material=null
			shadow_particles.material_override=null
