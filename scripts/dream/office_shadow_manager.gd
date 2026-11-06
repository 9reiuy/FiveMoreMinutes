extends Node3D
## Office-only shadow ownership. Light energy/AI/collision never depend on selection.
const LIMITS := {"low": 2, "standard": 4, "high": 6}
const SUN_RAY := Vector3(-0.45, -0.75, -0.48)
const MOON_RAY := Vector3(.22, -.68, 1.0)
const UPDATE_SECONDS := 0.1
const HOLD_SECONDS := 0.8
const FADE_SECONDS := 0.25
const PLAYER_CASTER_LAYER := 4
## Synthetic roof blocks outdoor moonlight only, not the indoor directional key.
## Bits 18/19 are reserved by reflection capture/city; bit 17 is roof-only.
const MOON_ROOF_LAYER := 1 << 17
const WINDOW_LIMITS := {"low":1,"standard":2,"high":3}
const PERF_TRACE=preload("res://scripts/app/performance_markers.gd")
var _diagnostic_light_signature:=""

var world: Node3D
var quality := "standard"
var suspended := false
var sparse_lighting_enabled := false

func set_sparse_lighting_enabled(value: bool) -> void:
	sparse_lighting_enabled = value
	if value:
		for light in active.keys(): _disable(light)
		selected.clear()
		if is_instance_valid(player_shadow_light): _set_player_caster(player_shadow_light, false)
		player_shadow_light = null
		if is_instance_valid(sun): _set_player_caster(sun, false)
		for source in window_sources:
			if is_instance_valid(source.light): source.light.hide()
			source.weight = 0.0
	_elapsed = UPDATE_SECONDS
	_window_room = -2
var candidates: Array[Light3D] = []
var selected: Array[Light3D] = []
var active: Dictionary = {}
var sun: DirectionalLight3D
var roof: MeshInstance3D
var roof_cell_count := 0
var _elapsed := 0.0
var _clock := 0.0
var _previous_atlas := 0
var _previous_subdivisions: Array[int] = []
var player_shadow_light: Light3D
var _player_caster_masks: Dictionary = {}
var window_sources: Array[Dictionary] = []
var _window_room := -2
var _window_selection: Array[Light3D] = []
var _bounce_weights: Dictionary = {}

func configure(owner_world: Node3D) -> void:
	world = owner_world
	_previous_atlas = get_viewport().positional_shadow_atlas_size
	if world.uses_office_night_lighting():
		for quadrant in 4:
			var setting := "positional_shadow_atlas_quad_%d" % quadrant
			_previous_subdivisions.append(int(get_viewport().get(setting)))
			get_viewport().set(setting, Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_16)
	set_quality(quality)
	process_priority = 20

func set_quality(value: String) -> void:
	quality = value if LIMITS.has(value) else "standard"
	if is_inside_tree():
		get_viewport().positional_shadow_atlas_size = 2048 if quality == "low" else 4096
	# Quality reductions obey the hard cap immediately, even during a fade.
	while active.size() > int(LIMITS[quality]):
		var light: Light3D = active.keys().back()
		_disable(light)
	_elapsed = UPDATE_SECONDS
	_window_room = -2

func _exit_tree() -> void:
	if is_instance_valid(world):
		get_viewport().positional_shadow_atlas_size = _previous_atlas
		for quadrant in _previous_subdivisions.size():
			get_viewport().set("positional_shadow_atlas_quad_%d" % quadrant, _previous_subdivisions[quadrant])

func register_light(light: Light3D) -> void:
	if not is_instance_valid(light) or candidates.has(light):
		return
	light.shadow_enabled = false
	light.shadow_opacity = 0.0
	if bool(light.get_meta(&"fixture_bounce",false)):
		if not light.has_meta(&"fixture_bounce_energy"):
			light.set_meta(&"fixture_bounce_energy",light.light_energy)
		light.light_energy = 0.0
		light.hide()
		light.set_meta(&"bounce_hidden_by_room",true)
	candidates.append(light)
	_player_caster_masks[light] = light.shadow_caster_mask
	_set_player_caster(light, false)
	light.tree_exiting.connect(unregister_light.bind(light), CONNECT_ONE_SHOT)

