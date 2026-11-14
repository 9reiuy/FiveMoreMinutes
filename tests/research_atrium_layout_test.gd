extends SceneTree
const L:=preload("res://scripts/testing/research_atrium/atrium_layout.gd")
var failed: Array[String]=[]
var count:=0
func check(ok: bool,label: String) -> void:
	count+=1
	print("PASS " if ok else "FAIL ",label)
	if not ok:failed.append(label)
func _initialize() -> void:
	var cells: Dictionary=L.cells()
	check(cells.has(L.ENTRY) and cells.has(Vector2i(-7,-7)),"Side entrance and upper-left endpoint exist")
	check(not cells.has(Vector2i.ZERO),"Central mech well is outside the walking floor")
	check(not cells.has(Vector2i(-7,0)) and not cells.has(Vector2i(0,7)),"No left or lower wing remains in the temporary L-shaped layout")
	var queue: Array[Vector2i]=[L.ENTRY]
	var visited: Dictionary={L.ENTRY:true}
	var index:=0
	while index<queue.size():
		var at:=queue[index];index+=1
		for dir: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next:=at+dir
			if cells.has(next) and not visited.has(next):visited[next]=true;queue.append(next)
	check(visited.size()==cells.size(),"Entire descending circuit is connected")
	check(is_equal_approx(L.height_at(Vector2(L.ENTRY)),4.6) and is_equal_approx(L.height_at(L.EXIT),3.8),"Raised route descends only 0.8m without reaching the lower platform")
	var last:=L.TOP
	var descending_samples:=0
	for i in range(L.PATH.size()-1):
		var length: float=L.PATH[i].distance_to(L.PATH[i+1])
		for j in range(ceili(length/.1)+1):
			var point: Vector2=L.PATH[i].lerp(L.PATH[i+1],minf(j*.1/length,1.0))
			var height: float=L.height_at(point)
			if height>last+.00001:failed.append("Uphill sample at "+str(point))
			if height<last-.001:descending_samples+=1
			if last-height>.026:failed.append("Discontinuous ramp at "+str(point))
			last=height
	check(descending_samples>28 and failed.is_empty(),"Two imported shallow ramps have a continuous downward floor profile")
	check(is_equal_approx(L.sample(Vector2(7,7)).height,4.6) and is_equal_approx(L.sample(Vector2(7,-7)).height,4.2),"Entry and L corner preserve the small downward progression")
	print("ATRIUM_LAYOUT checks=",count," failures=",failed)
	quit(0 if failed.is_empty() else 1)
