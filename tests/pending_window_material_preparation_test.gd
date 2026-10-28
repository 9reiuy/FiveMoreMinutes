extends SceneTree
## CPU regression: collect the owner's future materials without running owners.
const WORKER=preload("res://scripts/dream/destruction_render_preparation.gd")
const DRESSING=preload("res://scripts/dream/preview/sample_wall_and_desktop_review.gd")
var checks:=0
var failures:Array=[]
func expect(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func material(code:String)->ShaderMaterial:
	var shader:=Shader.new();shader.code=code
	var result:=ShaderMaterial.new();result.shader=shader;return result
func owner()->Node3D:
	var result:=Node3D.new();root.add_child(result);return result
func dressing(world:Node3D)->Node:
	var node:=DRESSING.new();node.world=world;node.production_mode=true;world.add_child(node);return node
func _initialize()->void:call_deferred("run")
func run()->void:
	var saved_pause:=paused;paused=true
	var first:Node3D=owner();var second:Node3D=owner()
	var own:Node=dressing(first);var foreign:Node=dressing(second)
	var future:=material("shader_type spatial; void fragment(){ALBEDO=vec3(0.2);}")
	var same_code:=material(future.shader.code)
	var other:=material("shader_type spatial; void fragment(){ALBEDO=vec3(0.7);}")
	var empty:=ShaderMaterial.new();var standard:=StandardMaterial3D.new()
	own.windows.assign([{"new_mat":future},{"new_mat":same_code},{"new_mat":null},{"new_mat":empty},{"new_mat":standard}])
	foreign.windows.assign([{"new_mat":other}])
	var sample:Node=dressing(first);sample.production_mode=false;sample.windows.assign([{"new_mat":other}])
	var stale:Node=dressing(first);stale.world=second;stale.windows.assign([{"new_mat":other}])
	var unrelated:=Node.new();first.add_child(unrelated);unrelated.add_to_group(&"office_wall_dressing")
	var before:PackedByteArray=var_to_bytes([own.windows,own._cutaway_dirty,own.is_processing(),future.shader.code])
	var selected:Array[ShaderMaterial]=WORKER._pending_window_materials(self,first)
	expect(selected.size()==1,"only one owned production shader family")
	expect(selected.size()==1 and selected[0]==future,"retain exact owner-held future material, not a copy")
	expect(not other in selected,"foreign/sample/stale-owner materials excluded")
	expect(not same_code in selected,"equal code deduplicated")
	expect(not empty in selected,"missing shader excluded")
	expect(var_to_bytes([own.windows,own._cutaway_dirty,own.is_processing(),future.shader.code])==before,"owner records, dirty flag, scheduling and material remain unchanged")
	expect(paused,"does not change tree pause")
	expect(WORKER._pending_window_materials(self,null).is_empty(),"null owner safe")
	var queued:Node3D=owner();dressing(queued);queued.queue_free()
	expect(WORKER._pending_window_materials(self,queued).is_empty(),"queued world excluded")
	var removed:Node3D=owner();dressing(removed);root.remove_child(removed)
	expect(WORKER._pending_window_materials(self,removed).is_empty(),"detached world excluded")
	removed.free();first.free();second.free();await process_frame;paused=saved_pause
	print("PENDING_WINDOW_LOGIC ",JSON.stringify({"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
