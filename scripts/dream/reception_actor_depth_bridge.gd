extends "res://scripts/dream/dream_3d_actor_depth_bridge.gd"
## Lobby-only raised concourse; shared combat/carrier coordinates stay intact.
var lobby_height_owner: Node
var contact_shadow:MeshInstance3D
var contact_material:ShaderMaterial
static var contact_texture:Texture2D
static var contact_region:Vector4

func _lobby_height() -> float:
	if not is_instance_valid(lobby_height_owner) or not is_instance_valid(source_actor):return 0.0
	var collider:=source_actor.get_node_or_null("CollisionShape2D") as Node2D
	var point: Vector2=collider.global_position if collider!=null else source_actor.global_position
	return lobby_height_owner.get_lobby_surface_height(point/PIXELS_PER_WORLD_CELL)

func _character_ground() -> Vector3:
	return super._character_ground()+Vector3.UP*_lobby_height()

func _process(delta: float) -> void:
	super._process(delta)
	if configured and is_instance_valid(actor_sprite) and is_instance_valid(source_actor) and source_actor.is_in_group(&"reception_npc"):
		var camera := _active_world_camera()
		if camera != null:
			# Peaceful NPCs stay outside combat groups, but use the same authored
			# foot contact as characters instead of the generic prop-plane offset.
			actor_sprite.global_position=_character_colour_origin(camera,0.0)
		_sync_contact_shadow()
		return
	# Other presentation planes use the generic carrier branch.
	if configured and is_instance_valid(actor_sprite) and not character_projection and not (ground_only and (_cached_is_player or _cached_is_enemy)):
		actor_sprite.global_position.y+=_lobby_height()
	_sync_contact_shadow()

func _sync_contact_shadow() -> void:
	if not configured or not is_instance_valid(source_actor) or not source_paths.has(^"CharacterVisual"):return
	if not (_cached_is_player or source_actor.is_in_group(&"reception_npc")):return
	if not is_instance_valid(contact_shadow):
		if contact_texture==null:
			contact_texture=preload("res://art/Dream/shadow.png")
			var area:=contact_texture.get_image().get_used_rect();var size:=Vector2(contact_texture.get_size())
			contact_region=Vector4(area.position.x/size.x,area.position.y/size.y,area.size.x/size.x,area.size.y/size.y)
		contact_material=ShaderMaterial.new();contact_material.shader=preload("res://shaders/dream3d/reception_contact_shadow.gdshader")
		contact_material.set_shader_parameter("shadow_texture",contact_texture)
		contact_material.set_shader_parameter("shadow_region",contact_region)
		contact_shadow=MeshInstance3D.new();contact_shadow.name="FootContactShadow"
		var plane:=QuadMesh.new();plane.size=Vector2(.46,.23);contact_shadow.mesh=plane
		contact_shadow.rotation.x=-PI*.5;contact_shadow.material_override=contact_material
		contact_shadow.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(contact_shadow)
	var height:=_source_fake_height_pixels() if character_projection else 0.0
	contact_shadow.global_position=_character_ground()+Vector3.UP*.008
	contact_shadow.visible=source_actor.visible and room_presentation_active
	contact_material.set_shader_parameter("opacity",.26*(1.-clampf(height/56.,0.,.85)))