func unregister_light(light: Light3D) -> void:
	if player_shadow_light == light:
		player_shadow_light = null
	if is_instance_valid(light) and _player_caster_masks.has(light):
		light.shadow_caster_mask = int(_player_caster_masks[light])
	_player_caster_masks.erase(light)
	_bounce_weights.erase(light)
	candidates.erase(light)
	selected.erase(light)
	active.erase(light)

func clear_floor() -> void:
	for source in window_sources:
		if is_instance_valid(source.light): source.light.hide()
	window_sources.clear()
	_bounce_weights.clear()
	_window_selection.clear()
	_window_room = -2
	player_shadow_light = null
	for light in candidates:
		if is_instance_valid(light):
			light.shadow_enabled = false
			if _player_caster_masks.has(light):
				light.shadow_caster_mask = int(_player_caster_masks[light])
	_player_caster_masks.clear()
	candidates.clear()
	selected.clear()
	active.clear()
	for node in [sun, roof]:
		if is_instance_valid(node):
			node.free()
	sun = null
	roof = null
	roof_cell_count = 0

func rebuild_floor() -> void:
	clear_floor()
	if not is_instance_valid(world):
		return
	for wall in world.wall_root.get_children():
		if wall.has_method("set_floor_shadow_lighting_enabled"):
			wall.set_floor_shadow_lighting_enabled(true)
			var lamp: Light3D = wall.get("window_light")
			if is_instance_valid(lamp) and bool(wall.get("window_light_enabled")):
				var room_id := -1
				for cell in world._edge_side_cells(wall.get_meta(&"edge",{})):
					if world.floor_cells.has(cell): room_id = int(world.room_cells.get(cell,-1))
				lamp.hide()
				window_sources.append({"light":lamp,"room":room_id,"weight":0.0,"energy":float(lamp.get_meta(&"window_source_energy",lamp.light_energy))})
	# Traverse live holders rather than cached candidates: rollback reparents fixtures.
	var night: bool = world.uses_office_night_lighting()
	if not night:
		_register_descendants(world.ceiling_light_root)
	_build_roof(night)
	sun = DirectionalLight3D.new()
	sun.name = "ExteriorWindowSun"
	sun.light_color = Color(0.52, 0.76, 1.0)
	sun.light_energy = 0.18
	sun.light_specular = 0.0
	sun.light_cull_mask = 7 | 8 | MOON_ROOF_LAYER
	sun.shadow_enabled = true
	_set_player_caster(sun, false)
	# A shallow sun ray grazing the 45-degree walls used to self-shadow their
	# face at pixel frequency. Move the shadow receiver just enough to remove
	# that moire without removing the real furniture/person/window shadows.
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 28.0
	add_child(sun)
	# A single world-space direction, independent of the rotated map or window normals.
	var ray: Vector3 = world.global_basis * MOON_RAY if night else SUN_RAY
	sun.global_basis = Basis.looking_at(ray.normalized(), Vector3.UP)
	if night:
		sun.light_color = Color("c8d7ed")
		sun.light_energy = .43
		sun.light_angular_distance = .8
		sun.shadow_normal_bias = .16
		sun.shadow_bias = .025
		sun.shadow_caster_mask = 1 | 4 | 8 | MOON_ROOF_LAYER
	sun.visible = not suspended
	_select_window_sources()
	_elapsed = UPDATE_SECONDS

func _select_window_sources() -> void:
	# Local city/sky projectors belong to the entered room, not the visual wall
	# cutaway or the cursor. Selection is stable throughout that room; other
	# facades retain the shared, occluded moon light without dozens of shadow maps.
	_window_room = int(world.current_room_id)
	_window_selection.clear()
	var ranked: Array[Dictionary] = []
	var center: Vector3 = world.get_gameplay_world_position(world._room_bounds_pixels(_window_room,0.0).get_center())
	for source in window_sources:
		if is_instance_valid(source.light) and source.room == _window_room: ranked.append(source)
	ranked.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.light.global_position.distance_squared_to(center) < b.light.global_position.distance_squared_to(center))
	for i in mini(ranked.size(),int(WINDOW_LIMITS[quality])):
		_window_selection.append(ranked[i].light)
	# Room commits already replace the camera view. Do not overlap old/new
	# shadow maps during that commit or exceed the quality cap on a downgrade.
	for source in window_sources:
		if is_instance_valid(source.light) and not _window_selection.has(source.light):
			source.weight = 0.0
			source.light.hide()

