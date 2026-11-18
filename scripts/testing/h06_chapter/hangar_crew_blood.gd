extends Node3D
## Static masks baked from the existing painter; no per-return blood simulation.
const DATA := preload("res://scripts/testing/h06_chapter/hangar_crew_blood_data.gd")
const SHADER := preload("res://shaders/dream3d/blood_lit_ground_carrier.gdshader")
var marks: Array[Sprite3D] = []
var pixel_count := 0

func _init() -> void:
	name = "CrewDragBloodScenery"
	set_meta(&"surface_blood_excluded",true)
	for stamp: Dictionary in DATA.STAMPS:
		var mark := Sprite3D.new()
		mark.name = "DragBlood_%02d"%marks.size()
		mark.texture = stamp.texture
		mark.pixel_size = 1.0/32.0
		mark.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mark.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		mark.alpha_scissor_threshold = 0.05
		mark.position = Vector3(stamp.at.x,DATA.HEIGHT,stamp.at.y)
		mark.rotation.x = -PI*0.5
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.set_meta(&"surface_blood_excluded",true)
		var material := ShaderMaterial.new()
		material.shader = SHADER
		material.set_shader_parameter("capture_texture",stamp.texture)
		mark.material_override = material
		add_child(mark)
		marks.append(mark)
		pixel_count += int(stamp.pixels)
	hide()
