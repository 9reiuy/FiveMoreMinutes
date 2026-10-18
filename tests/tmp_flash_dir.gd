extends SceneTree
const SCENE := preload("res://scenes/dream/Dream3D_RandomDungeon.tscn")
func _init() -> void: call_deferred("_run")
func _frames(n:int)->void:
	for _i in n:
		await physics_frame
		await process_frame
func _run()->void:
	var w:=SCENE.instantiate(); w.generate_on_ready=false; w.spawn_content=false; w.persist_profile=false; w.show_debug_markers=false; root.add_child(w); await _frames(2); w.regenerate(41005); await _frames(4)
	var p:Node2D=w.player; p.set_physics_process(false); w.night_lighting.set_process(false); var g:=p.global_position; var a:=g+Vector2(220,40); w.night_lighting.aim_flashlight(g,a); var l:SpotLight3D=w.night_lighting.flashlight; print("ground=",g," aim=",a," pos=",l.global_position," basis_x=",l.global_basis.x," basis_y=",l.global_basis.y," basis_z=",l.global_basis.z," -z=",-l.global_basis.z); quit(0)
