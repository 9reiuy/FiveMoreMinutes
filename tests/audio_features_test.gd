extends SceneTree

var checks := 0
var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAILED: " + label)
	else:
		print("PASS: " + label)

func run() -> void:
	create_timer(20.0).timeout.connect(func() -> void:
		push_error("TIMEOUT")
		quit(2)
	)

	print("=== Running Audio Features (BGM, Combat Ducking, Death Finish) Tests ===")

	var sfx := preload("res://scripts/audio/sfx_manager.gd")
	var config := preload("res://resources/demo_config.tres")
	var manager: Node = root.get_node_or_null("SFXManager")
	check(manager != null, "SFXManager singleton is active in root")

	# 1. Test Music Baseline & Combat Ducking Configuration
	check(is_equal_approx(config.music_baseline_volume_db, -6.0), "Default music_baseline_volume_db is -6.0 dB")
	check(is_equal_approx(config.combat_duck_db, -7.0), "Default combat_duck_db is -7.0 dB")
	check(is_equal_approx(config.combat_duck_hold_duration, 0.8), "Default combat_duck_hold_duration is 0.8s")
	check(is_equal_approx(config.player_death_tape_stop_seconds, 0.4), "Default player_death_tape_stop_seconds is 0.4s")

	# 2. Test Music Streams
	check(sfx.MUSIC_STREAMS.has(&"safe"), "MUSIC_STREAMS has 'safe'")
	check(sfx.MUSIC_STREAMS.has(&"sweet_vermouth"), "MUSIC_STREAMS has 'sweet_vermouth'")
	check(sfx.MUSIC_STREAMS.has(&"sing_swing_bada_bing"), "MUSIC_STREAMS has 'sing_swing_bada_bing'")
	check(sfx.MUSIC_STREAMS.has(&"groovy_ignition"), "MUSIC_STREAMS has 'groovy_ignition'")
	check(sfx.MUSIC_STREAMS.has(&"battle"), "MUSIC_STREAMS has 'battle'")

	# Check non-null streams
	check(sfx.MUSIC_STREAMS[&"sweet_vermouth"] != null, "Sweet Vermouth stream is loaded")
	check(sfx.MUSIC_STREAMS[&"sing_swing_bada_bing"] != null, "Sing Swing Bada Bing stream is loaded")
	check(sfx.MUSIC_STREAMS[&"groovy_ignition"] != null, "Groovy Ignition stream is loaded")

	# Check looping enabled
	check(sfx.MUSIC_STREAMS[&"sweet_vermouth"].loop == true, "Sweet Vermouth has loop enabled")
	check(sfx.MUSIC_STREAMS[&"sing_swing_bada_bing"].loop == true, "Sing Swing Bada Bing has loop enabled")
	check(sfx.MUSIC_STREAMS[&"groovy_ignition"].loop == true, "Groovy Ignition has loop enabled")

	# 3. Test Start Offsets Table
	check(is_equal_approx(float(sfx.MUSIC_START_OFFSETS.get(&"sweet_vermouth", 0.0)), 41.0), "Sweet Vermouth start offset is 41.0s (0:41)")
	check(is_equal_approx(float(sfx.MUSIC_START_OFFSETS.get(&"safe", 0.0)), 41.0), "Safe music start offset is 41.0s (0:41)")
	check(is_equal_approx(float(sfx.MUSIC_START_OFFSETS.get(&"sing_swing_bada_bing", 0.0)), 12.0), "Sing Swing Bada Bing start offset is 12.0s (0:12)")
	check(is_equal_approx(float(sfx.MUSIC_START_OFFSETS.get(&"groovy_ignition", 0.0)), 15.0), "Groovy Ignition start offset is 15.0s (0:15)")

	# 4. Test SFX Streams
	check(sfx.STREAMS.has(&"canned_laughter"), "STREAMS has 'canned_laughter'")
	check(sfx.STREAMS.has(&"audience_applause"), "STREAMS has 'audience_applause'")
	check(sfx.STREAMS.has(&"golf_clap"), "STREAMS has 'golf_clap'")
	check(sfx.STREAMS.has(&"rimshot"), "STREAMS has 'rimshot'")
	check(sfx.STREAMS.has(&"vinyl_scratch_brake"), "STREAMS has 'vinyl_scratch_brake'")

	var played_events: Array[StringName] = []
	manager.connect("sfx_played", func(event_id: StringName) -> void:
		played_events.append(event_id)
	)

	# 5. Test Play Safe Music
	sfx.play_safe_music()
	check(manager.current_music_id == &"sweet_vermouth", "play_safe_music set current_music_id to sweet_vermouth")
	await create_timer(0.6).timeout
	check(manager.music_player.stream == sfx.MUSIC_STREAMS[&"sweet_vermouth"], "Safe music player loaded Sweet Vermouth stream")
	check(manager.music_player.playing, "Safe music player is playing")
	check(is_equal_approx(manager._music_target_volume_db(), -6.0), "Safe music target volume sits at baseline -6.0 dB")

	# 6. Test Play Battle Music Rotation
	manager.battle_track_index = 0
	sfx.play_battle_music()
	var track1: StringName = manager.current_music_id
	check(track1 == &"sing_swing_bada_bing", "First battle track is Sing Swing Bada Bing")

	sfx.play_battle_music()
	var track2: StringName = manager.current_music_id
	check(track2 == &"groovy_ignition", "Second battle track rotated to Groovy Ignition")

	await create_timer(0.6).timeout
	check(manager.music_player.playing, "Battle music player is playing")

	# 7. Test Combat Sidechain Ducking
	# Play gunshot -> triggers combat duck
	played_events.clear()
	sfx.play_weapon_fire()
	check(played_events.has(&"gunshot"), "Gunshot event played")
	check(manager.music_duck_reasons.has(&"combat_fire"), "Combat duck reason 'combat_fire' is active after gunshot")
	check(is_equal_approx(float(manager.music_duck_reasons[&"combat_fire"]), -7.0), "Combat duck depth is -7.0 dB")
	check(is_equal_approx(manager._music_target_volume_db(), -13.0), "Total music volume during combat duck is -13.0 dB (-6dB baseline - 7dB duck)")

	# 8. Test Multi-kill Reaction & Sidechain Ducking
	played_events.clear()
	sfx.trigger_multi_kill_reaction(&"canned_laughter")
	check(played_events.has(&"canned_laughter"), "trigger_multi_kill_reaction played canned_laughter")
	check(manager.music_duck_reasons.has(&"multi_kill_reaction"), "Sidechain duck reason 'multi_kill_reaction' is active")

	# 9. Test Dramatic Combat Finish (Floor Clear)
	# Test Rimshot
	played_events.clear()
	sfx.finish_combat_music("rimshot")
	check(played_events.has(&"rimshot"), "finish_combat_music('rimshot') played rimshot")
	check(not manager.music_player.playing, "Combat music stopped immediately on rimshot finish")
	check(is_equal_approx(manager.music_player.pitch_scale, 1.0), "Pitch restored to 1.0 after rimshot finish")

	# Test Tape Stop
	sfx.play_battle_music()
	await create_timer(0.6).timeout
	check(manager.music_player.playing, "Battle music restarted before tape stop")
	sfx.finish_combat_music("tape_stop")
	check(manager.music_tween != null and manager.music_tween.is_valid(), "finish_combat_music('tape_stop') started tape stop tween")

	# Test Both
	await create_timer(0.4).timeout
	sfx.play_battle_music()
	await create_timer(0.6).timeout
	played_events.clear()
	sfx.finish_combat_music("both")
	check(manager.music_tween != null and manager.music_tween.is_valid(), "finish_combat_music('both') started tape stop tween")

	# 10. Test Dramatic Player Death Finish
	await create_timer(0.4).timeout
	sfx.play_battle_music()
	await create_timer(0.6).timeout
	check(manager.music_player.playing, "Battle music playing before player death")

	sfx.finish_player_death_music()
	check(manager.music_tween != null and manager.music_tween.is_valid(), "finish_player_death_music() started 0.4s tape stop power-cut tween")
	check(manager.current_music_id == &"", "current_music_id cleared on player death")

	await create_timer(0.5).timeout
	check(not manager.music_player.playing, "Music stopped completely after player death tape stop")
	check(is_equal_approx(manager.music_player.pitch_scale, 1.0), "Pitch restored to 1.0 after death tape stop")

	# 11. Test Run Interface Streak Logic & Death Integration
	var run_interface_script = preload("res://scripts/dream/dream_3d_run_interface.gd")
	var run_if = run_interface_script.new()
	root.add_child(run_if)

	played_events.clear()
	# First kill: streak = 1, no reaction
	run_if.record_kill()
	check(run_if.kill_streak_count == 1, "First kill: streak count = 1")
	check(played_events.is_empty(), "First kill does not trigger reaction")

	# Second kill within window: streak = 2, golf_clap
	run_if.record_kill()
	check(run_if.kill_streak_count == 2, "Second kill: streak count = 2")
	check(played_events.has(&"golf_clap"), "Double kill triggered golf_clap")

	# Third kill: streak = 3, canned_laughter
	run_if.record_kill()
	check(run_if.kill_streak_count == 3, "Third kill: streak count = 3")
	check(played_events.has(&"canned_laughter"), "Triple kill triggered canned_laughter")

	# Fourth kill: streak = 4, audience_applause
	run_if.record_kill()
	check(run_if.kill_streak_count == 4, "Fourth kill: streak count = 4")
	check(played_events.has(&"audience_applause"), "Quad kill triggered audience_applause")

	# 12. Test Elevator Music ("降E大调夜曲Op.9 No.2") & Floor Badge Finish
	check(sfx.MUSIC_STREAMS.has(&"elevator"), "MUSIC_STREAMS has 'elevator'")
	check(sfx.MUSIC_STREAMS.has(&"nocturne"), "MUSIC_STREAMS has 'nocturne'")
	var nocturne_stream: AudioStream = sfx.MUSIC_STREAMS.get(&"elevator")
	check(nocturne_stream != null, "Elevator nocturne stream is loaded")
	check(nocturne_stream.loop == true, "Elevator nocturne stream has loop enabled")
	var total_len: float = nocturne_stream.get_length() if nocturne_stream != null else 0.0
	check(total_len > 60.0, "Elevator nocturne stream length is > 60s (actual: %.1fs)" % total_len)

	# Test floor badge pickup stops music with tape stop & WorldSFX isolation
	sfx.play_battle_music()
	await create_timer(0.6).timeout
	check(manager.music_player.playing, "Battle music playing before badge pickup")

	played_events.clear()
	var world_bus_idx := AudioServer.get_bus_index(sfx.WORLD_SFX_BUS)
	sfx.finish_floor_badge_music()
	check(played_events.has(&"elevator_badge"), "finish_floor_badge_music() played elevator_badge chime")
	check(played_events.has(&"vinyl_scratch_brake"), "finish_floor_badge_music() played vinyl_scratch_brake SFX")
	check(AudioServer.is_bus_mute(world_bus_idx), "WorldSFX bus is muted during tape stop for noise isolation")
	check(manager.music_tween != null and manager.music_tween.is_valid(), "finish_floor_badge_music() started 0.3s tape stop tween")

	await create_timer(0.4).timeout
	check(not manager.music_player.playing, "Music completely stopped after floor badge tape stop")
	check(not AudioServer.is_bus_mute(world_bus_idx), "WorldSFX bus unmuted after tape stop finishes")
	check(is_equal_approx(manager.music_player.pitch_scale, 1.0), "Pitch scale reset to 1.0 after badge tape stop")

	# Test elevator music playback & random seek constraint (< total_len - 30.0)
	sfx.play_elevator_music()
	check(manager.current_music_id == &"elevator", "Current music ID is 'elevator'")
	await create_timer(0.6).timeout
	check(manager.music_player.playing, "Elevator music is playing")
	var pos: float = manager.music_player.get_playback_position()
	check(pos <= maxf(0.0, total_len - 28.0), "Playback position is not within 30s of end (pos: %.1fs, max allowed: %.1fs)" % [pos, total_len - 30.0])

	# Test elevator music stop on arrival chime
	sfx.stop_elevator_music()
	check(not manager.music_player.playing, "stop_elevator_music() stopped elevator music cleanly")
	check(manager.current_music_id == &"", "current_music_id reset to empty after stop_elevator_music()")

	run_if.queue_free()

	print("\n=== SUMMARY ===")
	print("Checks: %d, Failures: %d" % [checks, failures])
	if failures == 0:
		print("ALL AUDIO FEATURE TESTS PASSED!")
		quit(0)
	else:
		push_error("%d AUDIO FEATURE TESTS FAILED!" % failures)
		quit(1)
