extends RefCounted
## Shared television UI colour. TV_04 is the accepted middle-right reference.
const REFERENCE_BLUE := Color("597fd7")

static func vivid(authored: Color) -> Color:
	return Color.from_hsv(authored.h, clampf(authored.s * 1.2 + 0.12, 0.80, 0.94), maxf(authored.v, 0.94))

static func primary() -> Color:
	return vivid(REFERENCE_BLUE)

static func hover() -> Color:
	return Color.WHITE
