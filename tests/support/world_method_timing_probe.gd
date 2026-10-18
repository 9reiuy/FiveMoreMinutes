extends "res://scripts/dream/office_skeleton_world_base.gd"
## Test-only per-call CPU timing. No cadence or gameplay changes.
var timing_active := false
var timing_rows: Dictionary = {}
func timing_begin() -> void:
	timing_rows.clear(); timing_active=true
func record_timing(key: String, start: int) -> void:
	if not timing_active: return
	if not timing_rows.has(key): timing_rows[key]=[]
	timing_rows[key].append((Time.get_ticks_usec()-start)/1000.0)
func timing_finish() -> Dictionary:
	timing_active=false
	var results: Dictionary={}
	for key in timing_rows:
		var rows: Array=timing_rows[key]; rows.sort()
		results[key]={"calls":rows.size(),"median_ms":rows[rows.size()/2],"p95_ms":rows[floori(rows.size()*.95)],"max_ms":rows.back(),"total_ms":rows.reduce(func(a,b): return a+b,0.0)}
	return results
func _process(delta: float) -> void:
	var start:=Time.get_ticks_usec()
	super._process(delta)
	record_timing("world_process",start)
func _update_camera_and_actor_projection(delta: float = 0.0) -> void:
	var start:=Time.get_ticks_usec()
	super._update_camera_and_actor_projection(delta)
	record_timing("camera_and_projection",start)
func _cleanup_door_transit_registry() -> void:
	var start:=Time.get_ticks_usec()
	super._cleanup_door_transit_registry()
	record_timing("_cleanup_door_transit_registry",start)
func _update_projectile_local_lights() -> void:
	var start:=Time.get_ticks_usec()
	super._update_projectile_local_lights()
	record_timing("_update_projectile_local_lights",start)
func _update_occlusion_cutouts() -> void:
	var start:=Time.get_ticks_usec()
	super._update_occlusion_cutouts()
	record_timing("_update_occlusion_cutouts",start)
func _update_world_weapon_interaction() -> void:
	var start:=Time.get_ticks_usec()
	super._update_world_weapon_interaction()
	record_timing("_update_world_weapon_interaction",start)
func _process_pit_contacts() -> void:
	var start:=Time.get_ticks_usec()
	super._process_pit_contacts()
	record_timing("_process_pit_contacts",start)
func _update_player_door_interaction() -> void:
	var start:=Time.get_ticks_usec()
	super._update_player_door_interaction()
	record_timing("_update_player_door_interaction",start)
func _resolve_pending_enemy_pickup_requests() -> void:
	var start:=Time.get_ticks_usec()
	super._resolve_pending_enemy_pickup_requests()
	record_timing("_resolve_pending_enemy_pickup_requests",start)
func _begin_cutout_query_snapshot() -> void:
	var start:=Time.get_ticks_usec()
	super._begin_cutout_query_snapshot()
	record_timing("occlusion_snapshot",start)
func _segment_hits_wall_visual(from: Vector3,to: Vector3,ray: Vector3) -> bool:
	var start:=Time.get_ticks_usec()
	var result:=super._segment_hits_wall_visual(from,to,ray)
	record_timing("wall_query",start)
	return result
func _segment_hits_visual_tree(from: Vector3,to: Vector3,node: Node) -> bool:
	var start:=Time.get_ticks_usec()
	var result:=super._segment_hits_visual_tree(from,to,node)
	record_timing("visual_tree_query",start)
	return result
func _segment_hits_furniture_visual(from: Vector3,to: Vector3) -> bool:
	var start:=Time.get_ticks_usec()
	var result:=super._segment_hits_furniture_visual(from,to)
	record_timing("furniture_query",start)
	return result
func spawn_death_blood_pool(at_position: Vector2,source_room_id: int=-1,intensity: float=1.0,dismember: bool=false,direction: Vector2=Vector2.ZERO) -> void:
	var start:=Time.get_ticks_usec()
	super.spawn_death_blood_pool(at_position,source_room_id,intensity,dismember,direction)
	record_timing("death_pool_spawn_inclusive",start)
func spawn_black_blood(at_position: Vector2,direction: Vector2=Vector2.ZERO,lethal: bool=false,source_room_id: int=-1,intensity: float=1.0,droplet_multiplier: float=1.0,speed_multiplier: float=1.0,spread_multiplier: float=1.0) -> bool:
	var start:=Time.get_ticks_usec()
	var result:=super.spawn_black_blood(at_position,direction,lethal,source_room_id,intensity,droplet_multiplier,speed_multiplier,spread_multiplier)
	record_timing("blood_burst_spawn_inclusive",start)
	return result
func _add_3d_blood_effect(blood: Node2D,room_id: int,floor_visual: bool=true) -> Node2D:
	var start:=Time.get_ticks_usec()
	var result:=super._add_3d_blood_effect(blood,room_id,floor_visual)
	record_timing("blood_add_bridge_inclusive",start)
	return result
func _refresh_3d_blood_effect_after_setup(blood: Node2D,attach_airborne: bool=false) -> void:
	var start:=Time.get_ticks_usec()
	super._refresh_3d_blood_effect_after_setup(blood,attach_airborne)
	record_timing("blood_refresh_inclusive",start)
