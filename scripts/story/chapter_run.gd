extends Node
## Chapter-specific goals over the existing world, without a second combat owner.
const RULES=preload("res://scripts/story/chapter_one_state.gd")
const UI=preload("res://scripts/story/chapter_panel.gd")
const STAGING=preload("res://scripts/story/chapter_room_staging.gd")
const FX=preload("res://scripts/story/chapter_stage_fx.gd")
var maintenance_site: Dictionary={}
var boss_room_started:=false
var boss_edge_lights: Array[OmniLight3D]=[]
var sealed_doors: Array[PhysicalDoor3D]=[]
var boss_ceiling: Array[Dictionary]=[]
var coordinator: Node
var world: Node3D
var panel: CanvasLayer
var token: int=-1
var ready_floor:=false
var cameras: Node3D
var terminal_collision: StaticBody2D
var terminal_position:=Vector2.ZERO
var applied_build: String=""
var tarot_applied:=false
var boss: Node2D
var boss_phase:=0
var modal:=false
var returning:=false
var terminal_hint: Control
func _ready() -> void:
	world=get_parent(); await world.ready
	panel=UI.new(); add_child(panel); panel.choice_selected.connect(_choose_build)
	terminal_hint=preload("res://scripts/story/context_hint.gd").new(); panel.add_child(terminal_hint)
func _process(_delta: float) -> void:
	if not is_instance_valid(panel) or not is_instance_valid(world.player): return
	terminal_hint.hide()
	if world.floor_transition_in_progress or world.rooms.is_empty(): return
	if token!=world.get_current_floor_token(): prepare_floor()
	if not ready_floor: return
	_apply_build()
	var role: String=RULES.FLOOR_ROLES[clampi(world.floor_index,0,3)]
	if role=="rest":
		var prompt: String="[E] 使用工作台" if world.player.global_position.distance_to(terminal_position)<75. else "寻找亮着屏幕的工作台"
		panel.show_status("休息层  ·  "+prompt if coordinator.state.build=="" else "构筑已保存  ·  领取电梯卡，前往上层")
		if not modal and not get_tree().paused and world.player.global_position.distance_to(terminal_position)<125.:
			var at: Vector2=world.player.get_presentation_hud_position(world.camera_3d.unproject_position(world.get_gameplay_world_position(terminal_position,1.3)))
			terminal_hint.present("[E] 使用维护台" if coordinator.state.build=="" else "构筑已保存 · 领取电梯卡",at+Vector2(0,-20))
	elif role=="boss":
		if coordinator.state.stage=="RETURN":
			world.set_meta(&"chapter_one_return",true)
			panel.show_status("清理结束  ·  领取电梯卡，乘梯回房")
		elif world.current_room_id==world.boss_room_id:
			if not is_instance_valid(world.boss_enemy): world._spawn_room_boss()
			boss=world.boss_enemy
			if is_instance_valid(boss):
				if not boss_room_started: _boss_arrival()
				panel.show_status("报废宿主 01  ·  " + ("维护协议" if boss_phase==0 else "异常过载"))
				if not boss.dead and boss_phase==0 and boss.current_health<boss.maximum_health*.5:
					boss_phase=1; boss.equip_weapon("assault_rifle"); boss.attack_cooldown_left=1.25
					panel.command("警告 / 宿主过载")
					FX.pulse(cameras,Vector3(boss.position.x/32.,0.,boss.position.y/32.),Color("bd6059"))
					for edge_light in boss_edge_lights: edge_light.light_color=Color(.72,.18,.12)
				if boss.dead and coordinator.commit("boss"):
					_restore_boss_lighting()
					for sealed in sealed_doors:
						if is_instance_valid(sealed): sealed.seal_encounter(false)
					world.set_meta(&"chapter_one_return",true)
					world._spawn_employee_badge(boss.global_position,world.boss_room_id)
		else: panel.show_status("第一章 · 报废目标  /  寻找档案室中的宿主")
	else:
		var cleared:=0; var total:=0
		for room in world.rooms:
			if int(room.id)==world.spawn_room_id or not world._is_combat_room(room): continue
			total+=1
			# A final hit can knock an enemy across the room boundary. Its home
			# encounter is still complete; don't strand that room in ACTIVE.
			var encounter: Dictionary=world.room_encounters.get(int(room.id),{})
			if world.get_room_state(int(room.id))==&"ACTIVE" and bool(encounter.get("activated",false)) and required_hostiles(int(room.id))==0:
				world.mark_room_cleared(int(room.id))
			if world.get_room_state(int(room.id))==&"CLEARED" and required_hostiles(int(room.id))==0: cleared+=1
		if cleared==total and total>0 and not world.has_floor_badge and not is_instance_valid(world.floor_badge_pickup):
			# The finite chapter has no population refill. If a generated carrier
			# slot had no physical spawn, issue a real pickup after full clearance.
			world._spawn_employee_badge(world.player.global_position,world.spawn_room_id)
		panel.show_status("第一章 · %dF  /  肃清 %d/%d  ·  %s"%[world.floor_index+1,cleared,total,"返回电梯" if can_advance() else "拿走电梯卡，肃清本层"])
	world._set_elevator_runtime_active()
