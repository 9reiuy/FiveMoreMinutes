extends SceneTree
const ADAPTER=preload("res://scripts/dream/dream_3d_run_interface.gd")
const CRT=preload("res://scripts/ui/death_crt_effect.gd")
const SAVE=preload("res://scripts/app/game_save_store.gd")
class Player extends Node2D:
	signal died
	var dead:=true
	var last_damage_source:StringName=&"projectile"
	var attack_enabled:=true
	var dash_enabled:=true
	var death_shot_elapsed := -1.0
	func set_attacking_enabled(value:bool)->void:attack_enabled=value
	func set_dash_enabled(value:bool)->void:dash_enabled=value
	func get_death_shot_elapsed() -> float: return death_shot_elapsed
class World extends Node3D:
	var persist_profile:=true
	var resets:=0
	func reset_hit_stop()->void:resets+=1
class Host extends Node:
	var saved:=0
	func _on_dream_profile_changed(profile:Dictionary)->void:
		if SAVE.save_game(profile):saved+=1
var checks:=0
var failures:Array[String]=[]
func expect(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
	AudioServer.set_bus_mute(0,true);CRT.prepare_audio()
	var world:=World.new();root.add_child(world)
	var player:=Player.new();world.add_child(player)
	var host:=Host.new();root.add_child(host)
	var adapter:=ADAPTER.new();world.add_child(adapter);adapter.world=world;adapter.player=player;adapter.host=host;adapter.set_process(false)
	adapter.profile={"balance":42,"ram":3,"melatonin_inventory":2,"weekday_index":1,"permanent_upgrades":{}}
	player.died.connect(adapter._on_death)
	var monitor:Node=root.get_node("PerformanceMonitor");monitor.start_recording("user://death_chain_test")
	player.died.emit()
	expect(not player.attack_enabled and not player.dash_enabled and world.resets==1,"death signal synchronously disables controls and resets time state")
	expect(host.saved==1 and SAVE.load_game()==JSON.parse_string(JSON.stringify(adapter.profile)),"save remains synchronous and complete through JSON numeric normalization")
	expect(is_instance_valid(adapter.death_effect) and adapter.death_effect.active,"original death CRT starts at signal handling")
	for stage in ["death_save_io","death_audio_ctrl","death_crt_init","death_actor_cleanup"]:expect(monitor._stage_calls.get(stage,0)>0,"death stage captured: "+stage)
	var old:WeakRef=weakref(adapter.death_effect)
	adapter._clear_death_presentation()
	await process_frame;await process_frame
	expect(old.get_ref()==null,"quick clear retires old CRT instead of leaving dormant active effect")
	adapter.profile.balance=43;player.died.emit()
	expect(host.saved==2 and SAVE.load_game().balance==43,"rapid repeat death preserves save ordering")
	adapter._clear_death_presentation()
	player.death_shot_elapsed = 0.0
	player.died.emit()
	var live := adapter.death_effect as DeathCrtEffect
	expect(is_instance_valid(live) and live.active and live.material.get_shader_parameter("live_camera_zoom"),
		"grounded death starts CRT at the impact and gives the live camera the zoom")
	player.death_shot_elapsed = 0.46
	live._process(0.0)
	var progress := live.effect_progress
	expect(is_equal_approx(progress, 0.46 / live.effect_duration), "CRT uses the same elapsed time as the shot")
	live._process(0.5)
	expect(is_equal_approx(live.effect_progress, progress), "CRT holds while the shot clock is frozen")
	print("DEATH_CHAIN_STAGES ",JSON.stringify(monitor._stage_ms))
	monitor.recorder.close("death chain test");monitor.recording_enabled=false
	world.free();host.free();await process_frame
	print("DEATH_CHAIN checks=%d failures=%s"%[checks,failures])
	quit(0 if failures.is_empty() else 1)
