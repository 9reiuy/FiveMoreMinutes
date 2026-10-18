extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var scene:=preload("res://scenes/entities/employee_enemy.tscn")
	for index in 12:
		var enemy: EmployeeEnemy=scene.instantiate()
		var actual:=enemy.get_instance_id()
		check(enemy._steering_identity()==actual,"Ordinary identity unchanged")
		enemy._schedule_perception_update()
		check(is_equal_approx(enemy.perception_update_left,enemy._perception_update_interval()*float(actual%17)/17.0),"Ordinary perception phase unchanged")
		var fixture_id:=actual+1
		enemy.set_meta(&"test_steering_identity",fixture_id)
		check(enemy._steering_identity()==fixture_id,"Explicit fixture identity replayed")
		check(enemy._steering_identity()%2==fixture_id%2,"Fixture side parity replayed")
		enemy._schedule_perception_update()
		check(is_equal_approx(enemy.perception_update_left,enemy._perception_update_interval()*float(fixture_id%17)/17.0),"Fixture phase replayed")
		enemy.remove_meta(&"test_steering_identity")
		check(enemy._steering_identity()==actual,"Removing diagnostic metadata restores ordinary rule")
		enemy.free()
	print("ENEMY_STEERING_IDENTITY checks=",checks," failures=",failures)
	quit(1 if failures else 0)
