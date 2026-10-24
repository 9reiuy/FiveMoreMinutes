extends Node
## Floor-owned presenter; one immutable sample per actor and frame.
var world: Node
var layer: CanvasLayer
var visible := true:
	set(value):
		visible=value
		if is_instance_valid(layer): layer.visible=value
var surface: Control
var flashes: Array[Dictionary]=[]
var prepared_lines: Array[Dictionary]=[]
var smoothed_points: Dictionary={}
var last_drawn_enemy_ids: Array[int]=[]

func _ready() -> void:
	process_priority=100
	layer=CanvasLayer.new()
	layer.name="CombatThreatHUD"
	layer.layer=40
	layer.set_meta(&"threat_world_id",world.get_instance_id())
	add_child(layer)
	layer.add_to_group(&"enemy_threat_huds")
	_claim_layer()
	surface=Control.new()
	surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
	surface.clip_contents=true
	layer.add_child(surface)
	surface.draw.connect(draw_lines)

func _claim_layer() -> void:
	if not is_inside_tree() or not is_instance_valid(world) or world.floor_root!=get_parent(): return
	for other in get_tree().get_nodes_in_group(&"enemy_threat_huds"):
		if other!=layer and other.get_meta(&"threat_world_id",0)==world.get_instance_id(): other.visible=false

static func line_style(progress: float) -> Dictionary:
	var amount:=clampf(progress,0,1)
	return {"width":lerpf(1.0,3.5,amount),"color":Color(1,.5,.5,.28).lerp(Color(.68,.015,.025,.98),amount)}

func _process(delta: float) -> void:
	var real_delta:=delta/maxf(Engine.time_scale,.001)
	for flash in flashes: flash.left-=real_delta
	flashes=flashes.filter(func(f: Dictionary) -> bool: return f.left>0)
	prepared_lines.clear()
	surface.queue_redraw()
	if not _can_draw(): return
	var size: Vector2=world.camera_3d.get_viewport().get_visible_rect().size
	surface.position=world.player.get_presentation_hud_position(Vector2.ZERO)
	surface.size=world.player.get_presentation_hud_position(size)-surface.position
	var seen: Dictionary={}
	for enemy in world.enemy_root.get_children():
		var id: int=enemy.get_instance_id()
		if seen.has(id): continue
		var segment:=aim_segment(enemy)
		if segment.is_empty(): continue
		seen[id]=true
		var start_world: Vector3=world.get_gameplay_world_position(segment.start,.75)
		var snapshot: Dictionary=world._weapon_visual_snapshot(enemy,segment.start)
		if not snapshot.is_empty():
			start_world=snapshot.world_origin
		var difference: Vector2=segment.end-segment.start
		var end_world: Vector3=start_world+world.global_basis*Vector3(difference.x,0,difference.y)/32.0
		if smoothed_points.has(id):
			var previous: Dictionary=smoothed_points[id]
			if Vector3(previous.start).distance_squared_to(start_world)<16.0:
				var weight:=1.0-exp(-50.0*real_delta)
				start_world=Vector3(previous.start).lerp(start_world,weight)
				end_world=Vector3(previous.end).lerp(end_world,weight)
		smoothed_points[id]={"start":start_world,"end":end_world}
		prepared_lines.append({"id":id,"from":screen_point(start_world),"to":screen_point(end_world),"style":line_style(segment.progress)})
	for id in smoothed_points.keys():
		if not seen.has(id): smoothed_points.erase(id)

func _can_draw() -> bool:
	return visible and can_process() and is_instance_valid(world) and world.floor_root==get_parent() and is_instance_valid(world.player) and not world.player.dead and not world.floor_transition_in_progress and world.transition_phase==&"IDLE"

func screen_point(point: Vector3) -> Vector2:
	return world.player.get_presentation_hud_position(world.camera_3d.unproject_position(point))-surface.position

func wall_end(start: Vector2,end: Vector2) -> Vector2:
	var query:=PhysicsRayQueryParameters2D.create(start,end,1|4)
	var exclusions: Array[RID]=[world.player.get_rid()]
	for i in 12:
		query.exclude=exclusions
		var hit: Dictionary=world.player.get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): return end
		var collider: Node=hit.get("collider")
		if collider!=null and collider.is_in_group(&"glass_windows"):
			exclusions.append(collider.get_rid()); continue
		return hit.position
	return start

func aim_segment(enemy: Node) -> Dictionary:
	if not is_instance_valid(enemy) or not enemy.has_method("get_ranged_telegraph_state"): return {}
	if enemy.get_meta(&"smoke_hidden_from_player",false):return {}
	if world.has_method("is_smoke_sight_blocked") and world.is_smoke_sight_blocked(world.player.global_position,enemy.global_position):return {}
	var state: Dictionary=enemy.get_ranged_telegraph_state()
	if state.is_empty(): return {}
	# Visual muzzle is stable; gameplay get_projectile_origin() clamps against
	# nearby furniture, which must not yank an aiming line back and forth.
	var start: Vector2=state.start if state.has("start") else enemy.projectile_origin.global_position
	if wall_end(world.player.global_position,enemy.global_position).distance_to(enemy.global_position)>.5: return {}
	return {"start":start,"end":wall_end(start,state.target),"progress":state.progress}

func draw_lines() -> void:
	last_drawn_enemy_ids.clear()
	if not _can_draw(): return
	for line in prepared_lines:
		last_drawn_enemy_ids.append(line.id)
		surface.draw_line(line.from,line.to,line.style.color,line.style.width,true)
	for flash in flashes:
		var center:=screen_point(world.get_gameplay_world_position(flash.point,.75))
		surface.draw_arc(center,9.0*(1.0-float(flash.left)/.12),0,TAU,12,Color(1,.9,.65),2,false)
		surface.draw_line(center-Vector2(8,0),center+Vector2(8,0),Color.WHITE,1,false)

func _notification(what: int) -> void:
	if what==NOTIFICATION_DISABLED: visible=false
	elif what==NOTIFICATION_ENABLED:
		visible=true
		_claim_layer()
	elif what==NOTIFICATION_PREDELETE and is_instance_valid(layer): layer.queue_free()
