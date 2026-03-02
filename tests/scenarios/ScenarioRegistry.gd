extends RefCounted

const COMBO_PUSH = preload("res://tests/scenarios/rush_combo_push.gd")
const POWERUP_RECOVERY = preload("res://tests/scenarios/rush_powerup_recovery.gd")


func create(scenario_id: String):
	match scenario_id.strip_edges().to_lower():
		"rush_combo_push":
			return COMBO_PUSH.new()
		"rush_powerup_recovery":
			return POWERUP_RECOVERY.new()
		_:
			return null


func list_ids() -> PackedStringArray:
	return PackedStringArray([
		"rush_combo_push",
		"rush_powerup_recovery",
	])


func default_id() -> String:
	return "rush_combo_push"