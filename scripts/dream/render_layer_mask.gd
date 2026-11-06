extends RefCounted

static func apply(visual: VisualInstance3D, mask: int) -> void:
	if visual.layers == mask:
		return
	if visual.is_inside_tree() and RenderingServer.get_current_rendering_method() == "forward_plus":
		var instance := visual.get_instance()
		var scenario := visual.get_world_3d().scenario
		# In the affected engine version, lights retain their old pairings
		# across layer updates. Unpair while the old membership still exists.
		RenderingServer.instance_set_scenario(instance, RID())
		visual.layers = mask
		RenderingServer.instance_set_scenario(instance, scenario)
	else:
		visual.layers = mask
