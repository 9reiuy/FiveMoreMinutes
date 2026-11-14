extends SceneTree
## Read-only dependency audit for the standalone chapter export.

var pending: Array[String] = ["res://scenes/standalone/PrologueDemo.tscn"]
var seen: Dictionary = {}
var missing: Array[String] = []
var unresolved_literals: Array[String] = []
var classes: Array[Dictionary]
var literals := RegEx.new()


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	classes = ProjectSettings.get_global_class_list()
	literals.compile("[\"'](res://[^\"'\\r\\n]*)[\"']")
	for property in ProjectSettings.get_property_list():
		var key := String(property.name)
		if key.begins_with("autoload/"):
			add_path(String(ProjectSettings.get_setting(key)).trim_prefix("*"), true)
	add_path(String(ProjectSettings.get_setting("gui/theme/custom", "")), true)
	while not pending.is_empty():
		var path := pending.pop_back() as String
		if seen.has(path):
			continue
		seen[path] = true
		var extension := path.get_extension().to_lower()
		if extension in ["gd", "tscn", "tres", "gdshader", "gdshaderinc", "json"]:
			var code := FileAccess.get_file_as_string(path)
			for match in literals.search_all(code):
				add_path(match.get_string(1))
			if extension == "gd":
				for entry in classes:
					if code.contains(String(entry.class)):
						add_path(entry.path)
		if extension in ["gd", "tscn", "tres", "scn", "res", "gdshader"]:
			for dependency in ResourceLoader.get_dependencies(path):
				for piece in dependency.split("::"):
					if piece.begins_with("res://"):
						add_path(piece, true)
	var files := PackedStringArray(seen.keys())
	files.sort()
	var bytes := 0
	for file in files:
		var handle := FileAccess.open(file, FileAccess.READ)
		if handle != null:
			bytes += handle.get_length()
	var report := "res://.runtime/prologue_export_20261111/resources.json"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--manifest="):
			report = argument.trim_prefix("--manifest=")
	DirAccess.make_dir_recursive_absolute(report.get_base_dir())
	FileAccess.open(report, FileAccess.WRITE).store_string(JSON.stringify({"files": files, "bytes": bytes, "missing": missing, "unresolved_literals": unresolved_literals}, "\t"))
	var notices := Engine.get_license_text() + "\n\nThird-party copyrights\n\n" + JSON.stringify(Engine.get_copyright_info(), "\t")
	var licenses := Engine.get_license_info()
	for name: String in licenses:
		notices += "\n\n" + name + "\n\n" + String(licenses[name])
	FileAccess.open(report.get_base_dir().path_join("Godot-LICENSES.txt"), FileAccess.WRITE).store_string(notices)
	print("PROLOGUE_RESOURCES files=", files.size(), " bytes=", bytes, " missing=", missing)
	quit(0 if missing.is_empty() else 1)


func add_path(path: String, required := false) -> void:
	if not path.begins_with("res://") or path.begins_with("res://.runtime/") or path.begins_with("res://tests/"):
		return
	if seen.has(path) or pending.has(path):
		return
	if FileAccess.file_exists(path):
		pending.append(path)
	elif DirAccess.dir_exists_absolute(path):
		add_directory(path)
	elif "%" in path:
		var prefix := path.get_slice("%", 0).get_base_dir()
		if DirAccess.dir_exists_absolute(prefix):
			add_directory(prefix)
	elif path.get_extension() in ["gd", "tscn", "tres", "scn", "res", "gdshader", "gdshaderinc", "json", "png", "wav", "ogg", "mp3", "ttf", "otf", "glb"]:
		if required:
			if not missing.has(path): missing.append(path)
		elif not unresolved_literals.has(path):
			unresolved_literals.append(path)


func add_directory(path: String) -> void:
	for file in DirAccess.get_files_at(path):
		if file.get_extension() in ["gd", "tscn", "tres", "scn", "res", "gdshader", "gdshaderinc", "json", "png", "wav", "ogg", "mp3", "ttf", "otf", "glb"]:
			add_path(path.path_join(file))
	for directory in DirAccess.get_directories_at(path):
		if not directory.begins_with("."):
			add_directory(path.path_join(directory))
