extends Node3D
## Fixed-direction sparse lighting. Neither rooms nor actors own the light pose.
## Original lights remain available for explicit rollback, not toggled per draw.
const MAIN_RAY := Vector3(1.7, -2.25, -1.1)
var world: Node3D
var main: DirectionalLight3D
var fill: DirectionalLight3D
var environment_owner: WorldEnvironment
var original_environment: Environment
var sparse_environment: Environment
var enabled := false
var suspended := false
var powered := true
var _allow_window_spots := false
var _floor_token := -1
var _pending: Array[WeakRef] = []
var _suppressed: Dictionary = {}

func configure(owner_world: Node3D) -> void:
	world = owner_world
	# No per-frame player lookup or source transform update.
	set_process(false)
	environment_owner = world.get_node("Lighting/WorldEnvironment")
	original_environment = environment_owner.environment
	sparse_environment = original_environment.duplicate()
	sparse_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sparse_environment.ambient_light_color = Color("6d7e9a")
	sparse_environment.ambient_light_energy = .025 if world.uses_office_night_lighting() else .52
	main = DirectionalLight3D.new()
	main.name = "SparseMainLight"
	add_child(main)
	main.light_color = Color("d5dce7")
	# Directional light has no distance/cone falloff; do not reuse spot energy.
	main.light_energy = 0.65
	main.light_specular = 0.0
	main.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	main.directional_shadow_max_distance = 28.0
	main.directional_shadow_fade_start = 0.8
	main.light_cull_mask = 15
	main.shadow_caster_mask = 15
	main.shadow_enabled = world.dynamic_shadows_enabled
	main.shadow_bias = 0.035
	main.shadow_normal_bias = 0.6
	main.global_basis = Basis.looking_at(MAIN_RAY.normalized(), Vector3.UP)
	main.hide()
	fill = DirectionalLight3D.new()
	fill.name = "SparseShapeFill"
	add_child(fill)
	# The accepted preview's fill is local to the rotated gameplay world.
	fill.rotation_degrees = Vector3(-52, -30, 0)
	fill.light_energy = 0.24
	fill.light_color = Color("bcc9e3")
	fill.light_specular = 0.0
	fill.light_cull_mask = 15
	fill.shadow_enabled = false
	fill.hide()
	get_tree().node_added.connect(_node_added)
	RenderingServer.frame_pre_draw.connect(_before_draw)
	set_enabled(true)

func set_enabled(value: bool) -> void:
	if enabled == value: return
	enabled = value
	if is_instance_valid(world.shadow_manager):
		world.shadow_manager.set_sparse_lighting_enabled(value)
	if enabled:
		for node in world.find_children("*", "Light3D", true, false):
			_register_light(node)
		prepare_loading_pose()
	else:
		_restore_lights()
		_pending.clear()
	_sync_power()

func set_suspended(value: bool) -> void:
	suspended = value
	_sync_power()

func set_window_spot_passthrough(value: bool) -> void:
	if _allow_window_spots == value: return
	_allow_window_spots = value
	if not value:
		for source in world.shadow_manager.window_sources:
			if is_instance_valid(source.light): _keep_hidden(source.light.get_instance_id())

func prepare_loading_pose() -> void:
	# Retain the loading contract without positioning a source at the player.
	_floor_token = world.get_current_floor_token()

func _node_added(node: Node) -> void:
	# Inspect final names/ancestry after construction, not the partial add_child.
	if enabled and node is Light3D and world.is_ancestor_of(node) and not is_ancestor_of(node):
		_pending.append(weakref(node))

func _register_light(light: Light3D) -> void:
	if not is_instance_valid(light) or is_ancestor_of(light): return
	var path := String(world.get_path_to(light))
	for fragment in ["Elevator", "elevator", "NightLighting", "ExteriorPatrolDrones", "HotelRobot", "Muzzle", "Flashlight"]:
		if path.contains(fragment): return
	if is_instance_valid(world.shadow_manager) and light == world.shadow_manager.sun: return
	var id := light.get_instance_id()
	if _suppressed.has(id): return
	_suppressed[id] = {"ref":weakref(light), "visible":light.visible}
	light.visibility_changed.connect(_keep_hidden.bind(id))
	light.tree_exiting.connect(_forget_light.bind(id), CONNECT_ONE_SHOT)
	light.hide()

func _keep_hidden(id: int) -> void:
	if not enabled or not _suppressed.has(id): return
	var light: Node3D = _suppressed[id].ref.get_ref()
	if _allow_window_spots and is_instance_valid(light) and light.has_meta(&"window_source_energy"): return
	# Room/city presentation may request show() later in frame_pre_draw. Apply
	# the policy synchronously so callback order cannot flash the old sources.
	if is_instance_valid(light) and light.visible: light.hide()

func _forget_light(id: int) -> void:
	if not _suppressed.has(id): return
	var light: Node3D = _suppressed[id].ref.get_ref()
	var visible: bool = _suppressed[id].visible
	_suppressed.erase(id)
	if is_instance_valid(light):
		var callback := _keep_hidden.bind(id)
		if light.visibility_changed.is_connected(callback): light.visibility_changed.disconnect(callback)
		light.visible = visible

func _restore_lights() -> void:
	for id in _suppressed.keys():
		var light: Node3D = _suppressed[id].ref.get_ref()
		if is_instance_valid(light):
			var callback := _forget_light.bind(id)
			if light.tree_exiting.is_connected(callback): light.tree_exiting.disconnect(callback)
		_forget_light(id)

func _before_draw() -> void:
	if not enabled or not is_instance_valid(world): return
	for reference in _pending:
		var node = reference.get_ref()
		if is_instance_valid(node) and node.is_inside_tree() and world.is_ancestor_of(node): _register_light(node)
	_pending.clear()
	_sync_power()

func _sync_power() -> void:
	if not is_instance_valid(world): return
	powered = true
	for cabinet in get_tree().get_nodes_in_group(&"floor_power_switches"):
		if not world.is_ancestor_of(cabinet): continue
		# Rollback stashes belong to the old floor, not the newly loaded one.
		if int(cabinet.get_meta(&"wall_attachment_floor", world.get_current_floor_token())) != world.get_current_floor_token(): continue
		if not cabinet.powered: powered = false
	var show_lights := enabled and powered and not suspended
	var native_night: bool = world.uses_office_night_lighting()
	main.visible = show_lights and not native_night
	fill.visible = main.visible
	var retain_night := enabled and native_night and not suspended
	var wanted: Environment = sparse_environment if show_lights or retain_night else original_environment
	if environment_owner.environment != wanted: environment_owner.environment = wanted

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_before_draw): RenderingServer.frame_pre_draw.disconnect(_before_draw)
	if get_tree().node_added.is_connected(_node_added): get_tree().node_added.disconnect(_node_added)
	_restore_lights()
	if is_instance_valid(environment_owner): environment_owner.environment = original_environment