func prepare_floor() -> void:
	_restore_boss_lighting()
	token=world.get_current_floor_token(); ready_floor=true; boss_phase=0; boss_room_started=false; boss_edge_lights.clear(); sealed_doors.clear()
	if is_instance_valid(terminal_collision): terminal_collision.queue_free()
	if world.floor_index>int(coordinator.state.floor): coordinator.commit("floor",{"index":world.floor_index})
	if is_instance_valid(cameras): cameras.queue_free()
	cameras=Node3D.new(); cameras.name="ChapterSurveillance"; world.add_child(cameras)
	for i in mini(4,world.rooms.size()):
		var site: Dictionary=STAGING.camera_site(world,i)
		if site.is_empty(): continue
		var prop:=preload("res://scripts/story/surveillance_camera.gd").create(world,site)
		cameras.add_child(prop)
	var role: String=RULES.FLOOR_ROLES[clampi(world.floor_index,0,3)]
	if role=="rest":
		_build_terminal()
	elif role=="boss":
		var furthest: float=-1.
		for room in world.rooms:
			if int(room.id)==world.spawn_room_id: continue
			var distance: float=Vector2(room.center_cell).distance_squared_to(Vector2(world.spawn_cell))
			if distance>furthest: furthest=distance; world.boss_room_id=int(room.id)
		if coordinator.state.stage=="RETURN":
			world.boss_defeated=true
			world._spawn_employee_badge(world.player.global_position,world.spawn_room_id)
	else:
		play_command("答案在上层" if world.floor_index==0 else "肃清阻碍")
func play_command(text: String) -> void:
	await panel.command(text)
func can_advance() -> bool:
	if not ready_floor: return false
	if world.floor_index==2: return not str(coordinator.state.build).is_empty()
	if world.floor_index==3: return coordinator.state.stage=="RETURN"
	for room in world.rooms:
		if int(room.id)==world.spawn_room_id or not world._is_combat_room(room): continue
		if world.get_room_state(int(room.id))!=&"CLEARED" or required_hostiles(int(room.id))>0: return false
	return true
func required_hostiles(room_id: int) -> int:
	var count:=0
	for enemy in world.enemy_root.get_children():
		if not (enemy is EmployeeEnemy or enemy.get_meta("content_kind",&"")==&"hotel_robot"): continue
		if not enemy.dead and int(enemy.get_meta("dream_room_id",-1))==room_id: count+=1
	return count
