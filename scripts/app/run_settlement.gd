class_name RunSettlement
extends RefCounted

const STATE_RULES := preload("res://scripts/app/game_state_rules.gd")


static func attendance_for_minutes(wake_minutes: float) -> String:
	if wake_minutes < 450.0:
		return "正常上班"
	if wake_minutes < 480.0:
		return "轻微迟到"
	if wake_minutes < 540.0:
		return "严重迟到"
	return "旷工"


static func wage_ratio_for_status(status: String, config: DemoConfig) -> float:
	match status:
		"正常上班": return config.wage_ratio_on_time
		"轻微迟到": return config.wage_ratio_slightly_late
		"严重迟到": return config.wage_ratio_severely_late
		_: return config.wage_ratio_absent


## RAM唯一来源：本次真正完成并提交的天数。最终等级、经验和当前累计Day均不参与。
static func calculate_completed_day_ram(completed_days: int, config: DemoConfig) -> int:
	return maxi(completed_days, 0) * maxi(config.ram_per_completed_day, 0)


static func _apply_attendance_stress(meta: Dictionary, status: String, is_sunday: bool, config: DemoConfig) -> int:
	if is_sunday:
		return 0
	var change := 0
	match status:
		"轻微迟到", "严重迟到": change = config.stress_late_gain
		"旷工": change = config.stress_absent_gain
	return STATE_RULES.change_stress(meta, change, &"attendance", config) if change != 0 else 0


static func apply_early_wake_stress(summary: Dictionary, meta: Dictionary, config: DemoConfig) -> int:
	if bool(summary.get("is_sunday", false)):
		return 0
	var gain := STATE_RULES.calculate_early_wake_stress_gain(
		float(summary.get("dream_end_minutes", summary.get("wake_minutes", config.weekday_alarm_minutes))),
		float(summary.get("alarm_minutes", config.weekday_alarm_minutes)),
		bool(summary.get("is_sunday", false)),
		config
	)
	return STATE_RULES.change_stress(meta, gain, &"early_wake", config) if gain > 0 else 0


static func _apply_weapon_unlocks(meta: Dictionary, status: String) -> Array[String]:
	# Deleted weapons are no longer granted by attendance; the remaining unlock
	# flow is unchanged.
	return []


static func _check_high_stress_unemployment(meta: Dictionary, config: DemoConfig) -> bool:
	var day_id := int(meta.get("calendar_day_id", 0))
	if int(meta.get("high_stress_checked_day_id", -1)) == day_id:
		return false
	meta.high_stress_checked_day_id = day_id
	if int(meta.get("stress_value", config.stress_default)) >= config.stress_unemployment_threshold:
		meta.high_stress_consecutive_days = int(meta.get("high_stress_consecutive_days", 0)) + 1
	else:
		meta.high_stress_consecutive_days = 0
	if int(meta.high_stress_consecutive_days) < config.stress_unemployment_required_days or bool(meta.get("is_unemployed", false)):
		return false
	meta.is_unemployed = true
	meta.unemployed = true
	meta.normal_attendance_workday_streak = 0
	return true


static func settle(summary: Dictionary, meta: Dictionary, config: DemoConfig) -> Dictionary:
	if summary.get("settled", false):
		return summary
	var is_sunday := bool(summary.get("is_sunday", false))
	var status := "休息日" if is_sunday else attendance_for_minutes(float(summary.get("wake_minutes", 420.0)))
	var ratio := 0.0 if is_sunday else wage_ratio_for_status(status, config)
	var story_day_id := int(meta.get("calendar_day_id", 0))
	var completed_days_now := 0
	if int(meta.get("last_ram_settled_story_day_id", -1)) != story_day_id:
		completed_days_now = 1
		meta.last_ram_settled_story_day_id = story_day_id
		meta.completed_story_days = int(meta.get("completed_story_days", 0)) + 1
	var run_ram := calculate_completed_day_ram(completed_days_now, config)
	meta.ram = int(meta.get("ram", 0)) + run_ram
	var stress_before := int(meta.get("stress_value", config.stress_default))
	summary.early_wake_stress_change = apply_early_wake_stress(summary, meta, config)
	summary.attendance_stress_change = _apply_attendance_stress(meta, status, is_sunday, config)
	summary.stress_change = int(meta.get("stress_value", config.stress_default)) - stress_before
	summary.stress_value = int(meta.get("stress_value", config.stress_default))
	summary.weapon_unlocks = _apply_weapon_unlocks(meta, status) if not is_sunday else []
	summary.unemployment_triggered = _check_high_stress_unemployment(meta, config)
	var unemployed_now := bool(meta.get("is_unemployed", meta.get("unemployed", false)))
	var wage := 0 if is_sunday or unemployed_now else int(floor(config.daily_base_wage * ratio))
	var actual_wage := STATE_RULES.change_balance(meta, wage)
	var final_status := "失业" if unemployed_now and not is_sunday else status
	summary.attendance_status = final_status
	var streak := int(meta.get("normal_attendance_workday_streak", 0))
	if not is_sunday and not bool(meta.get("is_unemployed", false)):
		streak = streak + 1 if final_status == "正常上班" else 0
	elif bool(meta.get("is_unemployed", false)):
		streak = 0
	meta.normal_attendance_workday_streak = streak
	var ending_unlocked := bool(meta.get("normal_life_ending_unlocked", false))
	var ending_triggered := not is_sunday and not ending_unlocked and streak >= config.normal_life_ending_required_workdays
	if ending_triggered:
		meta.normal_life_ending_unlocked = true
		meta.any_ending_completed = true
	summary.normal_attendance_workday_streak = streak
	summary.normal_life_ending_triggered = ending_triggered
	summary.wage_ratio = 0.0 if unemployed_now or is_sunday else ratio
	summary.wage = actual_wage
	summary.run_ram = run_ram
	summary.completed_days_settled_now = completed_days_now
	summary.total_ram = meta.ram
	summary.total_balance = meta.balance
	summary.settled = true
	return summary


static func format_time(total_minutes: float) -> String:
	var wrapped := posmod(int(floor(total_minutes)), 1440)
	return "%02d:%02d" % [wrapped / 60, wrapped % 60]
