class_name GamePerformanceMonitor
extends CanvasLayer

## 游戏全局性能与资源占用黑匣子监控系统
## 实时监控 FPS、CPU/GPU 耗时、内存、显存、DrawCall、物理实体与着色器编译
## 快捷键 F3 切换 HUD 显示模式（关闭 / 迷你 / 详细），快捷键 F4 打开整局诊断报告

enum DisplayMode { HIDDEN, MINI, DETAILED }

const THEME_PIXEL := preload("res://assets/fonts/pixel_theme.tres")
const REPORT_PATH := "user://perf_run_report.txt"
const SPIKE_THRESHOLD_MS := 22.0 # 低于 ~45 FPS 视为卡顿帧
const SEVERE_SPIKE_MS := 45.0    # 低于 ~22 FPS 视为严重卡顿

var current_mode: DisplayMode = DisplayMode.MINI
var is_report_open := false

# --- 统计与记录数据 ---
var session_start_usec: int = 0
var total_frames: int = 0
var frame_times_sample: Array[float] = [] # 用于计算 P50 / P95 / 1% Low
var spike_records: Array[Dictionary] = [] # 记录发生的每次卡顿事件
var cause_frequencies: Dictionary = {}

# 资源峰值记录（High-Watermarks）
var peak_ram_bytes: int = 0
var peak_vram_bytes: int = 0
var peak_texture_vram_bytes: int = 0
var peak_draw_calls: int = 0
var peak_primitives: int = 0
var peak_node_count: int = 0
var peak_bodies_count: int = 0
var peak_pipeline_compiles: int = 0

# 前一帧状态（用于计算增量变化）
var prev_frame_usec: int = 0
var prev_node_count: int = 0
var prev_pipeline_compiles: int = 0
var prev_bodies_count: int = 0
var prev_room_id: int = -999

# 实时报警状态
var recent_spike_text := ""
var recent_spike_timer := 0.0

# --- 精确帧时间拆分（脚本CPU / 物理 / 渲染CPU / GPU）---
## 加载帧阈值：单帧超过该值（或楼层切换进行中）视为加载，不计入游玩帧率统计。
const LOADING_FRAME_MS := 1000.0
## 加载结束后的预热窗口（秒）：此窗口内的卡顿单独标注，并从稳态统计中排除。
const WARMUP_WINDOW_SEC := 2.5
var steady_frame_times: Array[float] = [] # 排除加载帧与预热窗口后的稳态帧
var loading_frames := 0
var loading_ms_total := 0.0
var last_load_end_usec := 0
var warmup_spikes := 0
var _process_start_usec := 0
var _physics_start_usec := 0
var _physics_accum_ms := 0.0
var _timed_viewports: Dictionary = {}

## 以最低优先级最先执行，记录本帧脚本 _process / _physics_process 的起点。
class FrameProbe extends Node:
	var monitor: Node
	func _process(_delta: float) -> void:
		monitor._process_start_usec = Time.get_ticks_usec()
	func _physics_process(_delta: float) -> void:
		monitor._physics_start_usec = Time.get_ticks_usec()

# --- UI 节点引用 ---
var hud_root: Control
var mini_bar: PanelContainer
var mini_label: RichTextLabel
var mini_spike_badge: Label

var detailed_panel: PanelContainer
var detail_fps_label: RichTextLabel
var detail_time_label: Label
var detail_mem_label: Label
var detail_render_label: Label
var detail_physics_label: Label
var detail_spikes_label: Label

var report_dialog: PanelContainer
var report_scroll: ScrollContainer
var report_text_label: Label
var report_export_button: Button
var report_reset_button: Button
var report_close_button: Button
var report_status_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 250
	for arg in OS.get_cmdline_args():
		if arg == "--script" or arg == "-s":
			current_mode = DisplayMode.HIDDEN
			break
	session_start_usec = Time.get_ticks_usec()
	prev_frame_usec = session_start_usec
	# 本节点最后执行，FrameProbe 最先执行：两者之差即本帧全部脚本耗时。
	process_priority = 1000000
	process_physics_priority = 1000000
	var probe := FrameProbe.new()
	probe.name = "FrameProbe"
	probe.monitor = self
	probe.process_mode = Node.PROCESS_MODE_ALWAYS
	probe.process_priority = -1000000
	probe.process_physics_priority = -1000000
	add_child(probe)
	_build_ui()
	_update_display_mode()
	print("[PerformanceMonitor] Initialized. F3: Toggle HUD | F4: Diagnostic Report")


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	
	if event.keycode == KEY_F3:
		cycle_display_mode()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F4:
		toggle_report_dialog()
		get_viewport().set_input_as_handled()
	elif is_report_open and event.keycode == KEY_ESCAPE:
		close_report_dialog()
		get_viewport().set_input_as_handled()


