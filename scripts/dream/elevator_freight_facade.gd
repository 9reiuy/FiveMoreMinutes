extends "res://scripts/dream/elevator_industrial_facade.gd"
## Shared freight door dressing, aperture and opening-driven interior light.
## The owning door retains animation, collision and floor-transition authority.
var bay_number:=0
static var coating_texture: Texture2D
static var aperture_shader: Shader
var aperture_materials: Array[ShaderMaterial]=[]
var interior_light: OmniLight3D
var spill_light: SpotLight3D
var opening_fraction:=0.0
var last_door_transform:=Transform3D()

func configure(source: Node3D) -> void:
	source.indicator_label.hide()
	for panel in ["FramePostLeft","FramePostRight","FrameLintelTop"]:
		source.frame_root.get_node(panel).hide()
	if aperture_shader==null:
		aperture_shader=Shader.new()
		# Reuse the authored surface lighting; only the moving plates gain a
		# fixed door-local aperture, shared by both faces and all attached detail.
		aperture_shader.code=PIXEL.SHADER.code.replace("varying vec3 pattern_position;",
			"uniform mat4 world_to_door;\nuniform float aperture_half_width;\nvarying vec3 pattern_position;")
		aperture_shader.code=aperture_shader.code.replace("void fragment() {",
			"void fragment() {\nvec3 aperture_point=(world_to_door*vec4(architecture_world,1.0)).xyz;\nif(abs(aperture_point.x)>aperture_half_width || aperture_point.y<0.0 || aperture_point.y>2.6) { discard; }")
	super.configure(source)

func _process(_delta: float) -> void:
	if not is_instance_valid(door) or not is_instance_valid(interior_light): return
	var leaf_width: float=(door.left_door_mesh.mesh as BoxMesh).size.x
	# The existing animation leaves a 0.10-unit return inside each jamb.
	# Normalize against that visible aperture, without changing its travel.
	opening_fraction=clampf((absf(door.left_door_mesh.position.x)-leaf_width*.5)*2.0/(door.opening_width-.20),0.0,1.0)
	interior_light.light_energy=1.8*opening_fraction
	spill_light.light_energy=2.1*opening_fraction
	get_node("FreightInteriorLamp").visible=opening_fraction>.001
	if last_door_transform!=_door_transform():
		last_door_transform=_door_transform()
		for material in aperture_materials:
			material.set_shader_parameter("world_to_door",last_door_transform.affine_inverse())

func _door_transform() -> Transform3D:
	return door.global_transform if door.is_inside_tree() else door.transform

static func coated_material(color: Color, glow: bool=false) -> ShaderMaterial:
	if coating_texture==null:
		var image:=Image.create(32,32,false,Image.FORMAT_RGBA8)
		# Painted plates have continuous faces. Geometry owns all panel seams;
		# the generic metal swatch's repeating dark border must not add a grid.
		image.fill(Color(.9,.9,.9,1)); image.generate_mipmaps()
		coating_texture=ImageTexture.create_from_image(image)
	var material:=PIXEL.make(color,"paint",true,glow).duplicate() as ShaderMaterial
	material.set_shader_parameter("pixel_texture",coating_texture)
	return material
func _init() -> void:
	materials=[
		coated_material(Color("626f79")),
		coated_material(Color("939ca1")),
		coated_material(Color("303c46")),
		coated_material(Color("c1a15a")),
		coated_material(Color("4c5963")),
		coated_material(Color("e0aa58"),true)
	]

