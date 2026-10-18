extends SceneTree

const THEME := preload("res://scripts/dream/dream_room_environment_theme.gd")
const LIGHTING := preload("res://scripts/dream/dream_3d_ceiling_lighting.gd")

func _init() -> void:
	print("--- TEST LIGHTING AND THEME START ---")
	
	# 1. Test Theme materials
	assert(THEME.get_base_floor_material("office") != null, "Office base material null")
	assert(THEME.get_base_floor_material("conference") != null, "Conference base material null")
	assert(THEME.get_base_floor_material("lounge") != null, "Lounge base material null")
	assert(THEME.get_base_floor_material("storage") != null, "Storage base material null")
	
	var storage_accent := THEME.get_accent_floor_material("storage")
	assert(storage_accent != null, "Storage accent material null")
	print("Storage accent material loaded: ", storage_accent.resource_name)
	
	var lounge_accent := THEME.get_accent_floor_material("lounge")
	assert(lounge_accent != null, "Lounge accent material null")
	print("Lounge accent material loaded: ", lounge_accent.resource_name)
	
	# 2. Test Ceiling Lighting instantiations
	var light_root: Node3D = LIGHTING.new()
	root.add_child(light_root)
	
	var archetypes := ["office", "conference", "lounge", "storage"]
	for idx in range(archetypes.size()):
		var arch: String = archetypes[idx]
		light_root.call(
			"_create_light_at",
			"Test_%s" % arch,
			idx,
			Vector3(float(idx * 10), 3.0, 0.0),
			Rect2i(0, 0, 8, 8),
			3.0,
			&"room",
			1,
			arch
		)
		light_root.call(
			"_create_room_center_fill",
			idx,
			Rect2i(0, 0, 8, 8),
			3.0,
			arch
		)
	
	print("Total children created: ", light_root.get_child_count())
	assert(light_root.get_child_count() == 8, "Expected 8 holders (4 fixtures + 4 center fills)")
	
	for child in light_root.get_children():
		var holder: Node3D = child as Node3D
		if holder.name.begins_with("Test_"):
			var fixture := holder.get_node_or_null("FixtureMesh") as MeshInstance3D
			assert(fixture != null, "FixtureMesh missing on " + holder.name)
			assert(fixture.mesh != null, "Fixture mesh null on " + holder.name)
			assert(fixture.material_override != null, "Material override null on " + holder.name)
			var spot := holder.get_node_or_null("RoomLight") as SpotLight3D
			assert(spot != null, "RoomLight missing on " + holder.name)
			assert(spot.light_cull_mask == 7, "Cull mask should include Layer 1")
			assert(spot.shadow_enabled == false, "Shadow should be false")
			print("Fixture verified: ", holder.name, " subchildren: ", fixture.get_child_count())
		elif holder.name.ends_with("_CenterFill"):
			var fill := holder.get_node_or_null("RoomFillLight") as OmniLight3D
			assert(fill != null, "RoomFillLight missing on " + holder.name)
			assert(fill.shadow_enabled == false, "Fill shadow should be false")
			print("Center fill verified: ", holder.name)
			
	light_root.queue_free()
	print("--- TEST LIGHTING AND THEME PASSED ---")
	quit(0)
