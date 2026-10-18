class_name FlipPhoneShell
extends Control

## A real hinged 3D device; live UI is mapped onto its recessed display.
signal action_pressed(action: StringName)
signal action_released(action: StringName)
signal screen_activity(active: bool)
signal animation_finished(opened: bool)

const PHONE_SIZE := Vector2(200, 420)
const SCREEN_SIZE := Vector2i(148, 230)
const SCREEN_POS := Vector2(16, 19)
const HINGE := Vector2(90, 262)
const REST_ANGLE := -0.035
const FONT := preload("res://assets/fonts/boutique_bitmap/BoutiqueBitmap9x9_Bold_1.9.ttf")
const SCREEN_METRES := Vector2(1.48, 2.30)
const CLOSED_ANGLE := 2.94
const RENDER_SCALE := 2.0
const RENDER_PADDING := 100.0
const REST_ROTATION := Vector3(-0.03, 0.06, -0.015)
const POINTER_LIMIT := 0.034906585

var screen_size := SCREEN_SIZE
var screen_root: Control
var is_open := false
var is_animating := false
var _render: SubViewport
var _ui: SubViewport
var _view: TextureRect
var _camera: Camera3D
var _stage: Node3D
var _lid: Node3D
var _screen_plane: MeshInstance3D
var _key_plane: Node3D
var _keys: Dictionary = {}
var _motion: Tween
var _drag_screen := false
var _pressed: StringName = &""
var _last_screen_point := Vector2.ZERO
var _materials: Dictionary = {}
var _pointer_pose: Node3D
var _held_actions: Dictionary = {}
var _pulse_until: Dictionary = {}
var _feedback_amounts: Dictionary = {}
var _pointer_target := Vector3.ZERO
var _pointer_global := Vector2.ZERO
var _interaction_frozen := false
var _screen_activity_state := false
var _wheel_freeze_until := 0
var _last_process_usec := 0
var _ring_mesh: MeshInstance3D
var _centre_mesh: MeshInstance3D
var _ring_rest_rotation := Vector3.ZERO
var _ring_rest_z := 0.0
var _centre_rest_z := 0.0


func _init() -> void:
 custom_minimum_size = PHONE_SIZE
 size = PHONE_SIZE
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 process_mode = Node.PROCESS_MODE_ALWAYS
 texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 _build()


