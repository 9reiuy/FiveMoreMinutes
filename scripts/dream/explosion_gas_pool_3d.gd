extends Node3D
## Drop-in presentation backend for elemental_particles_3d.gd.
## Damage, hazards, audio, time scaling and the four shared lights stay outside.
const BURST := preload("res://scripts/dream/explosion_gas_burst_3d.gd")
const LIBRARY_PATH := "res://art/Dream/VFX/CC0/JangaFX/GroundExplosion/ground_explosion_volume.res"
const LIBRARY := preload("res://art/Dream/VFX/CC0/JangaFX/GroundExplosion/ground_explosion_volume.res")
const LIMIT := 8
const DURATION := 2.8
const FLASH_SECONDS := .16
var bursts: Array[Dictionary] = []
var pool: Array[Node3D] = []
var library: Resource=LIBRARY
var rejected := 0
var serial := 0
var clock := 0.0

func _ready() -> void:
	# Headless uses the dummy renderer on this project and validates only the
	# lifetime/clock contracts. Actual textures and imagery use native Vulkan.
	if DisplayServer.get_name()=="headless":return
	assert(library!=null and library.frames.size()==101)
	for index in LIMIT:
		var node := BURST.new()
		node.name="GasBurst_%d" % index
		node.library=library
		add_child(node)
		pool.append(node)

func emit(at: Vector3,strength: float,seed_value: int=0) -> bool:
	if not at.is_finite() or not is_finite(strength):return false
	if bursts.size()>=LIMIT:
		rejected+=1
		return false
	var slot := 0
	while bursts.any(func(burst: Dictionary) -> bool:return int(burst.slot)==slot):slot+=1
	serial+=1
	strength=clampf(strength,.25,3.0)
	var seed_id := seed_value if seed_value!=0 else serial*73856093
	bursts.append({"id":serial,"slot":slot,"at":at,"strength":strength,"age":0.0,"drift":Vector3.ZERO})
	if not pool.is_empty():pool[slot].activate(at,strength,seed_id)
	return true

func advance(delta: float,wind: Vector3) -> void:
	if delta<=0.0 or not is_finite(delta):return
	clock+=delta
	for index in range(bursts.size()-1,-1,-1):
		var burst: Dictionary=bursts[index]
		burst.age+=delta
		if float(burst.age)>=DURATION:
			if not pool.is_empty():pool[int(burst.slot)].retire()
			bursts.remove_at(index)
			continue
		if wind.is_finite():burst.drift+=wind*delta*float(burst.age)*.20
		if not pool.is_empty():
			var node: Node3D=pool[int(burst.slot)]
			node.position=Vector3(burst.at)+Vector3(burst.drift)
			node.set_age(float(burst.age))

func upload() -> void:
	for burst in bursts:
		if not pool.is_empty():pool[int(burst.slot)].sync_transform()

func flash_energy(burst: Dictionary) -> float:
	return 3.0*pow(maxf(0.0,1.0-float(burst.age)/FLASH_SECONDS),2.0)

func clear() -> void:
	for node in pool:node.retire()
	bursts.clear()
	serial=0
	clock=0.0
