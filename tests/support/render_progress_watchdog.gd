extends Node
## Diagnostic only: distinguish a silent timed run from stalled draw callbacks.
var last_draw_usec:=0
var last_report_usec:=0
var draw_count:=0
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	last_draw_usec=Time.get_ticks_usec(); last_report_usec=last_draw_usec
	RenderingServer.frame_post_draw.connect(record_draw)
func record_draw() -> void:
	last_draw_usec=Time.get_ticks_usec(); draw_count+=1
func _process(_delta: float) -> void:
	var now:=Time.get_ticks_usec()
	if now-last_report_usec<5000000: return
	last_report_usec=now
	print("RENDER_PROGRESS ",JSON.stringify({"draws":draw_count,"since_draw_ms":(now-last_draw_usec)/1000.0,"process_frames":Engine.get_process_frames(),"window_mode":DisplayServer.window_get_mode()}))
func _exit_tree() -> void:
	if RenderingServer.frame_post_draw.is_connected(record_draw): RenderingServer.frame_post_draw.disconnect(record_draw)