func _update_window_sources(delta: float) -> void:
	if _window_room != int(world.current_room_id): _select_window_sources()
	for source in window_sources:
		var lamp: Light3D = source.light
		if not is_instance_valid(lamp): continue
		var target := 1.0 if _window_selection.has(lamp) else 0.0
		source.weight = move_toward(float(source.weight),target,delta / FADE_SECONDS)
		lamp.light_energy = float(source.energy) * float(source.weight)
		lamp.visible = float(source.weight) > 0.001

func _register_descendants(node: Node) -> void:
	for child in node.get_children():
		if child is Light3D and child.get_meta(&"shadow_kind", &"") == &"interior":
			register_light(child)
		_register_descendants(child)

func _build_roof(solid := false) -> void:
	var cells: Dictionary = world.floor_cells
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var y: float = world.wall_height
	var solid_mesh := SurfaceTool.new()
	solid_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var unit_box := BoxMesh.new()
	unit_box.size = Vector3.ONE
	# Horizontal runs coalesce adjacent cells without filling missing L/T corners.
	var rows: Dictionary = {}
	for cell: Vector2i in cells:
		if not solid and int(world.room_cells.get(cell, -1)) == int(world.elevator_room_id):
			continue
		if not rows.has(cell.y):
			rows[cell.y] = []
		rows[cell.y].append(cell.x)
		roof_cell_count += 1
	for z: int in rows:
		var xs: Array = rows[z]
		xs.sort()
		var start: int = xs[0]
		var end := start
		for i in range(1, xs.size() + 1):
			if i < xs.size() and int(xs[i]) == end + 1:
				end = int(xs[i])
				continue
			var base := vertices.size()
			# Cells are centered on integer world coordinates, matching floor meshes.
			vertices.append_array(PackedVector3Array([Vector3(start - .5, y, z - .5), Vector3(end + .5, y, z - .5), Vector3(end + .5, y, z + .5), Vector3(start - .5, y, z + .5)]))
			indices.append_array(PackedInt32Array([base, base+2, base+1, base, base+3, base+2]))
			if solid:
				var size := Vector3(float(end - start + 1), .18, 1.0)
				var center := Vector3((start + end) * .5, y + .09, z)
				solid_mesh.append_from(unit_box, 0, Transform3D(Basis.from_scale(size), center))
			if i < xs.size():
				start = int(xs[i])
				end = start
	if vertices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	roof = MeshInstance3D.new()
	roof.name = "FootprintRoofShadowOnly"
	roof.mesh = solid_mesh.commit() if solid else mesh
	roof.layers = MOON_ROOF_LAYER
	roof.material_override = material
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	add_child(roof)
	roof.visible = not suspended

func set_suspended(value: bool) -> void:
	suspended = value
	if value:
		for source in window_sources:
			if is_instance_valid(source.light): source.light.hide()
			source.weight = 0.0
	for node in [sun, roof]:
		if is_instance_valid(node):
			node.visible = not value
	if value:
		if is_instance_valid(player_shadow_light): _set_player_caster(player_shadow_light, false)
		player_shadow_light = null
		for light in active.keys():
			_disable(light)
		selected.clear()
	_elapsed = UPDATE_SECONDS

