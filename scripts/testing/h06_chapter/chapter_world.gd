extends "res://scripts/testing/h06_chapter/h06_base_world.gd"

const PLAN := preload("res://scripts/testing/h06_chapter/chapter_layout.gd")
const BLOCKOUT := preload("res://scripts/testing/h06_chapter/chapter_art.gd")
const OBSERVATION := preload("res://scripts/testing/h06_chapter/observation_window.gd")
const CRAWLER := preload("res://scripts/testing/h06_chapter/crawler_boss.gd")
const CRAWLER_MOTION := preload("res://scripts/testing/h06_chapter/crawler_motion.gd")
const BAR := preload("res://scripts/testing/metro_station/metro_boss_health.gd")
const FONT := preload("res://scripts/ui/crisp_interaction_font.gd")
const TAROT := preload("res://scripts/story/chapter_tarot.gd")
const WEST_ENCOUNTER := preload("res://scripts/testing/h06_chapter/west_shutter_encounter.gd")
const STAFF_STORY := preload("res://scripts/testing/h06_chapter/chapter_staff_story.gd")
const RETRY_KEY := &"h06_whitebox_pending_retry"
const LIFT_AMBUSH_DELAY := 2.15
const FREIGHT_PLATE_CHAIN_SECONDS := 3.25
signal district_entered(district: int)
signal chapter_completed
enum Stage { GALLERY, GUARD, INSPECTION, ARCHIVE, PUMP, RETURN, SEARCH, CHASE, STAFF, APPROACH, DROP, BOSS, EXIT, DONE }
enum Save { ENTRANCE, OBSERVATION, CALIBRATED, GUARD, INSPECTION, ARCHIVE, PUMP, RETURN_BAY, TRANSFER, CHASE, MIDPOINT, CROSS_DOCK, STAFF, ARMORY, ARENA }
var stage := Stage.GALLERY
var checkpoint := Save.ENTRANCE
var blockout: BLOCKOUT
var on_lower_floor := false
var members: Array[EmployeeEnemy] = []
var wave := ""
var mech_path := Curve2D.new()
var vehicle_obstacles: Array[Rect2]
var forklift_obstacle_index := -1
var forklift_restore_state := {}
var escape_path := Curve3D.new()
var chase_distance := 0.0
var ramp_distance := 0.0
var chase_grace := 0.0
var chase_red_timer := 0.0
var chase_light_red := 0.0
var pursuit_time := 0.0
var breached := false
var armory_stocked := false
var medicine_used := false
var saved_loadout := {}
var jump_time := -1.0
var takeoff := Vector2.ZERO
var landing := Vector2.ZERO
var jump_lift := 0.0
var fall_lift := 0.0
var fall_vel := 0.0
var abyss_falling := false
var freight_elapsed := 0.0
var plate_warning := ""
var _last_plate_fall := -INF
var _next_plate_fall := &"h06_plate_fall"
var climbing := false
var ladder_elapsed := 0.0
var going_down := false
var ladder_start := Vector2.ZERO
var ladder_end := Vector2.ZERO
var discovered := false
var drop_time := 0.0
var drop_origin := Vector3.ZERO
var boss: CRAWLER
var crawler_motion: CRAWLER_MOTION
var boss_bar: BAR
var instruction: Label
var objective := ""
var restart_queued := false
var camera_lead := Vector3.ZERO
var chase_reveal_left := 0.0
var prepared: BLOCKOUT
var previous_feet := Vector2.INF
var room_fill_weight := -1.0
var gate_state := {}
var seen_windows := {}
var unload_queue: Array[WeakRef] = []
const UNLOAD_BATCH_SIZE := 8
var _session_initialized := false
var receiving_shutter_triggered := false
var warehouse_triggered: Dictionary = {}
var warehouse_cleared: Dictionary = {}
var warehouse_squads: Dictionary = {}
var west_shutter_encounter: WEST_ENCOUNTER
var staff_story:=STAFF_STORY.new()
@export var hangar_crew_enabled := true
@export var hangar_crew_activity_enabled := true
var chapter_stream_ready := false
var chapter_stream_receipt := {}
var chapter_staged_regions: Dictionary = {}

func prepare_chapter_streaming(progress:Callable=Callable()) -> Dictionary:
	if chapter_stream_ready:return chapter_stream_receipt
	if not get_meta(&"h06_render_warmup",true):return {"skipped":"disabled"}
	var generation:=get_current_floor_token()
	var receipt:Dictionary=await preload("res://scripts/testing/h06_chapter/stream_render_preparation.gd").run(self,progress)
	if generation!=get_current_floor_token():return {"cancelled":true}
	chapter_stream_receipt=receipt
	chapter_stream_ready=chapter_stream_receipt.get("ready",false)
	return chapter_stream_receipt

func _clear_generated_building() -> void:
	if is_instance_valid(crawler_motion):
		crawler_motion.disable()
		crawler_motion.queue_free()
	crawler_motion = null
	west_shutter_encounter=null
	chapter_stream_ready=false
	chapter_stream_receipt={}
	chapter_staged_regions.clear()
	prepared=null
	unload_queue.clear()
	super._clear_generated_building()

func _ready() -> void:
	super._ready()
	if blockout != null:
		_setup_chapter_session()

func _regenerate_staged(requested_seed: int, target_floor: int, token: int, retain_rollback: bool = false) -> bool:
	var ok := await super._regenerate_staged(requested_seed, target_floor, token, retain_rollback)
	if ok and blockout != null:
		_setup_chapter_session()
		_sync_height_immediate()
	return ok

func _setup_chapter_session() -> void:
	if _session_initialized or not is_instance_valid(player) or blockout == null: return
	_session_initialized = true
	if not campaign_run:
		player.configure_weapon("basic",config,permanent_upgrades)
	player.set_dash_enabled(true)
	vehicle_obstacles = PLAN.crawler_obstacles()
	forklift_obstacle_index = vehicle_obstacles.find(PLAN.PROPS.forklift[0])
	mech_path.clear_points()
	mech_path.bake_interval = .5
	for p in PLAN.CHASE_PATH: mech_path.add_point(p)
	escape_path.clear_points()
	escape_path.bake_interval = .5
	for p in PLAN.FREIGHT_EXIT: escape_path.add_point(p)
	if instruction == null:
		instruction = Label.new()
		instruction.name = "ChapterObjective"
		instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
		instruction.add_theme_font_override(&"font",FONT.get_font())
		instruction.add_theme_font_size_override(&"font_size",12)
		instruction.add_theme_color_override(&"font_outline_color",Color("172126"))
		instruction.add_theme_constant_override(&"outline_size",3)
		run_interface.ui_layer.add_child(instruction)
		instruction.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		instruction.position += Vector2(12,-29)
	var tree := get_tree()
	var resume: Dictionary = tree.get_meta(RETRY_KEY,{})
	if tree.has_meta(RETRY_KEY): tree.remove_meta(RETRY_KEY)
	discovered = resume.get("secret",false)
	for key: String in resume.get("seen",[]): seen_windows[key] = true
	_use_region_cells()
	_restore_checkpoint(int(resume.get("checkpoint",Save.ENTRANCE)))
	ensure_crawler_motion()
	if blockout.visit == PLAN.Visit.WEST:
		_populate_west_warehouse_enemies()
	previous_feet = _feet()
	_update_room_light(previous_feet)
	for key: String in blockout.windows:
		if seen_windows.has(key): blockout.windows[key].finish()
	saved_loadout = resume.get("loadout",{})
	player.helmet_equipped = bool(resume.get("helmet", false))
	if not saved_loadout.is_empty():
		player.configure_weapon("",config,permanent_upgrades)
		for slot: String in ["reserve","active"]:
			var weapon: String = saved_loadout[slot]
			if not weapon.is_empty():
				player.equip_weapon(weapon,config,permanent_upgrades,saved_loadout[slot+"_skin"])
	if has_meta("has_tarot_card") and bool(get_meta("has_tarot_card",false)):
		TAROT.apply(player,str(get_meta("selected_tarot_card_id","")),bool(get_meta("selected_tarot_reversed",false)))

func _get_skeleton_source() -> Dictionary:
	return PLAN.skeleton()

func _build_floor() -> void:
	if get_meta(&"h06_resource_reuse",true):
		# This runs under the normal entry/loading transaction, before control is
		# released. Retain resource prototypes, not live regions or active AI.
		if not has_meta(&"h06_crawler_asset"):set_meta(&"h06_crawler_asset",load(BLOCKOUT.H06_MODEL))
		BLOCKOUT.WAREHOUSE.materials()
		BLOCKOUT.FREIGHT.materials()
		BLOCKOUT.LOGISTICS_HUB.materials()
	for key: String in PLAN.GATES: gate_state[key] = key not in ["cargo_access","refuge","arena","boarding"]
	var resume: Dictionary = get_tree().get_meta(RETRY_KEY,{})
	var save := int(resume.get("checkpoint",Save.ENTRANCE))
	staff_story.restore(resume.get("staff_story",{}))
	forklift_restore_state = resume.get("forklift", {})
	blockout = _plan_region(_checkpoint_region(save))
	while not blockout.build_steps.is_empty(): blockout.prepare_step()
	_art = blockout
	authored_cutout = blockout.cutout
	blockout.set_live(true)

func _build_ceiling_lights() -> void:
	if blockout!=null: blockout.configure_environment()

func _checkpoint_region(save: int) -> PLAN.Visit:
	if save>=Save.STAFF: return PLAN.Visit.STAFF
	if save>=Save.CHASE: return PLAN.Visit.FREIGHT
	if save>=Save.RETURN_BAY: return PLAN.Visit.EMPTY_HANGAR
	if save>=Save.CALIBRATED: return PLAN.Visit.WEST
	return PLAN.Visit.GALLERY

func _plan_region(id: PLAN.Visit) -> BLOCKOUT:
	if chapter_staged_regions.has(id):
		var cached:BLOCKOUT=chapter_staged_regions[id]
		chapter_staged_regions.erase(id)
		return cached
	var area := BLOCKOUT.new(self,true)
	area.plan_region(id,gate_state)
	return area

func _use_region_cells() -> void:
	floor_cells = PLAN.visit_cells(blockout.visit)
	room_cells.clear()
	for cell: Vector2i in floor_cells: room_cells[cell] = 0
	presentation_floor_cells = floor_cells.duplicate()
	rooms[0].shape_cells = floor_cells.keys()
	corridor_cells.clear()
	employee_path_cache.clear()
	district_entered.emit(blockout.region)
	blockout.activate_hangar_crew()
	if is_instance_valid(blockout.evacuation): blockout.evacuation.activate()
	if is_instance_valid(player) and is_instance_valid(player.body_collision):
		_update_room_light(_feet())

func _can_enter_next() -> bool:
	match blockout.visit:
		PLAN.Visit.GALLERY: return not on_lower_floor and checkpoint>=Save.OBSERVATION
		PLAN.Visit.WEST: return stage==Stage.RETURN and on_lower_floor
		PLAN.Visit.EMPTY_HANGAR: return stage==Stage.SEARCH and on_lower_floor and not gate_state.cargo_access
		PLAN.Visit.FREIGHT: return stage==Stage.CHASE
		PLAN.Visit.STAFF: return stage==Stage.APPROACH
	return false

func _update_passage(p: Vector2) -> void:
	if not _can_enter_next(): return
	var id := blockout.visit
	var cross := PLAN.passage_coordinates(id,p)
	var half_width: float = PLAN.PASSAGES[id].width*.5
	if prepared==null:
		if absf(cross.y)>half_width+3 or cross.x < -8: return
		if cross.x>0 and not PLAN.visit_contains(id+1,p,on_lower_floor): return
		prepared = _plan_region(id+1)
		_add_landing_cells(id)
	var crossed := cross.x
	if is_instance_valid(player.mounted_vehicle):
		var hull: Rect2 = blockout.forklift.get_obstacle_rect()
		var mouth: Dictionary = PLAN.PASSAGES[id]
		crossed = (hull.get_center() - mouth.at).dot(mouth.forward) - hull.size.dot((mouth.forward as Vector2).abs()) * 0.5
	if crossed<PLAN.ENTRY_DEPTH or not PLAN.visit_contains(id+1,p,on_lower_floor): return
	var approach := PLAN.passage_coordinates(id,previous_feet)
	var t := clampf(inverse_lerp(approach.x,cross.x,PLAN.ENTRY_DEPTH),0,1) if cross.x>approach.x else 1.0
	if absf(lerpf(approach.y,cross.y,t))<=half_width: _enter_prepared()

func _add_landing_cells(id: int) -> void:
	# Ordinary rolls also consult the shared floor grid. Authorize only their landing strip before reveal.
	var gate: Dictionary = PLAN.PASSAGES[id]
	var center: Vector2 = gate.at
	var reach := ceili(player.dash_distance/CELL_PIXELS)+2
	for z in range(floori(center.y)-reach,ceili(center.y)+reach+1):
		for x in range(floori(center.x)-reach,ceili(center.x)+reach+1):
			var cell := Vector2i(x,z)
			var at := Vector2(cell)
			var cross := PLAN.passage_coordinates(id,at)
			if cross.x<-.5 or cross.x>reach or absf(cross.y)>float(gate.width)*.5+.6: continue
			if PLAN.visit_contains(id+1,at,gate.height==0.0):
				floor_cells[cell] = &"building"
				room_cells[cell] = 0

