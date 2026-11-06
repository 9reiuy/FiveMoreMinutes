extends SceneTree
## Bake the same approved geometry and face textures used by the formal office.
const CATALOG=preload("res://scripts/dream/office_furniture_catalog.gd")
const FACES=preload("res://scripts/dream/preview/furniture_face_textures.gd")
const OUT="res://scenes/story/tutorial_props/"
func _initialize() -> void: call_deferred("build")
func build() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for kind in ["sofa","cabinet","shelf","workstation","chair","plant","coffee_table","water_dispenser"]:
		var visual: Node3D=CATALOG.make_visual_for_style(kind,"approved_room")
		visual.name="Approved_"+kind
		visual.set_meta("approved_kind",kind)
		visual.set_meta("solid_size",CATALOG.footprint(kind).size/32.)
		var variant: int=posmod(kind.hash(),4); visual.set_meta("approved_variant",variant)
		for mesh in visual.find_children("*","MeshInstance3D",true,false):
			var source: ShaderMaterial=mesh.material_override as ShaderMaterial
			if source==null: continue
			var atlas: Texture2D=source.get_shader_parameter("atlas")
			if atlas==null: continue
			var result: Dictionary=FACES.build(mesh.mesh,atlas,kind,variant)
			var material: ShaderMaterial=source.duplicate()
			material.set_shader_parameter("atlas",result.texture)
			mesh.mesh=result.mesh; mesh.material_override=material
		for child in visual.find_children("*","Node",true,false): child.owner=visual
		var scene:=PackedScene.new(); scene.pack(visual)
		assert(ResourceSaver.save(scene,OUT+kind+".tscn")==OK)
		print("APPROVED_TUTORIAL_PROP ",kind," variant=",variant)
		visual.free()
	quit()
