extends SceneTree
func _initialize():
	call_deferred('go')
func go():
	var art = load('res://scripts/dream/office_low_pixel_art.gd')
	var v = art.make_visual('partition')
	var m = v.find_child('AuthoredSurfaceMesh', true, false) as MeshInstance3D
	var sm = m.material_override as ShaderMaterial
	var code: String = sm.shader.code
	var i = code.find('render_mode')
	print('RENDER_LINE=', code.substr(i, 80).replace('\n',' '))
	print('HAS_DISCARD=', code.contains('occlusion_cut < 0.004'))
	print('HAS_PREPASS=', code.contains('depth_prepass_alpha'))
	print('HAS_NEVER=', code.contains('depth_draw_never'))
	quit(0)