func _build() -> void:
 _ui = SubViewport.new()
 _ui.name = "LivePhoneUIScreen"
 _ui.size = SCREEN_SIZE
 _ui.transparent_bg = false
 _ui.disable_3d = true
 _ui.handle_input_locally = true
 _ui.gui_disable_input = false
 _ui.render_target_update_mode = SubViewport.UPDATE_DISABLED
 add_child(_ui)
 screen_root = Control.new()
 screen_root.name = "PhoneScreen"
 screen_root.size = Vector2(SCREEN_SIZE)
 screen_root.custom_minimum_size = Vector2(SCREEN_SIZE)
 screen_root.clip_contents = true
 screen_root.mouse_filter = Control.MOUSE_FILTER_STOP
 _ui.add_child(screen_root)
 _render = SubViewport.new()
 _render.name = "PhoneGeometryViewport"
 _render.size = Vector2i((PHONE_SIZE + Vector2(RENDER_PADDING * 2.0, 0)) * RENDER_SCALE)
 _render.msaa_3d = Viewport.MSAA_4X
 _render.own_world_3d = true
 _render.transparent_bg = true
 _render.handle_input_locally = false
 _render.gui_disable_input = true
 _render.positional_shadow_atlas_size = 512
 _render.render_target_update_mode = SubViewport.UPDATE_DISABLED
 add_child(_render)
 _view = TextureRect.new()
 _view.name = "RenderedPhone"
 _view.texture = _render.get_texture()
 _view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 _view.stretch_mode = TextureRect.STRETCH_SCALE
 _view.position = Vector2(-RENDER_PADDING, 0)
 _view.size = PHONE_SIZE + Vector2(RENDER_PADDING * 2.0, 0)
 _view.mouse_filter = Control.MOUSE_FILTER_IGNORE
 _view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 add_child(_view)
 _view.visible = false
 var scene := Node3D.new()
 _render.add_child(scene)
 var environment := WorldEnvironment.new()
 var env := Environment.new()
 env.background_mode = Environment.BG_COLOR
 env.background_color = Color(0, 0, 0, 0)
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color("aab4d1")
 env.ambient_light_energy = 0.35
 env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
 environment.environment = env
 scene.add_child(environment)
 _camera = Camera3D.new()
 _camera.name = "PhoneCamera"
 _camera.position = Vector3(0, 0, 9.8)
 _camera.fov = 24.0
 _camera.keep_aspect = Camera3D.KEEP_HEIGHT
 _camera.near = 0.1
 _camera.far = 25
 scene.add_child(_camera)
 _camera.current = true
 var key_light := DirectionalLight3D.new()
 key_light.rotation_degrees = Vector3(-24, -32, 0)
 key_light.light_color = Color("fff5df")
 key_light.light_energy = 0.65
 key_light.shadow_enabled = true
 scene.add_child(key_light)
 var fill := DirectionalLight3D.new()
 fill.rotation_degrees = Vector3(16, 145, 0)
 fill.light_color = Color("9caddb")
 fill.light_energy = 0.18
 scene.add_child(fill)
 _stage = Node3D.new()
 _stage.name = "ThreeDimensionalPhoneBody"
 scene.add_child(_stage)
 _stage.rotation = REST_ROTATION
 _pointer_pose = Node3D.new()
 _pointer_pose.name = "PointerPose"
 _stage.add_child(_pointer_pose)
 _lid = Node3D.new()
 _lid.name = "MechanicalHinge"
 _lid.position = Vector3(0, -0.72, 0.10)
 _pointer_pose.add_child(_lid)
 var white := _material("plastic", Color("a3a6ac"), 0.72)
 var edge := _material("rim", Color("88909c"), 0.75)
 var dark := _material("graphite", Color("2c3440"), 0.70)
 var black := _material("glass", Color("101620"), 0.25)
 var seam := _material("seam", Color("727a87"), 0.82)
 # Thin silver-white rectangular lid: a narrow recessed LCD lip, no black faceplate.
 var upper := _box(_lid, Vector3(0, 1.32, 0), Vector3(1.80, 2.64, .15), .045, white)
 upper.name = "SilverUpperShell"
 _box(_lid, Vector3(0, 1.32, -.056), Vector3(1.79, 2.61, .030), .045, edge)
 _box(_lid, Vector3(0, 1.28, .080), Vector3(1.535, 2.355, .018), .018, seam)
 _box(_lid, Vector3(0, 1.28, .090), Vector3(1.505, 2.325, .012), .009, black)
 _screen_plane = MeshInstance3D.new()
 _screen_plane.name = "LiveDisplayGlass"
 var quad := QuadMesh.new()
 quad.size = SCREEN_METRES
 _screen_plane.mesh = quad
 _screen_plane.position = Vector3(0, 1.28, .100)
 var display := StandardMaterial3D.new()
 display.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 display.albedo_texture = _ui.get_texture()
 display.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
 display.cull_mode = BaseMaterial3D.CULL_DISABLED
 _screen_plane.material_override = display
 _lid.add_child(_screen_plane)
 # The small camera and earpiece belong to the white header; there is no logo.
 _disc(_lid, Vector3(-.64, 2.52, .080), .053, .012, dark)
 _disc(_lid, Vector3(-.64, 2.52, .088), .031, .008, black)
 _box(_lid, Vector3(-.50,2.52,.082), Vector3(.052,.018,.010), .007, seam)
 _box(_lid, Vector3(.57,2.51,.083), Vector3(.32,.037,.012), .012, dark)
 # Full length lower shell: its back and every keypad row remain solid offscreen.
 var lower := _box(_pointer_pose, Vector3(0, -2.04, -.015), Vector3(1.80, 2.64, .18), .045, white)
 lower.name = "SilverLowerShell"
 _box(_pointer_pose, Vector3(0, -2.04, -.079), Vector3(1.79, 2.60, .026), .045, edge)
 _box(_pointer_pose, Vector3(0, -2.04, .079), Vector3(1.70, 2.54, .020), .030, white)
 # The reference has a squared, full-width hinge with a large raised central block.
 _box(_pointer_pose, Vector3(0,-.72,.096), Vector3(1.80,.235,.205), .032, edge)
 _box(_pointer_pose, Vector3(0,-.70,.129), Vector3(.94,.225,.205), .025, white)
 for x in [-.70,.70]:
  _box(_pointer_pose, Vector3(x,-.70,.107), Vector3(.39,.235,.175), .025, white)
 for x in [-.49,.49]:
  _box(_pointer_pose, Vector3(x,-.715,.149), Vector3(.018,.215,.045), .003, seam)
 _key_plane = Node3D.new()
 _key_plane.name = "PhysicalKeyPlane"
 _key_plane.position = Vector3(0, -.72, .118)
 _pointer_pose.add_child(_key_plane)
 var key_white := _material("key", Color("b6bbc0"), .67)
 var centre_white := _material("key_center", Color("bcc2c6"), .66)
 # One shallow white circular navigation plate and a raised white centre button.
 _disc(_key_plane, Vector3(0,-.49,.001), .305, .012, seam)
 _disc(_key_plane, Vector3(0,-.49,.014), .292, .021, white)
 var ring_key := _disc(_key_plane, Vector3(0,-.49,.034), .278, .026, key_white)
 _disc(_key_plane, Vector3(0,-.49,.049), .112, .016, edge)
 var centre_key := _disc(_key_plane, Vector3(0,-.49,.065), .098, .030, centre_white)
 _ring_mesh = ring_key
 _centre_mesh = centre_key
 _ring_rest_rotation = ring_key.rotation
 _ring_rest_z = ring_key.position.z
 _centre_rest_z = centre_key.position.z
 _key(&"confirm", Vector2(0,-.49), Vector2(.19,.19), centre_key)
 _key(&"up", Vector2(0,-.27), Vector2(.20,.18), ring_key)
 _key(&"down", Vector2(0,-.71), Vector2(.20,.18), ring_key)
 _key(&"left", Vector2(-.22,-.49), Vector2(.18,.20), ring_key)
 _key(&"right", Vector2(.22,-.49), Vector2(.18,.20), ring_key)
 # Four small square auxiliary keys flank the circle, as in the supplied device.
 for action in [&"home",&"back"]:
  var x := -.57 if action==&"home" else .57
  var button := _box(_key_plane,Vector3(x,-.35,.030),Vector3(.24,.215,.052),.025,key_white)
  _key(action,Vector2(x,-.35),Vector2(.24,.215),button)
 for x in [-.57,.57]:
  _box(_key_plane,Vector3(x,-.67,.026),Vector3(.24,.215,.046),.025,key_white)
 _label(_key_plane,"MENU",Vector3(-.57,-.35,.062),5,Color("48505b"))
 _label(_key_plane,"←",Vector3(.57,-.35,.062),9,Color("48505b"))
 _label(_key_plane,"@",Vector3(-.57,-.67,.055),8,Color("48505b"))
 _label(_key_plane,"□",Vector3(.57,-.67,.055),8,Color("48505b"))
 # Three short function keys are below the directional control, not above it.
 for col in range(3):
  var at := Vector3((col-1)*.50,-.98,.022)
  _box(_key_plane,at,Vector3(.43,.20,.045),.025,key_white)
  _label(_key_plane,["CALL","CLR","END"][col],at+Vector3(0,0,.028),5,Color("48505b"))
 for row in range(4):
  for col in range(3):
   var at := Vector3((col-1)*.50,-1.25-row*.28,.018)
   _box(_key_plane,at,Vector3(.43,.205,.040),.025,key_white)
   var caption: String = str(row*3+col+1) if row<3 else ["*","0","#"][col]
   _label(_key_plane,caption,at+Vector3(0,0,.028),8,Color("48505b"))
 _disc(_key_plane,Vector3(0,-2.48,.010),.013,.009,seam)
 _stage.visible = false


