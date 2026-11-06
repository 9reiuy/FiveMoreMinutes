extends SceneTree
## Live pool slots must not be hidden/shown again on every refresh. This changes
## submission work only: emission, expiry, reuse, palette and pooling stay intact.
const SMOKE=preload("res://scripts/dream/muzzle_smoke.gd")
var checks:=0
var failures:=0
var toggles:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run()->void:
	var host:=Node3D.new();root.add_child(host)
	var smoke:=SMOKE.new();host.add_child(smoke)
	smoke.configure();smoke.set_physics_process(false);smoke.rng.seed=8371
	for sprite in smoke.fills+smoke.backs:
		sprite.visibility_changed.connect(func():toggles+=1)
	smoke.burst(Vector3.ZERO,Vector3.RIGHT)
	var first:int=smoke.puffs.size()
	check(first>0 and toggles==first*2,"Only newly allocated fill/outline slots become visible")
	toggles=0
	for tick in 12:smoke._physics_process(1.0/60.0)
	check(toggles==0,"Live smoke never dirties visibility while moving")
	# Nine initial slots plus thirteen three-puff bursts fills the pool exactly.
	# This test deliberately does not change the legacy burst allocator.
	for shot in 13:smoke.burst(Vector3.ZERO,Vector3.RIGHT,2)
	check(smoke.puffs.size()==SMOKE.LIMIT,"Burst saturation keeps the original pool bound")
	var live:Dictionary={}
	for puff in smoke.puffs:live[int(puff.slot)]=true
	check(live.size()==SMOKE.LIMIT,"Every live puff owns a unique slot")
	toggles=0;smoke._refresh()
	check(toggles==0,"Full-pool refresh does not re-toggle 96 sprites")
	for tick in 240:smoke._physics_process(1.0/60.0)
	check(smoke.puffs.is_empty(),"All lifetimes still expire")
	check(toggles==SMOKE.LIMIT*2,"Each retired slot hides exactly once")
	toggles=0;smoke._refresh()
	check(toggles==0,"Idle refresh performs no visibility work")
	smoke.burst(Vector3.ZERO,Vector3.LEFT)
	check(not smoke.puffs.is_empty(),"Expired slots can be reused")
	smoke.set_overlay_visible(false)
	check(smoke.puffs.is_empty() and smoke.fills.all(func(s:Sprite2D)->bool:return not s.visible),"Disabled overlay clears every slot")
	smoke.burst(Vector3.ZERO,Vector3.RIGHT)
	check(smoke.puffs.is_empty(),"Disabled overlay refuses new smoke")
	smoke.set_overlay_visible(true);smoke.burst(Vector3.ZERO,Vector3.RIGHT)
	check(not smoke.puffs.is_empty(),"Re-enabled overlay emits normally")
	smoke.clear()
	check(smoke.backs.all(func(s:Sprite2D)->bool:return not s.visible),"Clear hides all outlines")
	host.free();await process_frame
	check(root.find_child("MuzzleSmokeOverlay",true,false)==null,"No overlay survives floor teardown")
	print("MUZZLE_SMOKE_SUBMISSION checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