func _enter_prepared() -> void:
	while not prepared.build_steps.is_empty(): prepared.prepare_step()
	var previous := blockout
	var travelling: Variant = previous.forklift
	if is_instance_valid(travelling) and travelling.driver == player:
		previous.forklift = null
		travelling.visual.set_driver_onboard(false)
		travelling.transfer_to(collision_root, self)
	else:
		travelling = null
	if previous.visit in [PLAN.Visit.FREIGHT,PLAN.Visit.STAFF]:
		prepared.take_crawler(previous)
	previous.cutout.clear_slots()
	previous.set_live(false)
	for root: Node in [previous.floor_root,previous.wall_root,previous.lights_root,previous.physics_root]:
		unload_queue.append(weakref(root))
		# Retire the large atrium a few pieces per frame, including its collision and lights.
		for child in root.get_children(): unload_queue.append(weakref(child))
	_retire_room_content()
	blockout = prepared
	prepared = null
	_last_plate_fall = -INF
	_next_plate_fall = &"h06_plate_fall"
	_art = blockout
	authored_cutout = blockout.cutout
	blockout.set_lower(on_lower_floor)
	blockout.set_live(true)
	if is_instance_valid(travelling):
		travelling.transfer_to(blockout.physics_root, blockout.floor_root)
		blockout.forklift = travelling
		blockout.cutout.register_tree(travelling.visual, true)
		travelling.visual.set_driver_onboard(true)
	if blockout.visit==PLAN.Visit.EMPTY_HANGAR: blockout.play_spotlight_reveal(true)
	_use_region_cells()
	match blockout.visit:
		PLAN.Visit.WEST:
			_claim_staged_warehouse_people(blockout)
			_populate_west_warehouse_enemies()
			_prompt("驾驶叉车冲破西侧警戒栏杆")
		PLAN.Visit.FREIGHT:
			checkpoint = maxi(checkpoint,Save.TRANSFER)
			_prompt("穿过收件台，前往分拣厅")
		PLAN.Visit.ARENA:
			blockout.ensure_chase_crawler()
			blockout.mech.hide()
			chase_distance = mech_path.get_baked_length()
			ramp_distance = escape_path.get_baked_length()
			_prompt("登上货运平台")

func _retire_room_content() -> void:
	_layout_generation += 1
	west_shutter_encounter=null
	warehouse_squads.clear()
	warehouse_triggered.clear()
	warehouse_cleared.clear()
	var potions := floor_root.get_node_or_null("ScientistPotions")
	if is_instance_valid(potions): potions.clear_region()
	_clear_world_interaction_target()
	_clear_room_transition_transients()
	_clear_muzzle_and_burning_vfx()
	_cached_enemy_cutout_slots.clear()
	_cached_enemy_cutout_dists.clear()
	_last_cutout_slots.clear()
	pending_enemy_pickup_requests.clear()
	_settled_blood_buckets.clear()
	var retiring := {}
	for root: Node in [enemy_root,furniture_root,world_weapon_root,pickup_root,key_root,ground_debris_root,world_effects_root]:
		for node in root.get_children():
			if node==dash_aim_presentation: continue
			if prepared!=null and int(node.get_meta(&"h06_staged_visit",-1))==int(prepared.visit):continue
			retiring[node.get_instance_id()] = true
			if node is CanvasItem or node is Node3D: node.hide()
			node.process_mode = Node.PROCESS_MODE_DISABLED
			unload_queue.append(weakref(node))
	for bridge in actor_depth_bridges_root.get_children():
		var actor: Variant = bridge.get_meta(&"source_actor") if bridge.has_meta(&"source_actor") else null
		if is_instance_valid(actor) and retiring.has(actor.get_instance_id()):
			bridge.hide()
			if bridge.has_method("set_room_presentation_active"): bridge.set_room_presentation_active(false)

func _process(delta: float) -> void:
	super._process(delta)
	if get_meta(&"h06_streaming_budget",true):
		_prepare_ahead()
		if prepared!=null:prepared.prepare_budget(1500)
		_drain_retired_region()
		return
	if prepared!=null: prepared.prepare_step()
	for i in mini(UNLOAD_BATCH_SIZE,unload_queue.size()):
		var ref: WeakRef = unload_queue.pop_back()
		var node: Node = ref.get_ref()
		if is_instance_valid(node) and not node.is_queued_for_deletion(): node.queue_free()

func _prepare_ahead() -> void:
	if prepared!=null or blockout==null:return
	var wanted:=false
	match blockout.visit:
		PLAN.Visit.GALLERY:wanted=checkpoint>=Save.OBSERVATION
		PLAN.Visit.WEST:wanted=stage==Stage.RETURN or checkpoint>=Save.PUMP
		PLAN.Visit.EMPTY_HANGAR:wanted=stage==Stage.SEARCH
	if wanted:
		prepared=_plan_region(blockout.visit+1)
		_add_landing_cells(blockout.visit)

func _drain_retired_region() -> void:
	var started:=Time.get_ticks_usec()
	var released:=0
	while not unload_queue.is_empty() and released<UNLOAD_BATCH_SIZE:
		var reference:WeakRef=unload_queue.pop_back()
		var node:Node=reference.get_ref()
		if not is_instance_valid(node) or node.is_queued_for_deletion():continue
		# Imported geometry containers can own hundreds of meshes. Peel their
		# leaves, while gameplay scripts keep their original atomic exit lifecycle.
		var children:Array[Node]=[]
		if node.get_script()==null:
			for child in node.get_children():
				if not child.is_queued_for_deletion():children.append(child)
		if not children.is_empty():
			unload_queue.append(weakref(node))
			for child in children:unload_queue.append(weakref(child))
		else:
			node.queue_free()
			released+=1
		if Time.get_ticks_usec()-started>=1500:break

func _floor_height_at(p: Vector2) -> float:
	if blockout != null and is_instance_valid(blockout.forklift) and blockout.forklift.driver == player:
		return blockout.forklift.floor_height + blockout.forklift.MODEL.FOOTWELL_Y
	if climbing: return _ladder_height()
	if on_lower_floor and is_instance_valid(player) and is_instance_valid(player.body_collision):
		# The sprite pivot sits behind the collision feet. On the shallow treads that offset is visible.
		return PLAN.lower_height(_feet())+jump_lift+fall_lift
	return PLAN.upper_height(p)+jump_lift+fall_lift if not on_lower_floor else jump_lift+fall_lift

func get_gameplay_world_position(point: Vector2,height: float=.65) -> Vector3:
	var base := _ladder_height() if climbing else (PLAN.lower_height(point/CELL_PIXELS) if on_lower_floor else PLAN.upper_height(point/CELL_PIXELS))
	return super.get_gameplay_world_position(point,height+base)

func _spawn_depth_bridge(source: Node2D,paths: Variant,offset: Vector2=Vector2(64,96),
		billboard: BaseMaterial3D.BillboardMode=BaseMaterial3D.BILLBOARD_ENABLED,center: float=.70710678,
		depth: float=-.70710678,rotation_override: Vector3=Vector3.ZERO,disable_clone: bool=false,
		force_lit: bool=false,follow_rotation: bool=false,register_meta: bool=true) -> Node3D:
	var at := source.global_position/CELL_PIXELS
	var y := PLAN.lower_height(at) if on_lower_floor else PLAN.upper_height(at)
	var actor := source is EmployeeEnemy or source == player
	var bridge := super._spawn_depth_bridge(source,paths,offset,billboard,center if actor else center+y,
		depth,rotation_override,disable_clone,force_lit,follow_rotation,register_meta)
	if is_instance_valid(bridge) and actor: bridge.ground_surface_height = y
	return bridge

func _feet() -> Vector2:
	return player.body_collision.global_position / CELL_PIXELS

func _place_feet(p: Vector2) -> void:
	player.global_position += p*CELL_PIXELS - player.body_collision.global_position
	player.velocity = Vector2.ZERO

func _set_lower(enabled: bool) -> void:
	on_lower_floor = enabled
	blockout.set_lower(enabled)

func _prompt(message: String) -> void:
	objective = message
	if is_instance_valid(instruction): instruction.text = message

func _update_room_light(p: Vector2) -> void:
	# The roofed rooms lose the open hangar's sky fill across their doorways.
	var weight := 0.0
	if blockout.visit==PLAN.Visit.FREIGHT:
		weight = 0.88
	elif blockout.visit==PLAN.Visit.STAFF:
		weight = 0.78
	elif not on_lower_floor:
		if blockout.visit==PLAN.Visit.GALLERY:
			weight = smoothstep(8.65,12.55,-p.y)
		elif blockout.visit==PLAN.Visit.WEST and p.y<PLAN.UPPER.calibration.end.y+2.60:
			weight = smoothstep(PLAN.UPPER.calibration.position.x-1.65,PLAN.UPPER.calibration.position.x+1.65,p.x)
	if is_equal_approx(room_fill_weight,weight): return
	room_fill_weight = weight
	var env: Environment = get_node("Lighting/WorldEnvironment").environment
	env.ambient_light_energy = lerpf(BLOCKOUT.HANGAR_AMBIENT,.024,weight)
	env.ambient_light_color = BLOCKOUT.HANGAR_AMBIENT_COLOUR.lerp(Color("93a5b2"),minf(weight,1.0))
	var key: DirectionalLight3D = get_node("Lighting/KeyLight")
	key.light_energy = lerpf(BLOCKOUT.HANGAR_KEY,.038,weight)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_instance_valid(instruction) or player.dead or restart_queued:
		if blockout != null and is_instance_valid(blockout.inclined_lift):
			blockout.inclined_lift.stop_travel_audio()
		return
	_sync_forklift_obstacle()
	if climbing:
		_tick_ladder(delta)
		return
	var p := _feet()
	if blockout.region==PLAN.Region.GALLERY:
		blockout.service_view(on_lower_floor,p)
	_update_passage(p)
	if blockout.inclined_lift != null:
		blockout.inclined_lift.advance(delta)
	_update_room_light(p)
	if not on_lower_floor and blockout.visit in [PLAN.Visit.GALLERY,PLAN.Visit.WEST]:
		blockout.update_west_threshold(p,delta)
	_check_forklift_calibration_breach()
	if blockout.visit==PLAN.Visit.WEST and west_shutter_encounter!=null:
		west_shutter_encounter.tick(p,delta)
	if blockout.visit==PLAN.Visit.WEST and on_lower_floor and p.x < -27.5 and not receiving_shutter_triggered:
		_trigger_receiving_shutter()
	if blockout.visit==PLAN.Visit.FREIGHT:
		freight_elapsed += delta
		blockout.tick_freight_effects(delta,freight_elapsed)
		_tick_freight_plates(delta,p)
		_tick_freight_containers(delta,p)
		if abyss_falling: return
	previous_feet = p
	if on_lower_floor: blockout.reveal_hoist_floor(p)
	var viewing: OBSERVATION
	for room: String in blockout.windows:
		var window = blockout.windows[room]
		if PLAN.UPPER.has(room)==on_lower_floor or (room=="transfer_floor" and stage!=Stage.CHASE): continue
		if window.viewing_area.has_point(p):
			viewing = window
			window.approach()
			seen_windows[room] = true
	_frame_encounter(p,delta,viewing)
	match stage:
		Stage.GALLERY:
			if checkpoint==Save.ENTRANCE and PLAN.UPPER.observation.has_point(p):
				checkpoint = Save.OBSERVATION
				_prompt("从监控室北侧进入西翼检验区")
			if blockout.visit==PLAN.Visit.WEST and not gate_state.calibration and PLAN.UPPER.guard.has_point(p):
				_start_wave("guard",Stage.GUARD,Save.GUARD)
		Stage.GUARD,Stage.INSPECTION,Stage.ARCHIVE,Stage.PUMP:
			_tick_rooms(p)
		Stage.RETURN:
			if not on_lower_floor and PLAN.UPPER.landing.has_point(p): _set_lower(true)
			if blockout.visit==PLAN.Visit.EMPTY_HANGAR and on_lower_floor:
				stage = Stage.SEARCH
				checkpoint = Save.RETURN_BAY
				_prompt("机位空了　·　从南门进入货运区")
		Stage.SEARCH:
			if blockout.visit==PLAN.Visit.FREIGHT and p.y>=19.1 and PLAN.LOWER.west_bank.has_point(p):
				_start_chase(Save.CHASE)
		Stage.CHASE:
			_update_traversal(delta,p)
			blockout.reveal_roll_opening(p)
			if p.x >= 10.0 and PLAN.LOWER.loading.has_point(p) and checkpoint<Save.MIDPOINT:
				checkpoint = Save.MIDPOINT
			if p.x >= 60 and PLAN.LOWER.transfer_floor.has_point(p) and checkpoint<Save.CROSS_DOCK:
				checkpoint = Save.CROSS_DOCK
			if blockout.visit==PLAN.Visit.STAFF:
				stage = Stage.STAFF
				checkpoint = Save.STAFF
				if not blockout.freight_searchlight.is_empty():
					var sl_root := blockout.freight_searchlight.get("root") as Node3D
					if is_instance_valid(sl_root): sl_root.visible = false
				blockout.set_gate("refuge",true)
				_stock_armory()
				_prompt("物流中枢　·　穿行各功能舱室休整，北出口东北角武器库整备后前往电梯")
			else:
				_advance_chase(delta,p)
		Stage.STAFF:
			if checkpoint==Save.STAFF and PLAN.LOWER.clinic.has_point(p):
				checkpoint = Save.ARMORY
				_remember_weapons()
				_prompt("医务室可治疗　·　穿越物流大厅前往北出口旁武器库换装")
			if PLAN.LOWER.duty.has_point(p):
				checkpoint = Save.ARENA
				stage = Stage.APPROACH
				player.heal(player.maximum_health*.35)
				_remember_weapons()
				_prompt("北出口大厅　·　可在东北角武器库换枪后北门前往电梯大厅")
		Stage.APPROACH:
			_update_boss_approach(p)
		Stage.DROP:
			_update_drop(delta)
		Stage.EXIT:
			if blockout.inclined_lift.travel==BLOCKOUT.INCLINED_LIFT.Travel.UPPER:
				_finish_platform_ride()
	if stage in [Stage.STAFF,Stage.APPROACH]: _run_to_roof(delta)
	if stage in [Stage.GALLERY,Stage.SEARCH,Stage.STAFF,Stage.APPROACH]:
		var console := _nearby_console(p)
		instruction.text = str(CONSOLE_HINTS[console]) if not console.is_empty() else objective
	if is_instance_valid(blockout.forklift):
		var driving_hint := blockout.forklift.get_control_hint(player)
		if not driving_hint.is_empty(): instruction.text = driving_hint

func is_vehicle_floor_supported(point: Vector2) -> bool:
	if blockout == null: return false
	if blockout.visit == PLAN.Visit.WEST and PLAN.UPPER.stair.has_point(point): return true
	if not PLAN.visit_contains(blockout.visit,point,on_lower_floor):
		if prepared == null or not _can_enter_next() or not PLAN.visit_contains(blockout.visit+1,point,on_lower_floor): return false
		var cross := PLAN.passage_coordinates(blockout.visit,point)
		if cross.x < -0.2 or cross.x > 4.0 or absf(cross.y) > float(PLAN.PASSAGES[blockout.visit].width) * 0.5: return false
	return not PLAN.LOWER.pit.has_point(point) or PLAN.TRENCH_BRIDGE.has_point(point)