func _material(key: String, colour: Color, roughness: float) -> StandardMaterial3D:
 var material := StandardMaterial3D.new()
 material.albedo_color = colour
 material.roughness = roughness
 material.metallic = 0.0
 material.metallic_specular = 0.16
 _materials[key] = material
 return material


func _ring(width: float, height: float, bevel: float, z: float) -> Array[Vector3]:
 var x := width*.5
 var y := height*.5
 var b := minf(bevel,minf(x,y)*.6)
 return [Vector3(-x+b,-y,z),Vector3(x-b,-y,z),Vector3(x,-y+b,z),Vector3(x,y-b,z),Vector3(x-b,y,z),Vector3(-x+b,y,z),Vector3(-x,y-b,z),Vector3(-x,-y+b,z)]


func _box(parent: Node3D, at: Vector3, dimensions: Vector3, bevel: float, material: Material) -> MeshInstance3D:
 # Four octagonal rings form real front/back chamfers and full side walls.
 var depth := dimensions.z*.5
 var b := minf(bevel,minf(dimensions.x,dimensions.y)*.23)
 var dz := minf(depth*.5,b*.6)
 var rings := [_ring(dimensions.x-2*b,dimensions.y-2*b,b*.5,depth),_ring(dimensions.x,dimensions.y,b,depth-dz),_ring(dimensions.x,dimensions.y,b,-depth+dz),_ring(dimensions.x-2*b,dimensions.y-2*b,b*.5,-depth)]
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in range(8):
  var j := (i+1)%8
  _triangle(st,Vector3(0,0,depth),rings[0][i],rings[0][j])
  _triangle(st,Vector3(0,0,-depth),rings[3][j],rings[3][i])
  for band in range(3):
   _triangle(st,rings[band][i],rings[band+1][i],rings[band][j])
   _triangle(st,rings[band][j],rings[band+1][i],rings[band+1][j])
 st.generate_normals()
 var mesh := MeshInstance3D.new()
 mesh.mesh=st.commit()
 mesh.material_override=material
 mesh.position=at
 parent.add_child(mesh)
 return mesh


