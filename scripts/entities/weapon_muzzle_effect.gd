extends Node2D

## Passive presentation sync; only the real effect advances its lifetime.
func copy_depth_visual_state_to(target: Node2D) -> void:
	target.set("effect_kind", effect_kind)
	target.set("lifetime", lifetime)
	target.set("initial_lifetime", initial_lifetime)
	target.set("primary", primary)
	target.set("secondary", secondary)
	target.set("office_3d_style", office_3d_style)
	target.set("nyangeon_style", nyangeon_style)
	target.queue_redraw()

var direction := Vector2.RIGHT
var effect_kind: StringName = &"pistol"
var lifetime := 0.07
var initial_lifetime := 0.07
var primary := Color("ff9d32")
var secondary := Color("ffd07a")
## The same scene is used by the legacy 2D Dream. Its original drawing path
## remains untouched; only the 3D office world opts into this short pixel VFX.
var office_3d_style := false
var nyangeon_style := false
var sample_birth_pending := false
const SAMPLE_SHAPES=preload("res://scripts/dream/nyangeon_vfx_shapes.gd")
const OFFICE_EFFECT_SECONDS := 0.18
const CORE_SECONDS := 0.035
const FLAME_SECONDS := 0.080


func setup(new_direction: Vector2, new_kind: StringName, duration: float, primary_color: Color, secondary_color: Color) -> void:
	direction = new_direction.normalized()
	effect_kind = new_kind
	lifetime = maxf(duration, 0.01)
	initial_lifetime = lifetime
	primary = primary_color
	secondary = secondary_color
	rotation = direction.angle()
	queue_redraw()


func enable_office_3d_style() -> void:
	office_3d_style = true
	# The formal 3D bridge projects 2D pixels smaller than the old flat view.
	# Enlarge only this transient drawing around its unchanged muzzle origin.
	scale = Vector2.ONE * (2.0 if effect_kind == &"pistol" else 1.4)
	lifetime = OFFICE_EFFECT_SECONDS
	initial_lifetime = lifetime
	queue_redraw()


func _process(delta: float) -> void:
	# A newly born burst must submit its bright first frame. Delta can include
	# work before this node existed (notably GPU readback during capture).
	if nyangeon_style and sample_birth_pending:
		sample_birth_pending=false; queue_redraw(); return
	lifetime -= delta
	queue_redraw()
	if lifetime <= 0.0:
		queue_free()


func _draw() -> void:
	if nyangeon_style:
		_draw_nyangeon()
		return
	if office_3d_style:
		_draw_office_3d()
		return
	var alpha := clampf(lifetime / initial_lifetime, 0.0, 1.0)
	var c1 := Color(primary, alpha)
	var c2 := Color(secondary, alpha * 0.8)
	match effect_kind:
		&"shotgun":
			for angle in [-0.28, -0.14, 0.0, 0.14, 0.28]:
				draw_line(Vector2(4, 0), Vector2.RIGHT.rotated(angle) * 22.0, c1, 2.0)
			for point in [Vector2(14, -7), Vector2(19, 3), Vector2(12, 8)]:
				draw_rect(Rect2(point, Vector2(3, 3)), c2)
		_:
			draw_colored_polygon(PackedVector2Array([Vector2(4, 0), Vector2(12, -5), Vector2(20, 0), Vector2(12, 5)]), c1)
			draw_line(Vector2(8, 0), Vector2(24, 0), c2, 2.0)

func enable_nyangeon_style()->void:
	nyangeon_style=true
	sample_birth_pending=true
	lifetime=.24; initial_lifetime=lifetime
	queue_redraw()

func _draw_nyangeon()->void:
	var elapsed:=initial_lifetime-lifetime
	var wide:=1.4 if effect_kind==&"shotgun" else (.65 if effect_kind in [&"rifle",&"assault_rifle"] else 1.0)
	var reach:=25.0 if effect_kind in [&"rifle",&"assault_rifle"] else (22.0 if effect_kind==&"shotgun" else 17.0)
	if elapsed<.075:
		var shrink:=1.0 if elapsed<.035 else .7
		var points:=PackedVector2Array()
		for point in [Vector2(1,-2),Vector2(6,-2),Vector2(6,-5),Vector2(11,-5),Vector2(11,-3),Vector2(reach-3,-3),Vector2(reach-3,-1),Vector2(reach,0),Vector2(reach-3,2),Vector2(14,2),Vector2(14,5),Vector2(8,5),Vector2(8,3),Vector2(1,3)]:
			points.append(Vector2(roundf(point.x*shrink),roundf(point.y*wide*shrink)))
		SAMPLE_SHAPES.polygon(self,points,Color("ed8e36"))
		draw_rect(Rect2(1,-2,10*shrink,4),Color("ffe7a2"))
		if elapsed<.035:
			draw_rect(Rect2(1,-1,reach*.65,2),Color("fffbe5"))
			for point in [Vector2(12,-7*wide),Vector2(20,5*wide)]: draw_rect(Rect2(point.round(),Vector2(2,2)),Color("fff2ce"))
	if elapsed>.04:
		var t:=clampf((elapsed-.04)/.2,0,1)
		var colour:=Color("a6a9a3"); colour.a=1-t
		SAMPLE_SHAPES.puff(self,Vector2(8+8*t,-3-4*t),3.5*(1-t*.5),colour)
		colour.a*=.75
		SAMPLE_SHAPES.puff(self,Vector2(15+10*t,3*wide-4*t),2.5*(1-t*.5),colour)


