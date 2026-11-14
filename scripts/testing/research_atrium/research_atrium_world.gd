extends "res://scripts/dream/office_skeleton_world_base.gd"
## Authored 1-1 presentation. Formal player/input/combat are retained.
const ATRIUM_LAYOUT := preload("res://scripts/testing/research_atrium/atrium_layout.gd")
const ATRIUM_ART := preload("res://scripts/testing/research_atrium/atrium_cc0_art.gd")
signal level11_completed
var atrium: ATRIUM_ART
var completed := false
var _camera_floor := ATRIUM_LAYOUT.TOP
var _floor_ready := false
var _atrium_view_bias:=Vector2.ZERO

func _ready() -> void:
	set_meta(&"test_floor_reflections_disabled",true)
	configured_weapon_id="basic"
	super._ready()
	player.collision_mask|=ATRIUM_ART.ACTOR_EDGE
	player_has_left_elevator_cab=true
	if is_instance_valid(night_lighting):night_lighting.set_flashlight_enabled(false)
	if is_instance_valid(objective_guidance):objective_guidance.queue_free();objective_guidance=null
	preload("res://scripts/dream/office_light_optics.gd").install(self,true)
	_sync_elevated_actors()
	_update_camera_and_actor_projection(0.0)

func _get_skeleton_source() -> Dictionary:return ATRIUM_LAYOUT.source()
func uses_office_night_lighting() -> bool:return RenderingServer.get_current_rendering_method()=="forward_plus"
func uses_office_wall_cutaway() -> bool:return false
func _choose_elevator_anchor() -> bool:
	spawn_cell=ATRIUM_LAYOUT.ENTRY
	main_entrance={"start_cell":spawn_cell}
	elevator_room_id=-1
	return floor_cells.has(spawn_cell)
func _validate_layout() -> Dictionary:
	var result:=_validate_floor_connectivity()
	result.valid=bool(result.all_floor_reachable) and bool(result.all_room_centers_reachable) and floor_cells.has(spawn_cell)
	return result
func _validate_rendered_edge_nodes() -> void:rendered_edge_failures=0
func _build_floor() -> void:
	atrium=ATRIUM_ART.new(self)
	authored_cutout=atrium.cutout
	atrium.build()
	_floor_ready=true
func _build_walls() -> void:pass
func _build_doors() -> void:pass
func _build_ceiling_lights() -> void:atrium.build_lighting(ceiling_light_root)
func _spawn_random_content() -> void:pass
func _spawn_special_units() -> void:pass
func _spawn_elevator() -> bool:return true
func _prepare_approved_office_art() -> void:get_combat_defense()
func _spawn_room_encounter(_room_id: int) -> void:pass
func _clear_generated_building() -> void:
	_floor_ready=false
	completed=false
	_camera_floor=ATRIUM_LAYOUT.TOP
	_atrium_view_bias=Vector2.ZERO
	atrium=null
	super._clear_generated_building()

func _ground_height(point: Vector2) -> float:return ATRIUM_LAYOUT.height_at(point/CELL_PIXELS)

func _bridge_height(source: Node2D) -> float:
	if source.is_in_group(&"dream_projectiles"):
		var travelled: Variant=source.get("traveled")
		var progress: float=float(travelled) if travelled!=null else 0.0
		if progress<float(source.get_meta(&"atrium_last_travel",INF)):
			source.set_meta(&"atrium_shot_height",_ground_height(source.global_position))
		source.set_meta(&"atrium_last_travel",progress)
		return float(source.get_meta(&"atrium_shot_height",_ground_height(source.global_position)))
	return _ground_height(source.global_position)

func _sync_elevated_actors() -> void:
	if not _floor_ready or not is_instance_valid(player_depth_bridge):return
	var point: Vector2=player.body_collision.global_position
	player_depth_bridge.ground_surface_height=_ground_height(point)
	for bridge: Node in actor_depth_bridges_root.get_children():
		var source: Node2D=bridge.get("source_actor")
		if not is_instance_valid(source):continue
		var height:=_bridge_height(source)
		if bridge.get("character_projection")==true:
			bridge.set("ground_surface_height",height)
		else:
			if not bridge.has_meta(&"atrium_base_height"):bridge.set_meta(&"atrium_base_height",bridge.get("actor_center_height"))
			bridge.set("actor_center_height",float(bridge.get_meta(&"atrium_base_height"))+height)

func _update_camera_and_actor_projection(delta: float=0.0) -> void:
	_sync_elevated_actors()
	super._update_camera_and_actor_projection(delta)
	if not _floor_ready or not is_instance_valid(player):return
	var point: Vector2=player.body_collision.global_position
	var target:=_ground_height(point)
	_camera_floor=move_toward(_camera_floor,target,delta*3.5) if delta>0.0 else target
	camera_rig.position.y+=_camera_floor
	# Compose the upper walk with the first-floor exhibit through the left glass.
	# The local 1-1 framing includes the drop to the ground-floor machine bay.
	var desired: Vector2=(ATRIUM_ART.CENTRE-point/CELL_PIXELS)*.45
	desired=desired.limit_length(1.5)
	_atrium_view_bias=_atrium_view_bias.move_toward(desired,delta*4.0) if delta>0 else desired
	camera_rig.position+=Vector3(_atrium_view_bias.x,0.0,_atrium_view_bias.y)
	var ground:=Vector3(player.global_position.x/CELL_PIXELS,target,player.global_position.y/CELL_PIXELS)
	var screen:=camera_3d.unproject_position(to_global(ground))
	gameplay_canvas.transform=Transform2D(Vector2.RIGHT,Vector2.DOWN,screen-player.global_position)

func get_gameplay_world_position(point: Vector2,height: float=.65) -> Vector3:
	return to_global(Vector3(point.x/CELL_PIXELS,_ground_height(point)+height,point.y/CELL_PIXELS))

func get_gameplay_aim_position() -> Vector2:
	if not is_instance_valid(camera_3d):return player.global_position+Vector2.RIGHT*100
	var mouse: Vector2=player.get_presentation_pointer_position()
	var origin:=camera_3d.project_ray_origin(mouse)
	var direction:=camera_3d.project_ray_normal(mouse)
	var height:=_ground_height(player.body_collision.global_position)
	var point: Variant=Plane(Vector3.UP,height).intersects_ray(origin,direction)
	if point is Vector3:
		var mapped:=to_local(point)
		return Vector2(mapped.x,mapped.z)*CELL_PIXELS
	return player.global_position+player.last_aim_direction*100

func is_player_dash_landing_allowed(position: Vector2) -> bool:
	var start: Dictionary=ATRIUM_LAYOUT.sample(player.body_collision.global_position/CELL_PIXELS)
	var finish: Dictionary=ATRIUM_LAYOUT.sample(position/CELL_PIXELS)
	return absf(float(start.height)-float(finish.height))<1.9 and absf(float(start.progress)-float(finish.progress))<8.0 and floor_cells.has(_cell_for_gameplay_position(position))

func _physics_process(_delta: float) -> void:
	if not _floor_ready or player.dead:return
	_sync_elevated_actors()
	var point: Vector2=player.body_collision.global_position/CELL_PIXELS
	if not completed and point.distance_to(ATRIUM_LAYOUT.EXIT)<.75:
		completed=true
		level11_completed.emit()
