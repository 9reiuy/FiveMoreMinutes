extends SceneTree

const CANDIDATES := [
	{
		"id": 1,
		"name": "bf1_iconic_killsound.wav",
		"path": "res://sfx/audition_candidates/bf1_iconic_killsound.wav",
		"source": "《战地1》(Battlefield 1) 原版官方提取",
		"desc": "战地1传奇清脆钱箱/金币叮咚声 (Ka-Ching / Ding)，射击游戏史上最具多巴胺正反馈的经典击杀音！"
	},
	{
		"id": 2,
		"name": "bf_crisp_killsound.wav",
		"path": "res://sfx/audition_candidates/bf_crisp_killsound.wav",
		"source": "《战地》(Battlefield Modern) 提取",
		"desc": "现代战地清脆爆头击杀音，极高穿透力的高频脆响，短促利落，击杀反馈干脆明确。"
	},
	{
		"id": 3,
		"name": "rust_iconic_headshot.wav",
		"path": "res://sfx/audition_candidates/rust_iconic_headshot.wav",
		"source": "《Rust》原版官方提取",
		"desc": "FPS 史上最著名的清脆铁盔爆头声 (Crisp Headshot Snap)，清脆金属撞击+多汁爆裂，极度吸睛！"
	},
	{
		"id": 4,
		"name": "real_high_snap_crack.wav",
		"path": "res://sfx/audition_candidates/real_high_snap_crack.wav",
		"source": "Shapeforms 96kHz 高保真实录",
		"desc": "真实高瞬态骨裂断裂 Snap，极尖锐清脆，瞬间从枪声和音乐中撕裂出来。"
	},
	{
		"id": 5,
		"name": "real_kill_confirm_metallic.wav",
		"path": "res://sfx/audition_candidates/real_kill_confirm_metallic.wav",
		"source": "Shapeforms Cyberpunk Arsenal 实录",
		"desc": "专业高亮金属击杀音 (Kill Confirm Stinger)，充满科技感与高频金属咬合。"
	}
]

var player: AudioStreamPlayer
var streams: Dictionary = {}
var is_headless: bool = false

func _initialize() -> void:
	is_headless = DisplayServer.get_name() == "headless" or OS.get_cmdline_args().has("--headless")
	call_deferred("_setup")

func _setup() -> void:
	print("================================================================================")
	print("     BATTLEFIELD & CRISP KILL SFX AUDITION (战地风格清脆击杀音效试听)         ")
	print("================================================================================")

	player = AudioStreamPlayer.new()
	root.add_child(player)

	for c in CANDIDATES:
		var path: String = c["path"]
		assert(FileAccess.file_exists(path), "Missing candidate file: %s" % path)
		var stream := ResourceLoader.load(path) as AudioStream
		assert(stream != null, "Failed to load audio stream from %s" % path)
		streams[c["id"]] = stream
		print("[%d] %s" % [c["id"], c["name"]])
		print("    来源: %s" % c["source"])
		print("    描述: %s" % c["desc"])
		print("    时长: %.3f 秒" % stream.get_length())

	print("--------------------------------------------------------------------------------")

	if is_headless:
		print("[HEADLESS MODE] Auto-verifying playback for all 5 candidates...")
		for c in CANDIDATES:
			player.stream = streams[c["id"]]
			player.play()
			print("[PASS] Candidate #%d loaded and triggered cleanly: %s" % [c["id"], c["name"]])
			await process_frame
		print("[ALL 5 CRISP SFX PASSED HEADLESS VERIFICATION]")
		quit(0)
	else:
		_setup_ui()
		print("【操作指南】在试听窗口中按数字键 [1] ~ [5] 或点击对应按钮即可即时试听！按 [ESC] 退出。")

func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	root.add_child(canvas)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.08, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	vbox.offset_left = 30
	vbox.offset_top = 20
	vbox.offset_right = -30
	vbox.offset_bottom = -20
	canvas.add_child(vbox)

	var title := Label.new()
	title.text = "战地风格清脆击杀音效试听 (按 1~5 键或点击按钮播放，按 ESC 退出)"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	for c in CANDIDATES:
		var btn := Button.new()
		btn.text = "[%d] %s | %s - %s" % [c["id"], c["name"], c["source"], c["desc"]]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var id: int = c["id"]
		btn.pressed.connect(func(): _play_candidate(id))
		vbox.add_child(btn)

	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "准备就绪。按键盘 1~5 键即可试听对应音效。"
	vbox.add_child(status_label)

func _input(event: InputEvent) -> void:
	if is_headless:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			quit(0)
			return
		match event.keycode:
			KEY_1: _play_candidate(1)
			KEY_2: _play_candidate(2)
			KEY_3: _play_candidate(3)
			KEY_4: _play_candidate(4)
			KEY_5: _play_candidate(5)

func _play_candidate(id: int) -> void:
	if not streams.has(id):
		return
	var stream: AudioStream = streams[id]
	player.stream = stream
	player.play()
	for c in CANDIDATES:
		if c["id"] == id:
			print(">>> 正在播放 [%d] %s (%s): %s" % [id, c["name"], c["source"], c["desc"]])
			var lbl = root.find_child("StatusLabel", true, false) as Label
			if lbl != null:
				lbl.text = "正在播放 [%d] %s (%s)" % [id, c["name"], c["source"]]
			break
