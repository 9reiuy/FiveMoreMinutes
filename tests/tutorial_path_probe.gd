extends SceneTree
const WALK=preload("res://tests/support/world_walk_input.gd")
var main: Node
func _initialize(): call_deferred("run")
func frames(n=8):
 for i in n: await process_frame
func run():
 preload("res://tests/support/background_gpu.gd").start(self); Engine.max_fps=60
 main=load("res://scenes/app/main.tscn").instantiate(); root.add_child(main); await frames(90)
 main.persistent_day_state=main._create_initial_state(); main.chapter_one.start_new(); main.chapter_one.resume()
 await frames(180)
 var w: Node=main._supported_dream_world; var t: Node=w.get_node("ChapterTraining")
 t.stage=3; t._setup_training(); await frames(45)
 for name in ["DashToRange","GalleryCheckpointC"]:
  var g: Node=t._gate(name); print("GATE ",name," open=",g.is_open," body_layer=",g.body.collision_layer," at=",g.body.position)
 w.player.position=Vector2(128,240)
 w.player.set_meta("presentation_pointer_gate",func(): return true)
 w.player.set_meta("presentation_pointer_position",func(): return w.camera_3d.unproject_position(Vector3(4,.65,2.6)))
 w.player.equip_weapon("basic",w.CONFIG); t.picked=true; await frames(30)
 var target: Node=t.training_target
 print("TARGET health=",target.current_health," active=",target.room_runtime_active," damageactive=",target.is_damage_runtime_active()," hurtbox=",target.hurtbox_collision.global_position," layer=",target.hurtbox.collision_layer)
 print("AIM ",w.player._camera_muzzle_aim_direction()," muzzle=",w.player.projectile_origin.global_position," screen=",w.player.get_presentation_pointer_position())
 var origin: Vector2=w.player.projectile_origin.global_position; var direction: Vector2=w.player._camera_muzzle_aim_direction()
 var q:=PhysicsRayQueryParameters2D.create(origin,origin+direction*600,29); q.collide_with_areas=true; q.exclude=[w.player.get_rid()]
 print("FIRST_RAY ",w.player.get_world_2d().direct_space_state.intersect_ray(q))
 if not InputMap.has_action("attack"): InputMap.add_action("attack")
 Input.action_press("attack"); await create_timer(5.).timeout; Input.action_release("attack")
 print("AFTER health=",target.current_health," shots=",t.fired," ammo=",w.player.get_ammo_status()," at=",target.position)
 main.queue_free(); await frames(); quit()
