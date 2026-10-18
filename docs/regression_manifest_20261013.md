# 回归清单 2026-10-13

静态逐项检查入口、直接及传递的 literal load/preload/ext_resource。清单不是测试通过证明。GPU 全部串行；headless+gpu 必须分别运行，Headless 结果不能证明画面。skip_missing / skip_entry_missing 不计 PASS。纯 capture、profilers 和 previews 单列，不自动排入断言回归。

- diagnostic: 105
- gpu: 41
- headless: 183
- headless+gpu: 2
- skip_missing: 2

| Test | 分类 | 超时秒 | 依据 / 缺失引用 |
|---|---|---:|---|
| 3d_firearm_tuning_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| actor_capture_cost_profile | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| actor_volume_shadow_pose_parity_test | headless | 120 | New CPU/native parity regression; no GPU frame wait. |
| actor_volume_shadow_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| aim_preview_projection_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| approved_art_camera_cache_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| approved_art_texture_cache_test | gpu | 180 | Texture byte readback explicitly refuses a headless renderer. |
| approved_office_art_capture | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| approved_office_art_perf | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| approved_office_art_test | headless | 240 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| audition_enemy_death_sfx | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| background_gpu_probe | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| bedroom_art_test | headless | 240 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| blood_airborne_ray_reuse_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| blood_airborne_upload_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| blood_color_probe_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| blood_effect_otxo_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| blood_ground_capture_profile | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| blood_ground_redraw_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| blood_ground_replica_copy_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| blood_ground_transform_perf | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| blood_lifecycle_probe | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| blood_merge_camera_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| blood_merge_single_pass_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| blood_pixel_draw_profile | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| blood_pool_merge_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| blood_query_batch_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| blood_query_camera_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| blood_revision_integration_test | headless | 240 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| boutique_font_integration_test | headless | 240 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| bridge_transform_sync_test | headless | 120 | New CPU/native parity regression; no GPU frame wait. |
| build_office_pixel_atlas | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| camera_relative_movement_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| capture_before_baseline | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| capture_broken_door_jamb | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| capture_character_lighting | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| capture_firearm_revision | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| capture_first_use_profile | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| capture_formal_screenshots | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| capture_hkm_camera | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| capture_light_noise_gameplay | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| capture_map_rotation_review | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| capture_movement_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| capture_office_firearm_main_entry | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| capture_office_overview | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| capture_open_office_nav | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| capture_ordered_room_lighting | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| capture_reception_and_tarot_fix | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| capture_reception_scene | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| capture_settings_ui | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| capture_sync_bench | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| capture_tarot_overlay | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| capture_task_45_office | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| capture_tutorial_broken_door | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| capture_window_closeup | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| capture_window_detail | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| character_capture_cache_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| character_contact_scan_perf | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| character_projection_world_test | headless+gpu | 120 | Logic assertions plus actual Camera capture; both modes required. |
| character_weapon_projection_test | headless+gpu | 120 | Logic assertions plus actual Camera capture; both modes required. |
| combat_fixes_regression_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| compact_interaction_prompt_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| compact_office_layout_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| compare_sprite_vs_hud_pos | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| corpse_contact_world_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| corpse_drag_trail_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| corpse_drag_world_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| corpse_floor_contact_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| corpse_follow_bleed_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| corpse_follow_world_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| corpse_ragdoll_capture | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| corpse_ragdoll_contact_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| current_ui_task_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| cutout_lifetime_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| debug_retreat | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| destruction_family_first_draw | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| destruction_material_lifetime_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| destruction_mesh_profile | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| destruction_warm_transition_budget | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| dialogue_font_readability_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| dialogue_font_visual_capture | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| door_shard_material_profile | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| door_topology_regression_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| door_visual_20seed | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| dream_3d_dialogue_camera_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| dream_3d_random_dungeon_runtime_walk_test | headless | 240 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| dream_3d_random_dungeon_seed_test | headless | 300 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| dream_display_settings_entry_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| dream_player_editor_preview_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| dream_shard_transition_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| dream3d_boss_cycle_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| dream3d_ceiling_light_rule_test | headless | 300 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| dream3d_ceiling_light_visual_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| dream3d_combat_parity_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| dream3d_corridor_enemy_transit_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| dream3d_damage_number_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| dream3d_door_ai_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| dream3d_door_leaf_regression_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| dream3d_door_outline_visual_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| dream3d_effects_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| dream3d_hud_speed_door_feedback_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| dream3d_integration_test | headless | 240 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| dream3d_knockdown_collision_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| dream3d_macro_room_graph_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| dream3d_night_layout_test | headless | 300 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| dream3d_night_runtime_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| dream3d_night_visual_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| dream3d_parity_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| dream3d_population_refill_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| dream3d_room_encounter_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| dream3d_seed_key_pickup_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| dream3d_shape_diagnostic | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| dream3d_visual_fixes_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| dynamic_architecture_shadow_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| elevator_audio_test | headless | 240 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| elevator_floor_door_screen_orientation_test | headless | 240 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| elevator_loading_cover_test | headless | 240 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| elevator_wall_alignment_test | headless | 240 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| elevator_wall_visual_probe | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| employee_perception_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| employee_ragdoll_death_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| enemy_steering_identity_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| engine_profile_collector | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| environment_debris_atlas_candidate | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| environment_debris_atlas_perf | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| environment_debris_shared_texture_candidate | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| feedback_capture_reuse_profile | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| firearm_first_use_probe | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| firearm_impact_visual_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| firearm_loading_main_entry_test | gpu | 240 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| firearm_preparation_lifecycle_test | gpu | 240 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| firearm_shared_rules_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| floor_ab_probe | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| floor_capture_budget_test | gpu | 240 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| floor_exit_render_cover_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| floor_object_capture_profile | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| floor_object_pool_lifecycle_test | headless | 240 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| floor_path_adjacency_test | headless | 300 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| font_raster_probe | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| formal_performance_acceptance | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| formal_shader_identity_probe | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| frozen_render_comparison_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| furniture_destruction_transition_profile | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| furniture_face_texture_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| furniture_rotation_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| furniture_sleep_idle_perf | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| furniture_sleep_probe | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| impact_first_draw_probe | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| impact_mesh_reuse_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| independent_elevator_orientation_test | headless | 240 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| inspect_render_counters | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| interaction_font_visual_capture | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| katana_zero_dash_trail_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| legacy_2d_retirement_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| main_transition_integration_test | headless | 240 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| managed_light_shadow_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| native_generator_candidate_parity_test | headless | 120 | New CPU/native parity regression; no GPU frame wait. |
| occlusion_query_snapshot_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| office_architecture_scale_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_art_review_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_ballistics_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_blood_cross_room_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_blood_impact_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_blood_visual_capture | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| office_combat_capture | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| office_combat_layout_smoke | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_contour_footprint_smoke_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_dither_formal_capture | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| office_dither_formal_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_dressing_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| office_dynamic_shadow_capture | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| office_firearm_integration_test | headless | 240 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_flank_capture | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| office_flank_generator_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_flank_layout_test | skip_missing | 120 | Missing transitive literal load/preload/ext_resource dependencies; retired 2D references are not restored or counted as passed. res://scenes/dream/preview/OfficeFlankPreview.tscn |
| office_flank_movie | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| office_flank_runtime_test | skip_missing | 120 | Missing transitive literal load/preload/ext_resource dependencies; retired 2D references are not restored or counted as passed. res://scenes/dream/preview/OfficeFlankPreview.tscn |
| office_floor_full_runtime_test | headless | 240 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_floor_mask_visual_probe | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| office_furniture_height_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_level_pack_capture | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| office_level_pack_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_low_pixel_validation | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_material_separation_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_muzzle_visual_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_objective_guidance_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_room_low_pixel_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_room_pixel_capture | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| office_sample_art_capture | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| office_sample_input_smoke | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_sample_main_entry_smoke | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| office_sample_metrics | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| office_sample_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_sample_window_input_smoke | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_shadow_integration_test | headless | 240 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_skeleton_formal_runtime_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| office_skeleton_native_test | headless | 300 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_skeleton_playable_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_skeleton_runtime_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| office_slice_cap_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_weapon_swap_speed_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| office_window_sill_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| offscreen_capture_sync_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| otxo_blood_camera_capture | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| otxo_blood_morphology_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| otxo_breakable_doors_and_performance_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| otxo_combat_feel_and_camera_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| otxo_enemy_ai_parity_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| otxo_mansion_generation_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| otxo_performance_and_loading_test | headless | 240 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| otxo_preload_and_cross_room_combat_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| otxo_room_firefight_layout_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| otxo_tactical_ai_and_visibility_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| perf_stutter_profiler | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| phase_c_knock_probe | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| phase2_enemy_recovery_runner | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| phase2_enemy_recovery_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| phase2_player_caster_probe | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| phase2_probe_runner | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| phone_melatonin_currency_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| physical_door_hinge_cutaway_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| pixel_environment_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| pixel_shadow_preview_capture | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| pixel_shadow_preview_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| player_combat_info_hud_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| player_default_fists_capture | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| player_default_fists_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| player_rifle_spread_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| player_side_bangs_capture | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| player_side_bangs_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| point_blank_wall_door_shot_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| probe_vault | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| projectile_capture_extent_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| projectile_history_trail_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| quiet_room_art_test | gpu | 240 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| random_combat_perf | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| random_floor_lifecycle_test | headless | 240 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| random_office_art_style_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| random_office_capture | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| random_office_entry_layout_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| random_office_formal_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| random_office_functional_layout_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| random_office_route_width_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| random_progression_capture | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| random_progression_feedback_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| random_reception_boundaries_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| release_050_entry_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| reload_breakable_props_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| render_category_cost_probe | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| render_monitor_inventory | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| render_stall_control | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| review_refresh_index_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| sample_neon_city_runtime_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| scratch_btn_test | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| scratch_dialogue_anchor_test | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| scratch_tutorial_anchor_test | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| scratch_viewport_test | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| selective_pixel_formal_wrapper_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| selective_pixel_occlusion_gpu_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| selective_pixel_preview_capture | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| selective_pixel_preview_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| sfx_integration_test | headless | 240 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| shadow_first_activation_probe | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| shadow_preparation_steady_probe | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| shared_goal_search_test | headless | 300 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| shell_capture_atlas_candidate | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| shell_capture_atlas_perf | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| shell_creation_profile | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| shotgun_direct_fire_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| skeleton_clearance_cache_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| skeleton_generation_clear_parity_test | headless | 240 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| tactical_planning_dash_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| task_45_office_environment_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| task014_attack_recovery_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| task014_update_validation | gpu | 300 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| test_always_visible_rooms | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_character_atlas_and_facing | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_character_lighting_authenticity | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_character_lighting_scale | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_dialogue_camera_focus | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_dream_dialogue_bubble | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_dream_dialogue_controller | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_dream_dialogue_glyph_fall_fx | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_elevator_and_weapon_parity | headless | 240 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_elevator_animation_flow | headless | 240 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_elevator_components | gpu | 240 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| test_elevator_integration | gpu | 240 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| test_enemy_corpse_presentation | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_enemy_kill_sfx | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_formal_pixelation_main | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| test_furniture_bullet_penetration | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_glass_window_cutaway | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_hkm_camera_aim | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_light_noise_contour | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_lighting_and_theme | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_office_chair_physics | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_office_low_pixel_refined | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_office_shadow_manager_hysteresis | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_office_skeleton_layout | headless | 300 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_office_v2_generator | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_open_office_nav_fix | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_ordered_room_lighting | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_palette_black | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_palette_settings_full | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_pixelation_setting | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_player_dive_mechanics | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_reception_interaction_range | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_reception_room_assets | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_reception_scene | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_shadow_quality_settings | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| test_tarot_audio | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_tarot_draw_system | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_tarot_system | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_tarot_ui_system | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_task015_furniture_parity | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_tutorial_dialogue_integration | headless | 240 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_ui_alignment_integration | headless | 240 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_vault_mechanics | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| test_wall_door_verification | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| text_content_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| tmp_flash_dir | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| tmp_lighting_state | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| tmp_startup_profile_entry | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| tracer_step_coalescing_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| tutorial_room_direct_flow_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| tutorial_room_flow_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| tutorial_room_layout_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| verify_wall_segment_mesh | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| wall_shadow_batch_candidate | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| wall_shadow_batch_perf | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
| weapon_snapshot_pose_test | gpu | 180 | Requires rendered frame/image or explicit headless refusal; GPU must run serially. |
| window_sunlight_parity_test | headless | 120 | Assertion regression using engine logic/physics; no required rendered frame wait. |
| world_render_contribution_profile | diagnostic | 120 | Capture, benchmark, profiler, preview, scratch or one-off diagnostic; outside assertion regression suite. |