func get_vehicle_floor_height(point: Vector2) -> float:
	if blockout.visit == PLAN.Visit.WEST and PLAN.UPPER.stair.has_point(point): return PLAN.upper_height(point)
	return PLAN.lower_height(point) if on_lower_floor else PLAN.upper_height(point)

func _sync_forklift_obstacle() -> void:
	if is_instance_valid(blockout.forklift) and not blockout.forklift.destroyed and blockout.forklift.floor_height < 0.2:
		var footprint := blockout.forklift.get_obstacle_rect()
		if forklift_obstacle_index < 0:
			forklift_obstacle_index = vehicle_obstacles.size()
			vehicle_obstacles.append(footprint)
		else:
			vehicle_obstacles[forklift_obstacle_index] = footprint
	elif forklift_obstacle_index >= 0:
		vehicle_obstacles.remove_at(forklift_obstacle_index)
		forklift_obstacle_index = -1

func _update_world_weapon_interaction() -> void:
	if is_instance_valid(player) and is_instance_valid(player.mounted_vehicle):
		_clear_world_interaction_target()
		return
	super._update_world_weapon_interaction()

const CONSOLE_HINTS := {"clinic":"E　使用急救台",
	"hatch_down":"E　拉开踏板","hatch_up":"E　爬回展廊","prototype":"E　运行步态试验"}

func _nearby_console(p: Vector2) -> String:
	if blockout.visit==PLAN.Visit.GALLERY:
		if not on_lower_floor and p.distance_to(PLAN.HATCH)<1.14: return "hatch_down"
		if on_lower_floor and p.distance_to(PLAN.LADDER_FOOT)<1.28: return "hatch_up"
	if blockout.region==PLAN.Region.GALLERY and on_lower_floor and p.distance_to(PLAN.MODEL_BENCH+Vector2(0,1.3))<1.50: return "prototype"
	if stage in [Stage.STAFF,Stage.APPROACH] and not medicine_used and p.distance_to(PLAN.MEDICINE)<1.65:
		return "clinic"
	return ""

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or not is_instance_valid(player) or player.dead: return
	if event.physical_keycode!=KEY_E and event.keycode!=KEY_E: return
	var console := _nearby_console(_feet())
	if console.is_empty() or climbing: return
	get_viewport().set_input_as_handled()
	blockout.signal_used(console)
	match console:
		"hatch_down","hatch_up":
			_start_ladder(console=="hatch_down")
			return
		"prototype":
			discovered = true
			blockout.run_service_model()
			return
		"clinic":
			player.heal(player.maximum_health)
			medicine_used = true
			_prompt("已完成治疗　·　经中央分拣大厅北上前往出口旁武器库")
	SFX.play_event(&"heal" if console=="clinic" else &"confirm")

func _stock_armory() -> void:
	if armory_stocked: return
	armory_stocked = true
	for weapon: String in PLAN.RACK:
		var where: Vector2 = PLAN.RACK[weapon]
		var pickup = WORLD_WEAPON_SCENE.instantiate()
		pickup.position = (where+Vector2(0,.38))*CELL_PIXELS
		world_weapon_root.add_child(pickup)
		pickup.configure(weapon)
		pickup.freeze = true
		pickup.set_meta(&"dream_room_id",0)
		pickup.set_meta(&"content_kind",&"encounter_weapon_drop")
		pickup.set_room_runtime_active(true)
		var bridge = _spawn_depth_bridge(pickup,[^"WeaponSprite"])
		bridge.actor_center_height += .56
		pickup.set_meta(&"on_armory_shelf",true)
	_notify_room_weapon_available(0)

func _swap_world_weapon(pickup: Node2D) -> void:
	var on_shelf := is_instance_valid(pickup) and pickup.has_meta(&"on_armory_shelf")
	var previous := String(pickup.get("weapon_id")) if on_shelf else ""
	super._swap_world_weapon(pickup)
	if not on_shelf or pickup.is_queued_for_deletion() or String(pickup.get("weapon_id"))==previous: return
	# The shared swap reuses this pickup for the discarded gun on the floor.
	pickup.remove_meta(&"on_armory_shelf")
	pickup.set("freeze",false)
	var bridge = pickup.get_meta(&"depth_visual_bridge").get_ref()
	if is_instance_valid(bridge): bridge.actor_center_height -= .56
	_remember_weapons()

func _remember_weapons() -> void:
	var active: String = player.selected_weapon_id
	var reserve: String = player.melee_weapon_id if active==player.ranged_weapon_id else player.ranged_weapon_id
	saved_loadout = {"active":active,"reserve":reserve,"active_skin":player.get_weapon_skin_index(active),"reserve_skin":player.get_weapon_skin_index(reserve)}

func _frame_encounter(feet: Vector2,delta: float,viewing: OBSERVATION) -> void:
	# Window performances keep playing, but 1-2 through 1-4 retain the normal follow camera.
	if blockout.visit in [PLAN.Visit.WEST, PLAN.Visit.EMPTY_HANGAR, PLAN.Visit.FREIGHT, PLAN.Visit.STAFF]:
		camera_lead = Vector3.ZERO
		authoritative_camera_fov = GAMEPLAY_CAMERA_FOV
		return
	var look := Vector3.ZERO
	var lens := GAMEPLAY_CAMERA_FOV
	var ground := Vector3(feet.x,0,feet.y)
	if is_instance_valid(viewing) and not (stage==Stage.CHASE and viewing.room=="west_bank"):
		var behind_glass := Vector3(viewing.position.x,0,viewing.position.z-2.8)
		look = ((behind_glass-ground)*.56).limit_length(5.5)
		lens = 46
	elif on_lower_floor and blockout.region==PLAN.Region.GALLERY and PLAN.LOWER.secret.has_point(feet):
		look = ((Vector3(17.3,0,-2.65)-ground)*.41).limit_length(2.20)
		lens = 52
	elif stage==Stage.STAFF and (PLAN.LOWER.canteen.has_point(feet) or PLAN.LOWER.lockers.has_point(feet)):
		lens = 49
	elif stage==Stage.GALLERY and not on_lower_floor and blockout.visit==PLAN.Visit.GALLERY and _spotlight_triggered and PLAN.UPPER.east.has_point(feet):
		look = (blockout.mech.position-ground).limit_length(3.4)
		lens = 44
	elif stage==Stage.SEARCH and PLAN.LOWER.hangar.has_point(feet):
		var empty_bay := PLAN.ATRIUM.H06_BAY_RECT.get_center()
		look = (Vector3(empty_bay.x,0,empty_bay.y)-ground).limit_length(2.8)
		lens = 43
	elif stage==Stage.CHASE:
		chase_reveal_left = maxf(0,chase_reveal_left-delta)
		var reveal := smoothstep(0.0,.85,chase_reveal_left)
		look = (blockout.mech.position-ground).limit_length(6.4)*reveal
		lens = lerpf(43,58,reveal)
	elif blockout.inclined_lift != null:
		var center := PLAN.ARENA_DECK.get_center()
		var focus := Vector3(center.x,0,center.y)
		lens = 72
		if stage==Stage.BOSS and is_instance_valid(boss) and boss.attacks!=null:
			var mech_at := blockout.mech.position
			focus = Vector3(mech_at.x,0.,mech_at.z).lerp(focus,.28)
			lens = 70 if crawler_motion.jump==CRAWLER_MOTION.Jump.FLIGHT else 66
		look = ((focus-ground)*.51).limit_length(8.)
		if stage==Stage.APPROACH and blockout.inclined_lift.is_docked:
			var approach := 1.-smoothstep(1.5,8.,feet.y-PLAN.LIFT_ENTRY.y)
			look = Vector3(0.,0.,-3.5).lerp(look,approach)
			lens = lerpf(56.,lens,approach)
	var weight := 1.0-exp(-delta*5.5)
	camera_lead = camera_lead.lerp(look,weight)
	authoritative_camera_fov = lerpf(authoritative_camera_fov,lens,weight)

func _update_camera_and_actor_projection(delta: float=0.0) -> void:
	super._update_camera_and_actor_projection(delta)
	if not is_instance_valid(player): return
	var offset := camera_lead
	if blockout != null and blockout.inclined_lift != null:
		var deck_heave := blockout.inclined_lift.deck_vertical_offset
		if not is_zero_approx(deck_heave) and _screen_shake_enabled():
			offset.y -= deck_heave
	if offset.length_squared()<.00001: return
	camera_rig.position += offset
	var foot := _player_ground_anchor_position()
	var ground := to_global(Vector3(foot.x/CELL_PIXELS,_floor_height_at(foot/CELL_PIXELS),foot.y/CELL_PIXELS))
	var screen := camera_3d.unproject_position(ground)
	gameplay_canvas.transform.origin = screen-foot

func _check_forklift_calibration_breach() -> void:
	if blockout.visit != PLAN.Visit.WEST or on_lower_floor or not gate_state.get("calibration", false):
		return
	if not is_instance_valid(blockout.forklift) or not is_instance_valid(blockout.forklift.driver):
		return
	var hull: Rect2 = blockout.forklift.get_obstacle_rect()
	if absf(blockout.forklift.speed) < 0.75 or not hull.intersects(PLAN.GATES.calibration.grow(0.55)):
		return
	blockout.set_gate("calibration", false)
	checkpoint = maxi(checkpoint, Save.CALIBRATED)
	SFX.play_world_sfx_3d(&"wall_break", Vector3(-12.5, 4.0, -29.1), 1.8)
	request_camera_impulse(&"heavy", Vector2.LEFT)
	if has_method("_firearm_fx"):
		var fx: Variant = _firearm_fx()
		if is_instance_valid(fx):
			fx.impact(get_gameplay_world_position(PLAN.GATES.calibration.get_center() * CELL_PIXELS, 0.85), Vector3.RIGHT, &"metal", 1.35, 0.45)
	if not warehouse_triggered.has("guard"):
		_start_wave("guard", Stage.GUARD, Save.GUARD)
	else:
		_prompt("栏杆已冲破　·　沿黄色跑道清剿仓库目标")

func _west_upper_bounds() -> Rect2:
	var bounds := Rect2(-46.0,-37.0,33.5,34.0)
	if blockout.visit==PLAN.Visit.WEST and (blockout.is_west_shutter_open("inspection") or blockout.is_west_shutter_open("archive")):
		bounds.size.x += bounds.position.x - (-49.2)
		bounds.position.x = -49.2
	return bounds

func _west_receiving_bounds() -> Rect2:
	var bounds: Rect2 = PLAN.LOWER.receiving
	var left_x := float(PLAN.WEST_SHUTTER_BAYS.receiving.pocket_x)
	bounds.size.x += bounds.position.x - left_x
	bounds.position.x = left_x
	return bounds

func _settle_preplaced_employee(unit: EmployeeEnemy) -> void:
	if unit.sky_drop_active:
		unit.sky_drop_height = 0.0
		unit.sky_drop_delay_left = 0.0
		unit.sky_drop_vertical_velocity = 0.0
		unit.sky_drop_active = false
		unit.character_visual.position = unit.character_visual_base_position
		unit.weapon_root.position = unit.weapon_root_base_position
		if not unit.held_weapon_id.is_empty():
			unit.weapon_root.show()
		unit._restore_sky_drop_collision()

func _spawn_warehouse_squad(key: String, specs: Array, bounds: Rect2, visible_in_room: bool, floor_override := -1.0) -> void:
	var squad: Array[EmployeeEnemy] = []
	var room_bounds := Rect2(bounds.position * CELL_PIXELS, bounds.size * CELL_PIXELS).grow(-6)
	for spec: Array in specs:
		var archetype: StringName = spec[2] if spec.size() > 2 else &"employee"
		var unit := _spawn_regular_employee(0, spec[0] * CELL_PIXELS, archetype, false, spec[1])
		if not is_instance_valid(unit):
			continue
		unit.set_room_bounds(room_bounds)
		_settle_preplaced_employee(unit)
		unit.hostile = false
		unit.state = EmployeeEnemy.State.NEUTRAL_WANDER
		unit.set_room_runtime_active(false)
		unit.room_preview_visible = visible_in_room
		unit._apply_player_vision_visibility()
		if floor_override >= 0.0 and unit.has_meta(&"depth_visual_bridge"):
			var bridge: Variant = unit.get_meta(&"depth_visual_bridge").get_ref()
			if is_instance_valid(bridge):
				bridge.ground_surface_height = floor_override
		squad.append(unit)
	warehouse_squads[key] = squad

func _warehouse_squad_specs(key:String)->Array:
	for door:String in WEST_ENCOUNTER.DOORS:
		if key==door:return WEST_ENCOUNTER.spawn_specs(door)
		if key==WEST_ENCOUNTER.SECOND_KEYS[door]:return WEST_ENCOUNTER.spawn_specs(door,true)
	return PLAN.WEST_SHUTTER_BAYS.receiving.spawns if key=="receiving" else PLAN.WAVES[key]

func _populate_west_warehouse_enemies() -> void:
	if blockout.visit != PLAN.Visit.WEST:
		return
	var upper_bounds := Rect2(-49.2, -37.0, 36.7, 34.0)
	for zone_key: String in ["guard", "inspection", "archive", "pump"]:
		if warehouse_cleared.has(zone_key) or warehouse_triggered.has(zone_key) or warehouse_squads.has(zone_key):
			continue
		var show_now := zone_key in ["guard", "pump"]
		_spawn_warehouse_squad(zone_key, _warehouse_squad_specs(zone_key), upper_bounds, show_now)
	if not (warehouse_cleared.has("inspection") and warehouse_cleared.has("archive")):
		for door:String in WEST_ENCOUNTER.DOORS:
			var key:String=WEST_ENCOUNTER.SECOND_KEYS[door]
			if not warehouse_squads.has(key):_spawn_warehouse_squad(key,_warehouse_squad_specs(key),upper_bounds,false)
	if not receiving_shutter_triggered and not warehouse_squads.has("receiving"):
		_spawn_warehouse_squad("receiving", PLAN.WEST_SHUTTER_BAYS.receiving.spawns, _west_receiving_bounds(), false, 0.0)
	west_shutter_encounter=WEST_ENCOUNTER.new()
	west_shutter_encounter.configure(self)