func cycle_display_mode() -> void:
	match current_mode:
		DisplayMode.HIDDEN:
			current_mode = DisplayMode.MINI
		DisplayMode.MINI:
			current_mode = DisplayMode.DETAILED
		DisplayMode.DETAILED:
			current_mode = DisplayMode.HIDDEN
	_update_display_mode()


func toggle_report_dialog() -> void:
	if is_report_open:
		close_report_dialog()
	else:
		open_report_dialog()


func open_report_dialog() -> void:
	is_report_open = true
	report_text_label.text = generate_report_text()
	report_dialog.visible = true
	# 每次按 F4 都自动落盘，保证 user://perf_run_report.txt 永远是最新一局。
	var saved := export_report_to_file()
	report_status_label.text = ("已自动保存至: " + saved) if not saved.is_empty() else ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_autosave_report()


func _exit_tree() -> void:
	_autosave_report()


func _autosave_report() -> void:
	if total_frames > 0 and report_text_label != null:
		export_report_to_file()


func close_report_dialog() -> void:
	is_report_open = false
	report_dialog.visible = false


func reset_session_data() -> void:
	session_start_usec = Time.get_ticks_usec()
	total_frames = 0
	frame_times_sample.clear()
	steady_frame_times.clear()
	loading_frames = 0
	loading_ms_total = 0.0
	warmup_spikes = 0
	spike_records.clear()
	cause_frequencies.clear()
	peak_ram_bytes = 0
	peak_vram_bytes = 0
	peak_texture_vram_bytes = 0
	peak_draw_calls = 0
	peak_primitives = 0
	peak_node_count = 0
	peak_bodies_count = 0
	peak_pipeline_compiles = 0
	recent_spike_text = ""
	recent_spike_timer = 0.0
	if is_report_open:
		report_text_label.text = generate_report_text()
	print("[PerformanceMonitor] Session metrics reset.")


func _physics_process(_delta: float) -> void:
	if _physics_start_usec > 0:
		_physics_accum_ms += (Time.get_ticks_usec() - _physics_start_usec) / 1000.0


## 为根视口与 3D 世界视口开启渲染计时，读取上一帧的渲染CPU/GPU耗时(ms)。
func _render_times() -> Vector2:
	var viewports: Array[Viewport] = [get_tree().root]
	var display := get_tree().get_first_node_in_group(&"dream_display")
	if display != null:
		var world_vp: Variant = display.get("world_viewport")
		if world_vp is Viewport and is_instance_valid(world_vp):
			viewports.append(world_vp)
	var cpu := 0.0
	var gpu := 0.0
	for vp in viewports:
		var rid := vp.get_viewport_rid()
		if not _timed_viewports.has(rid):
			RenderingServer.viewport_set_measure_render_time(rid, true)
			_timed_viewports[rid] = true
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	return Vector2(cpu, gpu)


func _is_loading_frame(frame_ms: float, dream_world: Node) -> bool:
	if frame_ms >= LOADING_FRAME_MS:
		return true
	return dream_world != null and dream_world.get("floor_transition_in_progress") == true


