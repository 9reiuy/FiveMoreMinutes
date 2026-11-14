extends RefCounted
## Copy the finished game viewport into a separate GPU texture for the next frame.
## The monitor never samples the render target currently being drawn.
var output: Texture2D
var _gpu_output: Texture2DRD
var _fallback: ImageTexture
var _device: RenderingDevice
var _texture := RID()
var _size := Vector2i.ZERO
var _format := -1
var _mutex := Mutex.new()
var _running := true
var _pending := false
var _source := RID()
var copied_frames := 0
var last_error := OK

func _init() -> void:
	_device=RenderingServer.get_rendering_device()
	if _device!=null:
		_gpu_output=Texture2DRD.new();output=_gpu_output
	else:
		_fallback=ImageTexture.create_from_image(Image.create(1,1,false,Image.FORMAT_RGBA8));output=_fallback

func capture(view: Viewport) -> void:
	if _device==null:
		if DisplayServer.get_name()=="headless":return
		var frame:=view.get_texture().get_image()
		if frame==null or frame.is_empty():return
		if _fallback.get_size()!=Vector2(frame.get_size()):_fallback.set_image(frame)
		else:_fallback.update(frame)
		copied_frames+=1
		return
	_mutex.lock()
	if not _running or _pending:_mutex.unlock();return
	_source=view.get_texture().get_rid();_pending=true
	_mutex.unlock()
	var keep_alive: RefCounted=self
	RenderingServer.call_on_render_thread(func():keep_alive._copy_gpu())

func _copy_gpu() -> void:
	_mutex.lock()
	if not _running:_pending=false;_mutex.unlock();return
	var source:=RenderingServer.texture_get_rd_texture(_source)
	if not source.is_valid():_pending=false;_mutex.unlock();return
	var original:=_device.texture_get_format(source)
	var dimensions:=Vector2i(original.width,original.height)
	if dimensions!=_size or int(original.format)!=_format:
		var old:=_texture
		var format:=RDTextureFormat.new();format.width=dimensions.x;format.height=dimensions.y;format.format=original.format
		format.usage_bits=RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
		_texture=_device.texture_create(format,RDTextureView.new())
		_gpu_output.texture_rd_rid=_texture
		_size=dimensions;_format=original.format
		if old.is_valid():_device.free_rid(old)
	last_error=_device.texture_copy(source,_texture,Vector3.ZERO,Vector3.ZERO,Vector3(dimensions.x,dimensions.y,1),0,0,0,0)
	if last_error==OK:copied_frames+=1
	_pending=false;_mutex.unlock()

func get_stats() -> Dictionary:
	_mutex.lock()
	var result: Dictionary={"mode":"gpu_copy" if _device!=null else "headless" if DisplayServer.get_name()=="headless" else "cpu_copy","copied_frames":copied_frames,"last_error":last_error,"size":_size}
	_mutex.unlock();return result

func stop() -> void:
	_mutex.lock();_running=false;_mutex.unlock()
	if _device==null:return
	var keep_alive: RefCounted=self
	RenderingServer.call_on_render_thread(func():keep_alive._release_gpu())

func _release_gpu() -> void:
	_mutex.lock()
	_gpu_output.texture_rd_rid=RID()
	if _texture.is_valid():_device.free_rid(_texture);_texture=RID()
	_mutex.unlock()
