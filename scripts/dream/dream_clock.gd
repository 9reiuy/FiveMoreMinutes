extends Node

signal time_changed(total_minutes: float)
signal alarm_started

@export var config: DemoConfig

var current_minutes := 240.0
var alarm_active := false
var alarm_enabled := true


func _ready() -> void:
	current_minutes = config.dream_start_minutes
	time_changed.emit(current_minutes)


func _process(delta: float) -> void:
	# Engine time scale intentionally affects the dream clock during the wake-up struggle.
	current_minutes += delta / config.real_seconds_per_game_minute
	time_changed.emit(current_minutes)
	if alarm_enabled and not alarm_active and current_minutes >= config.alarm_start_minutes:
		alarm_active = true
		current_minutes = maxf(current_minutes, config.alarm_start_minutes)
		alarm_started.emit()


func get_alarm_elapsed_seconds() -> float:
	if not alarm_active:
		return 0.0
	return (current_minutes - config.alarm_start_minutes) * config.real_seconds_per_game_minute


func get_formatted_time() -> String:
	var total := maxi(0, int(floor(current_minutes)))
	var hours := (total / 60) % 24
	var minutes := total % 60
	return "%02d:%02d" % [hours, minutes]