func refresh() -> void:
	for child in get_children(): child.free()
	aperture_materials.clear()
	var width: float=door.opening_width
	var front: float=door.wall_depth*.5
	var build:=tools()
	# Broad structural shoulders; thick sides and top remain readable from above.
	for side in [-1.0,1.0]:
		var x: float=side*(width*.5+.16)
		box(build,2,Vector3(.32,2.78,.56),Vector3(x,1.39,front-.04))
		box(build,0,Vector3(.27,2.64,.22),Vector3(x,1.38,front+.32))
		box(build,1,Vector3(.055,2.55,.045),Vector3(x-side*.12,1.39,front+.455))
		box(build,2,Vector3(.34,.4,.27),Vector3(x,.2,front+.31))
		# Restrained hazard band on the feet, rather than a striped doorway.
		for y in [.09,.23,.37]:
			box(build,3,Vector3(.20,.065,.022),Vector3(x,y,front+.457))
		for y in [.61,2.48]:
			box(build,1,Vector3(.07,.07,.035),Vector3(x,y,front+.456))
	# Closed drive housing with a stepped lid and four broad cooling slots.
	box(build,2,Vector3(width+.64,.54,.68),Vector3(0,2.94,front+.02))
	box(build,0,Vector3(width+.53,.40,.15),Vector3(0,2.96,front+.43))
	box(build,1,Vector3(width+.64,.07,.72),Vector3(0,3.23,front+.025))
	for x in [-width*.35,-width*.26,width*.26,width*.35]:
		box(build,2,Vector3(.12,.21,.025),Vector3(x,2.99,front+.52))
	box(build,2,Vector3(.75,.22,.025),Vector3(0,2.98,front+.52))
	box(build,3,Vector3(.10,.06,.022),Vector3(-.26,3.04,front+.54))
	box(build,3,Vector3(.10,.06,.022),Vector3(.26,3.04,front+.54))
	# A real sill with a bright nosing, away from the moving leaf seam.
	box(build,0,Vector3(width+.3,.075,.62),Vector3(0,.04,front+.07))
	box(build,1,Vector3(width+.3,.035,.09),Vector3(0,.095,front+.37))
	for z in [front-.1,front+.05,front+.20]:
		box(build,2,Vector3(width-.15,.01,.035),Vector3(0,.083,z))
	# Warm, narrow downlight under the housing; not a floodlit facade.
	box(build,5,Vector3(width*.6,.045,.04),Vector3(0,2.63,front+.47))
	var frame:=MeshInstance3D.new(); frame.name="FreightStructuralFrame"
	frame.mesh=finish(build); frame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(frame)
	var warm:=OmniLight3D.new(); warm.name="FreightAmberDownlight"
	warm.position=Vector3(0,2.62,front+.42)
	warm.light_color=Color("e1ac64"); warm.light_energy=.35
	warm.omni_range=2.1; warm.shadow_enabled=false; add_child(warm)
	var leaf_width: float=(door.left_door_mesh.mesh as BoxMesh).size.x
	for i in leaf_displays.size():
		var plate:=tools()
		var face: float=(door.left_door_mesh.mesh as BoxMesh).size.z*.5
		for side in [-1.0,1.0]:
			# Steel slab, recessed central field, two broad stiles and end plates.
			box(plate,0,Vector3(leaf_width-.04,2.48,.14),Vector3(0,0,side*(face+.07)))
			box(plate,4,Vector3(leaf_width-.43,1.85,.03),Vector3(0,.02,side*(face+.157)))
			for x in [-1.0,1.0]:
				box(plate,0,Vector3(.16,2.42,.10),Vector3(x*(leaf_width*.5-.11),0,side*(face+.19)))
				box(plate,1,Vector3(.035,2.37,.035),Vector3(x*(leaf_width*.5-.17),0,side*(face+.259)))
			for y in [-1.06,1.06]:
				box(plate,0,Vector3(leaf_width-.10,.21,.10),Vector3(0,y,side*(face+.19)))
				for x in [-1.0,1.0]:
					box(plate,1,Vector3(.065,.065,.03),Vector3(x*(leaf_width*.5-.14),y,side*(face+.259)))
			# Short wear marks and one broad lower kick plate preserve quiet panels.
			box(plate,1,Vector3(leaf_width-.4,.035,.022),Vector3(0,-.87,side*(face+.18)))
			box(plate,2,Vector3(leaf_width-.35,.18,.025),Vector3(0,-.65,side*(face+.18)))
		leaf_displays[i].mesh=finish(plate)
		for surface in leaf_displays[i].mesh.get_surface_count():
			var clipped: ShaderMaterial=leaf_displays[i].mesh.surface_get_material(surface).duplicate()
			clipped.shader=aperture_shader
			clipped.set_shader_parameter("aperture_half_width",width*.5-.10)
			clipped.set_shader_parameter("world_to_door",_door_transform().affine_inverse())
			leaf_displays[i].mesh.surface_set_material(surface,clipped)
			aperture_materials.append(clipped)
	var base_leaf_material: ShaderMaterial=materials[0].duplicate()
	base_leaf_material.shader=aperture_shader
	base_leaf_material.set_shader_parameter("aperture_half_width",width*.5-.10)
	base_leaf_material.set_shader_parameter("world_to_door",_door_transform().affine_inverse())
	for leaf in [door.left_door_mesh,door.right_door_mesh]: leaf.material_override=base_leaf_material
	aperture_materials.append(base_leaf_material)
	_build_lit_recess(width)
	# Existing controls retain ownership; move their visible housings out of trim.
	door.card_reader_root.position=Vector3(width*.5+.16,1.32,front+.49)
	door.indicator_root.position=Vector3(0,2.99,front+.56)
	door.indicator_root.scale=Vector3(.3,1,1)
	var number:=Label3D.new(); number.name="FreightNumber"
	number.text="%02d"%(door.current_floor_index+1)
	number.font_size=32; number.pixel_size=.009; number.outline_size=0
	number.position=Vector3(0,2.98,front+.61); add_child(number)
	var reverse_number:=number.duplicate() as Label3D
	reverse_number.name="FreightNumberBack"; reverse_number.position.z=front-.37
	reverse_number.rotation.y=PI; add_child(reverse_number)
	update_number()