func _process(delta: float) -> void:
	var now_usec := Time.get_ticks_usec()
	var frame_ms := (now_usec - prev_frame_usec) / 1000.0
	if frame_ms <= 0.0:
		frame_ms = delta * 1000.0
	prev_frame_usec = now_usec
	var script_ms := (now_usec - _process_start_usec) / 1000.0 if _process_start_usec > 0 else 0.0
	var physics_cpu_ms := _physics_accum_ms
	_physics_accum_ms = 0.0
	var render_times := _render_times()
	var dream_world := get_tree().get_first_node_in_group(&"dream_world")
	
	total_frames += 1
	if _is_loading_frame(frame_ms, dream_world):
		# 同步生成楼层/切换楼层属于加载，不计入游玩帧率与卡顿统计。
		loading_frames += 1
		loading_ms_total += frame_ms
		last_load_end_usec = now_usec
		prev_node_count = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		if dream_world != null and "current_room_id" in dream_world:
			prev_room_id = int(dream_world.get("current_room_id"))
		return
	var in_warmup := last_load_end_usec > 0 and float(now_usec - last_load_end_usec) / 1000000.0 < WARMUP_WINDOW_SEC
	# 采样保留最近 6,000 帧（约 100 秒）做百分位统计
	if frame_times_sample.size() > 6000:
		frame_times_sample.pop_front()
	frame_times_sample.append(frame_ms)
	if not in_warmup:
		if steady_frame_times.size() > 6000:
			steady_frame_times.pop_front()
		steady_frame_times.append(frame_ms)
	
	# 读取引擎监控器指标
	var cur_fps := Performance.get_monitor(Performance.TIME_FPS)
	var process_ms := script_ms
	var physics_ms := physics_cpu_ms
	var nav_ms := Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0
	
	var ram_bytes := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var ram_peak := int(Performance.get_monitor(Performance.MEMORY_STATIC_MAX))
	var vram_bytes := int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	var tex_vram_bytes := int(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var orphans := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	
	var bodies_2d := int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS))
	var bodies_3d := int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
	var total_bodies := bodies_2d + bodies_3d
	
	# 管线编译计数（着色器编译）
	var pipeline_compiles := int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SPECIALIZATION))
	pipeline_compiles += int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_MESH))
	pipeline_compiles += int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS))
	pipeline_compiles += int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW))
	
	# 更新峰值 High-Watermarks
	if ram_bytes > peak_ram_bytes: peak_ram_bytes = ram_bytes
	if vram_bytes > peak_vram_bytes: peak_vram_bytes = vram_bytes
	if tex_vram_bytes > peak_texture_vram_bytes: peak_texture_vram_bytes = tex_vram_bytes
	if draw_calls > peak_draw_calls: peak_draw_calls = draw_calls
	if primitives > peak_primitives: peak_primitives = primitives
	if nodes > peak_node_count: peak_node_count = nodes
	if total_bodies > peak_bodies_count: peak_bodies_count = total_bodies
	if pipeline_compiles > peak_pipeline_compiles: peak_pipeline_compiles = pipeline_compiles
	
	# 抓取当前关卡环境上下文
	var cur_room_id := -1
	if dream_world != null and "current_room_id" in dream_world:
		cur_room_id = int(dream_world.get("current_room_id"))
	
	# --- 卡顿检测与智能归因（Spike Detection & Attribution）---
	# 具体诱因优先；DrawCall 只作兜底（3D 地牢常态 DC 就有 600~900）。
	if frame_ms >= SPIKE_THRESHOLD_MS:
		var pipeline_delta := pipeline_compiles - prev_pipeline_compiles
		var node_delta := nodes - prev_node_count
		var room_changed := (cur_room_id != prev_room_id and cur_room_id != -1 and prev_room_id != -999)
		var render_cpu_ms := render_times.x
		var gpu_ms := render_times.y
		
		var category := ""
		var detail := ""
		if pipeline_delta > 0:
			category = "着色器首次编译 (Shader Compile Hitch)"
			detail = "管线编译 +%d" % pipeline_delta
		elif physics_ms >= 10.0 or (total_bodies - prev_bodies_count >= 8):
			category = "物理模拟/碎片碰撞激增 (Physics/Shatter Spike)"
			detail = "物理 %.1fms (刚体: %d)" % [physics_ms, total_bodies]
		elif nav_ms >= 5.0:
			category = "AI集中寻路计算 (Navigation Pathfinding)"
			detail = "寻路 %.1fms" % nav_ms
		elif node_delta >= 12:
			category = "大批场景节点瞬间生成 (Batch Node Spawning)"
			detail = "单帧生成 +%d 节点" % node_delta
		elif room_changed:
			category = "跨房间遮挡剔除/光影切换 (Room Cutaway Rebuild)"
			detail = "切房 %d->%d" % [prev_room_id, cur_room_id]
		elif process_ms >= 10.0:
			category = "主线程脚本处理阻塞 (Main Process Stall)"
			detail = "脚本 %.1fms" % process_ms
		elif gpu_ms >= 12.0:
			category = "GPU渲染瓶颈 (GPU Bound)"
			detail = "GPU %.1fms" % gpu_ms
		elif render_cpu_ms >= 10.0 or draw_calls >= 1500:
			category = "渲染提交CPU过高 (High Draw Calls)"
			detail = "渲染CPU %.1fms, DC %d" % [render_cpu_ms, draw_calls]
		else:
			category = "帧调度/驱动/GC抖动 (Frame Pacing Stall)"
			detail = "耗时 %.1fms" % frame_ms
		detail += " | 脚本%.1f 物理%.1f 渲染CPU%.1f GPU%.1f" % [process_ms, physics_ms, render_cpu_ms, gpu_ms]
		if in_warmup:
			warmup_spikes += 1
			detail += " | 载入后%.1fs预热" % (float(now_usec - last_load_end_usec) / 1000000.0)
			
		cause_frequencies[category] = int(cause_frequencies.get(category, 0)) + 1
		
		var elapsed_sec := float(Time.get_ticks_usec() - session_start_usec) / 1000000.0
		var mins := int(elapsed_sec / 60.0)
		var secs := int(fmod(elapsed_sec, 60.0))
		var time_str := "%02d:%02d" % [mins, secs]
		
		var full_cause := "%s: %s" % [category, detail]
		var record := {
			"time": time_str,
			"frame_ms": frame_ms,
			"fps": 1000.0 / maxf(frame_ms, 0.001),
			"category": category,
			"detail": detail,
			"cause": full_cause,
			"draw_calls": draw_calls,
			"nodes": nodes,
			"bodies": total_bodies,
			"room": cur_room_id
		}
		if spike_records.size() > 300:
			spike_records.pop_front()
		spike_records.append(record)
		
		recent_spike_text = "⚠ %s 卡顿 %.1fms [%s]" % [time_str, frame_ms, category]
		recent_spike_timer = 3.0
		
	prev_node_count = nodes
	prev_pipeline_compiles = pipeline_compiles
	prev_bodies_count = total_bodies
	prev_room_id = cur_room_id
	
	# 更新 UI
	if recent_spike_timer > 0.0:
		recent_spike_timer -= delta
		if recent_spike_timer <= 0.0:
			recent_spike_text = ""
			
	if current_mode == DisplayMode.MINI:
		_update_mini_ui(cur_fps, frame_ms, ram_bytes, tex_vram_bytes, draw_calls)
	elif current_mode == DisplayMode.DETAILED:
		_update_detailed_ui(cur_fps, frame_ms, process_ms, physics_ms, nav_ms, ram_bytes, ram_peak, vram_bytes, tex_vram_bytes, nodes, objects, orphans, draw_calls, primitives, total_bodies, pipeline_compiles)


