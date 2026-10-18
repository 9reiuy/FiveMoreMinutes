extends Node2D

## Passive presentation sync; only the real effect advances its lifetime.
func copy_depth_visual_state_to(target: Node2D) -> void:
	target.set("direction", direction)
	target.set("is_kill", is_kill)
	target.set("lifetime", lifetime)
	target.set("elapsed", elapsed)
	target.set("phase_offsets", phase_offsets)
	target.set("primary_color", primary_color)
	target.set("secondary_color", secondary_color)
	target.set("warning_color", warning_color)
	target.set("nyangeon_style", nyangeon_style)
	target.queue_redraw()

var direction := Vector2.RIGHT
var is_kill := false
var lifetime := 0.18
var elapsed := 0.0
var phase_offsets := PackedFloat32Array()
var primary_color := Color("ff9d32")
var secondary_color := Color("ffd07a")
var warning_color := Color("d86b24")
var nyangeon_style:=false
var sample_birth_pending:=false
const SAMPLE_SHAPES=preload("res://scripts/dream/nyangeon_vfx_shapes.gd")


func setup(new_direction: Vector2, kill_effect: bool, requested_lifetime: float, new_primary: Color = Color("ff9d32"), new_secondary: Color = Color("ffd07a"), new_warning: Color = Color("d86b24")) -> void:
	direction = new_direction.normalized() if new_direction.length_squared() > 0.0001 else Vector2.RIGHT
	is_kill = kill_effect
	lifetime = maxf(0.05, requested_lifetime if kill_effect else minf(requested_lifetime, 0.16))
	primary_color = new_primary
	secondary_color = new_secondary
	warning_color = new_warning
	var fragment_count := 10 if is_kill else 6
	phase_offsets.resize(fragment_count)
	for index in fragment_count:
		phase_offsets[index] = fmod(float(index * 97 + get_instance_id()), 360.0) * PI / 180.0
	queue_redraw()


func _process(delta: float) -> void:
	if nyangeon_style and sample_birth_pending:
		sample_birth_pending=false; queue_redraw(); return
	elapsed += delta
	queue_redraw()
	if elapsed >= lifetime:
		queue_free()


func _draw() -> void:
	if nyangeon_style:
		_draw_nyangeon()
		return
	var progress := clampf(elapsed / lifetime, 0.0, 1.0)
	var alpha := 1.0 - progress
	var base_color := Color(primary_color, alpha) if not is_kill else Color(warning_color, alpha)
	for index in phase_offsets.size():
		var spread := Vector2.RIGHT.rotated(phase_offsets[index])
		if not is_kill:
			spread = (direction + spread * 0.85).normalized()
		var distance := lerpf(3.0, 28.0 if is_kill else 16.0, progress)
		var fragment_position := spread * distance
		var pixel_size := 3.0 if index % 3 == 0 else 2.0
		draw_rect(Rect2(fragment_position - Vector2.ONE * pixel_size * 0.5, Vector2.ONE * pixel_size), base_color)
	if not is_kill:
		draw_line(-direction * 3.0, direction * lerpf(12.0, 4.0, progress), Color(secondary_color, alpha), 2.0)
	else:
		draw_circle(Vector2.ZERO, lerpf(5.0, 18.0, progress), Color(secondary_color, alpha * 0.7), false, 2.0)

func enable_nyangeon_style()->void:
	nyangeon_style=true
	sample_birth_pending=true
	lifetime=.26 if is_kill else .20
	queue_redraw()

func _draw_nyangeon()->void:
	var t:=clampf(elapsed/lifetime,0,1)
	var size:=1.25 if is_kill else 1.0
	# Local white hit light, separate from the target's existing body flash.
	# Layered nearest-sampled disks make a short halo without another light,
	# viewport or gameplay event. Existing scene depth still occludes it.
	if elapsed<.15:
		var phase:=clampf(elapsed/.15,0,1)
		var fade:=1.0-smoothstep(.25,1.0,phase)
		var radius: float=lerpf(10,17,phase)*size
		draw_circle(Vector2.ZERO,roundf(radius),Color(1,1,1,.28*fade))
		draw_circle(Vector2.ZERO,roundf(radius*.7),Color(1,1,1,.62*fade))
		draw_circle(Vector2.ZERO,maxf(1,roundf(6*size*(1-phase*.75))),Color(1,1,1,.95*fade))
		if phase>.2:
			for angle in [0.0,PI*.5,PI,PI*1.5]:
				var ray:=Vector2.RIGHT.rotated(angle)
				draw_line((ray*(radius-2)).round(),(ray*(radius+2)).round(),Color(1,1,1,.8*fade),1)
	if elapsed<.065:
		var points:=PackedVector2Array()
		for point in [Vector2(-2,-2),Vector2(-2,-8),Vector2(0,-5),Vector2(2,-2),Vector2(8,-2),Vector2(4,0),Vector2(2,2),Vector2(2,8),Vector2(0,4),Vector2(-2,2),Vector2(-8,2),Vector2(-4,0)]: points.append((point*size).round())
		SAMPLE_SHAPES.polygon(self,points,Color("fff6db"))
	var colour:=Color("e1dbc2"); colour.a=1-t
	for i in (8 if is_kill else 5):
		var angle:=direction.angle()+(-1.2+i*.55)
		var ray:=Vector2.RIGHT.rotated(angle)
		var point: Vector2=(ray*(4+(17 if is_kill else 12)*t)).round()
		var end: Vector2=(point+ray*(4*(1-t)+1)).round()
		draw_line(point+Vector2.DOWN,end+Vector2.DOWN,Color(.12,.15,.19,colour.a),3)
		draw_line(point,end,colour,1 if i%2 else 2)