func _process(delta: float) -> void:
	if sparse_lighting_enabled or suspended or not is_instance_valid(world):
		return
	delta = world._get_presentation_delta(delta)
	var room_changed := _window_room != int(world.current_room_id)
	_update_window_sources(delta)
	if room_changed: _elapsed = UPDATE_SECONDS
	# Reflected fixture light must never become an unshadowed room flood when
	# it loses a shadow slot. Only the entered room's selected source can emit.
	for lamp in candidates:
		if is_instance_valid(lamp) and bool(lamp.get_meta(&"fixture_bounce",false)):
			if int(lamp.get_meta(&"shadow_room_id",-1))!=int(world.current_room_id) or not active.has(lamp):
				lamp.hide()
				lamp.set_meta(&"bounce_hidden_by_room",true)
	_clock += delta
	_elapsed += delta
	if _elapsed >= UPDATE_SECONDS:
		_elapsed = 0.0
		_select_lights()
	for light in active.keys():
		if not is_instance_valid(light):
			active.erase(light)
			continue
		var target := 1.0 if selected.has(light) else 0.0
		if bool(light.get_meta(&"fixture_bounce",false)):
			# Fade reflected ENERGY, never the wall's occlusion. Starting with
			# transparent shadows briefly lit straight through solid room walls.
			var weight := move_toward(float(_bounce_weights.get(light,0.0)),target,delta / FADE_SECONDS)
			_bounce_weights[light] = weight
			light.shadow_opacity = 1.0
			light.light_energy = float(light.get_meta(&"fixture_bounce_energy",0.0))*weight
			if target>0.0 and weight>0.0 and int(light.get_meta(&"shadow_room_id",-1))==int(world.current_room_id) and bool(light.get_meta(&"bounce_hidden_by_room",false)):
				light.show()
				light.set_meta(&"bounce_hidden_by_room",false)
			if target==0.0 and weight<=0.0: _disable(light)
			continue
		var next_opacity := move_toward(light.shadow_opacity, target, delta / FADE_SECONDS)
		if light.shadow_opacity != next_opacity:
			light.shadow_opacity = next_opacity
		if target == 0.0 and next_opacity <= 0.0:
			_disable(light)
	for light in selected:
		if active.size() >= int(LIMITS[quality]):
			break
		if is_instance_valid(light) and not active.has(light):
			active[light] = _clock
			light.shadow_enabled = true
			light.shadow_opacity = 0.0
			if bool(light.get_meta(&"fixture_bounce",false)):
				_bounce_weights[light]=0.0
				light.light_energy=0.0
				light.shadow_opacity=1.0
				light.show()
				light.set_meta(&"bounce_hidden_by_room",false)
	_update_player_shadow_light()
	if PERF_TRACE.current(self)!=null:
		var state:Array=[]
		for light in active:
			if is_instance_valid(light):state.append([light.get_instance_id(),light.shadow_enabled,light.shadow_opacity>0.0,light.shadow_caster_mask])
		var signature:=String(quality)+str(state)
		if signature!=_diagnostic_light_signature:
			_diagnostic_light_signature=signature
			PERF_TRACE.lighting_event(world,"live_selection")

func _set_player_caster(light: Light3D, enabled: bool) -> void:
	var next_mask := light.shadow_caster_mask | PLAYER_CASTER_LAYER if enabled else light.shadow_caster_mask & ~PLAYER_CASTER_LAYER
	if light.shadow_caster_mask != next_mask: light.shadow_caster_mask = next_mask

func _player_light_score(light: Light3D, point: Vector3) -> float:
	if not is_instance_valid(light) or not light.shadow_enabled or not light.is_visible_in_tree() or light.shadow_opacity <= 0.0:
		return 0.0
	# Bounce does not replace the established directional body/weapon shadow.
	if bool(light.get_meta(&"fixture_bounce",false)): return 0.0
	if light.light_cull_mask & PLAYER_CASTER_LAYER == 0 or int(_player_caster_masks.get(light, light.shadow_caster_mask)) & PLAYER_CASTER_LAYER == 0:
		return 0.0
	var offset := point - light.global_position
	var distance := offset.length()
	var radius: float = light.spot_range if light is SpotLight3D else (light.omni_range if light is OmniLight3D else 0.0)
	if radius <= 0.0 or distance >= radius: return 0.0
	var cone := 1.0
	if light is SpotLight3D and distance > 0.001:
		var edge := cos(deg_to_rad(light.spot_angle))
		cone = clampf((-light.global_basis.z).dot(offset / distance) - edge, 0.0, 1.0) / maxf(1.0 - edge, 0.001)
		cone = pow(cone, light.spot_angle_attenuation)
	return light.light_energy * cone / maxf(distance * distance, 0.25)

