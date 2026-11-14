extends Control
## Presentation wrapper, including mouse mapping at the actual render size.
var view: SubViewport
var coast: Node3D
var image: TextureRect
@export var coast_scene: PackedScene = preload("res://scenes/preview/night_coast_city_cliff_sample.tscn")
@export var native_resolution := false
func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 view=SubViewport.new(); view.size=_render_size()
 view.own_world_3d=true; view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 if native_resolution:
  view.msaa_3d=Viewport.MSAA_2X
  view.scaling_3d_scale=1.0
 add_child(view)
 coast=coast_scene.instantiate()
 if bool(coast.get_meta(&"native_coast_presentation",false)) and not native_resolution:
  native_resolution=true
  view.size=_render_size()
  view.msaa_3d=Viewport.MSAA_2X
  view.scaling_3d_scale=1.0
 view.add_child(coast)
 image=TextureRect.new()
 image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 image.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR if native_resolution else CanvasItem.TEXTURE_FILTER_NEAREST
 image.texture=view.get_texture(); image.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(image)
 if native_resolution:
  get_window().title="红海岸线 · 光晕与薄雾预览"
  if coast.get_meta(&"coast_static_morse",false): get_window().title="红海岸线 · LOVE 常亮预览"
  get_window().size_changed.connect(_resize_native_view)
  resized.connect(_resize_native_view)

func _render_size() -> Vector2i:
 if not native_resolution: return Vector2i(640,360)
 var logical: Vector2=get_viewport_rect().size.max(Vector2.ONE)
 var extent: Vector2=size if size.x>0.0 and size.y>0.0 else logical
 var pixels:=Vector2(get_window().size)*extent/logical
 return Vector2i(maxi(1,roundi(pixels.x)),maxi(1,roundi(pixels.y)))

func _resize_native_view() -> void:
 if is_instance_valid(view) and native_resolution: view.size=_render_size()

func _unhandled_input(event: InputEvent) -> void:
 if not is_instance_valid(view): return
 var local_event:=event.duplicate() as InputEvent
 if local_event is InputEventMouse:
  var scale_factor:=maxf(.0001,minf(size.x/float(view.size.x),size.y/float(view.size.y)))
  var offset: Vector2=(size-Vector2(view.size)*scale_factor)*.5
  local_event.position=(event.position-offset)/scale_factor
  local_event.global_position=local_event.position
 view.push_input(local_event,true)