func stage_warehouse_people(area: BLOCKOUT) -> void:
	if area.visit!=PLAN.Visit.WEST or not area.staged_warehouse_squads.is_empty():return
	var previous:Dictionary=warehouse_squads
	var count:=enemy_count
	warehouse_squads={}
	var bounds:=Rect2(-49.2,-37.0,36.7,34.0)
	for key:String in ["guard","inspection","archive","pump"]:_spawn_warehouse_squad(key,_warehouse_squad_specs(key),bounds,true,3.04)
	for door:String in WEST_ENCOUNTER.DOORS:
		var key:String=WEST_ENCOUNTER.SECOND_KEYS[door]
		_spawn_warehouse_squad(key,_warehouse_squad_specs(key),bounds,true,3.04)
	_spawn_warehouse_squad("receiving",PLAN.WEST_SHUTTER_BAYS.receiving.spawns,_west_receiving_bounds(),true,0.0)
	area.staged_warehouse_squads=warehouse_squads
	warehouse_squads=previous
	enemy_count=count
	for squad:Array in area.staged_warehouse_squads.values():
		for unit:EmployeeEnemy in squad:
			unit.set_meta(&"h06_staged_visit",int(PLAN.Visit.WEST))
			# Future sources stay in their canonical containers so their capture
			# bridges survive. Keep them outside the current room's wake/sound API.
			unit.set_meta(&"dream_room_id",-1)
			var reference:WeakRef=unit.get_meta(&"depth_visual_bridge")
			if is_instance_valid(reference.get_ref()):reference.get_ref().set_meta(&"dream_room_id",-1)

func _claim_staged_warehouse_people(area: BLOCKOUT) -> void:
	if area.staged_warehouse_squads.is_empty():return
	warehouse_squads=area.staged_warehouse_squads
	area.staged_warehouse_squads={}
	for key:String in warehouse_squads:
		for unit:EmployeeEnemy in warehouse_squads[key]:
			unit.remove_meta(&"h06_staged_visit")
			unit.set_meta(&"dream_room_id",0)
			unit.add_to_group(&"dream_enemies")
			unit.add_to_group(&"employee_enemies")
			unit.room_preview_visible=key in ["guard","pump"]
			unit._apply_player_vision_visibility()
			var reference:WeakRef=unit.get_meta(&"depth_visual_bridge")
			if is_instance_valid(reference.get_ref()):
				reference.get_ref().set_meta(&"dream_room_id",0)
				reference.get_ref().set_room_presentation_active(true)
			enemy_count+=1

func _activate_warehouse_squad(key: String, bounds: Rect2, track_members: bool) -> void:
	if not warehouse_squads.has(key):
		var specs: Array = _warehouse_squad_specs(key)
		_spawn_warehouse_squad(key, specs, bounds, true, 0.0 if key == "receiving" else -1.0)
	var room_bounds := Rect2(bounds.position * CELL_PIXELS, bounds.size * CELL_PIXELS).grow(-6)
	for unit: EmployeeEnemy in warehouse_squads.get(key, []):
		if not is_instance_valid(unit) or unit.dead:
			continue
		unit.set_room_bounds(room_bounds)
		unit.set_room_runtime_active(true)
		unit.hostile = true
		unit._remember_target_position(player.global_position, 0)
		unit.state = EmployeeEnemy.State.ATTACK_PLAYER
		if track_members and not members.has(unit):
			members.append(unit)

func _start_wave(key: String,next: Stage,save: Save) -> void:
	if key in WEST_ENCOUNTER.DOORS and west_shutter_encounter!=null:
		west_shutter_encounter.start()
		return
	stage = next
	var safe_save:=save
	if key=="pump" and west_shutter_encounter!=null and not west_shutter_encounter.finished():safe_save=Save.GUARD
	checkpoint = maxi(checkpoint,safe_save)
	wave = key
	warehouse_triggered[key] = true
	var alive: Array[EmployeeEnemy] = []
	for u: EmployeeEnemy in members:
		if is_instance_valid(u) and not u.dead: alive.append(u)
	members = alive
	if blockout.visit==PLAN.Visit.WEST and PLAN.WEST_SHUTTER_BAYS.has(key):
		blockout.open_west_shutter(key)
		var bay: Dictionary = PLAN.WEST_SHUTTER_BAYS[key]
		SFX.play_world_sfx_3d(&"wall_break",Vector3(-46.0,3.6,float(bay.z)))
	_activate_warehouse_squad(key, _west_upper_bounds(), true)
	_prompt("清理仓库警卫与异常目标" if key=="guard" else ("左侧卷帘门已开启　·　清理"+String({"inspection":"零件检验区","archive":"样本库区"}[key])) if key in ["inspection","archive"] else "清理泵房区")


func _trigger_receiving_shutter() -> void:
	receiving_shutter_triggered = true
	blockout.open_west_shutter("receiving")
	SFX.play_world_sfx_3d(&"wall_break",Vector3(-46.0,0.8,3.2))
	_activate_warehouse_squad("receiving", _west_receiving_bounds(), false)

func _tick_rooms(p: Vector2) -> void:
	if blockout.visit==PLAN.Visit.WEST and not on_lower_floor and not gate_state.calibration:
		for zone: Array in [["pump",Stage.PUMP,Save.PUMP]]:
			var zk: String = zone[0]
			if not warehouse_triggered.has(zk) and PLAN.UPPER[zk].has_point(p):
				_start_wave(zk,zone[1],zone[2])
				break
	if not wave.is_empty():
		if west_shutter_encounter!=null and west_shutter_encounter.has_pending_batches():return
		for unit in members:
			if is_instance_valid(unit) and not unit.dead: return
		for zk: String in warehouse_triggered:
			warehouse_cleared[zk] = true
		wave = ""
		members.clear()
		if warehouse_cleared.size() >= 4:
			blockout.set_gate("pump",false)
			stage = Stage.RETURN
			_prompt("沿员工梯返回一层机库")
		else:
			match stage:
				Stage.GUARD: _prompt("仓库四向已贯通　·　清理剩余区域（注意左侧卷帘门）")
				Stage.INSPECTION: _prompt("继续清理仓储区南侧与东侧目标")
				Stage.ARCHIVE: _prompt("清理东侧泵房区以解锁下楼楼梯")
				Stage.PUMP: _prompt("清理剩余仓储区目标以解锁楼梯出口")

func _start_chase(save: Save) -> void:
	stage = Stage.CHASE
	fall_lift = 0.0
	fall_vel = 0.0
	abyss_falling = false
	plate_warning = ""
	var midway := save!=Save.CHASE
	checkpoint = save
	chase_distance = mech_path.get_closest_offset(Vector2(6.8,54)) if midway else 0.0
	if save==Save.CROSS_DOCK: chase_distance = mech_path.get_closest_offset(Vector2(47,90))
	chase_grace = 1.4 if midway else 1.1
	chase_red_timer = 0.0
	chase_light_red = 0.0
	chase_reveal_left = 0 if midway else 1.6
	breached = midway
	ramp_distance = 0
	pursuit_time = 0
	blockout.rear_leaf.hide()
	if midway: blockout.breach_freight()
	_sync_freight_breakables_to_chase_distance(true)
	var start := mech_path.sample_baked(chase_distance)
	blockout.mech.position = Vector3(start.x,0,start.y)
	blockout.mech.show()
	var motion := ensure_crawler_motion()
	if is_instance_valid(motion): motion.teleport(blockout.mech.position)
	_collapse_passed_bays_immediately(start)
	if not midway:
		SFX.play_world_sfx_3d(&"wall_break",Vector3(-6.5,1,14),2,45)
		request_camera_impulse(&"heavy",Vector2.RIGHT)
	_prompt("沿装卸道逃往防火门")

func ensure_crawler_motion() -> CRAWLER_MOTION:
	if not get_meta(&"h06_physical_crawler",true) or blockout==null or not is_instance_valid(blockout.mech): return null
	if is_instance_valid(crawler_motion) and crawler_motion.model==blockout.mech: return crawler_motion
	if is_instance_valid(crawler_motion):
		crawler_motion.disable()
		crawler_motion.queue_free()
	crawler_motion = CRAWLER_MOTION.new()
	collision_root.add_child(crawler_motion)
	crawler_motion.configure(self,blockout.mech)
	return crawler_motion

func _move_mech(toward: Vector3,delta: float,bob: bool=true,face: Vector2=Vector2.INF) -> void:
	var motion := ensure_crawler_motion()
	if is_instance_valid(motion):
		motion.sync_road(vehicle_obstacles,breached)
		motion.move_toward_point(toward,delta,face)
		blockout.update_crawler_deck()
		return
	var before := blockout.mech.position
	var d := Vector2(toward.x-before.x,toward.z-before.z)
	var look_d := (face-Vector2(before.x,before.z)) if face!=Vector2.INF else d
	if look_d.length_squared()>.00001:
		blockout.mech.rotation.y = lerp_angle(blockout.mech.rotation.y,atan2(look_d.x,look_d.y),1-exp(-delta*8))
	pursuit_time += d.length()*2.0
	blockout.stride(pursuit_time,1 if d.length_squared()>.00001 else 0)
	blockout.mech.position = toward + Vector3.UP*(absf(sin(pursuit_time))*.07 if bob else 0.0)
	blockout.update_crawler_deck()

func _advance_chase(delta: float,p: Vector2) -> void:
	var cur := Vector2(blockout.mech.position.x,blockout.mech.position.z)
	_tick_freight_collapse(delta, p, cur)
	if abyss_falling:
		return
	chase_grace -= delta
	if chase_grace > 0:
		_update_h06_searchlight(delta, p, 0.0, _searchlight_has_line(cur, p))
		return
	# The shutter retracts before the first leg enters the opening.
	if not breached and cur.y>=PLAN.HEAVY_GATE.position.y-PLAN.CRAWLER_RADIUS-.72 and absf(cur.x-PLAN.HEAVY_GATE.get_center().x)<1.75:
		breached = true
		blockout.breach_freight()
		SFX.play_world_sfx_3d(&"wall_break",Vector3(7,1,38))
		request_camera_impulse(&"medium",Vector2.DOWN)
	var speed: float = player.movement_speed / CELL_PIXELS
	var p_off := mech_path.get_closest_offset(p)
	var progress := clampf(p_off + 2.5, chase_distance, mech_path.get_baked_length())
	var next_distance := move_toward(chase_distance, progress, speed * .90 * delta)
	var anchor := mech_path.sample_baked(chase_distance)
	var next_anchor := mech_path.sample_baked(next_distance)
	if cur.distance_to(anchor) < .30 or (cur.distance_to(next_anchor) < 4.5 and _clear_pursuit_line(cur, next_anchor)):
		chase_distance = next_distance
		anchor = next_anchor
	var end_of_route := chase_distance >= mech_path.get_baked_length() - 2.5
	var goal := anchor
	var pursuing_player := false
	if end_of_route or (cur.distance_to(p) <= 15.0 and anchor.distance_to(p) <= 15.0):
		var best := _find_best_pursuit_target(cur, anchor, p)
		if best != Vector2.INF:
			goal = best
			pursuing_player = true
	var move_speed := speed * (0.94 if pursuing_player and cur.distance_to(p) < 8.5 else 1.02)
	var target := cur.move_toward(goal, move_speed * delta)
	if not _clear_pursuit_line(cur, target):
		target = cur.move_toward(anchor, move_speed * delta)
	var face_pt := p if (pursuing_player or cur.distance_to(p) <= 15.0) and _searchlight_has_line(cur, p) else Vector2.INF
	_move_mech(Vector3(target.x, 0, target.y), delta, true, face_pt)
	var actual := Vector2(blockout.mech.position.x, blockout.mech.position.z)
	var touched := is_instance_valid(crawler_motion) and crawler_motion.contact_player
	var body_dist := actual.distance_to(p)
	var foot_dist := _nearest_mech_foot_distance(p, actual)
	var light_clear := _searchlight_has_line(actual, p)
	var close_metric := minf(body_dist, foot_dist + 2.0)
	var corner_pinned := pursuing_player and cur.distance_to(goal) < 0.65 and body_dist <= 7.6 and light_clear
	var target_red := clampf(inverse_lerp(7.0, 4.5, close_metric), 0.0, 1.0) if light_clear else 0.0
	if corner_pinned:
		target_red = maxf(target_red, 0.85)
	_update_h06_searchlight(delta, p, target_red, light_clear)
	var crush_window := (body_dist <= 5.25 or foot_dist <= 3.10) and target_red >= 0.52 and light_clear
	if (touched or body_dist < 2.20 or foot_dist < 1.25) and jump_time < 0 and not player.dashing:
		_execute_h06_crush(p)
		return
	if crush_window or corner_pinned:
		chase_red_timer += delta
		var crush_delay := 0.42 if crush_window else 0.85
		if chase_red_timer >= crush_delay and jump_time < 0 and not player.dashing:
			_execute_h06_crush(p)
			return
	else:
		chase_red_timer = move_toward(chase_red_timer, 0.0, delta * 3.5)

func _crawler_clear_padded(pt: Vector2, pad := 0.22) -> bool:
	if not PLAN.crawler_clear(pt, vehicle_obstacles):
		return false
	for off: Vector2 in [Vector2(pad, 0.0), Vector2(-pad, 0.0), Vector2(0.0, pad), Vector2(0.0, -pad)]:
		if not PLAN.crawler_clear(pt + off, vehicle_obstacles):
			return false
	return true

func _find_best_pursuit_target(cur: Vector2, anchor: Vector2, p: Vector2) -> Vector2:
	if _crawler_clear_padded(p) and _clear_pursuit_line(cur, p):
		return p
	var best := Vector2.INF
	var best_d2 := INF
	var rays: Array[Vector2] = []
	if cur.distance_squared_to(p) > 0.01:
		rays.append((cur - p).normalized())
	if anchor.distance_squared_to(p) > 0.01:
		rays.append((anchor - p).normalized())
	for k in 12:
		var ang := TAU * float(k) / 12.0
		rays.append(Vector2(cos(ang), sin(ang)))
	for dist: float in [0.9, 1.8, 2.7, 3.6, 4.4, 5.2, 6.2, 7.2]:
		for dir: Vector2 in rays:
			var cand := p + dir * dist
			var d2 := cand.distance_squared_to(p)
			if d2 >= best_d2:
				continue
			if not _crawler_clear_padded(cand):
				continue
			if not _clear_pursuit_line(cur, cand):
				continue
			best = cand
			best_d2 = d2
		if best != Vector2.INF:
			return best
	return best

