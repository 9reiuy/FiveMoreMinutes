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
			_place_npc_on_pixel_grid(camera)
		_sync_contact_shadow()
		return
	# Other presentation planes use the generic carrier branch.
	if configured and is_instance_valid(actor_sprite) and not character_projection and not (ground_only and (_cached_is_player or _cached_is_enemy)):
		actor_sprite.global_position.y+=_lobby_height()
	_sync_contact_shadow()

func _place_npc_on_pixel_grid(camera: Camera3D) -> void:
	var original_origin := _character_colour_origin(camera, 0.0)
	var facing := camera.global_basis.orthonormalized()
	var texel_world := actor_sprite.pixel_size
	var center := Vector2(render_viewport.size) * 0.5
	var contact := body_contact_local + viewport_offset - center
	var local_foot := Vector3(contact.x, -contact.y, 0.0) * texel_world
	var world_foot := original_origin + facing * local_foot
	if camera.is_position_behind(world_foot):
		actor_sprite.global_position = original_origin
		return

	var foot_px := camera.unproject_position(world_foot)
	var next_px := camera.unproject_position(world_foot + facing.x * texel_world)
	var pixels_per_texel := next_px.x - foot_px.x
	if pixels_per_texel <= 0.001:
		actor_sprite.global_position = original_origin
		return

	# Resize the full capture uniformly around its foot contact. Each source
	# texel maps to a whole square of display pixels at the native resolution.
	var integer_pixels := maxf(1.0, roundf(pixels_per_texel))
	var ratio := integer_pixels / pixels_per_texel
	var fitted := Basis(facing.x * ratio, facing.y * ratio, facing.z)
	var origin := world_foot - fitted * local_foot
	var local_corner := Vector3(-center.x, center.y, 0.0) * texel_world
	var corner_px := camera.unproject_position(origin + fitted * local_corner)
	var snap := corner_px.round() - corner_px
	origin += (facing.x * snap.x - facing.y * snap.y) * (texel_world / pixels_per_texel)
	actor_sprite.global_transform = Transform3D(fitted, origin)


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
