extends Node
## Event-driven, floor-owned display only. No enemy polling or combat RNG changes.
const COMIC=preload("res://scripts/ui/comic_pixel_text.gd")
const HOLD:=.6
const LIFETIME:=.85
const MAX_RECORDS:=48
const CRITICAL_FILL=preload("res://shaders/comic_critical_fill.gdshader")
const KILL_WORDS: Array[String]=["干得好","爆了","有意思"]
var world: Node3D
var layer: CanvasLayer
var surface: Control
var shadow: Control
var records: Dictionary={}
var rng:=RandomNumberGenerator.new()
var last_kill:=-1
var critical_surfaces: Dictionary={}

func configure(owner_world: Node3D) -> void:
	world=owner_world; process_mode=Node.PROCESS_MODE_ALWAYS; rng.randomize()
	layer=CanvasLayer.new(); layer.name="EnemyCombatTextHUD"; layer.layer=38; add_child(layer)
	shadow=Control.new(); surface=Control.new()
	for canvas in [shadow,surface]:
		canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
		canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; layer.add_child(canvas)
	var material:=ShaderMaterial.new(); material.shader=COMIC.HALFTONE; shadow.material=material
	shadow.draw.connect(_draw.bind(shadow,true)); surface.draw.connect(_draw.bind(surface,false))
	layer.hide()

func _active() -> bool:
	return is_instance_valid(world) and is_inside_tree() and world.get("floor_root")==get_parent() and not get_tree().paused and world.get("floor_transition_in_progress")!=true and world.get("elevator_transition_in_progress")!=true and is_instance_valid(world.player) and not world.player.dead

static func health_owner(enemy: Node) -> Node:
	if not is_instance_valid(enemy): return null
	var drone: Variant=enemy.get("drone")
	return drone if is_instance_valid(drone) else enemy

static func health(enemy: Node) -> float:
	var owner:=health_owner(enemy)
	if owner==null: return 0
	for property in [&"current_health",&"hp"]:
		var value: Variant=owner.get(property)
		if value!=null: return maxf(0,float(value))
	return 0

static func capture(world_node: Node3D,enemy: Node) -> Dictionary:
	if not is_instance_valid(enemy) or not enemy is Node2D: return {}
	var origin: Vector3=world_node.get_gameplay_world_position(enemy.global_position,.8)
	var drone: Variant=enemy.get("drone")
	if is_instance_valid(drone) and drone is Node3D: origin=drone.global_position+Vector3.UP*.3
	var reference: Variant=enemy.get_meta(&"depth_visual_bridge") if enemy.has_meta(&"depth_visual_bridge") else null
	var bridge: Node=reference.get_ref() if reference is WeakRef else null
	if is_instance_valid(bridge) and bridge.has_method("get_hit_feedback_world_position"):
		origin=bridge.get_hit_feedback_world_position()
	return {"id":enemy.get_instance_id(),"health":health(enemy),"origin":origin}

func accept(snapshot: Dictionary,enemy: Node,result: Dictionary) -> void:
	if snapshot.is_empty() or not _active(): return
	var amount:=float(snapshot.health)-health(enemy)
	if amount<=0: return
	var id: int=snapshot.id
	var previous: Dictionary=records.get(id,{})
	if previous.get("killed",false): return
	var killed:=health(enemy)<=0
	var total:=amount+(float(previous.get("total",0)) if float(previous.get("age",LIFETIME))<HOLD else 0.0)
	var critical:=bool(result.get("is_critical",false))
	var camera: Camera3D=world.camera_3d
	var origin: Vector3=snapshot.origin
	var depth:=maxf(.1,-(camera.global_transform.affine_inverse()*origin).z)
	var viewport_size:=camera.get_viewport().get_visible_rect().size
	var hud_width: float=world.player.get_presentation_hud_position(viewport_size).x-world.player.get_presentation_hud_position(Vector2.ZERO).x
	var units:=camera.project_position(camera.unproject_position(origin)+Vector2(viewport_size.x/maxf(1,hud_width),0),depth).distance_to(origin)
	var text:=str(roundi(total))
	if killed:
		last_kill=(last_kill+rng.randi_range(1,KILL_WORDS.size()-1))%KILL_WORDS.size(); text=KILL_WORDS[last_kill]
	records[id]={"age":0.0,"total":total,"text":text,"origin":origin,"up":camera.global_basis.y.normalized(),"units":units,"critical":critical,"crit_age":0.0 if critical else float(previous.get("crit_age",LIFETIME)),"killed":killed,"scale":1.0 if killed else damage_scale(total)}
	if not critical and not killed and previous.get("critical",false): records[id].critical=true
	if records[id].critical and not critical_surfaces.has(id):
		var canvas:=Control.new(); canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE
		canvas.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		var fill:=ShaderMaterial.new(); fill.shader=CRITICAL_FILL; canvas.material=fill
		layer.add_child(canvas); critical_surfaces[id]=canvas
		canvas.draw.connect(_draw_critical.bind(canvas,id))
	while records.size()>MAX_RECORDS: _remove(records.keys()[0])
	layer.show(); _redraw()

