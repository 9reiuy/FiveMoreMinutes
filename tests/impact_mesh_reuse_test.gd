extends SceneTree
const EFFECT=preload("res://scripts/dream/firearm_impact_visual_3d.gd")
const LEGACY=preload("res://tests/support/legacy_impact_mesh_probe.gd")
var checks:=0
var failures:=0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	for frame in 4: await process_frame
	var first_mesh: QuadMesh
	var node_baseline:=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	for floor_index in 3:
		var floor_root:=Node3D.new(); root.add_child(floor_root)
		for kind in [&"solid",&"metal",&"glass",&"soft"]:
			var current:=EFFECT.new(); var previous:=LEGACY.new()
			floor_root.add_child(current); floor_root.add_child(previous)
			current.setup(Vector3(1,1,0),kind); previous.setup(Vector3(1,1,0),kind)
			var mesh: QuadMesh=current._emitter.mesh
			if first_mesh==null: first_mesh=mesh
			check(mesh==first_mesh,"One immutable mesh retained across surfaces and floors")
			check(mesh.size==Vector2(.09,.09),"Original pixel quad size")
			var material: StandardMaterial3D=mesh.material
			check(material.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED and material.vertex_color_use_as_albedo,"Original unshaded particle colors")
			check(material.billboard_mode==BaseMaterial3D.BILLBOARD_ENABLED and material.cull_mode==BaseMaterial3D.CULL_DISABLED and material.texture_filter==BaseMaterial3D.TEXTURE_FILTER_NEAREST,"Original billboard and nearest silhouette")
			for key in [&"amount",&"color",&"initial_velocity_min",&"initial_velocity_max",&"lifetime",&"direction",&"spread",&"gravity",&"one_shot",&"explosiveness",&"local_coords",&"cast_shadow"]:
				check(current._emitter.get(key)==previous._emitter.get(key),"Independent emitter parity: "+String(kind)+"/"+String(key))
			check(current._emitter!=previous._emitter,"No simulation or emitter sharing")
		var reference: WeakRef=weakref(floor_root)
		floor_root.queue_free()
		for frame in 4: await process_frame
		check(reference.get_ref()==null,"Floor and its particle emitters released")
		check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==node_baseline,"No floor nodes held by shared resource")
	print("IMPACT_MESH_REUSE_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
