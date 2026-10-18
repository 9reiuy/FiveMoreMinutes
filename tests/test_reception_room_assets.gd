extends SceneTree

const RECEPTION_DESK_3D = preload("res://scripts/dream/props/reception_desk_3d.gd")
const RECEPTION_WAITRESS_NPC = preload("res://scripts/dream/reception_waitress_npc.gd")

func _init() -> void:
	print("==================================================")
	print("--- TESTING RECEPTION ROOM PROPS & NPC ASSETS ---")
	print("==================================================")
	
	test_reception_desk_scene()
	test_reception_desk_programmatic()
	test_waitress_npc_scene()
	test_waitress_npc_programmatic()
	
	print("==================================================")
	print("--- ALL RECEPTION ASSET TESTS PASSED CLEANLY! ---")
	print("==================================================")
	quit(0)


func test_reception_desk_scene() -> void:
	print("\n[Test 1] Testing ReceptionDesk3D scene instantiation...")
	var scene: PackedScene = load("res://scenes/dream/3d/props/reception_desk_3d.tscn")
	assert(scene != null, "Failed to load reception_desk_3d.tscn")
	
	var desk: Node3D = scene.instantiate() as Node3D
	assert(desk != null, "Failed to instantiate reception_desk_3d.tscn")
	root.add_child(desk)
	
	_verify_desk_properties(desk)
	
	desk.queue_free()
	print("  -> ReceptionDesk3D scene test passed!")


func test_reception_desk_programmatic() -> void:
	print("\n[Test 2] Testing ReceptionDesk3D.new() programmatic instantiation...")
	var desk: Node3D = RECEPTION_DESK_3D.new()
	assert(desk != null, "Failed to instantiate ReceptionDesk3D.new()")
	root.add_child(desk)
	
	_verify_desk_properties(desk)
	
	# Verify 2D collision setup
	var collision_root := Node2D.new()
	root.add_child(collision_root)
	
	var collider: StaticBody2D = desk.setup_gameplay_2d(collision_root, Vector2(256.0, 128.0))
	assert(collider != null, "setup_gameplay_2d must return StaticBody2D")
	assert(collider.name == "ReceptionDeskCollider2D", "Collider name must be ReceptionDeskCollider2D")
	assert(collider.collision_layer == 4, "Collision layer must be 4 (WORLD_WALL_LAYER)")
	assert(collider.collision_mask == 0, "Collision mask must be 0")
	assert(collider.position == Vector2(256.0, 128.0), "Collider position mismatch")
	
	var shape_owner: CollisionShape2D = collider.get_node("CollisionShape2D") as CollisionShape2D
	assert(shape_owner != null, "CollisionShape2D must exist")
	var rect_shape: RectangleShape2D = shape_owner.shape as RectangleShape2D
	assert(rect_shape != null, "Shape must be RectangleShape2D")
	var expected_size := Vector2(3.4 * 32.0, 1.1 * 32.0)
	print("  -> 2D Gameplay Collision size: ", rect_shape.size, " (expected: ", expected_size, ")")
	assert(rect_shape.size == expected_size, "Collision size must equal Vector2(3.4*32, 1.1*32)")
	
	desk.queue_free()
	collision_root.queue_free()
	print("  -> ReceptionDesk3D programmatic test passed!")


