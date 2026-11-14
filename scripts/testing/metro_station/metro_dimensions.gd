extends RefCounted
const CAR_LENGTH:=18.0
const HALF_CAR:=9.0
const CAR_CENTER:=9.3
const CAR_COUNT:=6
const CAR_SPACING:=18.6
const TRAIN_LENGTH:=111.0
const STATION_LENGTH:=48.0
const STATION_HALF:=24.0
const TUNNEL_TRAVEL:=92.0
const JOURNEY_TIME:=17.0
const DOOR_CENTERS=[-5.8,5.8]

static func carriage_center(index: int) -> float:
	return (float(index)-float(CAR_COUNT-1)*.5)*CAR_SPACING
