extends RefCounted
## One renderer for player interjections and enemy combat text; native bitmap strokes.
const FONT=preload("res://scripts/ui/crisp_interaction_font.gd")
const INK:=Color("edf2ff")
const DARK:=Color("121525")
const HALFTONE=preload("res://shaders/player_hurt_word_halftone.gdshader")

static func glyph_pose(t: float,index: int,lifetime: float=.85) -> Dictionary:
	var local:=t-index*.028
	if local<0: return {"visible":false}
	var size:=1.0
	if local<.075: size=lerpf(.45,1.35,local/.075)
	elif local<.16: size=lerpf(1.35,.92,(local-.075)/.085)
	elif local<.25: size=lerpf(.92,1.0,(local-.16)/.09)
	var bounce:=sin(clampf(local/.25,0,1)*TAU)*4.0*maxf(0,1-local/.3)
	var tilt:=(-1.0 if index%2==0 else 1.0)*(.10+maxf(0,1-local/.3)*.22)
	return {"visible":true,"scale":Vector2(roundf(1.65*size*8)/8,roundf(1.65*size*(1.0+.12*sin(local*25)*maxf(0,1-local/.3))*8)/8),"rotation":tilt,"offset":Vector2(0,roundf(-bounce)),"alpha":clampf((lifetime-t)/.22,0,1)}

static func draw(target: Control,text: String,origin: Vector2,t: float,shadow: bool,size: float=1.0,ink: Color=INK,lifetime: float=.85) -> void:
	var font: Font=FONT.get_font()
	var widths: Array[float]=[]
	var width:=0.0
	# Caller scale is capped: even the pop peak never exceeds player-hurt lettering.
	var multiplier:=clampf(size,.1,1.0)
	for glyph in text:
		var advance:=font.get_string_size(glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+2
		widths.append(advance); width+=advance*1.65*multiplier
	var cursor: float=-width*.5
	for i in text.length():
		var pose:=glyph_pose(t,i,lifetime)
		var advance:=widths[i]*1.65*multiplier
		if pose.visible:
			var center: Vector2=(origin+Vector2(cursor+advance*.5,-8*multiplier)+pose.offset*multiplier).round()
			if shadow: center+=Vector2(5,5)*multiplier
			target.draw_set_transform(center,pose.rotation,pose.scale*multiplier)
			var baseline:=Vector2(-widths[i]*.5,5)
			var glyph:=text.substr(i,1)
			var alpha: float=pose.alpha
			if shadow:
				for offset in [Vector2.ZERO,Vector2.RIGHT]:
					target.draw_string(font,baseline+offset,glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("aaa1c2",alpha))
			else:
				# FontFile outlines break this bitmap face under transforms; dilate glyphs.
				for y in range(-1,2):
					for x in range(-1,3):
						target.draw_string(font,baseline+Vector2(x,y),glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(DARK,alpha))
				for offset in [Vector2.ZERO,Vector2.RIGHT]:
					target.draw_string(font,baseline+offset,glyph,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(ink,alpha))
		cursor+=advance
	target.draw_set_transform(Vector2.ZERO)