func _update_player_shadow_light() -> void:
	# A single existing lamp owns the player's body projection. Other lamps
	# still cast all environment/enemy shadows and illuminate the player/floor.
	# Receiver masks, energies and the body geometry never change here.
	if suspended or not is_instance_valid(world) or not is_instance_valid(world.player): return
	var point: Vector3 = world.get_gameplay_world_position(world.player.global_position) + Vector3.UP * 0.65
	var view: Camera3D = world.get("camera_3d")
	var toward_view := Vector3(view.global_basis.z.x, 0, view.global_basis.z.z).normalized() if is_instance_valid(view) else Vector3.ZERO
	var winner: Light3D
	var best := 0.0
	var front := false
	for light: Light3D in active:
		var score := _player_light_score(light, point)
		if score <= 0.0: continue
		# Prefer the lamp whose floor projection falls in front of the feet,
		# keeping the readable long shadow rather than a silhouette behind hair.
		var candidate_front := (point-light.global_position).dot(toward_view) > 0.001
		if (candidate_front and not front) or (candidate_front == front and score > best):
			best = score; winner = light; front = candidate_front
	if is_instance_valid(player_shadow_light) and active.has(player_shadow_light):
		var incumbent := _player_light_score(player_shadow_light, point)
		var incumbent_front := (point-player_shadow_light.global_position).dot(toward_view) > 0.001
		if incumbent > 0.0 and incumbent_front == front and best < incumbent * 1.4:
			winner = player_shadow_light
	if winner == null and is_instance_valid(sun) and sun.is_visible_in_tree(): winner = sun
	if winner == player_shadow_light: return
	if is_instance_valid(player_shadow_light): _set_player_caster(player_shadow_light, false)
	player_shadow_light = winner
	if is_instance_valid(winner): _set_player_caster(winner, true)

func _disable(light: Light3D) -> void:
	if is_instance_valid(light):
		if bool(light.get_meta(&"fixture_bounce",false)):
			light.hide()
			light.light_energy=0.0
			light.set_meta(&"bounce_hidden_by_room",true)
		_set_player_caster(light, false)
		if player_shadow_light == light: player_shadow_light = null
		light.shadow_enabled = false
		light.shadow_opacity = 0.0
	active.erase(light)
	_bounce_weights.erase(light)


func prepare_loading_selection() -> void:
	# Resolve the same visible candidates without consuming gameplay/presentation
	# time. Their opacity starts at zero, just as on the first normal update.
	if sparse_lighting_enabled or suspended or not is_instance_valid(world): return
	_select_lights()
	for light in selected:
		if active.size()>=int(LIMITS[quality]): break
		if is_instance_valid(light) and not active.has(light):
			active[light]=_clock
			light.shadow_enabled=true
			light.shadow_opacity=0.0
			if bool(light.get_meta(&"fixture_bounce",false)):
				_bounce_weights[light]=0.0
				light.light_energy=0.0
				light.shadow_opacity=1.0
				light.show()
				light.set_meta(&"bounce_hidden_by_room",false)

