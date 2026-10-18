extends SceneTree

const PALETTE_SHADER := preload("res://shaders/palette_quantize.gdshader")

func _init() -> void:
	print("--- TEST PALETTE BLACK / VOID VERIFICATION START ---")
	
	var shader_code := PALETTE_SHADER.code
	assert(shader_code.find("PALETTE_00") != -1, "PALETTE_00 constant must exist in shader")
	assert(shader_code.find("0.0196078, 0.0235294, 0.0392157") != -1, "#05060A vec3 values must exist in shader")
	
	# Read GPL files
	var gpl1 := FileAccess.get_file_as_string("res://art/5min_more_palette.gpl")
	assert(gpl1.find("5   6  10\t#05060A Void / 绝对暗部") != -1, "#05060A missing from 5min_more_palette.gpl")
	
	var gpl2 := FileAccess.get_file_as_string("res://art/5min_more_palette_sorted.gpl")
	assert(gpl2.find("5   6  10\t#05060A Void / 绝对暗部") != -1, "#05060A missing from 5min_more_palette_sorted.gpl")
	
	# Simulate nearest_palette_color in GDScript with exact shader math
	var palette: Array[Vector3] = [
		Vector3(0.0196078, 0.0235294, 0.0392157), # 01 #05060A Void / 绝对暗部
		Vector3(0.0509804, 0.0627451, 0.1254902), # 02 #0D1020 极深蓝黑
		Vector3(0.0784314, 0.0941176, 0.1764706), # 03 #14182D 深阴影
		Vector3(0.1098039, 0.1294118, 0.2509804), # 04 #1C2140 墙体深影
		Vector3(0.1490196, 0.1764706, 0.3411765), # 05 #262D57 主暗部
		Vector3(0.1921569, 0.2274510, 0.4392157), # 06 #313A70 深蓝紫
		Vector3(0.2274510, 0.2666667, 0.4823529), # 07 #3A447B 墙体主色
		Vector3(0.2745098, 0.3215686, 0.5411765), # 08 #46528A 地面主色
		Vector3(0.3254902, 0.3803922, 0.5921569), # 09 #536197 地面亮部
		Vector3(0.3843137, 0.4431373, 0.6470588), # 10 #6271A5 家具中间调
		Vector3(0.4431373, 0.5058824, 0.7019608), # 11 #7181B3 家具 / 角色亮面
		Vector3(0.5176471, 0.5803922, 0.7607843), # 12 #8494C2 边缘高光
		Vector3(0.6117647, 0.6666667, 0.8196078), # 13 #9CAAD1 冷亮部
		Vector3(0.7098039, 0.7568627, 0.8784314), # 14 #B5C1E0 高亮
		Vector3(0.8156863, 0.8509804, 0.9372549), # 15 #D0D9EF 冷白
		Vector3(0.9294118, 0.9490196, 1.0000000), # 16 #EDF2FF UI / 极亮点
	]
	
	var nearest_color := func(source: Vector3) -> Vector3:
		var best := palette[0]
		var delta := source - best
		var best_dist := delta.dot(delta)
		for i in range(1, palette.size()):
			var cand := palette[i]
			var d := source - cand
			var cand_dist := d.dot(d)
			if cand_dist < best_dist:
				best_dist = cand_dist
				best = cand
		return best
	
	# Pure black maps to PALETTE_00 (#05060A Void)
	var res_black: Vector3 = nearest_color.call(Vector3(0.0, 0.0, 0.0))
	assert(res_black == palette[0], "Pure black must map to PALETTE_00 (#05060A)")
	print("[PASS] Vector3(0, 0, 0) -> PALETTE_00 (#05060A)")
	
	# Near black (e.g. #05060A itself)
	var res_void: Vector3 = nearest_color.call(Vector3(0.0196078, 0.0235294, 0.0392157))
	assert(res_void == palette[0], "#05060A must map to PALETTE_00")
	print("[PASS] Vector3(0.0196, 0.0235, 0.0392) -> PALETTE_00")
	
	# Deepest shadow (#14182D)
	var res_shadow: Vector3 = nearest_color.call(Vector3(0.0784314, 0.0941176, 0.1764706))
	assert(res_shadow == palette[2], "Deep shadow must preserve PALETTE_02")
	print("[PASS] Deep shadow Vector3(0.078, 0.094, 0.176) -> PALETTE_02")
	
	# Pure white maps to PALETTE_15 (#EDF2FF)
	var res_white: Vector3 = nearest_color.call(Vector3(1.0, 1.0, 1.0))
	assert(res_white == palette[15], "Pure white must map to PALETTE_15 (#EDF2FF)")
	print("[PASS] Vector3(1, 1, 1) -> PALETTE_15 (#EDF2FF)")
	
	print("--- ALL PALETTE BLACK / VOID TESTS PASSED! ---")
	quit(0)
