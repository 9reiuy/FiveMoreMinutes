extends Control
## Fixed pixel presentation for standalone F6/launcher, including mouse mapping.
var view: SubViewport
var coast: Node3D
func _ready() -> void:
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 view=SubViewport.new(); view.size=Vector2i(640,360)
 view.own_world_3d=true; view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 add_child(view)
 coast=preload("res://scenes/preview/night_coast.tscn").instantiate()
 view.add_child(coast)
 var image:=TextureRect.new()
 image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 image.texture=view.get_texture(); image.mouse_filter=Control.MOUSE_FILTER_IGNORE
 add_child(image)

func _unhandled_input(event: InputEvent) -> void:
 if not is_instance_valid(view): return
 var local_event:=event.duplicate() as InputEvent
 if local_event is InputEventMouse:
  var scale_factor:=minf(size.x/640.0,size.y/360.0)
  var offset: Vector2=(size-Vector2(640,360)*scale_factor)*.5
  local_event.position=(event.position-offset)/scale_factor
  local_event.global_position=local_event.position
 view.push_input(local_event,true)
