extends SceneTree
var checks := 0
var failures := 0
var frames: Array[float] = []
func check(ok: bool, message: String) -> void:
 checks+=1
 if not ok: failures+=1; push_error(message)
 print("PASS " if ok else "FAIL ",message)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 preload("res://tests/support/background_gpu.gd").start(self)
 var output:="res://.runtime/red_coast_20261028"
 DirAccess.make_dir_recursive_absolute(output)
 var view:=SubViewport.new()
 view.size=Vector2i(640,360)
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(view)
 var scene: Node2D=load("res://scenes/preview/red_coast.tscn").instantiate()
 scene.external_step=true
 view.add_child(scene)
 await process_frame
 check(scene.actor.texture.atlas.resource_path=="res://art/Dream/dream_chr_32x32.png","original character art reused")
 var initial: Vector2=scene.actor_position
 for i in 140:
  var start:=Time.get_ticks_usec()
  var direction:=Vector2(.14,-1).normalized() if i<95 else Vector2(-.5,.6).normalized()
  if i>120: direction=Vector2.ZERO
  scene.advance(.05,direction)
  await process_frame
  await RenderingServer.frame_post_draw
  frames.append((Time.get_ticks_usec()-start)/1000.0)
  if i%2==0:
   var image:=view.get_texture().get_image()
   image.save_png(output+"/frame_%03d.png"%(i/2))
 check(scene.actor_position.distance_to(initial)>120,"walking changes real actor position")
 check(scene.emitted>20,"footsteps create water splashes")
 var count: int=scene.emitted
 for i in 30: scene.advance(.05,Vector2.ZERO)
 check(scene.emitted==count,"standing creates no new splash")
 check(scene.splashes.is_empty(),"splash lifetime releases particles")
 var before: float=scene.clock
 var position_before: Vector2=scene.actor_position
 scene.paused=true
 scene.advance(.5,Vector2.ONE)
 check(scene.clock==before and scene.actor_position==position_before,"pause freezes sea and actor")
 scene.paused=false
 scene.reset_coast()
 check(scene.clock==0 and scene.splashes.is_empty() and scene.emitted==0,"reset clears effects and time")
 scene.external_step=false
 Input.action_press("move_up")
 for i in 5: await process_frame
 Input.action_release("move_up")
 check(scene.actor_position.y<900,"engine movement action drives scene")
 var key:=InputEventKey.new()
 key.keycode=KEY_SPACE
 key.pressed=true
 view.push_input(key, true)
 await process_frame
 check(scene.paused,"space key pauses standalone scene")
 key=InputEventKey.new()
 key.keycode=KEY_SPACE
 key.pressed=false
 view.push_input(key, true)
 await process_frame
 var reset_key:=InputEventKey.new()
 reset_key.keycode=KEY_R
 reset_key.pressed=true
 view.push_input(reset_key, true)
 await process_frame
 check(scene.actor_position==Vector2(855,900),"R key restores starting position")
 frames.sort()
 var report:={"checks":checks,"failures":failures,"render_loop_ms_p50":frames[70],"render_loop_ms_p95":frames[133],"scope":"640x360 minimized GPU, forced draw and readback; not gameplay benchmark","gpu":RenderingServer.get_video_adapter_name()}
 var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "))
 file.close()
 view.queue_free()
 await process_frame
 print(JSON.stringify(report))
 quit(failures)