func _nearest_mech_foot_distance(p: Vector2, center: Vector2) -> float:
	var best := maxf(0.0, center.distance_to(p) - 2.35)
	if is_instance_valid(crawler_motion) and crawler_motion.gait != null:
		for leg: Dictionary in crawler_motion.gait.legs:
			var ankle := leg.get("ankle") as Node3D
			if is_instance_valid(ankle):
				var gp := ankle.global_position
				best = minf(best, Vector2(gp.x, gp.z).distance_to(p))
	return best

func _searchlight_has_line(from: Vector2, to: Vector2) -> bool:
	if not breached and _crosses_rect(from, to, PLAN.HEAVY_GATE.grow(0.1)):
		return false
	for r: Rect2 in PLAN.PARTITIONS:
		if _crosses_rect(from, to, r.grow(0.08)):
			return false
	if blockout != null:
		for br: Dictionary in blockout.freight_breakables:
			if not bool(br.get("exploded", false)) and _crosses_rect(from, to, (br.rect as Rect2).grow(-0.08)):
				return false
		for cl: Dictionary in blockout.freight_clutter_entries:
			if not bool(cl.get("exploded", false)) and float(cl.get("height", 1.5)) >= 1.15 and _crosses_rect(from, to, (cl.rect as Rect2).grow(-0.08)):
				return false
		for dr: Dictionary in blockout.freight_deck_drops:
			if not bool(dr.get("exploded", false)) and String(dr.state) in ["falling", "bounce", "landed"] and _crosses_rect(from, to, (dr.rect as Rect2).grow(-0.08)):
				return false
	for prop_val: Array in PLAN.PROPS.values():
		var pr: Rect2 = prop_val[0]
		if float(prop_val[1]) >= 1.15 and PLAN.visit_contains(PLAN.Visit.FREIGHT, pr.get_center(), true) and _crosses_rect(from, to, pr.grow(-0.08)):
			return false
	return true

func _update_h06_searchlight(delta: float, p: Vector2, target_red: float, light_clear: bool) -> void:
	if blockout == null or blockout.freight_searchlight.is_empty() or not is_instance_valid(blockout.mech):
		return
	var sl: Dictionary = blockout.freight_searchlight
	var rig := sl.get("root") as Node3D
	if not is_instance_valid(rig):
		return
	rig.visible = blockout.mech.visible and stage == Stage.CHASE
	if not rig.visible:
		return
	chase_light_red = move_toward(chase_light_red, target_red, delta * 5.2)
	var yaw := blockout.mech.rotation.y
	var fwd := Vector3(sin(yaw), 0.0, cos(yaw))
	# Mounted high atop Boss's dorsal turret head (y=2.82) so tall containers/pillars cast real shadows over the player
	var emit3 := blockout.mech.position + fwd * 1.48 + Vector3(0.0, 2.82, 0.0)
	var aim3 := Vector3(p.x, 0.25, p.y)
	var white_col := Color("f0f7ff")
	var red_col := Color("ff0e06")
	var col_t := smoothstep(0.08, 0.70, chase_light_red)
	var lcol := white_col.lerp(red_col, col_t)
	var pulse := 1.0 + chase_light_red * 0.24 * sin(freight_elapsed * 18.0)

	var safe_xz := Vector2(aim3.x - emit3.x, aim3.z - emit3.z).length_squared() > 0.004
	var spot := sl.get("spot") as SpotLight3D
	if is_instance_valid(spot):
		spot.position = emit3
		if safe_xz and emit3.distance_squared_to(aim3) > 0.04:
			spot.look_at(aim3, Vector3.UP)
		spot.light_color = lcol
		spot.light_energy = lerpf(32.0, 42.0, col_t) * pulse
		spot.spot_angle = lerpf(50.0, 56.0, col_t)

	var bulb := sl.get("bulb") as MeshInstance3D
	if is_instance_valid(bulb):
		bulb.position = blockout.mech.position + fwd * 1.62 + Vector3(0.0, 2.28, 0.0)
	var bulb_mat := sl.get("bulb_mat") as StandardMaterial3D
	if bulb_mat != null:
		bulb_mat.albedo_color = lcol
		bulb_mat.emission = lcol
		bulb_mat.emission_energy_multiplier = lerpf(4.8, 8.2, col_t) * pulse

func _execute_h06_crush(p: Vector2) -> void:
	if blockout != null and not blockout.freight_searchlight.is_empty():
		chase_light_red = 1.0
		_update_h06_searchlight(0.016, p, 1.0, true)
	var burn := _ensure_freight_burn()
	if is_instance_valid(burn) and is_instance_valid(burn.get("effects")):
		var fx: Node3D = burn.effects
		var local_p: Vector3 = fx.to_local(to_global(Vector3(p.x, 0.2, p.y)))
		fx.emit_fire(local_p, 0.45, 0.65)
		fx.emit_smoke(local_p, 16, 1.45)
	SFX.play_world_sfx_3d(&"wall_break", Vector3(p.x, 0.2, p.y), 1.65, 36.0)
	request_camera_impulse(&"heavy", Vector2.DOWN)
	player.force_hazard_death(&"h06_chase")

func _ensure_freight_burn() -> Node:
	if blockout == null or not is_instance_valid(blockout.floor_root):
		return null
	var burn := blockout.floor_root.get_node_or_null("BurningEffects")
	if not is_instance_valid(burn):
		burn = preload("res://scripts/dream/burning_effects.gd").install(self)
	return burn

func _retire_collapsed_bay_contents(bay: Dictionary) -> void:
	var br: Rect2 = bay.rect
	var pivot := bay.get("pivot") as Node3D
	for fl: Dictionary in bay.get("lights", []):
		fl["killed"] = true
	if is_instance_valid(blockout.physics_root):
		for child: Node in blockout.physics_root.get_children():
			if not (child is StaticBody2D):
				continue
			var sb := child as StaticBody2D
			var nm := String(sb.name)
			if nm in ["OneWayEntrance", "PassageGuide", "RearPersonnelLimit", "RampPersonnelLimit"]:
				continue
			if br.has_point(sb.position / CELL_PIXELS):
				sb.collision_layer = 0
				for sc: Node in sb.get_children():
					if sc is CollisionShape2D:
						(sc as CollisionShape2D).set_deferred("disabled", true)
	for entry: Dictionary in blockout.unstable_plates:
		if String(entry.state) == "idle" and br.has_point((entry.rect as Rect2).get_center()):
			entry.state = "falling"
			entry.fall_y = 0.0
			entry.fall_vel = 2.6
	for entry: Dictionary in blockout.freight_fractures:
		var ec := (entry.rect as Rect2).get_center()
		var bridge_drop := String(bay.room) == "east_bank" and String(entry.id) == "frac_wb_bridge"
		if (br.has_point(ec) or bridge_drop) and is_instance_valid(pivot):
			var slab := entry.get("slab") as Node3D
			if is_instance_valid(slab) and String(entry.state) in ["intact", "telegraph"]:
				slab.reparent(pivot, true)
			entry.state = "broken"
			var holo := entry.get("holo") as Node3D
			if is_instance_valid(holo): holo.visible = false
	for entry: Dictionary in blockout.freight_clutter_entries:
		if not bool(entry.get("exploded", false)) and br.has_point(entry.center):
			entry.exploded = true
			blockout.set_freight_body_enabled(entry.get("body") as StaticBody2D, false)
	for entry: Dictionary in blockout.freight_breakables:
		var ec := (entry.rect as Rect2).get_center()
		if not bool(entry.exploded) and br.has_point(ec) and is_instance_valid(pivot):
			var node := entry.get("node") as Node3D
			if is_instance_valid(node):
				node.reparent(pivot, true)
			entry.exploded = true
			if is_instance_valid(entry.get("lock_mark")): entry.lock_mark.visible = false
	for entry: Dictionary in blockout.freight_deck_drops:
		var ec := (entry.rect as Rect2).get_center()
		if br.has_point(ec) and String(entry.state) in ["idle", "falling", "bounce", "landed"] and is_instance_valid(pivot):
			var node := entry.get("node") as Node3D
			if is_instance_valid(node) and node.visible:
				node.reparent(pivot, true)
			var ret := entry.get("reticle") as Node3D
			if is_instance_valid(ret): ret.visible = false
			entry.exploded = true

func _collapse_passed_bays_immediately(mech_pos2: Vector2) -> void:
	if blockout == null or blockout.freight_collapse_bays.is_empty():
		return
	var safe_off := chase_distance - 5.2
	for bay: Dictionary in blockout.freight_collapse_bays:
		if bool(bay.retain_at_end):
			continue
		var br: Rect2 = bay.rect
		if float(bay.offset) <= safe_off and mech_pos2.distance_to(mech_pos2.clamp(br.position, br.end)) >= 4.85:
			bay.state = "collapsed"
			bay.fall_y = -28.0
			_retire_collapsed_bay_contents(bay)
			var bnode := bay.get("node") as Node3D
			if is_instance_valid(bnode):
				bnode.visible = false

func _tick_freight_collapse(delta: float, p: Vector2, cur: Vector2) -> void:
	if blockout == null or blockout.freight_collapse_bays.is_empty():
		return
	var cur_off := mech_path.get_closest_offset(cur)
	var safe_off := minf(chase_distance, cur_off) - 5.2
	var burn := _ensure_freight_burn()
	for bay: Dictionary in blockout.freight_collapse_bays:
		var st := String(bay.state)
		var br: Rect2 = bay.rect
		if st == "collapsed":
			if not abyss_falling and jump_time < 0.0 and not bool(player.dashing) and br.grow(-0.22).has_point(p):
				_begin_abyss_fall(-0.18, 2.8)
			continue
		var pivot := bay.get("pivot") as Node3D
		if st == "intact":
			if bool(bay.retain_at_end):
				continue
			if float(bay.offset) <= safe_off:
				var d_boss := cur.distance_to(cur.clamp(br.position, br.end))
				if d_boss >= 4.85:
					bay.state = "shaking"
					bay.timer = 0.0
					bay.tilt_vel = Vector3(randf_range(-0.32, 0.32), randf_range(-0.10, 0.10), randf_range(-0.38, 0.38))
		elif st == "shaking":
			bay.timer = float(bay.timer) + delta
			var t := float(bay.timer)
			var frac := clampf(t / 0.38, 0.0, 1.0)
			if is_instance_valid(pivot):
				pivot.position.y = -0.14 * frac * frac + sin(t * 58.0) * (0.018 + 0.024 * frac)
				pivot.rotation.z = sin(t * 42.0) * 0.016 * frac
			if t >= 0.38:
				bay.state = "falling"
				bay.fall_y = -0.14
				bay.fall_vel = 2.6
				var center := br.get_center()
				SFX.play_world_sfx_3d(&"h06_deck_collapse", to_global(Vector3(center.x, 0.1, center.y)), 0.0, 34.0)
				_retire_collapsed_bay_contents(bay)
				if is_instance_valid(burn) and is_instance_valid(burn.get("effects")):
					var fx: Node3D = burn.effects
					var c2 := br.get_center()
					fx.emit_smoke(fx.to_local(to_global(Vector3(c2.x, 0.2, c2.y))), 8, 1.0)
		elif st == "falling":
			bay.fall_vel = float(bay.fall_vel) + 28.0 * delta
			bay.fall_y = float(bay.fall_y) - float(bay.fall_vel) * delta
			if is_instance_valid(pivot):
				pivot.position.y = float(bay.fall_y)
				pivot.rotation += Vector3(bay.tilt_vel) * delta
			if not abyss_falling and jump_time < 0.0 and not bool(player.dashing) and br.grow(-0.22).has_point(p):
				_begin_abyss_fall(float(bay.fall_y), float(bay.fall_vel))
			if float(bay.fall_y) <= -26.0:
				bay.state = "collapsed"
				var bnode := bay.get("node") as Node3D
				if is_instance_valid(bnode):
					bnode.visible = false

func _clear_pursuit_line(a: Vector2,b: Vector2) -> bool:
	var steps := maxi(1,ceili(a.distance_to(b)/.34))
	for i in range(1,steps+1):
		var p := a.lerp(b,float(i)/steps)
		if not PLAN.crawler_clear(p,vehicle_obstacles): return false
		if not breached and p.distance_to(p.clamp(PLAN.HEAVY_GATE.position,PLAN.HEAVY_GATE.end))<=PLAN.CRAWLER_RADIUS: return false
	return true

func _run_to_roof(delta: float) -> void:
	if chase_distance < mech_path.get_baked_length():
		var cur := Vector2(blockout.mech.position.x,blockout.mech.position.z)
		if cur.distance_to(mech_path.sample_baked(chase_distance))<.22:
			chase_distance = minf(chase_distance+delta*11,mech_path.get_baked_length())
		var target := mech_path.sample_baked(chase_distance)
		var pos := blockout.mech.position.move_toward(Vector3(target.x,0,target.y),delta*13)
		_move_mech(pos,delta,false)
	elif ramp_distance < escape_path.get_baked_length():
		if not is_instance_valid(crawler_motion) or blockout.mech.position.distance_to(escape_path.sample_baked(ramp_distance))<.26:
			ramp_distance = minf(ramp_distance+delta*10.0,escape_path.get_baked_length())
		var position_on_track := escape_path.sample_baked(ramp_distance)
		var front := PLAN.ramp_height(position_on_track.z-3.0)
		var rear := PLAN.ramp_height(position_on_track.z+3.0)
		position_on_track.y = (front+rear)*.5
		if is_instance_valid(crawler_motion):
			# A support-limited walker must catch up to each path sample; do not
			# let a timer drag it to the roof while its legs are still turning.
			position_on_track = blockout.mech.position.move_toward(position_on_track,delta*10.)
		_move_mech(position_on_track,delta,false)
		if not is_instance_valid(crawler_motion): blockout.mech.rotation.x = -atan2(front-rear,6.)
		if ramp_distance>=escape_path.get_baked_length(): blockout.mech.hide()

func _begin_abyss_fall(start_y: float, start_vel: float) -> void:
	abyss_falling = true
	fall_lift = start_y
	fall_vel = start_vel
	player.movement_enabled = false
	player.set_attacking_enabled(false, true)
	player.velocity = Vector2.ZERO


func _advance_falling_plate(plate: Dictionary, delta: float) -> void:
	var node := plate.node as Node3D
	plate.fall_vel += 26.0 * delta
	plate.fall_y -= plate.fall_vel * delta
	if is_instance_valid(node):
		node.position.y = plate.fall_y
		node.rotation.x = minf(node.rotation.x + delta * 1.4, 1.05)
		node.rotation.z = minf(node.rotation.z + delta * 0.9, 0.65)
	if plate.fall_y <= -14.5:
		plate.state = "collapsed"
		if is_instance_valid(node):
			node.visible = false