static func damage_scale(total: float) -> float:
	return clampf(.55+.45*sqrt(maxf(0,total)/100.0),.55,1.0)

func clear() -> void:
	records.clear()
	for canvas in critical_surfaces.values():
		if is_instance_valid(canvas): canvas.queue_free()
	critical_surfaces.clear()
	if is_instance_valid(layer): layer.hide()

func _remove(id: int) -> void:
	records.erase(id)
	if critical_surfaces.has(id):
		var canvas: Control=critical_surfaces[id]
		if is_instance_valid(canvas): canvas.queue_free()
		critical_surfaces.erase(id)

func _process(delta: float) -> void:
	if not _active(): clear(); return
	if records.is_empty(): return
	for id in records.keys():
		var record: Dictionary=records[id]; record.age+=delta; record.crit_age+=delta
		if record.age>=LIFETIME: _remove(id)
	if records.is_empty(): layer.hide()
	_redraw()

func _redraw() -> void:
	surface.queue_redraw(); shadow.queue_redraw()
	for id in critical_surfaces:
		var canvas: Control=critical_surfaces[id]
		canvas.visible=records.has(id) and records[id].critical and records[id].crit_age<LIFETIME
		if not canvas.visible: continue
		var position:=_screen_position(records[id])+Vector2(0,-24)
		var viewport_size:=canvas.get_viewport().get_visible_rect().size
		canvas.material.set_shader_parameter("word_rect",Vector4((position.x-21)/viewport_size.x,(position.y-25)/viewport_size.y,42/viewport_size.x,32/viewport_size.y))
		canvas.material.set_shader_parameter("dot_pixels",3.0*Vector2(canvas.get_viewport().get_texture().get_size()).x/maxf(1,viewport_size.x))
		canvas.queue_redraw()

func _screen_position(record: Dictionary) -> Vector2:
	var point: Vector3=record.origin+record.up*record.units*(22+maxf(0,record.age-HOLD)*35)
	return world.player.get_presentation_hud_position(world.camera_3d.unproject_position(point)).round()

func _draw_critical(canvas: Control,id: int) -> void:
	if not _active() or not records.has(id): return
	var record: Dictionary=records[id]
	if world.camera_3d.is_position_behind(record.origin): return
	COMIC.draw(canvas,"暴击",_screen_position(record)+Vector2(0,-24),record.crit_age,false,.8)

func _draw(target: Control,shadow_pass: bool) -> void:
	if not _active(): return
	for record in records.values():
		var t: float=record.age
		# Hold by the fixed impact position, then float away after the last hit.
		var point: Vector3=record.origin+record.up*record.units*(22+maxf(0,t-HOLD)*35)
		if world.camera_3d.is_position_behind(point): continue
		var position:=_screen_position(record)
		COMIC.draw(target,record.text,position,t,shadow_pass,record.scale)
		if shadow_pass and record.critical and record.crit_age<LIFETIME:
			COMIC.draw(target,"暴击",position+Vector2(0,-24),record.crit_age,true,.8)

func _exit_tree() -> void:
	clear()

func _notification(what: int) -> void:
	# Selective rendering may have reparented this clear HUD outside its floor.
	# Stash/rollback reparents the floor: exiting the tree is not destruction.
	if what==NOTIFICATION_PREDELETE and is_instance_valid(layer): layer.queue_free()
