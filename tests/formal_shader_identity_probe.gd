extends SceneTree
## Read-only material/shader identity inventory, not a performance claim.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var world: Node3D=load("res://scenes/dream/Dream3D_RandomDungeon.tscn").instantiate()
	world.generate_on_ready=false; world.persist_profile=false; world.enable_game_start_cab_exit=false
	root.add_child(world); paused=true
	if not world.regenerate(41001): quit(1); return
	var materials: Dictionary={}
	for node in world.find_children("*","Node",true,false):
		if node is GeometryInstance3D:
			for material in [node.material_override,node.material_overlay]:
				if material!=null: materials[material]=true
		if node is MeshInstance3D and node.mesh!=null:
			for surface in node.mesh.get_surface_count():
				var material: Material=node.get_active_material(surface)
				if material!=null: materials[material]=true
	var codes: Dictionary={}
	var seen: Dictionary={}
	while not materials.is_empty():
		var material: Material=materials.keys()[0]; materials.erase(material)
		if seen.has(material): continue
		seen[material]=true
		if material.next_pass!=null: materials[material.next_pass]=true
		if not material is ShaderMaterial or material.shader==null: continue
		var code: String=material.shader.code
		if not codes.has(code): codes[code]={"shaders":{},"materials":0,"paths":[]}
		codes[code].shaders[material.shader.get_instance_id()]=true
		codes[code].materials+=1
		if not codes[code].paths.has(material.shader.resource_path): codes[code].paths.append(material.shader.resource_path)
	var rows: Array=[]; var count:=0
	for code in codes:
		var group: Dictionary=codes[code]; count+=group.shaders.size()
		rows.append({"code_hash":String(code).sha256_text(),"shader_objects":group.shaders.size(),"materials":group.materials,"paths":group.paths})
	print("FORMAL_SHADER_IDENTITIES ",JSON.stringify({"code_groups":codes.size(),"shader_objects":count,"groups":rows}))
	world.queue_free()
	for frame in 4: await process_frame
	quit(0)
