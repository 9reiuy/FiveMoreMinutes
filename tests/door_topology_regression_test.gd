extends SceneTree

## Door topology 回归（批准书 §11-§15）：
## 1. 四向 T-junction 边界单元（H/V 各自 terminate/start 于垂直墙线）。
## 2. 完整 opening 独立审计：1000 显式种子（-- soak=5000 可扩），从当前
##    room_cells/floor_cells/wall_edges 重算，不信 door metadata。
## 3. Validator blind / Boss 单入口 / 连通性 / layout attempts 分布。

const GENERATOR := preload("res://scripts/dream/dream_3d_random_dungeon.gd")
const SEED_COUNT := 1000
const FIRST_SEED := 41001

var failures := 0
var checks := 0


func _init() -> void:
	call_deferred("_run")


func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL ", label)


func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _run() -> void:
	var soak := false
	var seed_count := SEED_COUNT
	for arg in OS.get_cmdline_user_args():
		if arg.contains("=") and arg.split("=", true, 1)[0] == "soak":
			seed_count = int(arg.split("=", true, 1)[1])
			soak = true
	_tjunction_unit_tests()
	await _full_seed_regression(seed_count, soak)
	print("DOOR TOPOLOGY checks=", checks, " failures=", failures)
	quit(1 if failures > 0 else 0)


## 四向 T：水平墙终止/起始/垂直墙终止/起始——每向都构造 3 房间最小布局，
## 断言：跨界坐标的完整 opening 必须非法，junction 必须被 clearance 拒绝。
func _tjunction_unit_tests() -> void:
	# 布局约定：partition P（被测墙线）+ partition Q（垂直，端点触及 P.cut）。
	# P: V cut=5, span [0,10) → 西侧 x∈[0,4]，东侧 x∈[5,9]。
	# Q: H cut=4, span [0,5)  → Q 的切割线只覆盖 x∈[0,4]（终止于 P.cut）。
	# 房间：W1 = x[0,4] y[0,3]；W2 = x[0,4] y[4,9]；E = x[5,9] y[0,9]。
	# 门候选 (P, y=3)：opening y=3（W1|E ✓）与 y=4（W2|E ✗）→ 必须非法。
	var orientations := {
		"H_ends_on_V": {"q_axis": "H", "q_cut": 4, "q_span_start": 0, "q_span_end": 5, "straddle": 4, "far": 7},
		"H_starts_on_V": {"q_axis": "H", "q_cut": 4, "q_span_start": 5, "q_span_end": 10,
			"w1": "x[5,9] y[0,3]", "w2": "x[5,9] y[4,9]", "e": "x[0,4] y[0,9]", "straddle": 4, "far": 7},
		"V_ends_on_H": {"q_axis": "V", "q_cut": 4, "q_span_start": 0, "q_span_end": 5, "straddle": 4, "far": 7, "swap": true},
		"V_starts_on_H": {"q_axis": "V", "q_cut": 4, "q_span_start": 5, "q_span_end": 10,
			"swap": true, "straddle": 4, "far": 7},
	}
	for orientation_name in orientations:
		var cfg: Dictionary = orientations[orientation_name]
		var swapped: bool = cfg.get("swap", false)
		var g: Node = GENERATOR.new()
		g.generate_on_ready = false
		g.room_count = 12
		g.wall_edges = {}
		g.door_edges = {}
		g.door_opening_edges = {}
		g.edge_states = {}
		# A fresh generator already owns an empty typed Array[Dictionary].
		# Do not assign an untyped Array here; Godot rejects that at runtime.
		g.connections.clear()
		g.door_corner_clearance = 3
		g.door_to_door_clearance = 4
		g.minimum_door_boundary_length = 4
		# 房间网格 10×10：三个 region（swap 后南北/东西镜像，语义不变）。
		g.room_cells = {}
		g.floor_cells = {}
		for y in range(10):
			for x in range(10):
				var cell := Vector2i(x, y)
				var room: int
				if not swapped:
					room = 0 if x < 4 else 1  # 西列再按 y 分 W1/W2
					if x < 4 and y >= 4:
						room = 2
					if x >= 5:
						room = 1
					if x < 4 and y < 4:
						room = 0
					if x < 4 and y >= 4:
						room = 2
				else:
					room = 0 if y < 4 else 2
					if y >= 4 and x < 4:
						room = 2
					if x >= 5 or y >= 5:
						room = 1
					if y < 4 and x >= 5:
						room = 1
					if y < 4 and x < 4:
						room = 0
					if y >= 4 and x >= 5:
						room = 1
				g.room_cells[cell] = room
				g.floor_cells[cell] = &"building"
		g.partitions.clear()
		g.partitions.append({"id": 0, "axis": "V" if not swapped else "H", "cut": 5, "span_start": 0, "span_end": 10})
		g.partitions.append({"id": 1, "axis": cfg["q_axis"], "cut": cfg["q_cut"], "span_start": cfg["q_span_start"], "span_end": cfg["q_span_end"]})
		var straddle: int = cfg["straddle"]
		var far: int = cfg["far"]
		# 跨界 opening（cell0=region0 侧 ✓，cell1=另一房间 ✗）必须非法。
		check(not g._is_full_door_opening_valid(g.partitions[0], straddle - 1),
			"%s: straddling full opening rejected" % orientation_name)
		# junction 位于 straddle（= Q.cut），clearance 3 内的候选必须被拒绝。
		check(not g._door_candidate_is_clear(g.partitions[0], straddle - 1,
			{"axis": "V" if not swapped else "H", "x": 5, "y": straddle - 1} if not swapped else
			{"axis": "H", "x": straddle - 1, "y": 5}),
			"%s: candidate at junction rejected (cell0)" % orientation_name)
		check(not g._door_candidate_is_clear(g.partitions[0], straddle,
			{"axis": "V" if not swapped else "H", "x": 5, "y": straddle} if not swapped else
			{"axis": "H", "x": straddle, "y": 5}),
			"%s: candidate at junction rejected (cell1)" % orientation_name)
		# 远离 junction 的同侧连续段：合法（正对照）。
		check(g._is_full_door_opening_valid(g.partitions[0], far - 1),
			"%s: far full opening valid" % orientation_name)
		g.free()