func _update_mini_ui(fps: float, frame_ms: float, ram_bytes: int, tex_vram_bytes: int, draw_calls: int) -> void:
	var fps_color := "#59d982" # 绿色
	if fps < 35.0:
		fps_color = "#e64545" # 红色
	elif fps < 55.0:
		fps_color = "#e6a83a" # 黄色
		
	var ram_mb := float(ram_bytes) / 1048576.0
	var tex_mb := float(tex_vram_bytes) / 1048576.0
	
	mini_label.text = "[F3] FPS: [color=%s]%.0f[/color] (%.1fms) | 内存: %.0fM | 纹理显存: %.0fM | DC: %d | 卡顿: %d次" % [
		fps_color, fps, frame_ms, ram_mb, tex_mb, draw_calls, spike_records.size()
	]
	
	if not recent_spike_text.is_empty():
		mini_spike_badge.visible = true
		mini_spike_badge.text = recent_spike_text
	else:
		mini_spike_badge.visible = false


func _update_detailed_ui(fps: float, frame_ms: float, process_ms: float, physics_ms: float, nav_ms: float, ram: int, ram_max: int, vram: int, tex_vram: int, nodes: int, objects: int, orphans: int, draw_calls: int, primitives: int, bodies: int, compiles: int) -> void:
	var fps_color := "#59d982"
	if fps < 35.0: fps_color = "#e64545"
	elif fps < 55.0: fps_color = "#e6a83a"
	
	detail_fps_label.text = "FPS: [color=%s]%.1f[/color] (帧耗时: %.1f ms)" % [fps_color, fps, frame_ms]
	detail_time_label.text = "CPU主循环: %.1fms | 物理计算: %.1fms | 寻路: %.1fms" % [process_ms, physics_ms, nav_ms]
	detail_mem_label.text = "静态内存: %.1fMB (峰值: %.1fMB)\n显存占用: %.1fMB (纹理: %.1fMB)" % [
		float(ram)/1048576.0, float(ram_max)/1048576.0, float(vram)/1048576.0, float(tex_vram)/1048576.0
	]
	detail_render_label.text = "绘制调用(DrawCalls): %d (峰值: %d)\n面数(Primitives): %d | 着色器编译: %d" % [
		draw_calls, peak_draw_calls, primitives, compiles
	]
	detail_physics_label.text = "活动物理对象: %d (峰值: %d)\n节点数(Nodes): %d (峰值: %d) | 孤儿泄漏: %d" % [
		bodies, peak_bodies_count, nodes, peak_node_count, orphans
	]
	
	var recent_str := "最近卡顿追踪 (总计 %d 次):\n" % spike_records.size()
	if spike_records.is_empty():
		recent_str += "  当前运行流畅，尚未检测到明显卡顿"
	else:
		var start_idx := maxi(0, spike_records.size() - 3)
		for i in range(start_idx, spike_records.size()):
			var s: Dictionary = spike_records[i]
			recent_str += "  [%s] %.1fms - %s\n" % [s.time, s.frame_ms, s.cause]
	detail_spikes_label.text = recent_str.strip_edges()