func _triangle(st: SurfaceTool,a:Vector3,b:Vector3,c:Vector3) -> void:
 # Godot's clockwise front faces are the reverse of the ring's counterclockwise order.
 st.add_vertex(c)
 st.add_vertex(b)
 st.add_vertex(a)


func _cylinder(parent:Node3D,at:Vector3,length:float,radius:float,material:Material,horizontal:bool=false) -> MeshInstance3D:
 var geometry := CylinderMesh.new()
 geometry.top_radius=radius
 geometry.bottom_radius=radius
 geometry.height=length
 geometry.radial_segments=12
 geometry.rings=1
 var node := MeshInstance3D.new()
 node.mesh=geometry
 node.material_override=material
 node.position=at
 node.rotation.z=PI*.5 if horizontal else 0.0
 parent.add_child(node)
 return node


func _disc(parent:Node3D,at:Vector3,radius:float,depth:float,material:Material) -> MeshInstance3D:
 var mesh := _cylinder(parent,at,depth,radius,material)
 mesh.rotation.x=PI*.5
 return mesh


func _label(parent:Node3D,text:String,at:Vector3,font_size:int,colour:Color) -> void:
 var node := Label3D.new()
 node.text=text
 node.font=FONT
 node.font_size=font_size
 node.pixel_size=.008
 node.outline_size=0
 node.modulate=colour
 node.no_depth_test=false
 node.shaded=true
 node.position=at
 parent.add_child(node)


func _key(action:StringName,at:Vector2,extent:Vector2,mesh:MeshInstance3D) -> void:
 _keys[action]={"position":at,"size":extent,"mesh":mesh,"rest_z":mesh.position.z if mesh else 0.0}


