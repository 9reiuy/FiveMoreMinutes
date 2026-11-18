extends Control
## Same tutorial material in a reference-style column, isolated from gameplay.
var viewport: SubViewport
var smoke: Node3D

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport=SubViewport.new()
	viewport.size=Vector2i(630,716)
	viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.positional_shadow_atlas_size=2048
	add_child(viewport)
	var scene:=Node3D.new()
	viewport.add_child(scene)
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color("b5d1f3")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("adc0fa")
	environment.environment.ambient_light_energy=.30
	scene.add_child(environment)
	var floor_mesh:=MeshInstance3D.new()
	var plane:=PlaneMesh.new()
	plane.size=Vector2(1000,1000)
	floor_mesh.mesh=plane
	var paint:=StandardMaterial3D.new()
	paint.albedo_color=Color("f5f5f0")
	paint.roughness=1.0
	floor_mesh.material_override=paint
	scene.add_child(floor_mesh)
	var light:=DirectionalLight3D.new()
	light.light_energy=preload("res://scripts/testing/stylized_smoke_column.gd").LIGHT_GAIN/PI
	light.rotation_degrees=Vector3(-50,-30,0)
	light.shadow_enabled=true
	light.shadow_blur=2.0
	scene.add_child(light)
	var camera:=Camera3D.new()
	camera.fov=40.0
	camera.near=.05
	camera.far=400.0
	scene.add_child(camera)
	camera.position=Vector3(6,3.35,12)
	camera.look_at(Vector3(0.0,3.55,0))
	camera.current=true
	smoke=preload("res://scripts/testing/stylized_smoke_column.gd").new()
	scene.add_child(smoke)
	smoke.configure_reference()
	# The world owns separate CanvasLayers for weapon and stage indicators.
	# Keep this isolated reference above those layers without mutating them.
	var overlay:=CanvasLayer.new()
	overlay.layer=300
	add_child(overlay)
	var background:=ColorRect.new()
	background.color=Color("171e29")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(background)
	var display:=TextureRect.new()
	display.texture=viewport.get_texture()
	display.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	overlay.add_child(display)
	var hint:=Label.new()
	hint.text="烟雾视觉修订 · F2 / Esc 返回旧交互白盒"
	hint.add_theme_font_override("font",preload("res://scripts/ui/crisp_interaction_font.gd").get_font())
	hint.add_theme_font_size_override("font_size",10)
	hint.add_theme_color_override("font_color",Color("d7e1ef"))
	hint.position=Vector2(12,12)
	overlay.add_child(hint)
