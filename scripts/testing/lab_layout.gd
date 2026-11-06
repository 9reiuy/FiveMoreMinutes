extends RefCounted
## Fixed layout compiled by the production adapter. One cell = 32 gameplay px.
static func build() -> Dictionary:
	var data := {"type":"LAB", "checks":{"ok":true}, "bounds":{"x":0,"y":0,"w":28,"h":24}, "rooms":[], "anchors":{}, "doors":[], "furniture":[], "enemies":[], "corridorSegments":[]}
	var specs := [["entry","01 / 出发与移动","reception",Rect2i(0,14,14,10)], ["range","02 / 射击与掩体","open_office",Rect2i(0,0,14,14)], ["effects","03 / 烟雾与破坏","conference_large",Rect2i(14,0,14,14)], ["stress","04 / 密集交战","open_office",Rect2i(14,14,14,10)]]
	for spec in specs:
		var rect: Rect2i = spec[3]
		var cells: Array[String] = []
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x): cells.append("%d,%d" % [x,y])
		data.rooms.append({"id":spec[0],"label":spec[1],"kind":spec[2],"cells":cells,"bounds":{"x":rect.position.x,"y":rect.position.y,"w":rect.size.x,"h":rect.size.y}})
		data.anchors[spec[0]] = "%d,%d" % [rect.get_center().x,rect.get_center().y]
	data.doors = [
		{"a":"entry","b":"range","vertical":false,"line":14,"start":5,"width":3,"glass":false},
		{"a":"range","b":"effects","vertical":true,"line":14,"start":3,"width":3,"glass":false},
		{"a":"range","b":"effects","vertical":true,"line":14,"start":8,"width":4,"glass":true},
		{"a":"entry","b":"stress","vertical":true,"line":14,"start":18,"width":3,"glass":false,"open":true},
		{"a":"effects","b":"stress","vertical":false,"line":14,"start":19,"width":3,"glass":false}]
	for item in [["range","办公桌",3,4,2,1],["range","档案柜",10,4,1,2],["range","沙发",3,8,3,1],["effects","会议桌",20,5,3,2],["effects","盆栽",25,10,1,1],["entry","等候沙发",2,17,3,1]]:
		data.furniture.append(prop(item))
	for y in [16,21]:
		for x in [17,21,25]: data.furniture.append(prop(["stress","工作桌",x,y,2,1]))
	return data

static func prop(item: Array) -> Dictionary:
	return {"room":item[0],"kind":item[1],"x":item[2],"y":item[3],"w":item[4],"h":item[5],"facing":null,"group":"lab"}