func _verify_desk_properties(desk: Node3D) -> void:
	# Verify all meshes
	var mesh_instances: Array[Node] = desk.find_children("*", "MeshInstance3D", true, false)
	print("  -> Total MeshInstance3D nodes: ", mesh_instances.size())
	assert(mesh_instances.size() >= 15, "Desk should have at least 15 mesh components for rich modern minimalist detail")
	
	# Verify TopCapCounter
	var top_cap: MeshInstance3D = desk.find_child("TopCapCounter", true, false) as MeshInstance3D
	assert(top_cap != null, "TopCapCounter not found")
	var top_mesh: BoxMesh = top_cap.mesh as BoxMesh
	assert(top_mesh != null, "TopCapCounter mesh must be BoxMesh")
	assert(is_equal_approx(top_mesh.size.x, 3.4), "TopCap width must be 3.4m")
	assert(is_equal_approx(top_mesh.size.y, 0.05), "TopCap height must be 0.05m")
	assert(is_equal_approx(top_mesh.size.z, 0.40), "TopCap depth must be 0.40m")
	assert(top_cap.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "TopCap must cast shadow")
	assert(top_cap.material_override is ShaderMaterial, "TopCap material must be ShaderMaterial")
	
	# Verify FrontModestyPanel
	var front_panel: MeshInstance3D = desk.find_child("FrontModestyPanel", true, false) as MeshInstance3D
	assert(front_panel != null, "FrontModestyPanel not found")
	var front_mesh: BoxMesh = front_panel.mesh as BoxMesh
	assert(is_equal_approx(front_mesh.size.x, 3.4), "FrontModestyPanel width must be 3.4m")
	assert(front_panel.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "FrontModestyPanel must cast shadow")
	
	# Verify BasePlinth (black recessed plinth)
	var base_plinth: MeshInstance3D = desk.find_child("BasePlinth", true, false) as MeshInstance3D
	assert(base_plinth != null, "BasePlinth not found")
	var plinth_mesh: BoxMesh = base_plinth.mesh as BoxMesh
	assert(is_equal_approx(plinth_mesh.size.x, 3.34), "BasePlinth width must be 3.34m (3.4m recessed by 0.03m on both sides)")
	assert(is_equal_approx(plinth_mesh.size.y, 0.10), "BasePlinth height must be 0.10m")
	assert(is_equal_approx(plinth_mesh.size.z, 1.04), "BasePlinth depth must be 1.04m (1.1m recessed by 0.03m)")
	
	# Verify InnerWorkSurface
	var inner_shelf: MeshInstance3D = desk.find_child("InnerWorkSurface", true, false) as MeshInstance3D
	assert(inner_shelf != null, "InnerWorkSurface not found")
	var shelf_mesh: BoxMesh = inner_shelf.mesh as BoxMesh
	assert(is_equal_approx(shelf_mesh.size.z, 0.70), "InnerWorkSurface depth must be 0.70m")
	
	# Verify End Caps
	var west_cap: MeshInstance3D = desk.find_child("WestEndCap", true, false) as MeshInstance3D
	var east_cap: MeshInstance3D = desk.find_child("EastEndCap", true, false) as MeshInstance3D
	assert(west_cap != null and east_cap != null, "End caps must exist")
	
	# Verify Modern All-In-One Screen Housing & Phosphor screen
	var screen_housing: MeshInstance3D = desk.find_child("ScreenHousing", true, false) as MeshInstance3D
	assert(screen_housing != null, "ScreenHousing must exist")
	var screen_mesh: BoxMesh = screen_housing.mesh as BoxMesh
	assert(is_equal_approx(screen_mesh.size.x, 0.55), "Screen housing width must be 0.55m")
	assert(is_equal_approx(screen_mesh.size.y, 0.36), "Screen housing height must be 0.36m")
	assert(is_equal_approx(screen_mesh.size.z, 0.025), "Screen housing depth must be 0.025m (ultra-thin)")
	
	var phosphor: MeshInstance3D = desk.find_child("PhosphorScreen", true, false) as MeshInstance3D
	assert(phosphor != null, "PhosphorScreen must exist")
	var phosphor_mat: ShaderMaterial = phosphor.material_override as ShaderMaterial
	assert(phosphor_mat != null, "PhosphorScreen must have ShaderMaterial")
	# Check glow parameter is enabled
	assert(phosphor_mat.get_shader_parameter("glow") == true, "PhosphorScreen must have glow enabled")
	
	# Verify Stand
	var stand_foot: MeshInstance3D = desk.find_child("StandFoot", true, false) as MeshInstance3D
	assert(stand_foot != null, "StandFoot must exist")
	
	# Verify Keyboard and Mouse
	var keyboard: MeshInstance3D = desk.find_child("KeyboardBody", true, false) as MeshInstance3D
	var mouse_pad: MeshInstance3D = desk.find_child("MousePad", true, false) as MeshInstance3D
	assert(keyboard != null, "KeyboardBody must exist")
	assert(mouse_pad != null, "MousePad must exist")
	
	# Verify Visitor Clipboard
	var clipboard: Node3D = desk.find_child("VisitorClipboard", true, false) as Node3D
	assert(clipboard != null, "VisitorClipboard must exist")


func test_waitress_npc_scene() -> void:
	print("\n[Test 3] Testing ReceptionWaitressNPC scene instantiation...")
	var scene: PackedScene = load("res://scenes/dream/reception_waitress_npc.tscn")
	assert(scene != null, "Failed to load reception_waitress_npc.tscn")
	
	var npc: Node2D = scene.instantiate() as Node2D
	assert(npc != null, "Failed to instantiate reception_waitress_npc.tscn")
	root.add_child(npc)
	
	_verify_waitress_properties(npc)
	
	npc.queue_free()
	print("  -> ReceptionWaitressNPC scene test passed!")


