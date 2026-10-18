extends SceneTree
const WORLD=preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
var checks:=0
var failures:Array[String]=[]
func _initialize()->void: call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures.append(label);push_error(label)
func count_sources(world:Node3D)->int:
	var count:=0
	for light in world.find_children("*","Light3D",true,false):
		if light.shadow_enabled and light.is_visible_in_tree() and light.shadow_caster_mask&4!=0 and light.light_cull_mask&4!=0:
			count+=1
	return count
func run()->void:
	AudioServer.set_bus_mute(0,true)
	var world:Node3D=WORLD.instantiate()
	world.generate_on_ready=false;world.persist_profile=false;world.enable_game_start_cab_exit=false
	root.add_child(world)
	for skeleton in ["A1","B2","C3","V3"]:
		world.native_skeleton_type=skeleton
		check(world.regenerate(42001),skeleton+" actual floor generation")
		var room:Dictionary={}
		for candidate in world.rooms:
			if String(candidate.get("archetype",""))=="reception":room=candidate;break
		if room.is_empty():room=world.rooms[world.spawn_room_id]
		world.activate_room(room.id);world.player.global_position=Vector2(room.grid_rect.get_center())*32
		world.player.dash_invulnerability_left=3600;world.player.set_attacking_enabled(true)
		for frame in 20:await process_frame
		var manager:Node=world.shadow_manager
		var bridge:Node=world.player_depth_bridge
		check(bridge.volume_shadow!=null and bridge.volume_shadow.weapon==null,skeleton+" player retains body without coarse weapon box")
		check(bridge.actor_sprite.layers==2 and bridge.weapon_sprite.layers==2,skeleton+" visible body and gun layers unchanged")
		check(bridge.weapon_material.get_shader_parameter("reference_depth_enabled")==true,skeleton+" normal weapon reference plane remains live")
		for quality in ["low","standard","high"]:
			manager.set_quality(quality)
			for frame in 12:await process_frame
			check(count_sources(world)<=1,skeleton+" "+quality+" has no duplicate player shadow source")
			check(manager.player_shadow_light!=null,skeleton+" "+quality+" keeps primary body shadow")
		var enemy_volume_count:=0
		for carrier in world.actor_depth_bridges_root.get_children():
			if carrier.get("character_projection")==true and carrier.get("source_actor") is EmployeeEnemy:
				var volume:Node=carrier.volume_shadow
				if volume!=null:
					enemy_volume_count+=1
					check(volume.parts.Head.layers==2 and volume.weapon!=null,skeleton+" enemy caster setup unchanged")
		check(enemy_volume_count>0,skeleton+" verifies real enemy bridges")
		world.night_lighting.flash_muzzle_world(world.get_gameplay_world_position(world.player.global_position),&"rifle")
		for light in world.night_lighting.muzzle_lights:
			check(light.shadow_caster_mask&4==0 and light.shadow_caster_mask&3==3,skeleton+" muzzle retains environment/enemy shadows without player duplicate")
		manager.set_suspended(true)
		check(manager.player_shadow_light==null and count_sources(world)==0,skeleton+" cab suspension clears player shadow")
		manager.set_suspended(false)
		for frame in 20:await process_frame
		check(manager.player_shadow_light!=null and count_sources(world)<=1,skeleton+" resume restores sole shadow owner")
		manager.clear_floor()
		check(manager.player_shadow_light==null and manager._player_caster_masks.is_empty(),skeleton+" floor cleanup drops old owner and light references")
	world.free();await process_frame
	print("PLAYER_SHADOW_FLOOR_INTEGRATION ",checks," checks ",failures.size()," failures")
	quit(1 if failures.size() else 0)