func _tick_freight_plates(delta: float, p: Vector2) -> void:
	if blockout == null or blockout.unstable_plates.is_empty():
		return
	if abyss_falling:
		fall_vel += 26.0 * delta
		fall_lift -= fall_vel * delta
		player_depth_bridge.ground_surface_height = fall_lift
		for plate: Dictionary in blockout.unstable_plates:
			if plate.state == "falling":
				_advance_falling_plate(plate, delta)
		if fall_lift <= -5.8:
			player.force_hazard_death(&"catwalk_collapse")
		return

	plate_warning = ""
	var standing_sag := 0.0
	var collapse_delay: float = float(BLOCKOUT.FREIGHT.COLLAPSE_DELAY)
	for plate: Dictionary in blockout.unstable_plates:
		var r: Rect2 = plate.rect
		var node := plate.node as Node3D
		var on_plate: bool = r.has_point(p) and jump_time < 0.0 and not bool(player.dashing)
		if plate.state == "idle":
			if on_plate:
				plate.state = "shaking"
				plate.timer = 0.0
				if is_instance_valid(node):
					SFX.play_world_sfx_3d(&"h06_plate_shake", node.global_position, 0.0, 28.0)
		elif plate.state == "shaking":
			plate.timer += delta
			var frac: float = clampf(float(plate.timer) / collapse_delay, 0.0, 1.0)
			var jitter: float = sin(float(plate.timer) * 56.0) * (0.018 + 0.024 * frac)
			var sag: float = -0.15 * frac * frac
			if is_instance_valid(node):
				node.position.y = sag + jitter
				node.rotation.z = sin(float(plate.timer) * 41.0) * (0.030 + 0.032 * frac)
				node.rotation.x = cos(float(plate.timer) * 33.0) * (0.022 + 0.028 * frac)
			var lmat := plate.get("lamp_mat") as StandardMaterial3D
			if lmat != null:
				var alert_pulse: bool = sin(float(plate.timer) * 28.0) > 0.0
				lmat.albedo_color = Color("e03024") if alert_pulse else Color("6e2018")
				lmat.emission = Color("ff442b") if alert_pulse else Color("aa2618")
				lmat.emission_energy_multiplier = 3.2 if alert_pulse else 0.9
			if on_plate:
				standing_sag = sag + jitter * 0.5
				plate_warning = "铁板正在剧烈晃动！迅速跑向下一块平台"
			if plate.timer >= collapse_delay:
				plate.state = "falling"
				plate.fall_y = sag
				plate.fall_vel = 2.2
				if is_instance_valid(node):
					_play_freight_plate_fall(node.global_position)
				if on_plate:
					_begin_abyss_fall(sag, 2.2)
					return
		elif plate.state == "falling":
			_advance_falling_plate(plate, delta)
		if not abyss_falling and (plate.state == "falling" or plate.state == "collapsed"):
			if r.grow(-0.34).has_point(p) and jump_time < 0.0 and not player.dashing:
				_begin_abyss_fall(-0.15, 2.6)
				return
	if jump_time < 0.0:
		player_depth_bridge.ground_surface_height = PLAN.lower_height(p) + standing_sag


func _sync_freight_breakables_to_chase_distance(quiet := false) -> void:
	if blockout == null or blockout.freight_breakables.is_empty():
		return
	for entry: Dictionary in blockout.freight_breakables:
		if bool(entry.exploded):
			continue
		var r: Rect2 = entry.rect
		var c := r.get_center()
		if mech_path.get_closest_offset(c) <= chase_distance + 1.5:
			if quiet:
				entry.exploded = true
				entry.locking = false
				if is_instance_valid(entry.get("node")):
					entry.node.visible = false
				if is_instance_valid(entry.get("scorch")):
					entry.scorch.visible = true
				if is_instance_valid(entry.get("lock_mark")):
					entry.lock_mark.visible = false
				blockout.set_freight_body_enabled(entry.get("body") as StaticBody2D, false)


func _explode_freight_breakable(entry: Dictionary, mech_at: Vector2) -> void:
	entry.exploded = true
	entry.locking = false
	if entry.has("state"):
		entry.state = "exploded"
	if stage == Stage.CHASE:
		chase_grace = maxf(chase_grace, 0.08 if entry.has("idx") else 0.28)
	var r: Rect2 = entry.rect
	var c := r.get_center()
	var h := float(entry.height)
	var blast_pos := Vector3(c.x, h * 0.45, c.y)
	var push_dir := mech_at.direction_to(c)
	if push_dir.length_squared() < 0.001:
		push_dir = Vector2.DOWN

	if is_instance_valid(entry.get("lock_mark")):
		entry.lock_mark.visible = false
	if is_instance_valid(entry.get("reticle")):
		entry.reticle.visible = false
	if is_instance_valid(entry.get("node")):
		entry.node.visible = false
	if is_instance_valid(entry.get("scorch")):
		entry.scorch.visible = true
	elif is_instance_valid(blockout.floor_root):
		var scorch := BLOCKOUT.FREIGHT.build_scorch_pad(blockout.floor_root, r)
		scorch.visible = true
		if is_instance_valid(entry.get("node")) and entry.node.get_parent() is Node3D and entry.node.get_parent() != blockout.floor_root:
			scorch.reparent(entry.node.get_parent() as Node3D, true)
		entry.scorch = scorch
	blockout.set_freight_body_enabled(entry.get("body") as StaticBody2D, false)

	var burn := preload("res://scripts/dream/burning_effects.gd").install(self)
	if is_instance_valid(burn) and is_instance_valid(burn.get("effects")):
		var fx: Node3D = burn.effects
		fx.explode(fx.to_local(to_global(blast_pos)), 2.15)
		fx.emit_smoke(fx.to_local(to_global(blast_pos + Vector3.UP * 0.65)), 24, 1.55)
	BLOCKOUT.FREIGHT.spawn_container_debris(
		blockout.floor_root,
		Vector3(c.x, 0.0, c.y),
		push_dir,
		Vector3(r.size.x, h, r.size.y),
		String(entry.get("tint", "orange")),
		blockout.freight_debris
	)
	SFX.play_world_sfx_3d(&"explosion", to_global(blast_pos), 0.0, 48.0)
	request_camera_impulse(&"heavy", push_dir)


func _nudge_player_out_of_drop(entry: Dictionary) -> void:
	var r: Rect2 = entry.rect
	var zone_rect: Rect2 = entry.get("zone_rect", r)
	var feet := _feet()
	var padded := r.grow(0.42)
	if not padded.has_point(feet) and not zone_rect.has_point(feet):
		return
	var eject: Vector2 = entry.get("eject_dir", Vector2.ZERO)
	if bool(entry.get("twin_eject", false)):
		eject = Vector2.LEFT if feet.x <= r.get_center().x else Vector2.RIGHT
	if eject.length_squared() > 0.25:
		var cand := feet
		if eject.x < -0.5:
			cand.x = minf(r.position.x, zone_rect.position.x) - 0.55
		elif eject.x > 0.5:
			cand.x = maxf(r.end.x, zone_rect.end.x) + 0.55
		elif eject.y < -0.5:
			cand.y = minf(r.position.y, zone_rect.position.y) - 0.55
		elif eject.y > 0.5:
			cand.y = maxf(r.end.y, zone_rect.end.y) + 0.55
		if PLAN.visit_contains(PLAN.Visit.FREIGHT, cand, true):
			_place_feet(cand)
			return
	var candidates := [
		Vector2(padded.position.x - 0.12, feet.y),
		Vector2(padded.end.x + 0.12, feet.y),
		Vector2(feet.x, padded.position.y - 0.12),
		Vector2(feet.x, padded.end.y + 0.12),
	]
	var best := feet
	var best_d := INF
	for cand: Vector2 in candidates:
		if PLAN.visit_contains(PLAN.Visit.FREIGHT, cand, true) and not zone_rect.has_point(cand):
			var d := feet.distance_squared_to(cand)
			if d < best_d:
				best_d = d
				best = cand
	if best != feet:
		_place_feet(best)


func _tick_mech_container_blast(entry: Dictionary, mech_at: Vector2, mech_origin3: Vector3,
		beam: MeshInstance3D, beam_shown: bool, lock_range: float, immediate_range: float,
		check_track: bool, lock_dur: float, use_rect_dist: bool, delta: float) -> bool:
	if bool(entry.get("exploded", false)):
		return beam_shown
	var r: Rect2 = entry.rect
	var c := r.get_center()
	var dist := mech_at.distance_to(mech_at.clamp(r.position, r.end)) if use_rect_dist else mech_at.distance_to(c)
	var on_track := check_track and mech_path.get_closest_offset(c) <= chase_distance + 2.0
	if not bool(entry.get("locking", false)) and (dist <= lock_range or on_track):
		entry.locking = true
		entry.lock_timer = 0.0
		if is_instance_valid(entry.get("lock_mark")):
			entry.lock_mark.visible = true
		SFX.play_world_sfx_3d(&"enemy_fire_cue", Vector3(c.x, 1.1, c.y), 1.4, 38.0)
	if bool(entry.get("locking", false)):
		entry.lock_timer = float(entry.get("lock_timer", 0.0)) + delta
		if is_instance_valid(entry.get("lock_mark")):
			entry.lock_mark.visible = fmod(float(entry.lock_timer) * 24.0, 1.0) < 0.65
		if is_instance_valid(beam) and not beam_shown:
			var target3 := Vector3(c.x, float(entry.height) * 0.55, c.y)
			var span := target3 - mech_origin3
			if span.length_squared() > 0.01:
				beam.position = (mech_origin3 + target3) * 0.5
				beam.quaternion = Quaternion(Vector3.UP, span.normalized())
				beam.scale = Vector3(1.0, span.length(), 1.0)
				beam.visible = true
				beam_shown = true
		if float(entry.lock_timer) >= lock_dur or dist <= immediate_range:
			_explode_freight_breakable(entry, mech_at)
	return beam_shown


func _play_freight_plate_fall(at: Vector3) -> void:
	if freight_elapsed - _last_plate_fall > FREIGHT_PLATE_CHAIN_SECONDS:
		_next_plate_fall = &"h06_plate_fall"
	SFX.play_world_sfx_3d(_next_plate_fall, at, 0.0, 28.0)
	_next_plate_fall = &"h06_plate_fall_alt" if _next_plate_fall == &"h06_plate_fall" else &"h06_plate_fall"
	_last_plate_fall = freight_elapsed


func _begin_drop_telegraph(entry: Dictionary, node: Node3D, reticle: Node3D) -> void:
	entry.state = "telegraph"
	entry.timer = 0.0
	entry.fall_y = 9.8
	node.position.y = 9.8
	node.visible = true
	if is_instance_valid(reticle):
		reticle.visible = true


