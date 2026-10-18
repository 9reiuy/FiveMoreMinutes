extends Node
## Approved furniture art; sample controls are disabled in the floor-owned production mode.
const ART = preload("res://scripts/dream/preview/furniture_face_textures.gd")
static var shader_cache: Dictionary={}
const CATALOG = preload("res://scripts/dream/office_furniture_catalog.gd")
const SOURCE = preload("res://scenes/dream/props/desk.tscn")
const REVIEW_KINDS := ["workstation", "cabinet", "water_dispenser", "chair", "sofa", "coffee_table", "table", "dining_table", "sorting_table", "shelf", "server", "counter", "appliance_counter", "fridge", "sink", "washbasin", "toilet", "partition", "stall_door", "reception", "whiteboard", "plant"]
const FOCUS_KINDS := ["workstation", "cabinet", "water_dispenser", "chair", "sofa", "coffee_table", "table", "shelf", "server", "counter", "fridge", "sink", "washbasin", "toilet", "partition", "stall_door", "reception", "whiteboard", "plant"]
var enabled := true
var records: Array[Dictionary]=[]
var registered: Dictionary={}
var world: Node
var label: Label
var water: WeakRef
var refresh := 0.0
var variant_override := -1
var focus_page := 0
var production_mode := false

func assigned_variant(source: Node2D, kind: String) -> int:
	# The seeded generator appends furniture in deterministic order. Freeze that
	# ordinal, not the physics position (which may move before the first render).
	if not source.has_meta(&"texture_review_identity"):
		var identity := "%s:%s:%s:%s" % [world.active_seed,source.get_meta(&"dream_room_id",0),kind,source.get_index()]
		source.set_meta(&"texture_review_identity",identity)
	return posmod(String(source.get_meta(&"texture_review_identity")).hash(),ART.VARIANT_COUNT)

func _ready() -> void:
	if world==null: world=get_parent()
	if production_mode:
		call_deferred("refresh_assets")
		return
	var canvas := CanvasLayer.new(); canvas.layer=110
	label=Label.new(); label.position=Vector2(18,48)
	label.add_theme_color_override("font_color",Color.WHITE)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	canvas.add_child(label); add_child(canvas)
	_update_label()
	call_deferred("refresh_assets")

func _process(delta: float) -> void:
	refresh+=delta
	if refresh>=.5: refresh=0.0; refresh_assets()

func refresh_assets() -> void:
	if production_mode and get_parent().get_parent()!=world.office_art_root: return
	if world.furniture_root==null or world.furniture_root.get_child_count()==0: return
	_add_review_water()
	records=records.filter(func(record: Dictionary) -> bool: return is_instance_valid(record.node.get_ref()))
	registered.clear()
	for record in records: registered[record.node.get_ref().get_instance_id()]=true
	for bridge in world.actor_depth_bridges_root.get_children():
		if not bridge is Furniture3DVisual: continue
		var source: Node2D=bridge.source_actor
		if not is_instance_valid(source): continue
		var kind := String(source.get_meta(&"office_furniture_kind",""))
		if production_mode and kind=="desk": kind="workstation"
		if production_mode and kind=="cabinet_open": kind="cabinet"
		if kind not in REVIEW_KINDS: continue
		for mesh in bridge.visual_instance.find_children("*","MeshInstance3D",true,false):
			if mesh.has_meta(&"review_desktop_detail"): continue
			if mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY or registered.has(mesh.get_instance_id()): continue
			var original := mesh.material_override as ShaderMaterial
			if original==null: continue
			var texture := original.get_shader_parameter("atlas") as Texture2D
			if texture==null: continue
			var assigned := assigned_variant(source,kind)
			var result := ART.build(mesh.mesh,texture,kind,assigned if variant_override<0 else variant_override)
			# Keep the active sample's lighting/dither/cutaway implementation unchanged.
			# Only this review material's atlas sampler switches to strict point filtering.
			var shader_id := original.shader.get_instance_id()
			if not shader_cache.has(shader_id):
				var shader := Shader.new()
				shader.code=original.shader.code.replace("filter_nearest_mipmap","filter_nearest")
				shader_cache[shader_id]=shader
			var material := ShaderMaterial.new(); material.shader=shader_cache[shader_id]
			for uniform in original.shader.get_shader_uniform_list():
				var value: Variant=original.get_shader_parameter(uniform.name)
				if value!=null: material.set_shader_parameter(uniform.name,value)
			material.set_shader_parameter("atlas",result.texture)
			var record := {"node":weakref(mesh),"mesh":mesh.mesh,"material":original,"new_mesh":result.mesh,"new_material":material,"result":result,"kind":kind,"assigned_variant":assigned,"identity":source.get_meta(&"texture_review_identity")}
			records.append(record); registered[mesh.get_instance_id()]=true
			_apply(record)