## 独立审计：从当前世界状态重算每扇内门的完整 opening。
## 返回违规计数（与 validator 的重算口径一致但独立实现）。
func _audit_doors(world: Node) -> Dictionary:
	var side_floor := 0
	var region_pair := 0
	var wall_overlap := 0
	var junction := 0
	for key in world.door_edges.keys():
		var edge: Dictionary = world.door_edges[key]
		if String(edge.get("kind", "internal")) == "main":
			continue
		var axis := String(edge["door_direction"])
		var cut := int(edge["x"]) if axis == "V" else int(edge["y"])
		var region_a := int(edge.get("region_a_id", -1))
		var region_b := int(edge.get("region_b_id", -1))
		var expected_a := -1
		var expected_b := -1
		for offset in range(int(edge.get("opening_cells", 2))):
			var coordinate := int(edge.get("opening_start", -1)) + offset
			var opening_edge: Dictionary
			if axis == "V":
				opening_edge = {"axis": "V", "x": cut, "y": coordinate}
			else:
				opening_edge = {"axis": "H", "x": coordinate, "y": cut}
			var opening_key := "%s:%d:%d" % [axis, cut, coordinate]
			if world.wall_edges.has(opening_key):
				wall_overlap += 1
			var sides: Array = world._edge_side_cells(opening_edge)
			if sides.size() < 2 or not world.floor_cells.has(sides[0]) or not world.floor_cells.has(sides[1]):
				side_floor += 1
				continue
			var room_a := int(world.room_cells.get(sides[0], -1))
			var room_b := int(world.room_cells.get(sides[1], -1))
			if offset == 0:
				expected_a = room_a
				expected_b = room_b
			if room_a != expected_a or room_b != expected_b:
				region_pair += 1
			if room_a != region_a or room_b != region_b:
				region_pair += 1
			# T/cross junction：opening 格垂直边框存在 WALL 边。
			var perpendicular_axis := "H" if axis == "V" else "V"
			for side_cell in sides:
				var junction_key := "%s:%d:%d" % [
					perpendicular_axis,
					int(side_cell.x) if perpendicular_axis == "H" else int(side_cell.y),
					int(side_cell.y) if perpendicular_axis == "H" else int(side_cell.x),
				]
				if world.wall_edges.has(junction_key):
					junction += 1
	return {
		"side_floor": side_floor, "region_pair": region_pair,
		"wall_overlap": wall_overlap, "junction": junction,
		"total": side_floor + region_pair + wall_overlap + junction,
	}


