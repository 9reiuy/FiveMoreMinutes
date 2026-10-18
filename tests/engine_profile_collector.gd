extends SceneTree
## Local diagnostic receiver for the exact Godot debugger protocol. Not a
## gameplay component. Run headless before the --remote-debug test process.
var server := TCPServer.new()
var stream: StreamPeerTCP
var packets := PacketPeerStream.new()
var started := 0
var connected := false
var signatures: Dictionary = {}
var function_totals: Dictionary = {}
var server_values: Dictionary = {}
var frame_values := {"frame_ms":[], "process_ms":[], "physics_ms":[], "script_ms":[]}
var frames := 0
var raw: FileAccess
var output_prefix := "engine_profile"
var listen_port := 6017
func _initialize() -> void:
	Engine.max_fps = 60
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--port="): listen_port=int(argument.trim_prefix("--port="))
		if argument.begins_with("--output-prefix="):
			var requested := argument.trim_prefix("--output-prefix=")
			if not requested.is_valid_filename():
				push_error("Profile prefix must be a filename, not a path"); quit(1); return
			output_prefix = requested
	started = Time.get_ticks_msec()
	if listen_port<1024 or listen_port>65535: push_error("Invalid local diagnostic port"); quit(1); return
	var err := server.listen(listen_port, "127.0.0.1")
	if err != OK: push_error("Profile listener: " + error_string(err)); quit(1); return
	raw = FileAccess.open("res://.runtime/"+output_prefix+"_frames.jsonl", FileAccess.WRITE)
	print("ENGINE_PROFILE_LISTENING 127.0.0.1:",listen_port)
func _process(_delta: float) -> bool:
	if not connected:
		if server.is_connection_available():
			stream = server.take_connection()
			packets.stream_peer = stream
			packets.input_buffer_max_size = 32 << 20
			connected = true
			print("ENGINE_PROFILE_CONNECTED")
		elif Time.get_ticks_msec() - started > 120000: finish(false)
		return false
	stream.poll()
	while packets.get_available_packet_count() > 0:
		var value: Variant = packets.get_var(false)
		if not value is Array or value.size() != 3: continue
		var name := String(value[0])
		var data: Array = value[2]
		if name == "servers:function_signature": signatures[int(data[1])] = data[0]
		elif name == "servers:profile_frame": receive_frame(data)
		elif name == "diagnostic:profile_finished": finish(true); return false
	if stream.get_status() != StreamPeerTCP.STATUS_CONNECTED or Time.get_ticks_msec() - started > 120000:
		finish(frames > 0)
	return false
func receive_frame(data: Array) -> void:
	if data.size() < 8: return
	frames += 1
	raw.store_line(JSON.stringify(data))
	frame_values.frame_ms.append(float(data[1]) * 1000)
	frame_values.process_ms.append(float(data[2]) * 1000)
	frame_values.physics_ms.append(float(data[3]) * 1000)
	frame_values.script_ms.append(float(data[5]) * 1000)
	var index := 7
	for _server in int(data[6]):
		var label := String(data[index]); var end := index + 2 + int(data[index + 1]); index += 2
		while index < end:
			var key := label + "/" + String(data[index])
			if not server_values.has(key): server_values[key] = []
			server_values[key].append(float(data[index + 1]) * 1000)
			index += 2
	var end := index + 1 + int(data[index]); index += 1
	while index < end:
		var id := int(data[index])
		if not function_totals.has(id): function_totals[id] = {"id":id,"calls":0,"self_ms":0.0,"total_ms":0.0,"native_ms":0.0}
		var record: Dictionary = function_totals[id]
		record.calls += int(data[index + 1])
		record.self_ms += float(data[index + 2]) * 1000
		record.total_ms += float(data[index + 3]) * 1000
		record.native_ms += float(data[index + 4]) * 1000
		index += 5
func stats(values: Array) -> Dictionary:
	values.sort()
	return {"median":values[values.size()/2],"p95":values[floori(values.size()*.95)]}
func finish(ok: bool) -> void:
	if raw != null: raw.close()
	if frames > 0:
		var top: Array = function_totals.values()
		top.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.self_ms > b.self_ms)
		for record in top:
			record.signature = signatures.get(record.id, "unknown")
			record.self_ms /= frames; record.total_ms /= frames; record.native_ms /= frames
			record.calls_per_frame = float(record.calls) / frames
		for index in mini(35,top.size()): print("ENGINE_PROFILE_FUNCTION ",JSON.stringify(top[index]))
		var summary: Dictionary = {}
		for key in frame_values: summary[key] = stats(frame_values[key])
		for key in server_values: summary[key] = stats(server_values[key])
		print("ENGINE_PROFILE_SUMMARY ",JSON.stringify(summary))
		var output := FileAccess.open("res://.runtime/"+output_prefix+"_summary.json",FileAccess.WRITE)
		output.store_string(JSON.stringify({"frames":frames,"functions":top,"summary":summary,"signatures":signatures},"\t")); output.close()
	server.stop()
	print("ENGINE_PROFILE_RESULT frames=",frames," success=",ok)
	quit(0 if ok else 1)