func update_number() -> void:
	var text: String="%02d"%(bay_number if bay_number>0 else door.current_floor_index+1)
	for label in ["FreightNumber","FreightNumberBack"]:
		var number:=get_node_or_null(label) as Label3D
		if number!=null: number.text=text

func _build_lit_recess(width: float) -> void:
	door.frame_root.get_node("ShaftBacking").hide()
	var interior:=tools()
	box(interior,4,Vector3(width,.06,.96),Vector3(0,.02,-.46))
	var recess:=MeshInstance3D.new(); recess.name="FreightLitRecess"
	recess.mesh=finish(interior); recess.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(recess)
	# A front-facing back wall does not obscure the door when the fixed floor
	# camera sees a southern facade from its reverse side.
	var back:=MeshInstance3D.new(); back.name="FreightInteriorBackWall"
	var back_mesh:=QuadMesh.new(); back_mesh.size=Vector2(width,2.58); back.mesh=back_mesh
	back.position=Vector3(0,1.30,-.93); back.material_override=materials[0]
	back.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; recess.add_child(back)
	# Inward-facing walls and ceiling have no opaque outer faces. The high
	# reverse gameplay camera must not see a roof covering the moving leaves.
	for side in [-1.0,1.0]:
		var wall:=MeshInstance3D.new(); wall.name="InteriorSide%d"%int(side)
		var panel:=QuadMesh.new(); panel.size=Vector2(.92,2.58); wall.mesh=panel
		wall.position=Vector3(side*(width*.5-.035),1.30,-.46)
		wall.rotation.y=-side*PI*.5; wall.material_override=materials[4]
		wall.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; recess.add_child(wall)
	var ceiling:=MeshInstance3D.new(); ceiling.name="InteriorCeiling"
	var ceiling_mesh:=PlaneMesh.new(); ceiling_mesh.size=Vector2(width,.96); ceiling.mesh=ceiling_mesh
	ceiling.position=Vector3(0,2.59,-.46); ceiling.rotation.x=PI
	ceiling.material_override=materials[2]; ceiling.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	recess.add_child(ceiling)
	var lamp:=MeshInstance3D.new(); lamp.name="FreightInteriorLamp"
	var lamp_mesh:=BoxMesh.new(); lamp_mesh.size=Vector3(width*.65,.035,.14); lamp.mesh=lamp_mesh
	lamp.position=Vector3(0,2.54,-.5)
	lamp.visible=false
	lamp.material_override=coated_material(Color("ffe1b4"),true)
	lamp.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(lamp)
	interior_light=OmniLight3D.new(); interior_light.name="FreightInteriorWarmWhite"
	interior_light.position=Vector3(0,1.85,-.45); interior_light.omni_range=2.2
	interior_light.light_color=Color("ffe3bc"); interior_light.light_energy=0
	interior_light.shadow_enabled=false; add_child(interior_light)
	spill_light=SpotLight3D.new(); spill_light.name="FreightOpeningSpill"
	spill_light.position=Vector3(0,2.3,-.30); spill_light.light_color=Color("ffe3bc")
	spill_light.spot_range=5; spill_light.spot_angle=48; spill_light.spot_angle_attenuation=.6
	spill_light.light_energy=0; spill_light.shadow_enabled=false; add_child(spill_light)
	spill_light.basis=Basis.looking_at(Vector3(0,-2.3,3.5).normalized(),Vector3.UP)
	last_door_transform=_door_transform()