func _full_seed_regression(seed_count: int, soak: bool) -> void:
	var attempts: Array[int] = []
	var exhausted := 0
	var bad_seeds: Array[String] = []
	var audit_totals := {"side_floor": 0, "region_pair": 0, "wall_overlap": 0, "junction": 0}
	var validator_blind := 0
	var boss_second_entry := 0
	var unreachable_floor := 0
	var disconnected := 0
	var start_open := 0
	var door_count_sum := 0
	for index in range(seed_count):
		var seed_value := FIRST_SEED + index
		var g: Node = GENERATOR.new()
		g.generate_on_ready = false
		g.room_count = 12
		if not g.generate_layout_only(seed_value):
			exhausted += 1
			g.free()
			continue
		var report: Dictionary = g.get_validation_report()
		attempts.append(int(report.get("layout_attempt", 1)))
		if not bool(report.get("valid", false)):
			# validation report 的 valid 覆盖门拓扑 + 图连通 + 入口封印等全部断言。
			bad_seeds.append("seed %d layout invalid: %s" % [seed_value, report])
			g.free()
			continue
		if int(report.get("boss_entry_count", -1)) != 1:
			boss_second_entry += 1
		if not bool(report.get("start_outer_wall_sealed", false)):
			start_open += 1
		if not bool(report.get("graph_connected", true)):
			disconnected += 1
		var audit: Dictionary = _audit_doors(g)
		for violation_name in ["side_floor", "region_pair", "wall_overlap", "junction"]:
			audit_totals[violation_name] += int(audit[violation_name])
		if int(audit["total"]) > 0:
			# validator blind：独立审计发现违规但官方 validation 报 valid。
			validator_blind += 1
			bad_seeds.append("seed %d audit=%s validator=%s" % [seed_value, audit, report.get("valid")])
		if not bool(report.get("all_floor_reachable", true)):
			unreachable_floor += 1
		door_count_sum += int(report.get("door_count", 0))
		g.free()

	attempts.sort()
	var avg_attempts := 0.0
	var p95_attempts := 0
	for value in attempts:
		avg_attempts += value
	avg_attempts /= float(maxi(attempts.size(), 1))
	if not attempts.is_empty():
		p95_attempts = attempts[mini(attempts.size() - 1, int(attempts.size() * 0.95))]
	print("DOOR REGRESSION seeds=%d soak=%s" % [seed_count, soak])
	print("DOOR REGRESSION invalid_doors=%d bad_seeds=%d validator_blind=%d" % [
		audit_totals["side_floor"] + audit_totals["region_pair"] + audit_totals["wall_overlap"] + audit_totals["junction"],
		bad_seeds.size(), validator_blind])
	print("DOOR REGRESSION violations side_floor=%d region_pair=%d wall_overlap=%d junction=%d" % [
		audit_totals["side_floor"], audit_totals["region_pair"], audit_totals["wall_overlap"], audit_totals["junction"]])
	print("DOOR REGRESSION boss_second_entry=%d disconnected=%d unreachable=%d start_open=%d exhausted=%d" % [
		boss_second_entry, disconnected, unreachable_floor, start_open, exhausted])
	print("DOOR REGRESSION attempts avg=%.2f p95=%d max=%d | avg_door_count=%.2f" % [
		avg_attempts, p95_attempts, attempts[attempts.size() - 1] if not attempts.is_empty() else 0,
		float(door_count_sum) / float(maxi(attempts.size(), 1))])
	check(audit_totals["side_floor"] == 0, "full opening side floor violations = 0")
	check(audit_totals["region_pair"] == 0, "opening region pair violations = 0")
	check(audit_totals["wall_overlap"] == 0, "wall overlap = 0")
	check(audit_totals["junction"] == 0, "junction violations = 0")
	check(validator_blind == 0, "validator blind = 0")
	check(boss_second_entry == 0, "boss single entry preserved")
	check(disconnected == 0, "graph connected everywhere")
	check(start_open == 0, "start exterior sealed everywhere")
	check(exhausted == 0, "no layout attempts exhausted")
	for entry in bad_seeds.slice(0, 10):
		print("DOOR REGRESSION BAD ", entry)
