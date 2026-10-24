extends Node3D
## Muzzle smoke, approximated from the reference build.
## Two layers of the same 30-frame life that are born together at the barrel:
## a white plume that travels forward down the shot, and a cooling plume that
## recedes and floats up. Both shrink as they die.
## Drawn onto a CanvasLayer above WorldPaletteLayer, so the 16-colour palette does
## not eat the warm ramp and the dark outline keeps its contrast.
## Cost of that choice: the plume always sits on top of the scene and can cover a
## wall it should have sat behind.
## The outline is a layer effect, exactly like the reference's onePixelOutline: a
## dark copy of every puff is drawn one screen pixel larger, all of them below all
## of the fills. Overlapping puffs therefore fuse into one mass with a single outer
## edge, and the edge stays one pixel thick whatever size the puff is drawn at.
const LIMIT := 48
const BODIES := [
	preload("res://assets/art/vfx/muzzle_smoke/body_0.png"),
	preload("res://assets/art/vfx/muzzle_smoke/body_1.png"),
	preload("res://assets/art/vfx/muzzle_smoke/body_2.png"),
	preload("res://assets/art/vfx/muzzle_smoke/body_3.png"),
	preload("res://assets/art/vfx/muzzle_smoke/body_4.png"),
	preload("res://assets/art/vfx/muzzle_smoke/body_5.png"),
]
## The white layer is not a cloud: the reference reads as a few separate hard-edged
## white dots trailing the muzzle, so it gets its own plain circle textures.
const DOTS := [
	preload("res://assets/art/vfx/muzzle_smoke/dot_0.png"),
	preload("res://assets/art/vfx/muzzle_smoke/dot_1.png"),
	preload("res://assets/art/vfx/muzzle_smoke/dot_2.png"),
]

## Cooling phases. These are the final on-screen colours: the plume is drawn on an
## overlay above the palette pass, so nothing quantises it and no marker is needed.
const PHASES := 4
const RAMP_CURVE := 0.55
const EDGE_COLOUR := Color("131333")
## Outline thickness in screen pixels. Held constant by scaling the dark copy by
## OUTLINE_PX * 2 / texture width, so a 5px puff and a 15px puff get the same edge.
const OUTLINE_PX := 1.0
## Every puff of one shot cools on this shared clock, so the whole plume changes
## colour together instead of each puff running its own ramp.
const COLOR_LIFE := 1.20
## World units per texture pixel. 1/28 puts the big puffs at roughly fourteen pixels
## of the 640x360 world viewport, the same order as the accepted footstep dust.
const PIXEL_SIZE := 1.0 / 28.0
## Where along the shot each puff is born, measured from the barrel. Random rather
## than indexed: a ladder indexed by puff number is exactly what made the earlier
## builds read as one straight evenly spaced line.
const REACH_MIN := 0.70
const REACH_MAX := 2.40
## The white dots sit much closer to the barrel than the plume does: the reference
## shows them trailing just past the muzzle while the colour stretches well beyond.
const WHITE_REACH_MIN := 0.35
const WHITE_REACH_MAX := 1.30

var rng := RandomNumberGenerator.new()
## Width of one body texture in pixels, read from the art rather than hardcoded so
## the outline stays one pixel thick if the sprites are ever re-exported bigger.
var texture_w := 0.0
## Drawn on a CanvasLayer above the palette pass: the palette quantises the whole
## world image, so anything inside it loses its warm ramp and its outline contrast.
var overlay: CanvasLayer
var camera: Camera3D
var fills: Array[Sprite2D] = []
var backs: Array[Sprite2D] = []
var puffs: Array[Dictionary] = []
var cursor := 0
var emitted := 0
var enabled := true
## True while any pool sprite may still be visible from the last refresh.
var _pool_drawn := false


## Authored cooling ramp. The plume bypasses the palette, so these are literal
## colours: orange -> bright yellow -> purple -> grey. The red step the reference
## had is replaced by the bright yellow, which takes its place in the sequence
## rather than sitting next to it.
var RAMP := [
	Color("D9762E"),
	Color("F2C548"),
	Color("8E2F26"),
	Color("3A3038"),
]
## Life fractions where each ramp step starts. The cooling step lands earlier than
## it used to: at 55% the puffs had already shrunk too far for the dark red to read,
## which is why the old purple was barely visible before it vanished.
var BOUNDS := [0.0, 0.18, 0.48, 0.75, 1.0001]

