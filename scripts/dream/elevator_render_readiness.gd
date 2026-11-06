extends RefCounted
## One loading transaction per floor. A timer or a non-cancelled skip is NOT
## rendering evidence. The receipt is valid only for its world/floor/journey.
const FIREARM = preload("res://scripts/dream/firearm_render_preparation.gd")
const EXIT = preload("res://scripts/dream/floor_exit_render_preparation.gd")

static func matches(world: Variant, report: Dictionary) -> bool:
	return is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion() \
		and int(report.get("world_id",0))==world.get_instance_id() \
		and int(report.get("floor_token",-1))==world.get_current_floor_token() \
		and int(report.get("transition_token",-1))==world.transition_generation_token

static func is_ready(world: Variant, report: Dictionary) -> bool:
	if not matches(world,report) or bool(report.get("cancelled",true)) or not bool(report.get("ready",false)): return false
	if bool(report.get("render_verified",false)): return true
	# Never mistake these explicitly marked non-rendering test paths for GPU QA.
	return DisplayServer.get_name()=="headless" or bool(world.get_meta(&"test_skip_firearm_render_preparation",false)) or bool(world.get_meta(&"test_skip_floor_exit_render_preparation",false))

static func run(tree: SceneTree, world: Node3D) -> Dictionary:
	if not is_instance_valid(world) or not world.is_inside_tree(): return {"cancelled":true,"ready":false}
	var receipt: Dictionary={"world_id":world.get_instance_id(),"floor_token":world.get_current_floor_token(),"transition_token":world.transition_generation_token,"ready":false,"render_verified":false,"cancelled":true}
	var started:=Time.get_ticks_usec()
	world.last_firearm_render_preparation=receipt.duplicate()
	if not tree.paused and world.can_process():
		receipt["reason"]="gameplay_not_frozen"
		return receipt
	var bypass: bool=DisplayServer.get_name()=="headless" or bool(world.get_meta(&"test_skip_firearm_render_preparation",false)) or bool(world.get_meta(&"test_skip_floor_exit_render_preparation",false))
	if bypass:
		receipt["skipped"]="headless" if DisplayServer.get_name()=="headless" else "diagnostic_baseline"
		receipt["ready"]=true; receipt["cancelled"]=false
	else:
		var pools: Dictionary=await EXIT.prepare_pools(tree,world,receipt.floor_token,receipt.transition_token)
		receipt["capture_pools"]=pools
		if not matches(world,receipt) or bool(pools.get("cancelled",true)): return receipt
		if not world.begin_firearm_render_preparation(): return receipt
		var rendering: Dictionary=await FIREARM.run(tree,world)
		receipt.merge(rendering,true)
		var destruction: Dictionary=rendering.get("destruction",{})
		var verified: bool=matches(world,receipt) and not bool(rendering.get("cancelled",true)) \
			and int(rendering.get("world_readback_bytes",0))>0 \
			and not bool(destruction.get("cancelled",true)) \
			and int(destruction.get("private_image_bytes",0))>0 \
			and bool(destruction.get("viewport_released",false))
		receipt["render_verified"]=verified
		receipt["ready"]=verified
		receipt["cancelled"]=not verified
		receipt["tasks"]=["capture_pools","glass_geometry","destruction_materials","room_materials","weapon_effects","arrival_receivers","gpu_readback","temporary_cleanup"]
		receipt["coverage"]="registered_floor_and_combat_variants_not_all_future_driver_variants"
	receipt["total_elapsed_ms"]=(Time.get_ticks_usec()-started)/1000.0
	if matches(world,receipt): world.complete_firearm_render_preparation(receipt)
	return receipt
