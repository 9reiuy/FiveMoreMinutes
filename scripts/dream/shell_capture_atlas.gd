extends Node3D
## Floor-owned passive captures. Every cell retains the original 128px grid;
## source gameplay, 3D carrier bounds, shader and lighting remain unchanged.
const CELL := 128
const CAPACITY := 32
var pages: Array[Dictionary]=[]
var slots: Dictionary={}
func register(bridge: Node3D) -> void:
	var page_index := -1
	var cell_index := -1
	for index in pages.size():
		cell_index=pages[index].owners.find(0)
		if cell_index>=0: page_index=index; break
	if page_index<0:
		var viewport := SubViewport.new()
		viewport.name="ShellCaptureAtlasPage%d"%pages.size()
		viewport.size=Vector2i(CELL*8,CELL*4)
		viewport.transparent_bg=true
		viewport.disable_3d=true
		viewport.handle_input_locally=false
		viewport.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		viewport.set_meta(&"shell_capture_atlas_page",true)
		add_child(viewport)
		var owners:=PackedInt64Array()
		owners.resize(CAPACITY)
		pages.append({"viewport":viewport,"owners":owners})
		page_index=pages.size()-1; cell_index=0
	var page: Dictionary=pages[page_index]
	var viewport: SubViewport=page.viewport
	var id:=bridge.get_instance_id()
	page.owners[cell_index]=id
	var tile:=Vector2(cell_index%8,cell_index/8)*CELL
	var capture: Node2D=bridge.render_root
	capture.reparent(viewport,false)
	capture.position=tile
	var texture:=AtlasTexture.new()
	texture.atlas=viewport.get_texture()
	texture.region=Rect2(tile,Vector2(CELL,CELL))
	bridge.actor_sprite.texture=texture
	bridge.lit_material.set_shader_parameter("capture_texture",viewport.get_texture())
	bridge.shared_capture_managed=true
	bridge.render_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	bridge.capture_atlas_release=Callable(self,"_free_slot").bind(id)
	slots[id]={"page":page_index,"cell":cell_index,"root":capture,"active":false,"bridge":weakref(bridge)}
func set_active(bridge: Node3D, active: bool) -> void:
	var id:=bridge.get_instance_id()
	if not slots.has(id): return
	slots[id].active=active
	_update_page(slots[id].page)
func _update_page(index: int) -> void:
	var page: Dictionary=pages[index]
	var active := false
	for id in page.owners:
		if id!=0 and slots.has(id) and slots[id].active: active=true; break
	page.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
func _free_slot(id: int) -> void:
	if not slots.has(id): return
	var slot: Dictionary=slots[id]
	if is_instance_valid(slot.root) and not slot.root.is_queued_for_deletion():
		# A cell can be reacquired before deferred deletion is flushed. Hide the
		# old passive tree immediately so it cannot paint into the new owner.
		slot.root.hide()
		slot.root.queue_free()
	pages[slot.page].owners[slot.cell]=0
	slots.erase(id)
	_update_page(slot.page)