## Not static: RAMP is a var so the capture harness can swap in alternative palettes
## and shoot them side by side. Production always uses the defaults above.
func ramp_colour(t: float) -> Color:
	var clamped := clampf(t, 0.0, 1.0)
	for i in RAMP.size():
		if clamped < float(BOUNDS[i + 1]):
			return RAMP[i]
	return RAMP[RAMP.size() - 1]


func configure(owner_world: Node3D = null) -> void:
	rng.randomize()
	texture_w = float(BODIES[0].get_width())
	if owner_world != null:
		camera = owner_world.get("camera_3d") as Camera3D
	_build_overlay()


## Builds the overlay and its fixed sprite pool. Called from configure() (normally while
## the floor loads) and again only if a later tree exit has dropped the overlay.
func _build_overlay() -> void:
	fills.clear()
	backs.clear()
	cursor = 0
	# Sit one layer above WorldPaletteLayer so the quantiser never touches these.
	overlay = CanvasLayer.new()
	overlay.name = "MuzzleSmokeOverlay"
	overlay.layer = 19
	# SelectivePixelPreview._retarget_canvas_layers() scans the world for CanvasLayers
	# and reparents every one of them onto the root Window canvas, skipping only the
	# ones flagged world_post_effect. Without this flag the overlay gets pulled out of
	# the world, so it outlives the world: the last plume then hangs on screen after the
	# run ends and reappears, stale, at the start of the next one.
	overlay.set_meta(&"world_post_effect", true)
	var host: Node = get_parent()
	var palette_layer := host.get_node_or_null("WorldPaletteLayer") if host != null else null
	if palette_layer == null:
		var tree_root := get_tree().root
		palette_layer = tree_root.find_child("WorldPaletteLayer", true, false)
	if palette_layer != null:
		overlay.layer = int(palette_layer.layer) + 1
	# Always ours: this node lives under the floor root, so the overlay dies with the
	# floor and with the world instead of outliving both. It is already inside the
	# world viewport, which is where it has to draw to stay above the palette pass.
	add_child(overlay)
	# Dark copies first, then the fills on top: z_index pins that order for the whole
	# pool, so a fill never covers the edge of a puff that was emitted later.
	for i in LIMIT:
		var back := Sprite2D.new()
		back.texture = BODIES[i % BODIES.size()]
		back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		back.modulate = EDGE_COLOUR
		back.z_index = 0
		back.visible = false
		overlay.add_child(back)
		backs.append(back)
	for i in LIMIT:
		var fill := Sprite2D.new()
		fill.texture = BODIES[i % BODIES.size()]
		fill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fill.z_index = 1
		fill.visible = false
		overlay.add_child(fill)
		fills.append(fill)


func clear() -> void:
	puffs.clear()
	for sprite in fills:
		sprite.visible = false
	for sprite in backs:
		sprite.visible = false


## Belt and braces for the overlay: if anything ever reparents it out of the world
## again, hiding the sprites here still stops a finished plume from surviving the run.
func _exit_tree() -> void:
	# DreamDisplayBootstrap moves the live world into its pixel viewport once. That is
	# the same run, not a teardown: keep the prebuilt overlay alive across the move.
	if has_meta(&"display_reparenting"):
		return
	puffs.clear()
	for sprite in fills:
		if is_instance_valid(sprite):
			sprite.visible = false
	for sprite in backs:
		if is_instance_valid(sprite):
			sprite.visible = false
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null


