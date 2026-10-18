extends SceneTree
const MANAGER = preload("res://scripts/dream/office_shadow_manager.gd")
class WorldStub extends Node3D:
	var player: Node2D
	var camera_3d: Camera3D
	func get_gameplay_world_position(point: Vector2) -> Vector3: return Vector3(point.x,0,point.y)
var checks:=0
var failures:Array[String]=[]
func _initialize()->void: call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures.append(label);push_error(label)
func run()->void:
	var world:=WorldStub.new();root.add_child(world)
	world.player=Node2D.new();world.add_child(world.player)
	var manager:=MANAGER.new();world.add_child(manager);manager.world=world;manager.set_process(false)
	var a:=OmniLight3D.new();a.position=Vector3(-3,3,0);a.omni_range=12;world.add_child(a)
	var b:=OmniLight3D.new();b.position=Vector3(2,3,0);b.omni_range=12;world.add_child(b)
	var original_mask:=a.shadow_caster_mask
	var cull:=a.light_cull_mask
	for light in [a,b]:
		manager.register_light(light);light.shadow_enabled=true;light.shadow_opacity=1;manager.active[light]=0.0
	manager._update_player_shadow_light()
	check(manager.player_shadow_light==b,"Nearest effective lamp owns the primary body shadow")
	check(a.shadow_caster_mask&4==0 and b.shadow_caster_mask&4!=0,"Secondary lamp cannot add another player silhouette")
	for light in [a,b]:
		check(light.shadow_caster_mask&3==original_mask&3,"Environment and enemy caster channels preserved")
		check(light.light_cull_mask==cull and is_equal_approx(light.light_energy,1),"Lighting receivers and energy unchanged")
	a.light_energy=1.25;manager._update_player_shadow_light()
	check(manager.player_shadow_light==b,"Small score variation does not flicker shadow direction")
	a.light_energy=8;manager._update_player_shadow_light()
	check(manager.player_shadow_light==a and b.shadow_caster_mask&4==0,"Stronger lamp takes sole ownership")
	a.light_cull_mask &= ~4;manager._update_player_shadow_light()
	check(manager.player_shadow_light==b,"Lamp excluding player cannot steal the primary shadow")
	a.light_cull_mask=cull;manager._update_player_shadow_light()
	manager.sun=DirectionalLight3D.new();manager.add_child(manager.sun);manager._set_player_caster(manager.sun,false)
	world.player.position=Vector2(100,100);manager._update_player_shadow_light()
	check(manager.player_shadow_light==manager.sun and a.shadow_caster_mask&4==0,"Exterior falls back to existing sun, without interior duplicates")
	world.player.position=Vector2.ZERO;manager._update_player_shadow_light()
	check(manager.player_shadow_light==a and manager.sun.shadow_caster_mask&4==0,"Interior lamp suppresses duplicate sun projection")
	var spot:=SpotLight3D.new();world.add_child(spot);spot.position=Vector3(0,3,0);spot.spot_range=10;spot.shadow_enabled=true
	check(manager._player_light_score(spot,Vector3.ZERO)==0,"Lamp facing away is not a false primary")
	manager.set_suspended(true)
	check(manager.player_shadow_light==null and manager.active.is_empty(),"Cab suspension clears player ownership and active shadows")
	check(a.shadow_caster_mask&4==0 and b.shadow_caster_mask&4==0,"Suspension leaves no duplicate player channel")
	manager.clear_floor()
	check(a.shadow_caster_mask==original_mask and b.shadow_caster_mask==original_mask,"Cleanup restores original masks for surviving lamps")
	check(manager._player_caster_masks.is_empty(),"Cleanup releases prior floor light references")
	world.free();await process_frame
	print("PLAYER_SINGLE_SHADOW ",checks," checks ",failures.size()," failures")
	quit(1 if failures.size() else 0)