func _draw_office_3d() -> void:
	var elapsed := initial_lifetime - lifetime
	var is_shotgun := effect_kind == &"shotgun"
	var is_rifle := effect_kind == &"assault_rifle" or effect_kind == &"rifle"
	var width := 6.0 if is_shotgun else (2.0 if is_rifle else 3.0)
	# Five hand-picked flat shades, with a few integer-sized pixel blocks rather
	# than noisy procedural texture or a screen-filling additive billboard.
	var hot := Color(1.0, 0.98, 0.87)
	var ivory := Color(1.0, 0.86, 0.55)
	var yellow := Color(1.0, 0.67, 0.26)
	var orange := Color(0.94, 0.38, 0.11)
	var smoke := Color(0.44, 0.47, 0.48, 0.0)
	if elapsed < FLAME_SECONDS:
		var flame_fade := clampf((FLAME_SECONDS - elapsed) / (FLAME_SECONDS - CORE_SECONDS), 0.0, 1.0) if elapsed > CORE_SECONDS else 1.0
		orange.a = flame_fade
		yellow.a = flame_fade
		ivory.a = flame_fade
		var reach := 21.0 if is_shotgun else (25.0 if is_rifle else 19.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(1, -width), Vector2(8, -width), Vector2(11, -width * 1.5),
			Vector2(reach, 0), Vector2(11, width * 1.5), Vector2(8, width), Vector2(1, width)
		]), orange)
		draw_colored_polygon(PackedVector2Array([
			Vector2(1, -width * 0.7), Vector2(8, -width * 0.7),
			Vector2(reach - 5.0, 0), Vector2(8, width * 0.7), Vector2(1, width * 0.7)
		]), yellow)
		draw_rect(Rect2(Vector2(2, -2), Vector2(9, 4)), ivory)
	if elapsed < CORE_SECONDS:
		var core_fade := clampf((CORE_SECONDS - elapsed) / CORE_SECONDS, 0.0, 1.0)
		hot.a = core_fade
		draw_rect(Rect2(Vector2(0, -2), Vector2(10, 4)), hot)
		draw_rect(Rect2(Vector2(7, -1), Vector2(9, 2)), hot)
	# These are fixed per-shot pixel sparks. They never create nodes or lights.
	# Shotgun opens a wider fan; rifle keeps the streaks narrow.
	var spark_fade := clampf((OFFICE_EFFECT_SECONDS - elapsed) / (OFFICE_EFFECT_SECONDS - FLAME_SECONDS), 0.0, 1.0)
	if elapsed < OFFICE_EFFECT_SECONDS:
		ivory.a = 0.75 * spark_fade
		yellow.a = 0.70 * spark_fade
		var spread := 1.8 if is_shotgun else (0.55 if is_rifle else 1.0)
		for point in [Vector2(14, -5), Vector2(23, 4), Vector2(29, -8), Vector2(18, 9)]:
			var spark_point := Vector2(point.x + elapsed * 22.0, roundf(point.y * spread))
			draw_rect(Rect2(spark_point, Vector2(2, 2)), ivory if point.x < 20.0 else yellow)
	if elapsed >= 0.055 and elapsed < OFFICE_EFFECT_SECONDS:
		var smoke_fade := clampf((OFFICE_EFFECT_SECONDS - elapsed) / (OFFICE_EFFECT_SECONDS - 0.055), 0.0, 1.0)
		smoke.a = 0.26 * smoke_fade
		draw_rect(Rect2(Vector2(12, -9 - roundf(elapsed * 12.0)), Vector2(4, 3)), smoke)
		draw_rect(Rect2(Vector2(21, -12 - roundf(elapsed * 9.0)), Vector2(3, 2)), smoke)