func test_waitress_npc_programmatic() -> void:
	print("\n[Test 4] Testing ReceptionWaitressNPC.new() programmatic instantiation...")
	var npc: Node2D = RECEPTION_WAITRESS_NPC.new()
	assert(npc != null, "Failed to instantiate ReceptionWaitressNPC.new()")
	root.add_child(npc)
	
	_verify_waitress_properties(npc)
	
	# Test interaction workflow
	var signal_emitted := [false]
	npc.interaction_requested.connect(func(): signal_emitted[0] = true)
	
	# Initially not targeted: prompt state should be empty
	var prompt_initial: Dictionary = npc.get_interaction_prompt_state()
	assert(prompt_initial.is_empty(), "Prompt should be empty when not targeted")
	
	# When targeted: prompt state should show "E 交谈"
	npc.set_interaction_targeted(true)
	var prompt_targeted: Dictionary = npc.get_interaction_prompt_state()
	print("  -> Interaction prompt state: ", prompt_targeted)
	assert(prompt_targeted.has("text"), "Prompt must have text")
	assert(prompt_targeted["text"] == "[E] 交谈", "Prompt text must be '[E] 交谈'")
	assert(prompt_targeted.has("position"), "Prompt must have position")
	
	# Request interaction
	npc.request_interaction()
	assert(signal_emitted[0] == true, "interaction_requested signal should have fired")
	print("  -> Interaction signal successfully fired!")
	
	# Test subtle breathing motion
	var initial_head_y: float = npc.head.position.y
	npc._process(0.5)
	var new_head_y: float = npc.head.position.y
	print("  -> Breathing motion delta: ", new_head_y - initial_head_y)
	assert(new_head_y != initial_head_y, "Breathing motion should modify head position")
	
	# Test blinking cycle
	npc.blink_timer = 0.0
	npc.blink_phase = 0
	npc._update_blinking(0.01)
	assert(npc.blink_phase == 1, "Blink phase should advance to 1 (half-blink)")
	assert(npc.head.texture == npc.head_frame_blink, "Head texture should be blink frame")
	
	npc._update_blinking(0.07)
	assert(npc.blink_phase == 2, "Blink phase should advance to 2 (closed)")
	assert(npc.head.texture == npc.head_frame_closed, "Head texture should be closed frame")
	
	npc._update_blinking(0.07)
	assert(npc.blink_phase == 0, "Blink phase should return to 0 (open)")
	assert(npc.head.texture == npc.head_frame_open, "Head texture should return to open frame")
	print("  -> Blinking 3-phase cycle verified successfully!")
	
	npc.queue_free()
	print("  -> ReceptionWaitressNPC programmatic test passed!")


func _verify_waitress_properties(npc: Node2D) -> void:
	# Verify groups
	assert(npc.is_in_group(&"reception_interaction_targets"), "Must be in reception_interaction_targets group")
	assert(npc.is_in_group(&"tutorial_interaction_targets"), "Must be in tutorial_interaction_targets group")
	
	# Verify CharacterVisual and child sprites
	var visual: Node2D = npc.get_node_or_null("CharacterVisual") as Node2D
	assert(visual != null, "CharacterVisual node must exist")
	
	var head: Sprite2D = visual.get_node_or_null("BodyPivot/Head") as Sprite2D
	var body: Sprite2D = visual.get_node_or_null("BodyPivot/Body") as Sprite2D
	var left_foot: Sprite2D = visual.get_node_or_null("LeftFoot") as Sprite2D
	var right_foot: Sprite2D = visual.get_node_or_null("RightFoot") as Sprite2D
	var left_hand: Sprite2D = visual.get_node_or_null("BodyPivot/LeftHand") as Sprite2D
	var right_hand: Sprite2D = visual.get_node_or_null("BodyPivot/RightHand") as Sprite2D
	var shadow: Sprite2D = npc.get_node_or_null("Shadow") as Sprite2D
	
	assert(head != null, "Head sprite must exist")
	assert(body != null, "Body sprite must exist")
	assert(left_foot != null, "LeftFoot sprite must exist")
	assert(right_foot != null, "RightFoot sprite must exist")
	assert(left_hand != null, "LeftHand sprite must exist")
	assert(right_hand != null, "RightHand sprite must exist")
	assert(shadow != null, "Shadow sprite must exist")
	
	# Verify Nearest Texture Filter
	assert(head.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Head must have NEAREST filter")
	assert(body.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Body must have NEAREST filter")
	assert(left_foot.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "LeftFoot must have NEAREST filter")
	assert(right_foot.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "RightFoot must have NEAREST filter")
	assert(left_hand.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "LeftHand must have NEAREST filter")
	assert(right_hand.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "RightHand must have NEAREST filter")
	
	# Verify AtlasTexture regions
	var head_tex: AtlasTexture = head.texture as AtlasTexture
	var body_tex: AtlasTexture = body.texture as AtlasTexture
	var lf_tex: AtlasTexture = left_foot.texture as AtlasTexture
	var rf_tex: AtlasTexture = right_foot.texture as AtlasTexture
	var lh_tex: AtlasTexture = left_hand.texture as AtlasTexture
	var rh_tex: AtlasTexture = right_hand.texture as AtlasTexture
	
	assert(head_tex.region == Rect2(32, 0, 28, 32), "Head open region must be Rect2(32, 0, 28, 32)")
	assert(body_tex.region == Rect2(64, 0, 32, 32), "Body region must be Rect2(64, 0, 32, 32)")
	assert(lf_tex.region == Rect2(108, 12, 4, 9), "LeftFoot region must be Rect2(108, 12, 4, 9)")
	assert(rf_tex.region == Rect2(113, 12, 4, 9), "RightFoot region must be Rect2(113, 12, 4, 9)")
	assert(lh_tex.region == Rect2(134, 15, 5, 4), "LeftHand region must be Rect2(134, 15, 5, 4)")
	assert(rh_tex.region == Rect2(149, 15, 5, 4), "RightHand region must be Rect2(149, 15, 5, 4)")
	print("  -> All character atlas texture regions verified accurately!")
