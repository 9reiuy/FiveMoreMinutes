extends SceneTree
const LIBRARY := preload("res://scripts/dream/explosion_volume_library.gd")
const TARGET := "res://art/Dream/VFX/CC0/JangaFX/GroundExplosion/ground_explosion_volume.res"
var source_dir := "res://.runtime/explosion_ground_cartoon_20261113/source_volume_sequence01/"
var artifact_dir := ""

func _initialize() -> void:call_deferred("run")

func run() -> void:
	AudioServer.set_bus_mute(0,true)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source-dir="):source_dir=arg.trim_prefix("--source-dir=")
		if arg.begins_with("--artifact-dir="):artifact_dir=arg.trim_prefix("--artifact-dir=")
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source_dir.path_join("manifest.json")))
	var data := LIBRARY.new()
	data.world_min=Vector3(manifest.world_min[0],manifest.world_min[1],manifest.world_min[2])
	data.world_size=Vector3(manifest.world_size[0],manifest.world_size[1],manifest.world_size[2])
	data.source_fps=manifest.source_fps
	data.source_archive_sha256="47c2c1d352b3c0dce31e462d09ede9f8bc95b5333ca9764564073b02113dc7b9"
	data.attribution="JangaFX Ground Explosion, CC0. Source density/flames, stride 2, area-averaged at 4 source voxels; RG8 square-root encoding."
	var width: int=manifest.width
	var height: int=manifest.height
	var depth: int=manifest.depth
	var slice_bytes := width*height*2
	for row: Dictionary in manifest.frames:
		var bytes := FileAccess.get_file_as_bytes(source_dir.path_join(row.file))
		if bytes.size()!=slice_bytes*depth:push_error("Invalid source frame");quit(1);return
		var images: Array[Image]=[]
		for layer in depth:
			images.append(Image.create_from_data(width,height,false,Image.FORMAT_RG8,bytes.slice(layer*slice_bytes,(layer+1)*slice_bytes)))
		var texture := ImageTexture3D.new()
		if texture.create(Image.FORMAT_RG8,width,height,depth,false,images)!=OK:quit(1);return
		data.frames.append(texture)
		data.source_frames.append(int(row.source_frame))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TARGET.get_base_dir()))
	if ResourceSaver.save(data,TARGET,ResourceSaver.FLAG_COMPRESS)!=OK:quit(1);return
	var restored: Resource=ResourceLoader.load(TARGET,"",ResourceLoader.CACHE_MODE_IGNORE)
	var failures: Array[String]=[]
	if restored.frames.size()!=101:failures.append("Frame count")
	for index in [0,18,50,100]:
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		for image: Image in restored.frames[index].get_data():hash.update(image.get_data())
		if hash.finish().hex_encode()!=manifest.frames[index].sha256:failures.append("Lossless RG8 round-trip "+str(index))
	if not artifact_dir.is_empty():
		var report := FileAccess.open(artifact_dir.path_join("asset_validation.json"),FileAccess.WRITE)
		report.store_string(JSON.stringify({"frames":restored.frames.size(),"failures":failures,"asset":TARGET,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Asset build only; no game export."},"\t"))
	print("EXPLOSION_VOLUME_ASSET frames=",restored.frames.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
