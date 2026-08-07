class_name GameStateRules
extends RefCounted


## 所有压力变化走同一入口，reason 会保留最近一次变化来源供结算和调试查看。
static func change_stress(state: Dictionary, amount: int, reason: StringName, config: DemoConfig) -> int:
	var before := clampi(int(state.get("stress_value", config.stress_default)), 0, config.stress_max)
	state.stress_value = clampi(before + amount, 0, config.stress_max)
	state.last_stress_change_reason = str(reason)
	state.last_stress_change_amount = int(state.stress_value) - before
	return int(state.stress_value) - before


## 返回实际余额变化；支出不会透支，调用方仍需在购买前检查余额是否足够。
static func change_balance(state: Dictionary, amount: int) -> int:
	var before := maxi(int(state.get("balance", 0)), 0)
	state.balance = maxi(before + amount, 0)
	return int(state.balance) - before


static func calculate_early_wake_stress_gain(dream_end_minutes: float, alarm_minutes: float, is_rest_day: bool, config: DemoConfig) -> int:
	if is_rest_day:
		return 0
	var stress_start_minutes := alarm_minutes - config.early_wake_stress_start_before_alarm_minutes
	var eligible_minutes := stress_start_minutes - dream_end_minutes
	if eligible_minutes <= 0.0:
		return 0
	var blocks := floori(eligible_minutes / maxf(config.early_wake_stress_block_minutes, 1.0))
	return mini(blocks * config.early_wake_stress_gain_per_block, config.early_wake_stress_max_gain)