func burst(world_position: Vector3, spread: Vector3, count: int = 5) -> void:
	if not enabled or not is_visible_in_tree(): return
	if overlay == null or not is_instance_valid(overlay):
		# Dropped by an earlier tree exit (floor stash/rollback): rebuild once.
		_build_overlay()
	var along := spread.normalized() if spread.length() > 0.001 else Vector3.RIGHT
	var side := Vector3(-along.z, 0.0, along.x)
	var wobble_phase := rng.randf() * TAU
	var wobble_step := rng.randf_range(2.2, 3.4)
	var fan := rng.randf_range(0.06, 0.13)
	var life_probe := 1.20
	# Both layers are born along the same stretch of the shot line and then split:
	# the white plume pushes further forward, the cooling plume recedes and floats up.
	# Their birth distance is drawn at random rather than stepped by puff index.
	# Puff i of each layer shares one birth slot, which is what makes the reference
	# read as interleaved: colour and white come out of the same spots and separate.
	# Drawing the two layers independently let their centroids swap by pure chance.
	var reaches: Array[float] = []
	var swings: Array[float] = []
	var rises: Array[float] = []
	for i in count:
		var reach := rng.randf_range(REACH_MIN, REACH_MAX)
		reaches.append(reach)
		swings.append(_swing(reach, wobble_step, wobble_phase))
		rises.append(rng.randf_range(-0.05, 0.20))
	# The white layer: a few separate hard dots trailing the muzzle, not a cloud.
	# The reference shows three or four of them sitting just past the barrel, biggest
	# nearest it — which is what the shrink-over-life curve produces on its own.
	var dots := maxi(1, count - 1)
	for i in dots:
		var slot_w := _free_slot()
		if slot_w < 0: break
		var dir_w := along.rotated(Vector3.UP, rng.randf_range(-fan, fan))
		puffs.append({
			"slot": slot_w,
			"age": life_probe * rng.randf_range(0.0, 0.30),
			"drift": Vector3.ZERO,
			"life": rng.randf_range(1.15, 1.25),
			"size": rng.randf_range(0.30, 0.52),
			"white": true,
			"tex": DOTS[rng.randi_range(0, DOTS.size() - 1)],
			"origin": world_position + dir_w * rng.randf_range(WHITE_REACH_MIN, WHITE_REACH_MAX) + side * rng.randf_range(-0.10, 0.10) + Vector3.UP * rng.randf_range(-0.04, 0.10),
			"velocity": dir_w * rng.randf_range(0.80, 1.40) + side * rng.randf_range(-0.04, 0.04),
			"rise": rng.randf_range(0.10, 0.30),
		})
		emitted += 1
	for i in count:
		var slot := _free_slot()
		if slot < 0: break
		var step_dir := along.rotated(Vector3.UP, rng.randf_range(-fan, fan))
		var swing := swings[i]
		var offset := side * (swing + rng.randf_range(-0.06, 0.06)) + Vector3.UP * rises[i]
		var life := rng.randf_range(1.15, 1.25)
		puffs.append({
			"slot": slot,
			# Age is random too: no puff is "older" just because it is nearer the barrel.
			"age": life * rng.randf_range(0.0, 0.45),
			"drift": Vector3.ZERO,
			"tex": BODIES[slot % BODIES.size()],
			"cage": 0.0,
			"life": life,
			# Sizes are random, not graded by distance: 70% big puffs, 30% small ones.
			"size": (rng.randf_range(0.40, 0.56) if rng.randf() < 0.70 else rng.randf_range(0.18, 0.28)),
			"origin": world_position + step_dir * reaches[i] + offset,
			# The reference puff recedes from where it was born: it drifts back along
			# the barrel while it cools, instead of pushing further down the shot.
			"velocity": -along * rng.randf_range(1.35, 2.15) + side * rng.randf_range(-0.04, 0.04),
			"rise": rng.randf_range(0.8, 1.4),
		})
		emitted += 1
	_refresh()


## Sideways offset for a puff born `reach` units down the shot. Tying the wobble to
## distance instead of puff index keeps the trail reading as one snaking band while
## still never repeating the same shape twice.
func _swing(reach: float, wobble_step: float, wobble_phase: float) -> float:
	var t := (reach - REACH_MIN) / maxf(0.001, REACH_MAX - REACH_MIN)
	return sin(t * wobble_step + wobble_phase) * rng.randf_range(0.05, 0.20) * (0.5 + t)


func _free_slot() -> int:
	for i in LIMIT:
		var slot := (cursor + i) % LIMIT
		if not fills[slot].visible:
			cursor = (slot + 1) % LIMIT
			return slot
	return -1


