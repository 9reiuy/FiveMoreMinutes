extends SceneTree
## Outside buildings stay solid; dissolve is restricted to interior overlap.
const CITY=preload("res://scripts/dream/preview/sample_neon_city.gd")
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func at(image:Image,topology:Dictionary,cell:Vector2i)->float:
	var p:=cell-Vector2i(topology.bounds.position)
	return image.get_pixel(p.x,p.y).r
func run()->void:
	var cells:Dictionary={}
	for y in range(15):
		for x in range(15):cells[Vector2i(x,y)]=true
	var topology:=CITY.classify_void(cells,Rect2i(-8,-8,32,32))
	var original:PackedByteArray=topology.image.get_data().duplicate()
	var external:Dictionary=topology.external.duplicate(true)
	var field:=CITY.interior_cut_depth_image(topology)
	check(field.get_format()==Image.FORMAT_RF and field.get_size()==topology.image.get_size(),"Float field matches original world-grid extent")
	var outside_solid:=true
	for cell in topology.external:outside_solid=outside_solid and at(field,topology,cell)==0.0
	check(outside_solid,"Every exterior cell has zero cut depth: no outward dissolved moat")
	check(at(field,topology,Vector2i(0,7))==1.0,"First interior cell starts overlap transition")
	var previous:=0.0
	var monotonic:=true
	for x in range(7):
		var value:=at(field,topology,Vector2i(x,7))
		monotonic=monotonic and value>=previous and is_equal_approx(value,minf(x+1,4))
		previous=value
	check(monotonic,"Cut depth increases inward and saturates at four world cells")
	check(at(field,topology,Vector2i(7,7))==4.0,"Deep playable interior fully rejects foreground city")
	check(topology.image.get_data()==original and topology.external==external,"Field preserves original floor classification")
	var ring:Dictionary={}
	for y in range(-3,4):
		for x in range(-3,4):
			if absi(x)==3 or absi(y)==3:ring[Vector2i(x,y)]=true
	var hole:=CITY.classify_void(ring,Rect2i(-8,-8,17,17))
	var hole_field:=CITY.interior_cut_depth_image(hole)
	check(not hole.external.has(Vector2i.ZERO) and at(hole_field,hole,Vector2i.ZERO)==4.0,"Enclosed holes stay protected")
	check(at(field,topology,Vector2i(-1,-1))==0.0 and at(field,topology,Vector2i(0,0))==1.0,"Convex corners keep exterior solid and cut only inward")
	var shader_source:String=CITY.CITY_SHADER.code
	check(shader_source.contains("!own_facade && texture(city_void, mask_uv).r < 0.5"),"Shader limits feathering to neighbour overlap")
	check(not shader_source.contains("actor_guard"),"No actor hole eats into exterior buildings")
	print("CITY_VISIBILITY_FIELD checks=",checks," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