func _score(light: Light3D, player_pos: Vector3 = Vector3.INF, enemy_positions: PackedVector3Array = PackedVector3Array()) -> float:
	var bounce := bool(light.get_meta(&"fixture_bounce",false))
	if bounce and int(light.get_meta(&"shadow_room_id",-1))!=int(world.current_room_id):
		return 0.0
	if not bounce and not light.is_visible_in_tree():
		return 0.0
	var camera: Camera3D = world.camera_3d
	var radius: float = light.spot_range if light is SpotLight3D else (light.omni_range if light is OmniLight3D else 5.0)
	var center := light.global_position
	center.y -= minf(radius * 0.5, 2.0)
	var distance := camera.global_position.distance_to(center)
	var size := camera.get_viewport().get_visible_rect().size
	var screen := camera.unproject_position(center)
	var screen_radius := size.y * radius / maxf(distance, 1.0)
	var visible_area := Rect2(Vector2.ZERO, size).intersection(Rect2(screen - Vector2.ONE * screen_radius, Vector2.ONE * screen_radius * 2.0)).get_area()
	if visible_area <= 0.0 or camera.is_position_behind(center):
		return 0.0
	var relevance := 1.0
	var resolved_player_pos: Vector3 = player_pos if player_pos.is_finite() else world.get_gameplay_world_position(world.player.global_position)
	if center.distance_to(resolved_player_pos) < radius:
		relevance += 0.5
	if not enemy_positions.is_empty():
		var radius_sq := radius * radius
		for e_pos in enemy_positions:
			if center.distance_squared_to(e_pos) < radius_sq:
				relevance += 0.2
				break
	else:
		for enemy in world.enemy_root.get_children():
			if enemy is Node2D and center.distance_to(world.get_gameplay_world_position(enemy.global_position)) < radius:
				relevance += 0.2
				break
	# Reserve a real shadow slot for the broad reflected source before the
	# remaining slots are assigned to direct fixtures. Never add an extra map.
	var energy: float = float(light.get_meta(&"fixture_bounce_energy",light.light_energy)) if bounce else light.light_energy
	return visible_area * maxf(energy, 0.0) * relevance * (4.0 if bounce else 1.0)

func _select_lights() -> void:
	var scores: Dictionary = {}
	var ranked: Array[Light3D] = []
	var player_pos: Vector3 = world.get_gameplay_world_position(world.player.global_position)
	var enemy_positions := PackedVector3Array()
	if is_instance_valid(world.enemy_root):
		for enemy in world.enemy_root.get_children():
			if enemy is Node2D:
				enemy_positions.append(world.get_gameplay_world_position(enemy.global_position))
	for light in candidates:
		if is_instance_valid(light):
			scores[light] = _score(light, player_pos, enemy_positions)
			ranked.append(light)
	ranked.sort_custom(func(a: Light3D, b: Light3D) -> bool: return scores[a] > scores[b])
	selected = selected.filter(func(light: Light3D) -> bool: return is_instance_valid(light) and scores.get(light, 0.0) > 0.0)
	var room_bounce: Light3D
	for lamp in ranked:
		if scores[lamp]>0.0 and bool(lamp.get_meta(&"fixture_bounce",false)):
			room_bounce=lamp; break
	# One room-reflection slot follows the committed room, including an A-B-A
	# return before old A finishes fading. General lamp hysteresis must not
	# prevent that still-active source from being selected/shown again.
	if room_bounce!=null and not selected.has(room_bounce):
		if selected.size()>=int(LIMITS[quality]):
			var weakest: Light3D=selected[0]
			for lamp in selected:
				if scores[lamp]<scores[weakest]: weakest=lamp
			selected.erase(weakest)
		selected.append(room_bounce)
	while selected.size() > int(LIMITS[quality]):
		selected.pop_back()
	for challenger in ranked:
		if scores[challenger] <= 0.0 or selected.has(challenger):
			continue
		if selected.size() < int(LIMITS[quality]):
			selected.append(challenger)
			continue
		var weakest: Light3D = null
		for incumbent in selected:
			if incumbent==room_bounce: continue
			if _clock - float(active.get(incumbent, _clock)) < HOLD_SECONDS:
				continue
			if weakest == null or scores[incumbent] < scores[weakest]:
				weakest = incumbent
		if weakest != null and scores[challenger] > scores[weakest] * 1.4:
			selected.erase(weakest)
			selected.append(challenger)

func get_debug_stats() -> Dictionary:
	return {"quality": quality, "interior_candidates": candidates.size(), "interior_shadow_lights": active.size(), "interior_limit": LIMITS[quality], "roof_cells": roof_cell_count, "window_suns": 1 if is_instance_valid(sun) and sun.visible else 0, "window_sources":_window_selection.size(), "window_limit":WINDOW_LIMITS[quality], "suspended": suspended}