## Rebuilds the plume from the puff table. Runs on burst and every frame, so a new
## shot is visible on the frame it was fired.
func _refresh() -> void:
	if overlay == null or not is_instance_valid(overlay):
		# The overlay is dropped when this node leaves the tree. Anything that still
		# calls in afterwards should stop quietly rather than touch freed sprites.
		puffs.clear()
		return
	# Idle floors (no live puffs, pool already hidden) skip the 96-sprite sweep.
	if puffs.is_empty() and not _pool_drawn:
		return
	_pool_drawn = not puffs.is_empty()
	if texture_w <= 0.0:
		texture_w = float(BODIES[0].get_width())
	for sprite in fills:
		sprite.visible = false
	for sprite in backs:
		sprite.visible = false
	for puff in puffs:
		var slot := int(puff["slot"])
		var fill := fills[slot]
		var back := backs[slot]
		# Each puff carries its own texture: plume puffs use the merged cloud bodies,
		# white dots use the plain circles. Assigning per frame keeps one shared pool.
		var tex := puff.get("tex", BODIES[slot % BODIES.size()]) as Texture2D
		fill.texture = tex
		back.texture = tex
		var t := clampf(float(puff["age"]) / float(puff["life"]), 0.0, 1.0)
		var age := float(puff["age"])
		# Rises as it drifts: the vertical term accelerates with age.
		var rise := float(puff.get("rise", 0.0))
		# Distance covered is accumulated, not velocity * age: velocity decays every
		# frame, so multiplying the decayed value by age discounts the decay twice and
		# leaves the plume covering barely a third of the distance it should.
		var body: Vector3 = (puff["origin"] as Vector3) + (puff.get("drift", Vector3.ZERO) as Vector3) \
			+ Vector3.UP * (0.22 * age + 0.30 * rise * age * age)
		var white := bool(puff.get("white", false))
		var size := float(puff["size"]) * (1.0 - 0.65 * t)
		var mapped := _to_screen(body, size)
		var scale := float(mapped[1])
		var alpha: float
		if white:
			alpha = 1.0 if t < 0.5 else clampf((1.0 - t) / 0.5, 0.0, 1.0)
			fill.modulate = Color(1.0, 1.0, 1.0, alpha)
		else:
			var colour := ramp_colour(clampf(float(puff.get("cage", puff["age"])) / COLOR_LIFE, 0.0, 1.0))
			alpha = 1.0 if t < 0.8 else clampf((1.0 - t) / 0.2, 0.0, 1.0)
			colour.a = alpha
			fill.modulate = colour
		fill.visible = true
		fill.position = mapped[0]
		fill.scale = Vector2.ONE * scale
		# The dark copy is drawn one screen pixel wider on every side and sits below
		# every fill, so the ring is the union's outer edge, not one ring per puff.
		back.visible = true
		back.position = mapped[0]
		back.scale = Vector2.ONE * (scale + OUTLINE_PX * 2.0 / texture_w)
		back.modulate = Color(EDGE_COLOUR, alpha)


## World point -> overlay pixel position, plus the Sprite2D scale that draws the
## texture at the on-screen size a 3D billboard of the same world size would have.
func _to_screen(world_point: Vector3, size: float) -> Array:
	if camera == null or not is_instance_valid(camera):
		camera = get_viewport().get_camera_3d()
	if camera == null:
		return [Vector2.ZERO, maxf(0.02, PIXEL_SIZE * size * 32.0)]
	var base := camera.unproject_position(world_point)
	var edge := camera.unproject_position(world_point + camera.global_transform.basis.x * 0.5)
	var pixels_per_unit := base.distance_to(edge) * 2.0
	return [base, maxf(0.02, PIXEL_SIZE * size * pixels_per_unit)]


func _physics_process(delta: float) -> void:
	for i in range(puffs.size() - 1, -1, -1):
		var puff: Dictionary = puffs[i]
		puff["age"] = float(puff["age"]) + delta
		puff["cage"] = float(puff.get("cage", 0.0)) + delta
		if float(puff["age"]) >= float(puff["life"]):
			puffs.remove_at(i)
			continue
		puff["drift"] = (puff.get("drift", Vector3.ZERO) as Vector3) + (puff["velocity"] as Vector3) * delta
		puff["velocity"] = (puff["velocity"] as Vector3) * (1.0 - 1.6 * delta)
	_refresh()
