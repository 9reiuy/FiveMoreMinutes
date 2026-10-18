extends RefCounted
## One mask and clock for scene changes and paused elevator loading covers.
const SHADER=preload("res://shaders/transitions/pixel_block_transition.gdshader")
const COVER_SECONDS:=0.25
const REVEAL_SECONDS:=0.30

static func material()->ShaderMaterial:
	var result:=ShaderMaterial.new(); result.shader=SHADER
	return result

static func animate(rect: ColorRect,from: float,to: float,seconds: float,guard: Callable=Callable())->bool:
	var reference: WeakRef=weakref(rect)
	var tree:=rect.get_tree()
	var started:=Time.get_ticks_usec()
	while true:
		var current: ColorRect=reference.get_ref()
		if not is_instance_valid(current) or not current.is_inside_tree(): return false
		if not guard.is_null() and (not guard.is_valid() or not bool(guard.call())): return false
		var ratio: float=1.0 if seconds<=0 else clampf((Time.get_ticks_usec()-started)/(seconds*1000000.0),0,1)
		var eased: float=ratio*ratio*(3.0-2.0*ratio)
		current.material.set_shader_parameter("invert",false)
		current.material.set_shader_parameter("progress",lerpf(from,to,eased))
		if ratio>=1.0: return true
		await tree.process_frame
	return false

static func present(tree: SceneTree,frames: int=1)->void:
	for i in frames:
		if DisplayServer.get_name()=="headless": await tree.process_frame
		else: await RenderingServer.frame_post_draw