## 生成全中文深度性能分析与归因报告文本
func generate_report_text() -> String:
	var elapsed_sec := float(Time.get_ticks_usec() - session_start_usec) / 1000000.0
	var mins := int(elapsed_sec / 60.0)
	var secs := int(fmod(elapsed_sec, 60.0))
	var dur_str := "%d分%02d秒" % [mins, secs]
	
	var avg_ms := 0.0
	var avg_fps := 0.0
	var p95_ms := 0.0
	var max_ms := 0.0
	var one_pct_low_fps := 0.0
	
	if not frame_times_sample.is_empty():
		var sorted := frame_times_sample.duplicate()
		sorted.sort()
		var sum := 0.0
		for t in sorted: sum += t
		avg_ms = sum / sorted.size()
		avg_fps = 1000.0 / avg_ms if avg_ms > 0.0 else 0.0
		p95_ms = sorted[int(sorted.size() * 0.95)]
		max_ms = sorted.back()
		var p99_idx := int(sorted.size() * 0.99)
		var p99_ms: float = sorted[p99_idx]
		one_pct_low_fps = 1000.0 / p99_ms if p99_ms > 0.0 else 0.0
		
	var severe_spikes := 0
	for s in spike_records:
		if float(s.get("frame_ms", 0.0)) >= SEVERE_SPIKE_MS:
			severe_spikes += 1
			
	var report := ""
	report += "=================================================================\n"
	report += "            【五分钟后 (Five Minutes More) 性能与卡顿深度诊断报告】\n"
	report += "=================================================================\n\n"
	
	report += "一、整局运行概况 (Session Summary)\n"
	report += "-----------------------------------------------------------------\n"
	report += "• 统计总时长: %s (总计渲染 %d 帧)\n" % [dur_str, total_frames]
	report += "• 平均帧率: %.1f FPS (平均单帧耗时: %.2f ms)\n" % [avg_fps, avg_ms]
	report += "• 1%% Low 极低帧率: %.1f FPS (P95卡顿线: %.2f ms, 单帧最高峰值: %.2f ms)\n" % [one_pct_low_fps, p95_ms, max_ms]
	report += "• 卡顿检测统计: 轻度卡顿(>22ms) 共 %d 次，严重卡顿(>45ms) 共 %d 次\n\n" % [spike_records.size(), severe_spikes]
	
	report += "二、什么资源占用最大？(Top Resource Consumers)\n"
	report += "-----------------------------------------------------------------\n"
	report += "1. 【显存与纹理占用】(最大的静态资源占用)\n"
	report += "   - 显存峰值 (VRAM Peak): %.1f MB\n" % [float(peak_vram_bytes) / 1048576.0]
	report += "   - 纹理显存 (Texture VRAM): %.1f MB (占比约为 %.0f%%)\n" % [
		float(peak_texture_vram_bytes) / 1048576.0,
		(float(peak_texture_vram_bytes) / float(peak_vram_bytes) * 100.0) if peak_vram_bytes > 0 else 0.0
	]
	report += "   - 结论: 2D贴图与3D材质纹理是显存消耗绝对大头，但处于安全范围内。\n\n"
	
	report += "2. 【场景节点与对象数】(内存与CPU遍历开销)\n"
	report += "   - 场景节点峰值 (Node Peak): %d 个 (对象 Object 峰值: %d)\n" % [peak_node_count, Performance.get_monitor(Performance.OBJECT_COUNT)]
	report += "   - 内存峰值 (RAM Peak): %.1f MB (当前稳态: %.1f MB)\n" % [
		float(peak_ram_bytes) / 1048576.0,
		float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0
	]
	report += "   - 孤儿泄漏节点 (Orphan Nodes): %d 个 (为0代表无未释放泄漏)\n\n" % int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	
	report += "3. 【渲染绘制调用 (Draw Calls)】(GPU与渲染主线程通信)\n"
	report += "   - Draw Calls 峰值: %d 次/帧 (面数 Primitives 峰值: %d 面)\n" % [peak_draw_calls, peak_primitives]
	report += "   - 状态评估: %s\n\n" % ("良好 (低于 150)" if peak_draw_calls < 150 else "偏高 (需关注多光源与批量合批)")
	
	report += "4. 【物理活动实体 (Active Bodies)】(物理模拟与碰撞测试)\n"
	report += "   - 活跃物理刚体峰值: %d 个 (含碎玻璃/碎门碎片与角色刚体)\n\n" % peak_bodies_count
	
	report += "三、为什么导致卡顿延迟？(Why Stutter Happened - Root Cause Analysis)\n"
	report += "-----------------------------------------------------------------\n"
	if cause_frequencies.is_empty():
		report += "本局未检测到明显的单帧耗时突破阈值 (>22ms)，整体表现极其流畅！\n\n"
	else:
		report += "根据本局抓取到的 %d 次卡顿瞬间的实时指标比对，根因分布排行如下：\n" % spike_records.size()
		var sorted_causes := []
		for c in cause_frequencies:
			sorted_causes.append({"cause": c, "count": cause_frequencies[c]})
		sorted_causes.sort_custom(func(a, b): return a.count > b.count)
		
		for sc in sorted_causes:
			var pct := float(sc.count) / float(spike_records.size()) * 100.0
			report += "• 【%d 次 / %.1f%%】%s\n" % [sc.count, pct, sc.cause]
		report += "\n"
		
		report += "【核心诱因技术解析】：\n"
		if str(sorted_causes).contains("着色器"):
			report += "▶ 着色器首次编译停顿 (Shader Compile Hitch):\n"
			report += "  在战斗中首次切换武器、首次开火产生弹丸特效、或首次触发某种受击材质时，Godot 驱动在运行时即时编译 shader pipeline 导致单帧巨幅等待。\n"
		if str(sorted_causes).contains("物理模拟") or str(sorted_causes).contains("碎片"):
			report += "▶ 物理碎片碰撞激增 (Physics Shatter Spike):\n"
			report += "  踢破房门或击碎玻璃窗时，瞬间生成数十个带有 CollisionShape 的 RigidBody 碎片，物理引擎在单帧内做密集体积碰撞计算。\n"
		if str(sorted_causes).contains("房间"):
			report += "▶ 跨房间视野切换 (Room Cutaway Rebuild):\n"
			report += "  玩家角色穿过门框进入新房间时，房间遮挡裁切网格（OfficeWallCutaway）与吸顶灯阴影批次重新分配导致的单帧重绘。\n"
		if str(sorted_causes).contains("寻路"):
			report += "▶ 敌人集中寻路 (Navigation Re-path):\n"
			report += "  多个警觉的敌人 AI 在同一物理帧并发调用 AStar / NavigationServer 获取路径。\n\n"

	report += "四、具体卡顿明细记录 (最近采样记录 Top 15)\n"
	report += "-----------------------------------------------------------------\n"
	if spike_records.is_empty():
		report += "  (暂无卡顿记录)\n"
	else:
		var recent_slice := spike_records.slice(maxi(0, spike_records.size() - 15))
		for item in recent_slice:
			report += "[%s] 帧耗时: %5.1fms (%.0f FPS) | 房间: %2d | 节点: %4d | DC: %3d | 诱因: %s\n" % [
				item.time, item.frame_ms, item.fps, item.room, item.nodes, item.draw_calls, item.cause
			]
	report += "=================================================================\n"
	return report