func _tick_freight_containers(delta: float, p: Vector2) -> void:
	if blockout == null:
		return
	var burn := get_node_or_null("floor_root/BurningEffects")
	if not is_instance_valid(burn):
		burn = floor_root.get_node_or_null("BurningEffects")

	# 1. H06 Boss targets & blasts container barricades (and any dropped seal directly obstructing its stride)
	var beam := blockout.freight_boss_beam
	var beam_shown := false
	if (stage == Stage.CHASE or stage == Stage.STAFF) and is_instance_valid(blockout.mech) and blockout.mech.visible:
		var mech_at := Vector2(blockout.mech.position.x, blockout.mech.position.z)
		var mech_origin3 := Vector3(blockout.mech.position.x, blockout.mech.position.y + 1.85, blockout.mech.position.z)
		for entry: Dictionary in blockout.freight_breakables:
			beam_shown = _tick_mech_container_blast(entry, mech_at, mech_origin3, beam, beam_shown, 9.8, 5.0, true, 0.36, false, delta)
		for entry: Dictionary in blockout.freight_clutter_entries:
			if bool(entry.get("exploded", false)):
				continue
			var r: Rect2 = entry.rect
			var cl_dist := mech_at.distance_to(mech_at.clamp(r.position, r.end))
			if cl_dist <= 8.5 and (_crosses_rect(mech_at, p, r.grow(1.25)) or cl_dist <= 4.0):
				beam_shown = _tick_mech_container_blast(entry, mech_at, mech_origin3, beam, beam_shown, 8.5, 4.2, false, 0.20, true, delta)
		for entry: Dictionary in blockout.freight_deck_drops:
			if String(entry.state) in ["falling", "bounce", "landed"]:
				beam_shown = _tick_mech_container_blast(entry, mech_at, mech_origin3, beam, beam_shown, 5.4, 3.2, false, 0.18, true, delta)
	if is_instance_valid(beam) and not beam_shown:
		beam.visible = false

	# 2. Approach-triggered deck-slamming crane cargo assemblies
	for entry: Dictionary in blockout.freight_deck_drops:
		var st: String = entry.state
		var node := entry.get("node") as Node3D
		var reticle := entry.get("reticle") as Node3D
		if st == "landed" or bool(entry.get("exploded", false)) or not is_instance_valid(node):
			continue
		if st == "idle":
			var trig: Rect2 = entry.get("trigger_rect", entry.rect)
			if trig.has_point(p):
				if float(entry.get("delay", 0.0)) > 0.001:
					entry.state = "queued"
					entry.timer = 0.0
				else:
					_begin_drop_telegraph(entry, node, reticle)
		elif st == "queued":
			entry.timer = float(entry.timer) + delta
			if float(entry.timer) >= float(entry.get("delay", 0.0)):
				_begin_drop_telegraph(entry, node, reticle)
		elif st == "telegraph":
			entry.timer = float(entry.timer) + delta
			var tt := clampf(float(entry.timer) / 0.22, 0.0, 1.0)
			entry.fall_y = lerpf(10.6, 7.8, tt)
			node.position.y = float(entry.fall_y)
			if is_instance_valid(reticle):
				reticle.visible = true
				var sh := reticle.get_node_or_null("DropShadow") as Node3D
				if sh != null:
					sh.scale = Vector3.ONE * lerpf(0.42, 0.65, tt)
			if float(entry.timer) >= 0.22:
				entry.state = "falling"
				entry.fall_vel = 6.8
				if is_instance_valid(entry.get("cable")):
					entry.cable.visible = false
				SFX.play_world_sfx_3d(&"h06_hoist_release", node.global_position, 0.0, 32.0)
		elif st == "falling":
			entry.fall_vel = float(entry.fall_vel) + 46.0 * delta
			entry.fall_y = float(entry.fall_y) - float(entry.fall_vel) * delta
			var rest_y := float(entry.height) * 0.5
			node.position.y = maxf(rest_y, float(entry.fall_y))
			node.rotation.z = sin(float(entry.fall_y) * 0.5) * 0.035
			if is_instance_valid(reticle):
				var sh := reticle.get_node_or_null("DropShadow") as Node3D
				if sh != null:
					sh.scale = Vector3.ONE * lerpf(0.65, 1.04, clampf(1.0 - (node.position.y - rest_y) / 7.5, 0.0, 1.0))
			if float(entry.fall_y) <= rest_y:
				entry.state = "bounce"
				entry.timer = 0.0
				entry.fall_y = rest_y
				if is_instance_valid(reticle):
					reticle.visible = false
				_nudge_player_out_of_drop(entry)
				blockout.set_freight_body_enabled(entry.get("body") as StaticBody2D, true)
				if not is_instance_valid(burn):
					burn = preload("res://scripts/dream/burning_effects.gd").install(self)
				if is_instance_valid(burn) and is_instance_valid(burn.get("effects")):
					var fx_drop: Node3D = burn.effects
					var dust_at := Vector3(node.position.x, 0.35, node.position.z)
					fx_drop.emit_smoke(fx_drop.to_local(to_global(dust_at)), 14, 1.25)
				if float(entry.get("delay", 0.0)) <= 0.06:
					SFX.play_world_sfx_3d(&"container_impact", to_global(Vector3(node.position.x, 0.5, node.position.z)), 0.0, 34.0)
					request_camera_impulse(&"medium", Vector2.DOWN)
		elif st == "bounce":
			entry.timer = float(entry.timer) + delta
			var bt := clampf(float(entry.timer) / 0.22, 0.0, 1.0)
			var rest_y := float(entry.height) * 0.5
			node.position.y = rest_y + sin(bt * PI) * 0.16 * (1.0 - bt * 0.3)
			node.rotation.z = sin(bt * PI * 2.0) * 0.045 * (1.0 - bt)
			if bt >= 1.0:
				entry.state = "landed"
				node.position.y = rest_y
				node.rotation.z = 0.0

	# 3. Boss missile strikes & breakaway deck chasm collapses
	_tick_freight_fractures(delta, p, burn)

	# 4. Abyssal hoist-snap chasm plunges
	for entry: Dictionary in blockout.freight_chasm_drops:
		var st: String = entry.state
		var node := entry.get("node") as Node3D
		if st == "gone" or not is_instance_valid(node):
			continue
		if st == "hanging":
			var phase := float(entry.phase)
			var base: Vector3 = entry.base_pos
			node.rotation.z = sin(freight_elapsed * 1.5 + phase) * 0.045
			node.position.y = base.y + cos(freight_elapsed * 2.1 + phase) * 0.08
			if p.x >= float(entry.min_x) and p.x <= float(entry.max_x) and p.y >= float(entry.min_y) and p.y <= float(entry.max_y):
				entry.state = "falling"
				entry.fall_vel = 1.6
				entry.fall_y = node.position.y
				if is_instance_valid(entry.get("cables")):
					entry.cables.visible = false
				if not is_instance_valid(burn):
					burn = preload("res://scripts/dream/burning_effects.gd").install(self)
				if is_instance_valid(burn) and is_instance_valid(burn.get("effects")):
					var fx_chasm: Node3D = burn.effects
					fx_chasm.emit_smoke(fx_chasm.to_local(to_global(node.position + Vector3.UP * 1.4)), 10, 0.90)
				SFX.play_world_sfx_3d(&"h06_hoist_release", node.global_position, 0.0, 34.0)
		elif st == "falling":
			entry.fall_vel = float(entry.fall_vel) + 26.0 * delta
			entry.fall_y = float(entry.fall_y) - float(entry.fall_vel) * delta
			node.position.y = float(entry.fall_y)
			node.rotation += Vector3(entry.spin) * delta
			if float(entry.fall_y) <= -26.0:
				entry.state = "gone"
				node.visible = false


func _launch_fracture_missiles(entry: Dictionary) -> void:
	var cut_r: Rect2 = entry.cutout_rect
	var c2 := cut_r.get_center()
	var m_origin := Vector3(-6.0, 2.5, 10.0)
	if is_instance_valid(blockout.mech) and blockout.mech.visible:
		m_origin = Vector3(blockout.mech.position.x, blockout.mech.position.y + 2.45, blockout.mech.position.z)
	var to_target := Vector3(c2.x - m_origin.x, 0.0, c2.y - m_origin.z)
	if to_target.length() > 30.0:
		m_origin = Vector3(c2.x, 2.4, c2.y) - to_target.normalized() * 26.0
	var count := int(entry.get("missile_count", 1))
	var active_missiles: Array = []
	for mi in count:
		var spread := (float(mi) - float(count - 1) * 0.5) * minf(cut_r.size.x, cut_r.size.y) * 0.28
		var tgt := Vector3(c2.x + spread, 0.12, c2.y + spread * 0.45)
		var m_node := BLOCKOUT.FREIGHT.build_missile_projectile(blockout.floor_root)
		m_node.position = m_origin
		active_missiles.append({
			"node": m_node,
			"start": m_origin + Vector3(float(mi) * 0.45, 0.0, 0.0),
			"target": tgt,
			"apex": maxf(m_origin.y, 2.5) + clampf(m_origin.distance_to(tgt) * 0.25, 3.8, 7.2),
			"smoke_acc": 0.0,
		})
	entry.missiles = active_missiles
	SFX.play_world_sfx_3d(&"enemy_fire_cue", m_origin, 1.5, 44.0)


func _tick_freight_fractures(delta: float, p: Vector2, burn_in: Node) -> void:
	var burn := burn_in
	for entry: Dictionary in blockout.freight_fractures:
		var st := String(entry.state)
		var holo := entry.get("holo") as Node3D
		var slab := entry.get("slab") as Node3D
		var rim := entry.get("rim") as Node3D
		if st == "broken":
			continue
		if st == "intact":
			if (entry.trigger_rect as Rect2).has_point(p):
				entry.state = "telegraph"
				entry.timer = 0.0
				if is_instance_valid(holo):
					holo.visible = true
					var curtains := holo.get_node_or_null("HazardHoloCurtains") as Node3D
					if curtains != null:
						curtains.visible = true
				_launch_fracture_missiles(entry)
		elif st == "telegraph":
			entry.timer = float(entry.timer) + delta
			var dur := 0.48
			var t := clampf(float(entry.timer) / dur, 0.0, 1.0)
			for m_data: Dictionary in entry.get("missiles", []):
				var m_node := m_data.get("node") as Node3D
				if not is_instance_valid(m_node):
					continue
				var s3: Vector3 = m_data.start
				var e3: Vector3 = m_data.target
				var apex := float(m_data.apex)
				var pos3 := s3.lerp(e3, t) + Vector3.UP * (sin(t * PI) * apex)
				var t_next := minf(1.0, t + 0.04)
				var next3 := s3.lerp(e3, t_next) + Vector3.UP * (sin(t_next * PI) * apex)
				m_node.position = pos3
				var aim_dir := next3 - pos3
				if aim_dir.length_squared() > 0.001 and absf(aim_dir.normalized().y) < 0.99:
					m_node.look_at(next3, Vector3.UP)
				m_data.smoke_acc = float(m_data.smoke_acc) + delta
				if float(m_data.smoke_acc) >= 0.065:
					m_data.smoke_acc = 0.0
					if not is_instance_valid(burn):
						burn = preload("res://scripts/dream/burning_effects.gd").install(self)
					if is_instance_valid(burn) and is_instance_valid(burn.get("effects")):
						var fx_m: Node3D = burn.effects
						fx_m.emit_smoke(fx_m.to_local(to_global(pos3)), 3, 0.55)
			if t >= 1.0:
				if not is_instance_valid(burn):
					burn = preload("res://scripts/dream/burning_effects.gd").install(self)
				var cut_r: Rect2 = entry.cutout_rect
				var cc := cut_r.get_center()
				var impact3 := Vector3(cc.x, 0.45, cc.y)
				for m_data: Dictionary in entry.get("missiles", []):
					var m_node := m_data.get("node") as Node3D
					if is_instance_valid(m_node):
						m_node.queue_free()
				entry.missiles = []
				if is_instance_valid(burn) and is_instance_valid(burn.get("effects")):
					var fx_b: Node3D = burn.effects
					fx_b.explode(fx_b.to_local(to_global(impact3)), 2.35)
					fx_b.emit_smoke(fx_b.to_local(to_global(impact3 + Vector3.UP * 0.65)), 24, 1.60)
				BLOCKOUT.FREIGHT.spawn_container_debris(
					blockout.floor_root,
					Vector3(cc.x, 0.0, cc.y),
					Vector2.ZERO,
					Vector3(minf(cut_r.size.x, 6.0), 1.4, minf(cut_r.size.y, 6.0)),
					"slate",
					blockout.freight_debris
				)
				SFX.play_world_sfx_3d(&"explosion", to_global(impact3), 0.0, 46.0)
				request_camera_impulse(&"heavy", Vector2.DOWN)
				if is_instance_valid(rim):
					rim.visible = true
				_nudge_player_out_of_drop(entry)
				blockout.set_freight_body_enabled(entry.get("body") as StaticBody2D, true)
				entry.state = "shattering"
				entry.timer = 0.0
				entry.fall_y = 0.0
				entry.fall_vel = 2.4
		elif st == "shattering":
			entry.timer = float(entry.timer) + delta
			entry.fall_vel = float(entry.fall_vel) + 28.0 * delta
			entry.fall_y = float(entry.fall_y) - float(entry.fall_vel) * delta
			if is_instance_valid(slab):
				slab.position.y = float(entry.fall_y)
				slab.rotation += Vector3(entry.tilt_vel) * delta
			if is_instance_valid(holo):
				if float(entry.timer) >= 1.25:
					holo.visible = false
				elif float(entry.timer) > 0.70:
					var curtains := holo.get_node_or_null("HazardHoloCurtains") as Node3D
					if curtains != null:
						curtains.visible = false
					var fade_k := clampf(1.0 - (float(entry.timer) - 0.70) / 0.55, 0.0, 1.0)
					var pad_m := holo.get_meta("pad_mat", null) as ShaderMaterial
					if pad_m != null:
						pad_m.set_shader_parameter("intensity", fade_k)
					for ch: Node in holo.get_children():
						if ch is Label3D:
							(ch as Label3D).modulate.a = 0.94 * fade_k
			if float(entry.fall_y) <= -26.0:
				if is_instance_valid(slab):
					slab.visible = false
				if is_instance_valid(holo):
					holo.visible = false
				entry.state = "broken"


func _update_traversal(delta: float,p: Vector2) -> void:
	if is_instance_valid(player.mounted_vehicle): return
	if jump_time >= 0.0:
		jump_time = minf(jump_time+delta,.46)
		var t := jump_time/.46
		_place_feet(takeoff.lerp(landing,t))
		jump_lift = sin(PI*t)*1.1
		player_depth_bridge.ground_surface_height = jump_lift
		if t >= 1.0:
			jump_time = -1
			jump_lift = 0
			player.movement_enabled = true
			player.set_attacking_enabled(true)
		return
	var pit: Rect2 = PLAN.LOWER.pit
	var at_pit := p.x>PLAN.TRENCH_BRIDGE.end.x and Rect2(pit.position+Vector2(.45,-2.45),Vector2(pit.size.x-.90,2.52)).has_point(p)
	var at_roller := Rect2(PLAN.ROLLER.position+Vector2(.28,PLAN.ROLLER.size.y-.06),Vector2(PLAN.ROLLER.size.x-.56,2.26)).has_point(p)
	var at_belt := Rect2(PLAN.BELT.position+Vector2(-2.45,.3),Vector2(2.54,PLAN.BELT.size.y-.60)).has_point(p)
	var message := objective
	if at_pit: message = "空格  翻滚跳过检修沟"
	elif at_roller: message = "空格  翻越辊架　·　也可从右侧绕行"
	elif at_belt: message = "空格  翻越输送带　·　靠观察窗一侧可绕行"
	elif p.distance_to(PLAN.LOW_GATE.get_center())<5: message = "朝半落卷帘门移动，按空格翻滚"
	elif not plate_warning.is_empty(): message = plate_warning
	elif chase_light_red >= 0.50: message = "警告：已被 H06 探照红光锁定！立即脱离碾压范围"
	instruction.text = message
	if not (at_roller or at_belt) or player.dashing or not Input.is_action_just_pressed(&"roll"): return
	var direction: Vector2 = player._read_gameplay_movement_input()
	if direction.length_squared()<.01: direction = player.last_move_direction
	if (at_belt and direction.x<.4) or (at_roller and direction.y>-.4): return
	takeoff = p
	landing = Vector2(p.x,PLAN.ROLLER.position.y-.84) if at_roller else Vector2(PLAN.BELT.end.x+.90,p.y)
	jump_time = 0.0
	player.movement_enabled = false
	player.set_attacking_enabled(false,true)
	player.velocity = Vector2.ZERO

