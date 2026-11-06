extends SceneTree
const OUT := "res://.runtime/unit_outline_alignment_20261102"
class OutlineWorld extends Node3D:
	var camera_3d: Camera3D
class Target extends Node2D:
	var dead := false
var errors: Array = []
func _initialize() -> void: call_deferred("run")
func measure(outline: Node3D, real: Camera3D) -> Dictionary:
	var maximum:=0.0; var squares:=0.0; var count:=0
	for record in outline.records:
		var source: MeshInstance3D=record.source.get_ref()
		var copy: MeshInstance3D=record.copy
		for surface in source.mesh.get_surface_count():
			var vertices: PackedVector3Array=source.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var expected:=real.unproject_position(source.to_global(vertex))
				var uv: Vector2=outline.camera.unproject_position(copy.to_global(vertex))/Vector2(outline.capture.size)
				var size: Vector2=outline.border.mesh.size
				var point:=Vector3((uv.x-.5)*size.x,(.5-uv.y)*size.y,0.0)
				var composed:=real.unproject_position(outline.border.to_global(point))
				var distance:=expected.distance_to(composed)
				maximum=maxf(maximum,distance); squares+=distance*distance; count+=1
	return {"max_px":maximum,"rms_px":sqrt(squares/maxi(count,1)),"vertices":count}
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var phase:=OS.get_environment("FMM_OUTLINE_PHASE")
	if phase.is_empty(): phase="after"
	var view:=SubViewport.new(); view.size=Vector2i(640,360); view.world_3d=World3D.new(); root.add_child(view)
	var world:=OutlineWorld.new(); view.add_child(world)
	# Preserve the exact formal CameraRig (including its authored 0.8 scale).
	var template=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	var rig: Node3D=template.get_node("CameraRig").duplicate()
	template.free(); world.add_child(rig)
	world.camera_3d=rig.get_node("Camera3D")
	var real:=world.camera_3d
	for kind in ["drone","robot"]:
		var holder:=Node3D.new(); world.add_child(holder)
		var model: Node3D=preload("res://scripts/dream/units/drone_model_builder.gd").build(true) if kind=="drone" else preload("res://scripts/dream/units/hotel_robot_builder.gd").build("calm")
		model.scale=Vector3.ONE*(1.3*2.0/3.0 if kind=="drone" else 2.0/3.0)
		holder.add_child(model)
		var actor:=Target.new(); root.add_child(actor)
		var outline=load("res://scripts/dream/units/special_unit_outline.gd").new(); holder.add_child(outline)
		outline.configure(world,model,actor,Vector3.ZERO if kind=="drone" else Vector3(0,.9,0),1.5)
		for resolution in [Vector2i(640,360),Vector2i(960,540)]:
			view.size=resolution
			for scale_factor in [1.0,0.8]:
				rig.scale=Vector3.ONE*scale_factor
				for shift in [Vector2.ZERO,Vector2(.006,-.004),Vector2(-.007,.005)]:
					real.h_offset=shift.x; real.v_offset=shift.y; real.force_update_transform()
					for location in [Vector3.ZERO,Vector3(-4,0,-3),Vector3(4,0,3),Vector3(-3,0,4),Vector3(3,0,-4)]:
						holder.position=location+Vector3.UP*(1.45 if kind=="drone" else 0.0)
						model.rotation.y+=.12
						outline.sync()
						var result:=measure(outline,real)
						result.merge({"kind":kind,"size":str(resolution),"rig_scale":scale_factor,"shift":str(shift),"location":str(location)})
						errors.append(result)
		holder.free(); actor.free()
	var maximum:=0.0
	for result in errors: maximum=maxf(maximum,float(result.max_px))
	var passed:=maximum>1.0 if phase=="before" else maximum<0.05
	FileAccess.open(OUT+"/projection_"+phase+".json",FileAccess.WRITE).store_string(JSON.stringify({"cases":errors.size(),"max_px":maximum,"passed":passed,"measurements":errors},"\t"))
	print("OUTLINE_PROJECTION phase=",phase," cases=",errors.size()," max_px=",maximum," passed=",passed)
	view.free(); await process_frame; quit(0 if passed else 1)