func _build_terminal() -> void:
	maintenance_site=STAGING.maintenance_site(world,world.spawn_room_id)
	if maintenance_site.is_empty():
		push_error("No legal maintenance wall bay for this floor")
		return
	terminal_position=Vector2(maintenance_site.position)*32.
	var bay:=Node3D.new(); bay.name="MaintenanceBay"
	bay.position=Vector3(terminal_position.x/32.,0,terminal_position.y/32.)
	var angle: float=atan2(maintenance_site.inward.x,maintenance_site.inward.y); bay.rotation.y=angle; cameras.add_child(bay)
	var mesh:=MeshInstance3D.new(); mesh.mesh=load("res://art/story/chapter1/workbench.obj"); mesh.material_override=load("res://art/story/chapter1/workbench.tres"); bay.add_child(mesh)
	terminal_collision=StaticBody2D.new(); terminal_collision.name="ChapterWorkbenchCollision"; terminal_collision.position=terminal_position
	terminal_collision.rotation=-angle; terminal_collision.collision_layer=4; terminal_collision.collision_mask=0
	var shape:=CollisionShape2D.new(); var rect:=RectangleShape2D.new(); rect.size=Vector2(48,27.2); shape.shape=rect; terminal_collision.add_child(shape)
	world.gameplay_canvas.get_node("GameplayWorld").add_child(terminal_collision)
	for side in [-1.,1.]:
		var cabinet: Node3D=load("res://scenes/story/tutorial_props/cabinet.tscn").instantiate(); cabinet.position=Vector3(side*1.5,0,-.15); bay.add_child(cabinet)
		var solid:=CollisionShape2D.new(); var form:=RectangleShape2D.new(); form.size=Vector2(cabinet.get_meta("solid_size"))*32.; solid.shape=form; solid.position=Vector2(side*1.5,-.15)*32.; terminal_collision.add_child(solid)
	var mat:=MeshInstance3D.new(); var box:=BoxMesh.new(); box.size=Vector3(4.2,.025,1.75); mat.mesh=box
	mat.position=Vector3(0,.018,1.); mat.material_override=OfficePixelMaterials.make_floor(Color(.11,.16,.18),"rug"); mat.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; bay.add_child(mat)
	for spec in [[Vector3(0,1.45,-.62),Vector3(1.4,.07,.05)],[Vector3(.56,1.75,-.62),Vector3(.28,.45,.08)]]:
		var cable:=MeshInstance3D.new(); var form:=BoxMesh.new(); form.size=spec[1]; cable.mesh=form; cable.position=spec[0]; cable.material_override=OfficePixelMaterials.make(Color(.24,.30,.34),"metal"); bay.add_child(cable)
	for spec in [[Vector3(0,2.83,.2),Vector3(1.55,.10,.30)],[Vector3(-.60,2.94,.2),Vector3(.04,.24,.04)],[Vector3(.60,2.94,.2),Vector3(.04,.24,.04)]]:
		var fixture:=MeshInstance3D.new(); var form:=BoxMesh.new(); form.size=spec[1]; fixture.mesh=form; fixture.position=spec[0]
		fixture.name="MaintenanceLamp"; fixture.material_override=OfficePixelMaterials.make(Color(.42,.46,.48),"metal"); fixture.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; bay.add_child(fixture)
	var task:=SpotLight3D.new(); task.name="MaintenanceTaskLight"; task.position=Vector3(0,2.65,.2); task.rotation.x=-PI/2.
	task.light_color=Color(.95,.79,.56); task.light_energy=.90; task.spot_range=4.; task.spot_angle=56.; task.spot_attenuation=.85; task.spot_angle_attenuation=.6; task.shadow_enabled=false; task.light_specular=0.; bay.add_child(task)
	if not str(coordinator.state.build).is_empty(): world._spawn_employee_badge(terminal_position+Vector2(0,24),world.spawn_room_id)
	preload("res://scripts/audio/sfx_manager.gd").finish_combat_music()
func _input(event: InputEvent) -> void:
	if not ready_floor or world.floor_transition_in_progress or get_tree().paused or world.floor_index!=2: return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_E and coordinator.state.build=="" and world.player.global_position.distance_to(terminal_position)<75.:
		get_viewport().set_input_as_handled(); modal=true
		get_node("/root/PauseManager").request_pause(&"UPGRADE")
		world.player.movement_enabled=false; world.player.set_attacking_enabled(false)
		var damage: float=world.player.acquired_damage_multiplier
		var tempo: float=world.player.acquired_attack_speed_multiplier
		var reach: float=world.player.acquired_range_pixels
		panel.offer("MAINT / 模块维护","设备自检：就绪   /   链路：同步\n选择一项改装；本章生效，重试保留。",[
			["damage","握持稳定器    伤害 %.2f → %.2f 倍"%[damage,damage*1.15]],
			["tempo","循环供能器    攻速 %.2f → %.2f 倍"%[tempo,tempo*1.15]],
			["range","光学校准镜    射程加成 +%d → +%d"%[roundi(reach),roundi(reach+64.)]]])