func is_player_dash_landing_allowed(point: Vector2) -> bool:
	var p: Vector2 = (point+player.body_collision.global_position-player.global_position)/CELL_PIXELS
	if blockout==null or climbing: return false
	var id := blockout.visit
	if not PLAN.visit_contains(id,p,on_lower_floor):
		if not _can_enter_next() or not PLAN.visit_contains(id+1,p,on_lower_floor): return false
		var cross := PLAN.passage_coordinates(id,p)
		var from := PLAN.passage_coordinates(id,_feet())
		var width: float = PLAN.PASSAGES[id].width
		var t := clampf(-from.x/maxf(.0001,cross.x-from.x),0,1)
		if cross.x<0 or from.x>PLAN.ENTRY_DEPTH or absf(lerpf(from.y,cross.y,t))>width*.5: return false
		for prop: Array in PLAN.PROPS.values():
			if (prop[0] as Rect2).grow(.2).has_point(p): return false
	if id==PLAN.Visit.GALLERY and not on_lower_floor:
		for furniture: Rect2 in PLAN.WATCH_FIXTURES.values():
			if _crosses_rect(_feet(),p,furniture.grow(.12)): return false
	if on_lower_floor:
		for solid: Rect2 in blockout.fixture_barriers:
			if _crosses_rect(_feet(),p,solid.grow(.12)): return false
		if id==PLAN.Visit.FREIGHT and blockout!=null:
			for cl: Dictionary in blockout.freight_clutter_entries:
				if not bool(cl.get("exploded", false)) and _crosses_rect(_feet(),p,(cl.rect as Rect2).grow(.12)): return false
			for plate: Dictionary in blockout.unstable_plates:
				if plate.state in ["falling","collapsed"] and (plate.rect as Rect2).grow(-0.20).has_point(p): return false
			for bay: Dictionary in blockout.freight_collapse_bays:
				if String(bay.state) in ["falling","collapsed"] and (bay.rect as Rect2).has_point(p): return false
			for br: Dictionary in blockout.freight_breakables:
				if not bool(br.exploded) and _crosses_rect(_feet(),p,(br.rect as Rect2).grow(.12)): return false
			for dr: Dictionary in blockout.freight_deck_drops:
				if bool(dr.get("exploded", false)): continue
				if String(dr.state) in ["telegraph","falling","bounce","landed"]:
					if _crosses_rect(_feet(),p,(dr.rect as Rect2).grow(.12)): return false
					if dr.has("zone_rect"):
						var zr: Rect2 = dr.zone_rect
						if zr.has_point(p) or _crosses_rect(_feet(),p,zr): return false
			for fr: Dictionary in blockout.freight_fractures:
				if String(fr.state) != "intact":
					var zr: Rect2 = fr.zone_rect
					if zr.has_point(p) or _crosses_rect(_feet(),p,zr): return false
		if not breached and PLAN.HEAVY_GATE.grow(.17).has_point(p): return false
		for r: Rect2 in PLAN.PARTITIONS:
			if r.grow(.15).has_point(p): return false
	if blockout != null:
		for key: String in blockout.closed:
			if not blockout.gates.has(key) or not blockout.closed[key]: continue
			if _crosses_rect(_feet(),p,PLAN.GATES[key].grow(.14)): return false
	for solid: Rect2 in (PLAN.WEST_WALLS if id==PLAN.Visit.WEST and not on_lower_floor else (PLAN.STAFF_SCREENS if id==PLAN.Visit.STAFF else [])):
		if _crosses_rect(_feet(),p,solid.grow(.14)): return false
	if id==PLAN.Visit.WEST:
		for prop_key: String in PLAN.PROPS:
			if prop_key=="forklift": continue
			var prop_rect: Rect2 = PLAN.PROPS[prop_key][0]
			if PLAN.visit_contains(id,prop_rect.get_center(),on_lower_floor) and _crosses_rect(_feet(),p,prop_rect.grow(.12)): return false
	return true

func _update_boss_approach(feet: Vector2) -> void:
	if blockout.visit != PLAN.Visit.ARENA: return
	var platform := blockout.inclined_lift
	if platform.is_docked:
		if not PLAN.ARENA_DECK.grow(-1.30).has_point(feet): return
		blockout.set_gate("boarding",true)
		blockout.set_gate("arena",true)
		_remember_weapons()
		platform.start_ascent()
		_prompt("货运平台上行")
	elif platform.travel_age>=LIFT_AMBUSH_DELAY:
		_start_drop()

func _offscreen_drop_origin() -> Vector3:
	var origin := Vector3(PLAN.BOSS_MARK.x,PLAN.ARENA_DROP_HEIGHT,PLAN.BOSS_MARK.y-3.5)
	var visible_rect := camera_3d.get_viewport().get_visible_rect().grow(110.)
	for i in 5:
		var world_at := to_global(origin)
		if camera_3d.is_position_behind(world_at) or not visible_rect.has_point(camera_3d.unproject_position(world_at)): break
		origin.y += 2.
	return origin

func _start_drop() -> void:
	stage = Stage.DROP
	drop_time = 0
	drop_origin = _offscreen_drop_origin()
	var motion := ensure_crawler_motion()
	blockout.mech.show()
	var destination := Vector3(PLAN.BOSS_MARK.x,0,PLAN.BOSS_MARK.y)
	if is_instance_valid(motion):
		motion.teleport(drop_origin,0.)
		motion.begin_drop(destination)
		motion.landed.connect(_crawler_landed,CONNECT_ONE_SHOT)
	else:
		blockout.mech.position = drop_origin
		blockout.stride(0,0)
	SFX.play_world_sfx_3d(&"wall_break",to_global(drop_origin))
	_prompt("避开 H06 落点")

func _update_drop(delta: float) -> void:
	if is_instance_valid(crawler_motion):
		crawler_motion.advance_jump(delta)
		if crawler_motion.jump==CRAWLER_MOTION.Jump.NONE: _begin_crawler_boss()
		return
	drop_time = minf(drop_time+delta,1.15)
	var t := drop_time/1.15
	blockout.mech.position = drop_origin.lerp(Vector3(PLAN.BOSS_MARK.x,0,PLAN.BOSS_MARK.y),t)
	blockout.mech.position.y = drop_origin.y*(1-t*t)
	if t<1.0: return
	_crawler_landed()
	_begin_crawler_boss()

func _crawler_landed() -> void:
	blockout.inclined_lift.shake_on_landing()
	if is_instance_valid(blockout.evacuation): blockout.evacuation.hit_by_crawler()
	request_camera_impulse(&"heavy",Vector2.DOWN)
	SFX.play_world_sfx_3d(&"wall_break",blockout.mech.global_position,2)
	if get_meta(&"h06_boss_patterns",true):
		var feet:Array=crawler_motion.gait.legs if is_instance_valid(crawler_motion) else []
		preload("res://scripts/testing/h06_chapter/crawler_attack_effects.gd").landing_dust(self,blockout.mech.position,feet)
		set_meta(&"h06_landing_smoke_count",int(get_meta(&"h06_landing_smoke_count",0))+1)
	if _feet().distance_to(PLAN.BOSS_MARK)<2.65: player.receive_damage(25,&"h06_landing",PLAN.BOSS_MARK*CELL_PIXELS)

func _begin_crawler_boss() -> void:
	stage = Stage.BOSS
	boss = CRAWLER.new()
	boss.name = "H06"
	boss.configure(self,blockout.mech,PLAN.BOSS_MARK)
	enemy_root.add_child(boss)
	boss_bar = BAR.new()
	var layer := CanvasLayer.new()
	layer.layer = 33
	layer.custom_viewport = get_tree().root
	add_child(layer)
	layer.add_child(boss_bar)
	boss_bar.anchor_top = .085
	boss_bar.anchor_bottom = .085
	boss_bar.get_node("BossName").text = "H06 六足战术爬虫"
	boss.health_changed.connect(boss_bar.set_health_ratio)
	boss.defeated.connect(_boss_down,CONNECT_ONE_SHOT)
	_prompt("击败 H06")

func _boss_down() -> void:
	stage = Stage.EXIT
	if is_instance_valid(crawler_motion): crawler_motion.disable()
	boss_bar.dismiss()
	blockout.inclined_lift.finish_ascent()
	_prompt("货运平台驶向上层")
	var fall := blockout.mech.create_tween().set_parallel(true)
	fall.tween_property(blockout.mech,"rotation:z",.24,.55)
	fall.tween_property(blockout.mech,"position:y",-.23,.55)

func _finish_platform_ride() -> void:
	stage = Stage.DONE
	player.set_attacking_enabled(false,true)
	player.set_dash_enabled(false)
	player.clear_scripted_locomotion()
	player.movement_enabled = false
	var truck := blockout.forklift
	if is_instance_valid(truck) and truck.driver==player:
		truck.set_physics_process(false)
		truck.set_process_unhandled_key_input(false)
		truck.speed = 0.
		truck.velocity = Vector2.ZERO
		if is_instance_valid(truck.drive_audio): truck.drive_audio.stop_all()
		if is_instance_valid(truck.boost_wind): truck.boost_wind.clear()
	SFX.play_event(&"elevator_ding")
	if bool(get_meta(&"chapter_one",false)):
		_prompt("货运平台已到站")
		call_deferred(&"_complete_chapter_run")
	else:
		_prompt("第一章结束　　F5 重新开始")

func _complete_chapter_run() -> void:
	await get_tree().create_timer(0.45,false).timeout
	if is_inside_tree():
		chapter_completed.emit()

func restart_current_floor_after_death() -> bool:
	if restart_queued or not player.dead: return false
	restart_queued = true
	var vehicle_save := {}
	if is_instance_valid(blockout.forklift):
		vehicle_save = blockout.forklift.save_state()
		vehicle_save["visit"] = blockout.visit
	get_tree().set_meta(RETRY_KEY,{"checkpoint":checkpoint,"seen":seen_windows.keys(),"secret":discovered,"loadout":saved_loadout,"forklift":vehicle_save,"helmet":player.helmet_equipped,"staff_story":staff_story.snapshot()})
	get_tree().paused = false
	if has_meta(&"story_retry_handler"):
		var retry_handler: Variant = get_meta(&"story_retry_handler")
		if retry_handler is Callable and (retry_handler as Callable).is_valid():
			(retry_handler as Callable).call()
			return true
	get_tree().call_deferred("reload_current_scene")
	return true

func _restore_checkpoint(save: int) -> void:
	checkpoint = save
	if save == Save.ENTRANCE:
		_prompt("沿展廊前往 206")
		return
	_spotlight_triggered = true
	if blockout.visit in [PLAN.Visit.GALLERY,PLAN.Visit.EMPTY_HANGAR]: blockout.play_spotlight_reveal(true)
	if is_instance_valid(blockout.mech): blockout.mech.visible = blockout.visit==PLAN.Visit.GALLERY
	var cleared_at := {"calibration":Save.CALIBRATED,"pump":Save.RETURN_BAY}
	for gate: String in cleared_at:
		if save>=int(cleared_at[gate]): blockout.set_gate(gate,false)
	if blockout.visit==PLAN.Visit.WEST:
		warehouse_triggered.clear()
		warehouse_cleared.clear()
		if save>=Save.INSPECTION:
			warehouse_triggered["guard"] = true
			warehouse_cleared["guard"] = true
		# A partial legacy inspection/archive save restarts their paired
		# encounter. PUMP is the first save after both shutter cohorts clear.
		if save>=Save.PUMP:
			warehouse_triggered["inspection"] = true
			warehouse_cleared["inspection"] = true
			blockout.close_west_shutter("inspection",true)
			warehouse_triggered["archive"] = true
			warehouse_cleared["archive"] = true
			blockout.close_west_shutter("archive",true)
	_set_lower(save>=Save.RETURN_BAY)
	match save:
		Save.OBSERVATION: _place_feet(Vector2(-5.5,-16)); _prompt("从监控室北侧进入西翼检验区")
		Save.CALIBRATED: _place_feet(Vector2(-5.4,-30)); _prompt("西翼警戒栏杆已破开　·　进入仓库清剿目标")
		Save.GUARD: _place_feet(Vector2(-15.2,-29)); _prompt("进入门卫室")
		Save.INSPECTION: _place_feet(Vector2(-27.8,-30.7)); stage = Stage.GUARD; _prompt("进入零件检验室")
		Save.ARCHIVE: _place_feet(Vector2(-38.7,-20.6)); stage = Stage.INSPECTION; _prompt("进入样本库")
		Save.PUMP: _place_feet(Vector2(-27.6,-14.2)); stage = Stage.ARCHIVE; _prompt("进入泵房")
		Save.RETURN_BAY,Save.TRANSFER:
			_place_feet(Vector2(-8.8,7.5) if save==Save.RETURN_BAY else Vector2(.5,9.0))
			stage = Stage.SEARCH
			_prompt("机位空了　·　从南门进入货运区" if save==Save.RETURN_BAY else "从南门进入货运区")
		Save.CHASE,Save.MIDPOINT,Save.CROSS_DOCK:
			var marks := {Save.CHASE:Vector2(.5,18.4),Save.MIDPOINT:Vector2(12.1,62.7),Save.CROSS_DOCK:Vector2(61.5,88.4)}
			_place_feet(marks[save])
			_start_chase(save)
		Save.STAFF,Save.ARMORY,Save.ARENA:
			var marks := {Save.STAFF:Vector2(44.5,34),Save.ARMORY:Vector2(28.5,35.2),Save.ARENA:Vector2(38,16)}
			_place_feet(marks[save])
			stage = Stage.APPROACH if save==Save.ARENA else Stage.STAFF
			blockout.set_gate("refuge",true)
			chase_distance = mech_path.get_baked_length()
			ramp_distance = escape_path.get_baked_length()
			blockout.ensure_chase_crawler()
			blockout.mech.position = PLAN.FREIGHT_EXIT[-1]
			blockout.mech.hide()
			_stock_armory()
			_prompt("物流中枢　·　穿行各功能舱室休整，北出口东北角武器库整备后前往电梯" if stage==Stage.STAFF else "北出口大厅　·　可在东北角武器库换枪后前往电梯大厅")
	_sync_height_immediate()
func _crosses_rect(a: Vector2,b: Vector2,r: Rect2) -> bool:
	if r.has_point(b): return true
	if r.has_point(a): return false
	var corners := [r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a,b,corners[i],corners[(i+1)%4])!=null: return true
	return false

func _start_ladder(down: bool) -> void:
	climbing = true
	going_down = down
	ladder_elapsed = 0
	ladder_start = _feet()
	ladder_end = PLAN.LADDER_FOOT if down else PLAN.HATCH
	player.movement_enabled = false
	player.set_attacking_enabled(false,true)
	player.velocity = Vector2.ZERO
	blockout.open_hatch(true)
	blockout.service_view(true,PLAN.LADDER_FOOT)
	instruction.text = ""

func _ladder_height() -> float:
	var t := smoothstep(0,.55,ladder_elapsed)
	return PLAN.upper_height(PLAN.HATCH)*(1.0-t if going_down else t)

func _tick_ladder(delta: float) -> void:
	ladder_elapsed = minf(.55,ladder_elapsed+delta)
	var t := smoothstep(0,.55,ladder_elapsed)
	_place_feet(ladder_start.lerp(ladder_end,t))
	if ladder_elapsed<.55: return
	climbing = false
	_set_lower(going_down)
	blockout.open_hatch(going_down)
	player.movement_enabled = true
	player.set_attacking_enabled(true)
	previous_feet = _feet()
	_sync_height_immediate()