func set_screen_content(content:Control) -> void:
 for child in screen_root.get_children():
  screen_root.remove_child(child)
  child.queue_free()
 if content != null:
  screen_root.add_child(content)
  content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func open_phone(animated:bool=true) -> void:
 if is_open and not is_animating:
  return
 _stop_motion()
 is_open=true
 _stage.visible=true
 _view.visible=true
 _ui.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 _render.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 if not animated:
  _stage.position=Vector3.ZERO
  _stage.rotation=REST_ROTATION
  _lid.rotation.x=.03
  _finish_motion(true)
  return
 is_animating=true
 _stage.position=Vector3(.30,-4.4,0)
 _stage.rotation=Vector3(-.23,-.32,-.07)
 _lid.rotation.x=CLOSED_ANGLE
 _motion=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true).set_parallel(true)
 _motion.tween_property(_stage,"position",Vector3.ZERO,.31).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 _motion.tween_property(_stage,"rotation",REST_ROTATION,.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 _motion.tween_property(_lid,"rotation:x",.03,.35).set_delay(.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 _motion.chain().tween_callback(_finish_motion.bind(true))


func close_phone(animated:bool=true) -> void:
 if not is_open and not is_animating:
  return
 _stop_motion()
 is_open=false
 if not animated:
  _finish_motion(false)
  return
 is_animating=true
 _motion=create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
 _motion.tween_property(_lid,"rotation:x",CLOSED_ANGLE,.23).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
 _motion.chain().tween_property(_stage,"position",Vector3(.30,-4.4,0),.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
 _motion.parallel().tween_property(_stage,"rotation",Vector3(-.23,-.32,-.07),.24)
 _motion.chain().tween_callback(_finish_motion.bind(false))


func _stop_motion() -> void:
 if _motion != null and _motion.is_valid():
  _motion.kill()
 is_animating=false
 if _drag_screen:
  var release := InputEventMouseButton.new()
  release.button_index=MOUSE_BUTTON_LEFT
  release.pressed=false
  release.position=_last_screen_point
  release.global_position=_last_screen_point
  _ui.push_input(release,true)
 _drag_screen=false
 _release_key()
 _held_actions.clear()
 _pulse_until.clear()
 _feedback_amounts.clear()
 _interaction_frozen = false
 _wheel_freeze_until = 0
 _pointer_pose.rotation = Vector3.ZERO
 _apply_feedback()
 _refresh_screen_activity()


func _finish_motion(opened:bool) -> void:
 is_animating=false
 _stage.visible=opened
 _view.visible=opened
 if not opened:
  _render.render_target_update_mode=SubViewport.UPDATE_DISABLED
  _ui.render_target_update_mode=SubViewport.UPDATE_DISABLED
  _ui.gui_release_focus()
 animation_finished.emit(opened)


func _viewport_position(point:Vector2) -> Vector2:
 return (get_global_transform_with_canvas().affine_inverse()*point-_view.position)*RENDER_SCALE


func _plane_hit(point:Vector2,node:Node3D) -> Vector3:
 var p := _viewport_position(point)
 var origin := _camera.project_ray_origin(p)
 var normal := _camera.project_ray_normal(p)
 var transform := node.global_transform.affine_inverse()
 var local_origin := transform*origin
 var local_direction := transform.basis*normal
 if absf(local_direction.z)<.000001:
  return Vector3.INF
 var t := -local_origin.z/local_direction.z
 if t<0:
  return Vector3.INF
 return local_origin+local_direction*t


func _screen_at(point:Vector2) -> Vector2:
 var hit := _plane_hit(point,_screen_plane)
 if not hit.is_finite():
  return Vector2.INF
 return Vector2((hit.x/SCREEN_METRES.x+.5)*SCREEN_SIZE.x,(.5-hit.y/SCREEN_METRES.y)*SCREEN_SIZE.y)


func screen_point_to_global(point:Vector2) -> Vector2:
 var local := Vector3((point.x/SCREEN_SIZE.x-.5)*SCREEN_METRES.x,(.5-point.y/SCREEN_SIZE.y)*SCREEN_METRES.y,0)
 return get_global_transform_with_canvas()*(_view.position+_camera.unproject_position(_screen_plane.global_transform*local)/RENDER_SCALE)


func key_point_to_global(action:StringName) -> Vector2:
 if not _keys.has(action):
  return Vector2.INF
 var point:Vector2=_keys[action].position
 return get_global_transform_with_canvas()*(_view.position+_camera.unproject_position(_key_plane.global_transform*Vector3(point.x,point.y,.07))/RENDER_SCALE)


func _key_at(point:Vector2) -> StringName:
 var hit := _plane_hit(point,_key_plane)
 if not hit.is_finite():
  return &""
 var p := Vector2(hit.x,hit.y)
 for action in [&"confirm",&"home",&"back",&"up",&"down",&"left",&"right"]:
  var item:Dictionary=_keys[action]
  var centre:Vector2=item.position
  var extent:Vector2=item.size
  if Rect2(centre-extent*.5,extent).grow(.025).has_point(p):
   return action
 return &""


func press_action(action: StringName) -> void:
 if not _keys.has(action) or not is_open or is_animating:
  return
 _held_actions[action] = true


func release_action(action: StringName) -> void:
 _held_actions.erase(action)


func pulse_action(action: StringName) -> void:
 if not _keys.has(action) or not is_open or is_animating:
  return
 _pulse_until[action] = Time.get_ticks_msec() + 110


func set_interaction_frozen(frozen: bool) -> void:
 _interaction_frozen = frozen


func set_pointer_position(globalpoint: Vector2) -> void:
 _pointer_global = globalpoint
 var viewport_size := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(640,360)
 var unit := globalpoint / viewport_size.max(Vector2.ONE) * 2.0 - Vector2.ONE
 _pointer_target = Vector3(clampf(unit.y,-1,1)*POINTER_LIMIT,clampf(unit.x,-1,1)*POINTER_LIMIT,0)


func _follow_frozen() -> bool:
 return _interaction_frozen or _drag_screen or not _held_actions.is_empty() or not _pulse_until.is_empty() or Time.get_ticks_msec() < _wheel_freeze_until


func get_feedback_state() -> Dictionary:
 return {
  "pressed": _held_actions.keys(),
  "amounts": _feedback_amounts.duplicate(),
  "dpad_rotation": _ring_mesh.rotation - _ring_rest_rotation,
  "dpad_depth": _ring_rest_z - _ring_mesh.position.z,
  "pointer_rotation": _pointer_pose.rotation,
  "pointer_target": _pointer_target,
  "pointer_global": _pointer_global,
  "frozen": _follow_frozen(),
  "screen_active": _screen_activity_state,
  "is_animating": is_animating
 }


func _process(_delta: float) -> void:
 var now := Time.get_ticks_usec()
 var elapsed := clampf(float(now-_last_process_usec)/1000000.0,0,.05) if _last_process_usec else .016
 _last_process_usec = now
 if not is_open or is_animating:
  return
 for action in _pulse_until.keys():
  if Time.get_ticks_msec() >= int(_pulse_until[action]):
   _pulse_until.erase(action)
 var weight := 1.0-exp(-elapsed*24.0)
 for action in _keys:
  var target := 1.0 if _held_actions.has(action) or _pulse_until.has(action) else 0.0
  _feedback_amounts[action] = lerpf(float(_feedback_amounts.get(action,0.0)),target,weight)
 _apply_feedback()
 if not _follow_frozen():
  _pointer_pose.rotation = _pointer_pose.rotation.lerp(_pointer_target,1.0-exp(-elapsed*9.0))
 _refresh_screen_activity()


func _amount(action: StringName) -> float:
 return float(_feedback_amounts.get(action,0.0))


func _apply_feedback() -> void:
 var horizontal := _amount(&"right")-_amount(&"left")
 var vertical := _amount(&"down")-_amount(&"up")
 var ring_down := maxf(maxf(_amount(&"up"),_amount(&"down")),maxf(_amount(&"left"),_amount(&"right")))
 _ring_mesh.rotation = _ring_rest_rotation + Vector3(vertical*.095,horizontal*.095,0)
 _ring_mesh.position.z = _ring_rest_z-ring_down*.018
 _centre_mesh.position.z = _centre_rest_z-_amount(&"confirm")*.025
 for action in [&"home",&"back"]:
  var key: Dictionary = _keys[action]
  key.mesh.position.z = key.rest_z-_amount(action)*.025


func _refresh_screen_activity() -> void:
 var active := _drag_screen or Time.get_ticks_msec() < _wheel_freeze_until
 if active != _screen_activity_state:
  _screen_activity_state=active
  screen_activity.emit(active)


func _release_key() -> void:
 if not _pressed.is_empty():
  var previous := _pressed
  release_action(previous)
  _pressed=&""
  action_released.emit(previous)


func _input(event: InputEvent) -> void:
 if not is_open or is_animating or not is_visible_in_tree():
  return
 if not event is InputEventMouse:
  return
 var mouse := event as InputEventMouse
 if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
  return
 if event is InputEventMouseMotion:
  set_pointer_position(mouse.position)
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and not _pressed.is_empty():
  _release_key()
  get_viewport().set_input_as_handled()
  return
 var point := _screen_at(mouse.position)
 var over_screen := Rect2(Vector2.ZERO,Vector2(SCREEN_SIZE)).has_point(point)
 if over_screen or _drag_screen:
  var mapped := event.duplicate() as InputEventMouse
  mapped.position=point
  mapped.global_position=point
  if mapped is InputEventMouseMotion:
   # Preserve the hardware motion gate: a stationary pointer must not become
   # synthetic hover merely because the 3D phone moved underneath it.
   mapped.relative=point-_last_screen_point if event.relative.length_squared() > 0 else Vector2.ZERO
  _last_screen_point=point
  if event is InputEventMouseButton:
   if event.button_index==MOUSE_BUTTON_LEFT:
    _drag_screen=event.pressed
   elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
    _wheel_freeze_until=Time.get_ticks_msec()+160
  _refresh_screen_activity()
  _ui.push_input(mapped,true)
  get_viewport().set_input_as_handled()
  return
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
  var action := _key_at(mouse.position)
  if not action.is_empty():
   _pressed=action
   press_action(action)
   # Activation occurs once on press; release only restores the physical key.
   action_pressed.emit(action)
   get_viewport().set_input_as_handled()