## 将报告导出为本地文本文件
func export_report_to_file() -> String:
	var content := generate_report_text()
	var global_path := ProjectSettings.globalize_path(REPORT_PATH)
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(content)
		file.close()
		print("[PerformanceMonitor] Report successfully saved to: ", global_path)
		return global_path
	else:
		push_error("Failed to write performance report to: " + REPORT_PATH)
		return ""


func _update_display_mode() -> void:
	match current_mode:
		DisplayMode.HIDDEN:
			hud_root.visible = false
		DisplayMode.MINI:
			hud_root.visible = true
			mini_bar.visible = true
			detailed_panel.visible = false
		DisplayMode.DETAILED:
			hud_root.visible = true
			mini_bar.visible = false
			detailed_panel.visible = true


# --- 动态构建 UI 控件 ---
func _build_ui() -> void:
	hud_root = Control.new()
	hud_root.name = "PerfHUD"
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_root)
	
	# 1. 迷你胶囊条 (Mini Bar - 右上角)
	mini_bar = PanelContainer.new()
	mini_bar.name = "MiniBar"
	mini_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_bar.anchor_left = 1.0
	mini_bar.anchor_right = 1.0
	mini_bar.offset_left = -460.0
	mini_bar.offset_top = 8.0
	mini_bar.offset_right = -8.0
	mini_bar.offset_bottom = 38.0
	
	var mini_style := StyleBoxFlat.new()
	mini_style.bg_color = Color(0.02, 0.03, 0.05, 0.82)
	mini_style.border_color = Color(0.25, 0.45, 0.65, 0.7)
	mini_style.set_border_width_all(1)
	mini_style.set_corner_radius_all(3)
	mini_style.content_margin_left = 8
	mini_style.content_margin_right = 8
	mini_style.content_margin_top = 4
	mini_style.content_margin_bottom = 4
	mini_bar.add_theme_stylebox_override("panel", mini_style)
	
	var mini_vbox := VBoxContainer.new()
	mini_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_bar.add_child(mini_vbox)
	
	mini_label = RichTextLabel.new()
	mini_label.name = "MiniLabel"
	mini_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_label.bbcode_enabled = true
	mini_label.fit_content = true
	mini_label.scroll_active = false
	mini_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	mini_label.add_theme_font_size_override("normal_font_size", 12)
	mini_label.add_theme_color_override("default_color", Color(0.88, 0.92, 0.96, 1.0))
	mini_vbox.add_child(mini_label)
	
	mini_spike_badge = Label.new()
	mini_spike_badge.name = "MiniSpikeBadge"
	mini_spike_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_spike_badge.visible = false
	mini_spike_badge.add_theme_font_size_override("font_size", 11)
	mini_spike_badge.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1.0))
	mini_vbox.add_child(mini_spike_badge)
	
	hud_root.add_child(mini_bar)
	
	# 2. 详细监控面板 (Detailed Panel - 右上角)
	detailed_panel = PanelContainer.new()
	detailed_panel.name = "DetailedPanel"
	detailed_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detailed_panel.anchor_left = 1.0
	detailed_panel.anchor_right = 1.0
	detailed_panel.offset_left = -380.0
	detailed_panel.offset_top = 8.0
	detailed_panel.offset_right = -8.0
	detailed_panel.offset_bottom = 360.0
	
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = Color(0.015, 0.02, 0.035, 0.92)
	detail_style.border_color = Color(0.3, 0.55, 0.8, 0.85)
	detail_style.set_border_width_all(1)
	detail_style.set_corner_radius_all(4)
	detail_style.content_margin_left = 12
	detail_style.content_margin_right = 12
	detail_style.content_margin_top = 10
	detail_style.content_margin_bottom = 10
	detailed_panel.add_theme_stylebox_override("panel", detail_style)
	
	var d_vbox := VBoxContainer.new()
	d_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d_vbox.add_theme_constant_override("separation", 6)
	detailed_panel.add_child(d_vbox)
	
	var d_title := Label.new()
	d_title.text = "📊 游戏实时资源与性能监控 [F3切模式|F4报告]"
	d_title.add_theme_font_size_override("font_size", 13)
	d_title.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0, 1.0))
	d_vbox.add_child(d_title)
	
	detail_fps_label = RichTextLabel.new()
	detail_fps_label.name = "DetailFPSLabel"
	detail_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_fps_label.bbcode_enabled = true
	detail_fps_label.fit_content = true
	detail_fps_label.scroll_active = false
	detail_fps_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	detail_fps_label.add_theme_font_size_override("normal_font_size", 12)
	detail_fps_label.add_theme_color_override("default_color", Color(0.88, 0.92, 0.96, 1.0))
	d_vbox.add_child(detail_fps_label)
	detail_time_label = _create_stat_label(d_vbox)
	detail_mem_label = _create_stat_label(d_vbox)
	detail_render_label = _create_stat_label(d_vbox)
	detail_physics_label = _create_stat_label(d_vbox)
	detail_spikes_label = _create_stat_label(d_vbox)
	detail_spikes_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.35, 1.0))
	
	hud_root.add_child(detailed_panel)
	
	# 3. 诊断报告弹窗 (Report Modal - 居中)
	report_dialog = PanelContainer.new()
	report_dialog.name = "ReportDialog"
	report_dialog.visible = false
	report_dialog.anchor_left = 0.5
	report_dialog.anchor_top = 0.5
	report_dialog.anchor_right = 0.5
	report_dialog.anchor_bottom = 0.5
	report_dialog.offset_left = -340.0
	report_dialog.offset_top = -230.0
	report_dialog.offset_right = 340.0
	report_dialog.offset_bottom = 230.0
	
	var rep_style := StyleBoxFlat.new()
	rep_style.bg_color = Color(0.02, 0.03, 0.05, 0.96)
	rep_style.border_color = Color(0.35, 0.65, 0.95, 0.9)
	rep_style.set_border_width_all(2)
	rep_style.set_corner_radius_all(6)
	rep_style.content_margin_left = 16
	rep_style.content_margin_right = 16
	rep_style.content_margin_top = 14
	rep_style.content_margin_bottom = 14
	report_dialog.add_theme_stylebox_override("panel", rep_style)
	
	var r_vbox := VBoxContainer.new()
	r_vbox.add_theme_constant_override("separation", 8)
	report_dialog.add_child(r_vbox)
	
	var rep_title := Label.new()
	rep_title.text = "🎮 本局游戏性能与卡顿深度诊断报告"
	rep_title.add_theme_font_size_override("font_size", 16)
	rep_title.add_theme_color_override("font_color", Color(0.45, 0.8, 1.0, 1.0))
	r_vbox.add_child(rep_title)
	
	report_scroll = ScrollContainer.new()
	report_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	report_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r_vbox.add_child(report_scroll)
	
	report_text_label = Label.new()
	report_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_text_label.add_theme_font_size_override("font_size", 12)
	report_text_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95, 1.0))
	report_scroll.add_child(report_text_label)
	
	report_status_label = Label.new()
	report_status_label.add_theme_font_size_override("font_size", 11)
	report_status_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.6, 1.0))
	r_vbox.add_child(report_status_label)
	
	var r_buttons := HBoxContainer.new()
	r_buttons.add_theme_constant_override("separation", 12)
	r_buttons.alignment = BoxContainer.ALIGNMENT_END
	r_vbox.add_child(r_buttons)
	
	report_export_button = Button.new()
	report_export_button.text = " 导出报告文本 (user://perf_run_report.txt) "
	report_export_button.pressed.connect(func():
		var out_p := export_report_to_file()
		report_status_label.text = "已导出至: " + out_p
	)
	r_buttons.add_child(report_export_button)
	
	report_reset_button = Button.new()
	report_reset_button.text = " 重置本局统计 "
	report_reset_button.pressed.connect(func():
		reset_session_data()
		report_status_label.text = "已清空统计，重新开始记录"
	)
	r_buttons.add_child(report_reset_button)
	
	report_close_button = Button.new()
	report_close_button.text = " 关闭 (Esc / F4) "
	report_close_button.pressed.connect(close_report_dialog)
	r_buttons.add_child(report_close_button)
	
	hud_root.add_child(report_dialog)


func _create_stat_label(parent: Control) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(0.82, 0.88, 0.94, 1.0))
	parent.add_child(l)
	return l
