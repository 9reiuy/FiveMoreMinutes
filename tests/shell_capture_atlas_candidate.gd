extends Node
## Diagnostic-only, never loaded by the formal world. Original 128px cells,
## captures, source motion and 3D lighting remain intact.
var atlas: SubViewport
var records: Array[Dictionary]=[]
func enable(bridges: Array[Node]) -> void:
	atlas=SubViewport.new()
	atlas.size=Vector2i(1024,128*ceili(float(bridges.size())/8.0))
	atlas.transparent_bg=true
	atlas.disable_3d=true
	atlas.handle_input_locally=false
	atlas.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	atlas.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(atlas)
	for index in bridges.size():
		var bridge: Node=bridges[index]
		var capture: Node2D=bridge.render_root
		var tile:=Vector2(index%8,index/8)*128.0
		records.append({"bridge":bridge,"parent":capture.get_parent(),"position":capture.position,"texture":bridge.actor_sprite.texture,"shader":bridge.lit_material.shader})
		capture.reparent(atlas,false)
		capture.position=tile
		var texture:=AtlasTexture.new()
		texture.atlas=atlas.get_texture()
		texture.region=Rect2(tile,Vector2(128,128))
		bridge.actor_sprite.texture=texture
		# Sprite3D's AtlasTexture already maps mesh UVs into the tile. Keep the
		# exact original lit shader; a second region mapping would enlarge pixels.
		bridge.lit_material.set_shader_parameter("capture_texture",atlas.get_texture())
func sync() -> void:
	for record in records:
		var bridge: Node=record.bridge
		bridge._process(0.0)
		# Only the diagnostic manager owns the shared target's update mode.
		bridge.render_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
func restore() -> void:
	for record in records:
		var bridge: Node=record.bridge
		bridge.render_root.reparent(record.parent,false)
		bridge.render_root.position=record.position
		bridge.actor_sprite.texture=record.texture
		bridge.lit_material.shader=record.shader
		bridge.lit_material.set_shader_parameter("capture_texture",record.texture)
		bridge._process(0.0)
	records.clear()
	atlas.queue_free()
	atlas=null
