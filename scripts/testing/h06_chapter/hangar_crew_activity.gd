extends RefCounted
## Presentation only. The crew's combat/physics callbacks stay disabled.
const CLIPBOARD := preload("res://art/icon/Sprites_Cropped/Software_Clipbaord_List_File_Copy_Paste.png")
const WRENCH := preload("res://art/Dream/weapons/Weapons/22.png")
var actor: EmployeeEnemy
var role := 0
var anchor := Vector2.ZERO
var age := 0.0
var current_task: StringName = &"inspect"
var prop := Sprite2D.new()

func bind(owner_actor: EmployeeEnemy, index: int) -> void:
	actor = owner_actor
	role = index
	anchor = actor.position
	prop.name = "WorkProp"
	prop.texture = WRENCH if role==2 else CLIPBOARD
	prop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prop.scale = Vector2.ONE*(0.55 if role==2 else 0.70)
	prop.z_index = 2
	actor.body_pivot.add_child(prop)
	actor.random.seed = hash(["hangar_crew_blink",role])
	actor.enemy_blink_time_left = 0.75+role*0.63
	present()

func advance(delta: float) -> void:
	age += delta
	present()
	actor._update_enemy_blink(delta)

func reset_pose() -> void:
	actor.character_visual.position = actor.character_visual_base_position
	actor.character_visual.rotation = 0
	actor.body_pivot.position = actor.body_pivot_base_position
	actor.body_pivot.rotation = 0
	actor.head.position = actor.head_base_position
	actor.head.rotation = 0
	actor.left_leg.position = actor.left_leg_base_position
	actor.right_leg.position = actor.right_leg_base_position
	actor.left_leg.rotation = 0
	actor.right_leg.rotation = 0
	actor.left_hand.position = actor.left_hand_base_position
	actor.right_hand.position = actor.right_hand_base_position
	actor.left_hand.rotation = 0
	actor.right_hand.rotation = 0
	prop.hide()

func present() -> void:
	reset_pose()
	actor.position = anchor
	actor.body_pivot.position.y += sin(age*1.7+role)*0.22
	var t := fmod(age,[14.4,16.8,17.1][role])
	if role==0:
		if t<3.5: task(&"inspect")
		elif t<5.7: walk(Vector2.ZERO,Vector2(-0.65,-0.95),(t-3.5)/2.2)
		elif t<9.0:
			actor.position += Vector2(-0.65,-0.95)*32
			task(&"record")
		elif t<11.2: walk(Vector2(-0.65,-0.95),Vector2.ZERO,(t-9.0)/2.2)
		else: task(&"point")
	elif role==1:
		if t<4.4: task(&"record")
		elif t<6.6: walk(Vector2.ZERO,Vector2(0.50,-0.70),(t-4.4)/2.2)
		elif t<10.6:
			actor.position += Vector2(0.50,-0.70)*32
			task(&"inspect")
		elif t<12.8: walk(Vector2(0.50,-0.70),Vector2.ZERO,(t-10.6)/2.2)
		else: task(&"record")
	else:
		if t<2.3: walk(Vector2.ZERO,Vector2(0.35,-1.20),t/2.3)
		elif t<6.9:
			actor.position += Vector2(0.35,-1.20)*32
			task(&"repair")
		elif t<9.7:
			actor.position += Vector2(0.35,-1.20)*32
			task(&"check_tool")
		elif t<12.0: walk(Vector2(0.35,-1.20),Vector2.ZERO,(t-9.7)/2.3)
		elif t<14.6: task(&"inspect")
		else: task(&"check_tool")

func walk(start: Vector2, finish: Vector2, progress: float) -> void:
	current_task = &"walk"
	var u := clampf(progress,0,1)
	actor.position = anchor+start.lerp(finish,u*u*(3-2*u))*32
	actor.face(finish-start)
	var stride := sin(age*10.0)
	actor.left_leg.position.y += stride*1.15
	actor.right_leg.position.y -= stride*1.15
	actor.character_visual.position.y -= absf(stride)*0.45
	actor.body_pivot.position.y -= absf(stride)*0.35
	actor.left_hand.position.y += stride
	actor.right_hand.position.y -= stride
	if role==2: show_tool(0.10+stride*0.08)

func task(kind: StringName) -> void:
	current_task = kind
	actor.face(Vector2(-3,1.6)-actor.position/32)
	match kind:
		&"record":
			actor.face(Vector2(-0.35,1))
			actor.left_hand.position = Vector2(-6,5)
			actor.right_hand.position = Vector2(0,5+sin(age*8)*0.65)
			actor.right_hand.rotation = -0.16+sin(age*8)*0.06
			prop.position = Vector2(-2,6)
			prop.rotation = -0.12
			prop.show()
		&"repair":
			# Lower the coat into a kneeling pose; the planted legs stay attached.
			actor.body_pivot.position.y += 3.0
			actor.body_pivot.rotation = -0.06
			actor.right_hand.position += Vector2(1.2,sin(age*5)*1.6)
			actor.left_hand.position += Vector2(2,-0.5)
			show_tool(-0.5+sin(age*5)*0.24)
		&"check_tool":
			actor.face(Vector2(0.25,1))
			actor.right_hand.position = Vector2(3,1.5+sin(age*2)*0.4)
			show_tool(-0.25+sin(age*2)*0.12)
		&"point":
			actor.right_hand.position = Vector2(7,-1.2+sin(age*2.4)*0.4)
			actor.right_hand.rotation = -0.55
		_:
			actor.head.position.y += sin(age*2.2)*0.35
			actor.left_hand.position += Vector2(1.3,sin(age*2.2)*0.6)
			actor.right_hand.position += Vector2(-1.3,-sin(age*2.2)*0.6)

func show_tool(angle: float) -> void:
	prop.position = actor.right_hand.position+Vector2(2,0)
	prop.rotation = angle
	prop.show()