func _add_review_water() -> void:
	if production_mode: return # Formal layout owns functional furniture counts.
	if water!=null and is_instance_valid(water.get_ref()): return
	for room in world.rooms:
		if String(room.get("sample_key",""))!="pantry": continue
		for cell in room.usable_cells:
			var point := Vector2(cell)*32.0
			if not world._content_position_is_clear(point,22.0): continue
			var source := SOURCE.instantiate() as Node2D
			CATALOG.configure(source,"water_dispenser")
			source.position=point
			if not world._furniture_placement_is_clear(source,room.id): source.free(); continue
			source.set_meta(&"dream_room_id",room.id)
			source.set_meta(&"office_visual_style","approved_room")
			source.set_meta(&"content_kind",&"furniture")
			source.set_meta(&"texture_review_prop",true)
			world.furniture_root.add_child(source)
			if source.has_method("reset_spawn_physics"): source.reset_spawn_physics()
			world._spawn_furniture_presentation(source)
			water=weakref(source)
			return

func _apply(record: Dictionary) -> void:
	var node: MeshInstance3D=record.node.get_ref()
	if not is_instance_valid(node): return
	node.mesh=record.new_mesh if enabled else record.mesh
	node.material_override=record.new_material if enabled else record.material
	# Same silhouette, triangles and opaque shadow blocker in both display modes.
	var shadow := node.get_node_or_null("SolidShadowCaster") as MeshInstance3D
	if shadow!=null: shadow.mesh=node.mesh

func set_texture_mode(value: bool) -> void:
	enabled=value
	for record in records: _apply(record)
	var floors := get_parent().get_node_or_null("SampleFloorTextureReview")
	if floors!=null: floors.set_mode(value)
	var dressing := get_parent().get_node_or_null("SampleWallAndDesktopReview")
	if dressing!=null: dressing.set_mode(value)
	_update_label()

func set_variant_override(value: int) -> void:
	variant_override=clampi(value,-1,ART.VARIANT_COUNT-1)
	for record in records:
		var texture := record.material.get_shader_parameter("atlas") as Texture2D
		var chosen: int=record.assigned_variant if variant_override<0 else variant_override
		var result := ART.build(record.mesh,texture,record.kind,chosen)
		record.result=result; record.new_mesh=result.mesh
		record.new_material.set_shader_parameter("atlas",result.texture)
		_apply(record)
	_update_label()

func _update_label() -> void:
	if label!=null:
		var subjects := "1 工位 2 柜 3 水机 4 椅 5 沙发\n6 茶几 7 会议桌 8 档案架 9 机柜 0 茶水台" if focus_page==0 else "1 冰箱 2 水槽 3 洗手盆 4 马桶 5 隔间板\n6 隔间门 7 前台 8 白板 9 花盆"
		label.text="家具纹理样板 · %s · %s\nT 对照 V 变体 P 翻页（%d/2）\n%s" % ["新像素纹理" if enabled else "原纹理","稳定随机" if variant_override<0 else "变体 %d" % (variant_override+1),focus_page+1,subjects]

func _unhandled_key_input(event: InputEvent) -> void:
	if production_mode: return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode==KEY_T: set_texture_mode(not enabled); get_viewport().set_input_as_handled()
	if event.keycode==KEY_V:
		set_variant_override(-1 if variant_override==ART.VARIANT_COUNT-1 else variant_override+1)
		get_viewport().set_input_as_handled()
	if event.keycode==KEY_P:
		focus_page=1-focus_page; _update_label()
		get_viewport().set_input_as_handled()
	var keys := [KEY_1,KEY_2,KEY_3,KEY_4,KEY_5,KEY_6,KEY_7,KEY_8,KEY_9,KEY_0]
	if event.keycode in keys:
		var index := keys.find(event.keycode)+focus_page*10
		if index<FOCUS_KINDS.size(): focus_kind(FOCUS_KINDS[index])
		get_viewport().set_input_as_handled()

func focus_kind(kind: String) -> bool:
	for source in world.furniture_root.get_children():
		if String(source.get_meta(&"office_furniture_kind",""))!=kind: continue
		for direction in [Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP]:
			var point: Vector2=source.global_position+direction*96.0
			if not world._content_position_is_clear(point,12.0): continue
			world.player.global_position=point
			world.activate_room(int(source.get_meta(&"dream_room_id",0)))
			return true
	return false
