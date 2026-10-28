extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 preload("res://tests/support/background_gpu.gd").start(self)
 create_timer(90).timeout.connect(func(): quit(2))
 var output:="res://.runtime/reference_palette_20261029"
 DirAccess.make_dir_recursive_absolute(output)
 var manager:=root.get_node("SettingsManager")
 manager.set_setting(&"palette_enabled",true)
 manager.set_setting(&"palette_scheme",1)
 var preview: Control=load("res://scripts/dream/preview/selective_pixel_preview.gd").new()
 preview.preview_mode=true
 root.add_child(preview)
 await process_frame
 for i in 12: await process_frame
 preview.world.process_mode=Node.PROCESS_MODE_DISABLED
 await RenderingServer.frame_post_draw
 preview.world_viewport.get_texture().get_image().save_png(output+"/original.png")
 manager.set_setting(&"palette_enabled",true)
 manager.set_setting(&"palette_scheme",2)
 if int(preview.palette_material.get_shader_parameter("palette_scheme"))!=2:
  push_error("Formal viewport did not apply scheme 2"); quit(1); return
 for i in 5: await process_frame
 await RenderingServer.frame_post_draw
 preview.world_viewport.get_texture().get_image().save_png(output+"/sample.png")
 manager.set_setting(&"palette_scheme",1)
 if int(preview.palette_material.get_shader_parameter("palette_scheme"))!=1:
  push_error("Formal viewport did not restore scheme 1"); quit(1); return
 var phone: Control=load("res://scripts/ui/phone_settings_screen.gd").new()
 root.add_child(phone); await process_frame
 phone._push_page(&"graphics")
 phone._selections[&"graphics"]=1
 phone._adjust_selection(1)
 if manager.get_palette_scheme()!=2 or not manager.get_palette_enabled():
  push_error("Phone failed to select scheme 2"); quit(1); return
 phone._adjust_selection(-1)
 if manager.get_palette_scheme()!=1: push_error("Phone failed to select scheme 1"); quit(1); return
 phone._adjust_selection(-1)
 if manager.get_palette_enabled(): push_error("Phone failed to disable palette"); quit(1); return
 phone._activate_selection()
 phone._activate_selection()
 phone._activate_selection()
 if manager.get_palette_enabled(): push_error("Phone confirmation failed to cycle back to off"); quit(1); return
 var saved:=ConfigFile.new()
 if saved.load("user://game_settings.cfg")!=OK or int(saved.get_value("graphics","palette_scheme",0))!=2:
  push_error("Palette scheme was not saved"); quit(1); return
 print("PASS scheme changes reach actual viewport and phone can select 1, 2, off")
 phone.queue_free()
 print("SAMPLE captured ",RenderingServer.get_video_adapter_name())
 preview.queue_free(); await process_frame; quit()
