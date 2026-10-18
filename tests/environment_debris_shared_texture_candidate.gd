extends Node3D
## Test-only passive atlas. Keep native Sprite3D geometry, shader and draw order.
var records: Array[Dictionary] = []
var texture: ImageTexture
var material: ShaderMaterial
func build(bridges: Array) -> void:
	var source_image: Image = bridges[0].source_actor.sprite.texture.get_image()
	var atlas := Image.create(1024,2688,false,Image.FORMAT_RGBA8)
	atlas.fill(Color(0,0,0,0))
	for frame in 42:
		for rotation in 4:
			var art := source_image.get_region(Rect2i((frame%7)*32,(frame/7)*32,32,32))
			for step in rotation: art.rotate_90(CLOCKWISE)
			var cell := frame*4+rotation
			atlas.blit_rect(art,Rect2i(0,0,32,32),Vector2i((cell%8)*128+48,(cell/8)*128+48))
	texture = ImageTexture.create_from_image(atlas)
	material = bridges[0].lit_material.duplicate() as ShaderMaterial
	material.set_shader_parameter("capture_texture",texture)
	for bridge in bridges:
		var art: Sprite2D = bridge.source_actor.sprite
		var cell := art.frame*4+posmod(roundi(art.global_rotation/(PI*.5)),4)
		var region := AtlasTexture.new(); region.atlas = texture
		region.region = Rect2((cell%8)*128,(cell/8)*128,128,128)
		records.append({"bridge":bridge,"texture":bridge.actor_sprite.texture,"material":bridge.actor_sprite.material_override,"atlas":region,"mode":bridge.render_viewport.render_target_update_mode})
	set_enabled(false)
func set_enabled(enabled: bool) -> void:
	for record in records:
		var bridge: Node = record.bridge
		bridge.actor_sprite.texture = record.atlas if enabled else record.texture
		bridge.actor_sprite.material_override = material if enabled else record.material
		bridge.render_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if enabled else record.mode