func _choose_build(id: String) -> void:
	if not modal or not coordinator.commit("build",{"id":id}): return
	modal=false; panel.dismiss(); _apply_build()
	FX.pulse(cameras,Vector3(world.player.position.x/32.,0.,world.player.position.y/32.),Color("6eaba3"))
	preload("res://scripts/audio/sfx_manager.gd").play_event(&"phone_operation")
	get_node("/root/PauseManager").release_pause(&"UPGRADE")
	world.player.movement_enabled=true; world.player.set_attacking_enabled(true); Input.mouse_mode=Input.MOUSE_MODE_HIDDEN
	world._spawn_employee_badge(terminal_position+Vector2(0,24),world.spawn_room_id)
func _apply_build() -> void:
	if not tarot_applied:
		preload("res://scripts/story/chapter_tarot.gd").apply(world.player,str(coordinator.state.tarot_id),bool(coordinator.state.tarot_reversed))
		tarot_applied=true
	var id: String=str(coordinator.state.build)
	if id=="" or applied_build==id: return
	match id:
		"damage": world.player.apply_damage_upgrade(1.15)
		"tempo": world.player.apply_attack_speed_upgrade(1.15)
		"range": world.player.apply_range_upgrade(64.)
	applied_build=id
func return_via_cab() -> void:
	if returning: return
	returning=true
	var cab: Node3D=preload("res://scripts/dream/independent_elevator_cab_3d.gd").new(world.floor_index)
	world.active_transition_cab=cab; cab.position=Vector3(0,0,-100); world.add_child(cab); cab.global_rotation=Vector3.ZERO
	cab.setup_gameplay_boundaries(world.gameplay_canvas.get_node("GameplayWorld"),Vector2(0,-3200))
	world._set_building_exterior_visible(false); cameras.hide()
	world.player.global_position=cab.get_player_initial_position_2d(); world.player.movement_enabled=true; world.player.set_dash_enabled(false)
	world.transition_phase=&"CAB_RIDE"; world._set_elevator_ride_rumbling(true)
	world._update_camera_and_actor_projection()
	panel.show_status("返回员工休息层")
	var elapsed:=0.
	while elapsed<3.:
		await get_tree().process_frame
		if not get_tree().paused: elapsed+=minf(get_process_delta_time(),.1)
	world.player.movement_enabled=false; world._set_elevator_ride_rumbling(false)
	await cab.open_cab_doors(.4)
	world._set_elevator_ride_rumbling(false); coordinator.returned()

func _boss_arrival() -> void:
	boss_room_started=true
	for node in world.find_children("*","Light3D",true,false):
		if int(node.get_meta("dream_room_id",-1))!=world.boss_room_id or cameras.is_ancestor_of(node): continue
		boss_ceiling.append({"light":node,"energy":node.light_energy,"color":node.light_color})
		var flicker:=create_tween()
		flicker.tween_property(node,"light_energy",node.light_energy*.1,.07)
		flicker.tween_property(node,"light_energy",node.light_energy*.8,.06)
		flicker.tween_property(node,"light_energy",node.light_energy*.32,.12)
		flicker.parallel().tween_property(node,"light_color",Color(.63,.43,.25),.25)
	panel.command("报废宿主 01 / 隔离启动")
	for site in STAGING.wall_sites(world,world.boss_room_id).slice(0,3):
		var light:=OmniLight3D.new(); light.position=Vector3(site.point.x+site.inward.x*.15,1.5,site.point.y+site.inward.y*.15)
		light.light_color=Color(.85,.48,.16); light.light_energy=.35; light.omni_range=3.2; light.light_specular=0.; cameras.add_child(light); boss_edge_lights.append(light)
	for door in world.door_root.get_children():
		if not door is PhysicalDoor3D: continue
		var edge: Dictionary=door.get_meta("wall_edge",{})
		if world.boss_room_id in [int(edge.get("region_a_id",-1)),int(edge.get("region_b_id",-1))]:
			door.seal_encounter(true); sealed_doors.append(door)

func _restore_boss_lighting() -> void:
	for entry in boss_ceiling:
		if is_instance_valid(entry.light): entry.light.light_energy=entry.energy; entry.light.light_color=entry.color
	boss_ceiling.clear()
