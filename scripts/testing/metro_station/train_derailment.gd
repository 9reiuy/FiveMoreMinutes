extends Node3D
## One-way, floor-owned destruction clock. Gameplay and scenery retire together.
const CONSIST := preload("res://scripts/testing/metro_station/train_chapter_consist.gd")
const PARTICLES := preload("res://scripts/dream/elemental_particles_3d.gd")
const INTERVAL := 20.0
const RETIRE_DISTANCE := CONSIST.D.TRAIN_LENGTH + CONSIST.D.CAR_LENGTH
# Temporary: the chosen washing-machine blast stands in for the carriage explosion.
const CRASH := preload("res://sfx/metro/train_explosion.wav")
var world: Node3D
var consist: CONSIST
var elapsed_real := 0.0
var next_car := 0
var retired: Dictionary = {}
var wrecks: Array[Dictionary] = []
var effects: Node3D
var _last_clock_usec := 0
var _travel := 0.0


func configure(owner_world: Node3D, player_train: CONSIST) -> void:
	world = owner_world
	consist = player_train
	name = "TrainDerailment"
	effects = PARTICLES.new()
	effects.name = "CarExplosionEffects"
	add_child(effects)
	effects.set_wind(Vector3(-5,0,0))
	var pause_manager := get_node_or_null("/root/PauseManager")
	if pause_manager != null: pause_manager.pause_state_changed.connect(_on_pause_changed)


func _on_pause_changed(_paused: bool) -> void:
	_last_clock_usec = 0


func update_clock(enabled: bool) -> void:
	if not enabled:
		_last_clock_usec = 0
		return
	var now := Time.get_ticks_usec()
	if _last_clock_usec > 0: advance((now-_last_clock_usec)/1000000.0)
	_last_clock_usec = now


func advance(real_delta: float) -> void:
	if world.player.dead or next_car >= CONSIST.CAR_COUNT: return
	elapsed_real += maxf(0.0,real_delta)
	while next_car < CONSIST.CAR_COUNT and elapsed_real+.00001 >= INTERVAL*(next_car+1):
		_derail(next_car)
		next_car += 1
		if world.player.dead: return


func _derail(index: int) -> void:
	retired[index] = true
	var occupied: bool = world._room_id_at_position(world.player.global_position) == index
	# Retire occupants before removing floor support, so death effects cannot
	# recover to a different live carriage or leave a weapon floating over void.
	for enemy: EmployeeEnemy in world.enemy_root.get_children():
		if int(enemy.get_meta(&"dream_room_id",-1)) != index: continue
		enemy.held_weapon_id = ""
		if not enemy.dead: enemy.force_pit_death(enemy.global_position)
		enemy.hide()
		enemy.queue_free()
	for host: Node in [world.world_weapon_root,world.world_effects_root,world.ground_debris_root,world.pickup_root]:
		for actor: Node in host.get_children():
			if int(actor.get_meta(&"dream_room_id",-1)) != index: continue
			if actor is CanvasItem: actor.hide()
			actor.queue_free()
	world._settled_blood_buckets.clear()
	restore_retired_floor_mask()
	world.employee_path_cache.clear()
	world._open_connected_rooms_cache.clear()
	world._open_boundary_edges_cache.clear()
	# Detonate the coupling, not the passenger cabin. The last remaining car
	# uses its rear coupling because there is no carriage ahead of it.
	var joint_index := mini(index,CONSIST.CAR_COUNT-2)
	var at := consist.root.to_global(Vector3(CONSIST.joint(joint_index),CONSIST.DECK_OFFSET+.65,0))
	var car := consist.detach_tail_car(index,self)
	effects.explode(effects.to_local(at),1.5)
	var voice := AudioStreamPlayer3D.new()
	voice.stream = CRASH
	voice.bus = &"Environment"
	voice.volume_db = -9.0
	voice.max_distance = 55.0
	effects.add_child(voice)
	voice.global_position = at
	voice.finished.connect(voice.queue_free)
	voice.play()
	world.request_camera_impulse(&"heavy",Vector2.LEFT)
	wrecks.append({"node":car,"base":car.transform,"travel_at":_travel})
	if occupied: world.player.force_hazard_death(&"train_derailment")


func restore_retired_floor_mask() -> void:
	for index: int in retired:
		for cell: Vector2i in world.rooms[index].shape_cells:
			world.floor_cells.erase(cell)
			world.presentation_floor_cells.erase(cell)
			world.room_cells.erase(cell)
		world.room_states[index] = &"RETIRED"


func set_travel(distance: float) -> void:
	# Share the scenery's actual travel rather than a second real-time clock.
	# Pauses, the dodge slow motion and station braking then stay in sync.
	_travel = distance
	effects.position.x = -distance
	for i in range(wrecks.size()-1,-1,-1):
		var wreck: Dictionary = wrecks[i]
		var node: Node3D = wreck.node
		var behind: float = maxf(0.0,distance-wreck.travel_at)
		if behind >= RETIRE_DISTANCE:
			node.queue_free()
			wrecks.remove_at(i)
			continue
		node.transform = wreck.base
		node.position.x -= behind
