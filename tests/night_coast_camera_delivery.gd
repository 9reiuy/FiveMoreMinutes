extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures+=1; push_error(label)
 print("PASS " if ok else "FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 preload("res://tests/support/background_gpu.gd").start(self)
 var output:="res://.runtime/night_coast_surf_crane_walk_20261029/regression"
 DirAccess.make_dir_recursive_absolute(output)
 var view:=SubViewport.new(); view.size=Vector2i(640,360)
 view.own_world_3d=true; view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(view)
 var coast: Node3D=load("res://scenes/preview/night_coast.tscn").instantiate()
 coast.external_step=true; view.add_child(coast)
 await process_frame
 check(coast.flow.width==48 and coast.flow.height==40,"independent scene owns real flow grid")
 check(coast.camera.current,"actual perspective Camera3D")
 check(coast.get_node("WaveBreakers").find_children("ConcreteCrossBlock_*","Node3D",false,false).size()==16,"sixteen four arm concrete cross blocks spread along coast")
 check(coast.pixel_materials.size()>=6,"water terrain rocks and concrete share main game pixel controls")
 check(coast.atmosphere.turbine_count==9,"nine offshore turbines built at staggered depths")
 check(coast.atmosphere.root.find_children("SeaFog_*","MeshInstance3D",false,false).size()==3,"three layered sea fog ribbons")
 check(coast.atmosphere.root.find_children("TurbineGreyOutline","MeshInstance3D",true,false).size()==45,"tower hub and every solid blade have grey outlines")
 var rotor_initial: float=coast.atmosphere.rotors[0].rotation.z
 check(coast.SLOPE_MOUNDS.size()==6 and coast.slope_dressing.rock_count==12,"slope keeps lower density grouped rocks")
 check(coast.slope_dressing.concrete_count==1,"most concrete dressing is moved toward shoreline")
 var borders:=coast.find_children("GreyOutline","MeshInstance3D",true,false)
 check(borders.size()==coast.slope_dressing.outlined_meshes and borders.size()>50,"all land and coastal props have grey silhouette meshes")
 var path_safe:=true
 for feature in coast.slope_dressing.footprints:
  if absf(feature.x-coast.ridge_center(feature.y))-feature.z<1.4: path_safe=false
 check(path_safe,"central walking route remains clear of decor footprints")
 var obstacle: Vector3=coast.slope_dressing.footprints[-1]
 var resolved: Vector3=coast.slope_dressing.resolve_motion(Vector3(-3,0,23),Vector3(obstacle.x,0,obstacle.y))
 check(Vector2(resolved.x-obstacle.x,resolved.z-obstacle.y).length()>=obstacle.z+.19,"decor footprint prevents walking through concrete")
 coast._update_light()
 await process_frame; await RenderingServer.frame_post_draw
 var outlined:=view.get_texture().get_image(); outlined.save_png(output+"/slope_outlined.png")
 for border in borders: border.visible=false
 await process_frame; await RenderingServer.frame_post_draw
 var no_outline:=view.get_texture().get_image(); no_outline.save_png(output+"/slope_no_outline.png")
 var outlined_pixels:=0
 for y in 360:
  for x in 640:
   var border_color:=outlined.get_pixel(x,y)
   if absf(border_color.r-no_outline.get_pixel(x,y).r)>.025 and border_color.r>.25 and absf(border_color.r-border_color.b)<.08: outlined_pixels+=1
 check(outlined_pixels>100,"grey outlines visible in actual overhead GPU image")
 for border in borders: border.visible=true
 coast.set_pixel_enabled(false)
 await process_frame; await RenderingServer.frame_post_draw
 var pixel_off:=view.get_texture().get_image(); pixel_off.save_png(output+"/pixel_off.png")
 coast.set_pixel_enabled(true)
 await process_frame; await RenderingServer.frame_post_draw
 var pixel_on:=view.get_texture().get_image(); pixel_on.save_png(output+"/pixel_on.png")
 var pixel_changes:=0
 for y in range(40,340):
  for x in 640:
   if absf(pixel_on.get_pixel(x,y).r-pixel_off.get_pixel(x,y).r)>.015: pixel_changes+=1
 check(pixel_changes>1000,"main game ordered pixel shading changes actual GPU output")
 var near_surface: MeshInstance3D=coast.get_node("Water")
 var near_bounds: AABB=near_surface.get_aabb()
 check(near_surface.position.z+near_bounds.end.z>45,"water geometry covers whole beach beyond former straight cut")
 var covered_sites:=0
 var foamy_sites:=0
 var foam_hits: Array[int]=[0,0,0,0,0,0]
 for phase in 3:
  coast.clock=9.+float(phase)*.5; coast._update_light()
  await process_frame; await RenderingServer.frame_post_draw
  var shore_image:=view.get_texture().get_image()
  for side_i in 2:
   var side: int=-1 if side_i==0 else 1
   for zone in 3:
    var z: float=16.+float(zone)*5.
    var point:=Vector3(coast.coast_edge_x(z,side)+side*.2,0,z)
    var screen: Vector2=coast.camera.unproject_position(point)
    if screen.x<12 or screen.x>628 or screen.y<25 or screen.y>340: continue
    if phase==0: covered_sites+=1
    var count:=0
    for y in range(maxi(0,int(screen.y)-18),mini(360,int(screen.y)+19)):
     for x in range(maxi(0,int(screen.x)-18),mini(640,int(screen.x)+19)):
      var color:=shore_image.get_pixel(x,y)
      if color.r>.45 and color.g>.35 and color.b>.35: count+=1
    foam_hits[side_i*3+zone]=maxi(foam_hits[side_i*3+zone],count)
 for hits in foam_hits:
  if hits>4: foamy_sites+=1
 check(covered_sites>=2 and foamy_sites>=2,"actual swash reaches formerly uncovered back beach zones")
 for i in 60:
  coast.advance(.1,Vector2.ZERO)
  await process_frame; await RenderingServer.frame_post_draw
  view.get_texture().get_image().save_png(output+"/shore_%03d.png"%i)
 check(absf(coast.atmosphere.rotors[0].rotation.z-rotor_initial)>.1,"turbine blades rotate with scene simulation")
 var curvature_min:=100.0; var curvature_max:=-100.0
 for z in range(2,20):
  var edge:=0.0
  for j in range(20,150):
   var x: float=-float(j)*.1
   if coast.coast_distance(x,float(z))>0: edge=x; break
  curvature_min=minf(curvature_min,edge); curvature_max=maxf(curvature_max,edge)
 check(curvature_max-curvature_min>2.0,"shore has inlets and sand tongues rather than a straight flank")
 var left_count:=0; var right_count:=0; var rear_count:=0
 for breaker in coast.wave_breakers:
  if breaker.p.y>14: rear_count+=1
  if breaker.p.y>5 and breaker.p.x<-3: left_count+=1
  if breaker.p.y>5 and breaker.p.x>-3: right_count+=1
 check(left_count>=10 and right_count>=10 and rear_count>=12,"coastal props span both flanks and rear beach")
 check(coast.get_node("WaveBreakers").get_child_count()==coast.wave_breakers.size(),"all coastal pieces have real scene geometry")
 var blocked:=0; var open:=0; var mismatch:=0.0
 for y in 40:
  for x in 48:
   var point:=Vector2(-12+(x+.5)*.5,-16+(y+.5)*.5)
   if coast.obstacle_distance(point)<0 and coast.flow.solid[y*48+x]!=0: blocked+=1
   if coast.obstacle_distance(point)>.1 and point.y<3: open+=1
   mismatch=maxf(mismatch,absf(coast.flow.bed[y*48+x]-coast.surface_height(point.x,point.y)))
 check(blocked>20 and open>500,"flow grid blocks breakers while retaining open water gaps")
 check(mismatch<.00001,"flow bed matches visible land height function")
 coast.player_position=Vector3(-3,0,6.3)
 coast._place_character(); coast.update_camera(0,true)
 var clear_time:=0.0; var dark_time:=0.0
 for i in 360:
  var t: float=i*.1
  if coast.visibility_at(t)>.99: clear_time=t
  if coast.visibility_at(t)<.01: dark_time=t
 coast.clock=clear_time; coast._update_light()
 await process_frame; await RenderingServer.frame_post_draw
 var clear:=view.get_texture().get_image(); clear.save_png(output+"/moon_clear.png")
 var turbines: Array[Node]=coast.atmosphere.root.find_children("Turbine_*","Node3D",false,false)
 for turbine in turbines: turbine.visible=false
 await process_frame; await RenderingServer.frame_post_draw
 var no_turbines:=view.get_texture().get_image(); no_turbines.save_png(output+"/turbines_hidden.png")
 for turbine in turbines: turbine.visible=true
 var turbine_pixels:=0
 for y in range(35,170):
  for x in range(35,605):
   if absf(clear.get_pixel(x,y).r-no_turbines.get_pixel(x,y).r)>.025: turbine_pixels+=1
 check(turbine_pixels>100,"offshore turbine towers hubs and blades remain readable at game camera")
 var center_clear:=true
 for rotor in coast.atmosphere.rotors:
  var center: Vector2=coast.camera.unproject_position(rotor.global_position)
  var radius: float=rotor.position.y*.42*rotor.global_basis.x.length()
  var side_point: Vector2=coast.camera.unproject_position(rotor.global_position+coast.camera.global_basis.x*radius)
  var extent:=absf(side_point.x-center.x)
  if not (center.x+extent<230 or center.x-extent>410): center_clear=false
 check(center_clear,"complete rotors stay on left and right leaving central sea view clear")
 var moon_world: Vector3=coast.get_node("WorldMoon").global_position
 var moon_screen: Vector2=coast.camera.unproject_position(moon_world)
 check(clear.get_pixel(int(moon_screen.x),int(moon_screen.y)).get_luminance()>.3,"GPU moon matches fixed world anchor projection")
 clear.save_png(output+"/moon_camera_before.png")
 var original_camera: Transform3D=coast.camera.global_transform
 coast.camera.rotate_y(.10); coast._update_light()
 await process_frame; await RenderingServer.frame_post_draw
 var moon_after: Vector2=coast.camera.unproject_position(moon_world)
 var pan_image:=view.get_texture().get_image(); pan_image.save_png(output+"/moon_camera_pan.png")
 check(moon_screen.distance_to(moon_after)>20 and pan_image.get_pixel(int(moon_after.x),int(moon_after.y)).get_luminance()>.3,"camera pan projects same world moon to correct new screen location")
 check(coast.get_node("WorldMoon").global_position==moon_world,"camera pan never moves moon world anchor")
 coast.camera.global_transform=original_camera; coast._update_light()
 check(coast.moon_light.light_energy>.6,"clear moon illuminates geometry")
 check(clear.get_pixel(300,300).get_luminance()>.012,"pixel lighting keeps the lookout surface readable")
 var red_pixels:=0
 var foam_pixels:=0
 for y in range(140,350):
  for x in 640:
   var c:=clear.get_pixel(x,y)
   if c.r>.12 and c.r>c.g*2.4 and c.r>c.b*1.8: red_pixels+=1
   if c.r>.48 and c.g>.38 and c.b>.38: foam_pixels+=1
 check(red_pixels>10000,"actual sea remains crimson rather than blue")
 check(foam_pixels>100,"actual coast displays pale broken foam")
 var sky_stars:=0
 for y in range(32,95):
  for x in range(250,410):
   var c:=clear.get_pixel(x,y)
   if c.r>.10 and c.g>.12 and c.b>.14: sky_stars+=1
 check(sky_stars<=12,"rendered star count stays sparse")
 coast.water_material.set_shader_parameter("ripples_enabled",false)
 await process_frame; await RenderingServer.frame_post_draw
 var without_ripples:=view.get_texture().get_image(); without_ripples.save_png(output+"/ripple_off.png")
 coast.water_material.set_shader_parameter("ripples_enabled",true)
 clear.save_png(output+"/ripple_on.png")
 var ripple_pixels:=0
 for y in range(140,300):
  for x in 640:
   if absf(clear.get_pixel(x,y).r-without_ripples.get_pixel(x,y).r)>.02: ripple_pixels+=1
 check(ripple_pixels>1500,"coherent ripple crests are visible in actual GPU output")
 coast.clock=dark_time; coast._update_light()
 await process_frame; await RenderingServer.frame_post_draw
 var dark:=view.get_texture().get_image(); dark.save_png(output+"/moon_covered.png")
 check(coast.moon_light.light_energy<.01,"cloud cover extinguishes moon light")
 var signal_pixels:=0
 for y in range(100,122):
  for x in range(20,620):
   var c:=dark.get_pixel(x,y)
   if c.g>.10 and c.r>.10 and c.b>.06 and c.g>c.b*1.03: signal_pixels+=1
 check(signal_pixels>=4,"SOS points remain visibly readable at sea sky boundary")
 var clear_sum:=0.0; var dark_sum:=0.0
 for y in range(140,250):
  for x in range(300,550):
   clear_sum+=clear.get_pixel(x,y).get_luminance()
   dark_sum+=dark.get_pixel(x,y).get_luminance()
 check(clear_sum>dark_sum*1.2,"real GPU moon road disappears with cloud")
 coast.clock=20
 coast.inject_at(Vector3(-2,0,1.5),.65,1)
 var volume: float=coast.flow.total_volume()
 var timings: Array[float]=[]
 for i in 240:
  var started:=Time.get_ticks_usec()
  coast.advance(.1,Vector2.ZERO)
  timings.append(float(Time.get_ticks_usec()-started)/1000)
  await process_frame; await RenderingServer.frame_post_draw
  view.get_texture().get_image().save_png(output+"/frame_%03d.png"%i)
 check(coast.flow.total_dye()>.4,"dye remains in active water simulation")
 var ledger: float=coast.flow.source_volume-coast.flow.sink_volume-coast.flow.evaporated_volume
 check(absf(coast.flow.total_volume()-ledger)<.02,"ocean boundary ledger matches water volume")
 var ledger_volume: float=coast.flow.total_volume()
 var steps: int=coast.flow.steps; var clock: float=coast.clock
 var rotor_before_pause: float=coast.atmosphere.rotors[0].rotation.z
 coast.paused=true; coast.advance(.5,Vector2.ONE)
 check(coast.flow.steps==steps and coast.clock==clock,"pause stops flow clouds and SOS clock")
 check(coast.atmosphere.rotors[0].rotation.z==rotor_before_pause,"pause freezes turbine motion")
 var lowest:=100.; var highest:=0.; var biggest_jump:=0.; var previous_level:=0.
 for i in 1800:
  coast.atmosphere.update(float(i)/60.,0.,coast)
  var level: float=coast.atmosphere.signals[0].get_shader_parameter("power")
  lowest=minf(lowest,level); highest=maxf(highest,level)
  if i>0: biggest_jump=maxf(biggest_jump,absf(level-previous_level))
  previous_level=level
 check(lowest>.75 and highest-lowest<.16 and biggest_jump<.003,"far lamps stay lit with gentle continuous brightness variation")
 check(coast.atmosphere.signals.size()==15 and coast.atmosphere.dash_count==3,"blurred horizon mixes isolated dots and three long dash strings")
 check(coast.find_children("House*","MeshInstance3D",false,false).is_empty(),"no concrete house or roof silhouettes")
 coast.player_position=Vector3(-3,0,23)
 coast.paused=false
 coast._place_character(); coast.update_camera(0,true)
 coast.clock=9
 var initial_height: float=coast.player_position.y
 var initial_pitch: float=coast.camera.rotation.x
 var initial_house: Vector2=coast.camera.unproject_position(Vector3(0,.25,-600))
 var previous_pitch: float=coast.camera.rotation.x
 var max_pitch_step:=0.0
 var max_height_step:=0.0
 var previous_height: float=coast.player_position.y
 var peak:=initial_height
 for i in 180:
  coast.advance(.1,Vector2.UP if i<118 else Vector2.ZERO)
  max_pitch_step=maxf(max_pitch_step,absf(coast.camera.rotation.x-previous_pitch))
  max_height_step=maxf(max_height_step,absf(coast.player_position.y-previous_height))
  previous_pitch=coast.camera.rotation.x; previous_height=coast.player_position.y
  peak=maxf(peak,coast.player_position.y)
  await process_frame; await RenderingServer.frame_post_draw
  view.get_texture().get_image().save_png(output+"/walk_%03d.png"%i)
  if i in [0,60,117]: view.get_texture().get_image().save_png(output+"/stage_%03d.png"%i)
 check(peak-initial_height>3.0,"walk climbs actual ridge by more than three metres")
 check(coast.player_position.z<6.4,"walk reaches rounded cliff lookout")
 check(coast.ridge_width(6.3)>2.0,"headland retains a broad walkable platform")
 check(absf(coast.terrain_height(-2,6.5)-coast.terrain_height(-4,6.5))<.6,"lookout top stays broadly level")
 check(coast.terrain_height(.9,6.3)<coast.player_position.y-2.5,"low side beach is physically below cliff")
 check(coast.camera.rotation.x>initial_pitch+.5,"camera moves from overhead toward horizon")
 check(max_pitch_step<.10 and max_height_step<.22,"continuous camera and terrain traversal")
 var final_house: Vector2=coast.camera.unproject_position(Vector3(0,.25,-600))
 check(initial_house.y<0 and final_house.y>0 and final_house.y<180,"horizon houses enter camera only after climb")
 timings.sort()
 var report:={"checks":checks,"failures":failures,"simulation_and_upload_cpu_ms_p50":timings[120],"simulation_and_upload_cpu_ms_p95":timings[228],"scope":"640x360 minimized GPU; each sample advances 0.1 simulation seconds, 3 updates, excludes draw/readback; not FPS benchmark","clear_time":clear_time,"covered_time":dark_time,"volume":ledger_volume,"ledger":ledger,"initial_injected_volume":volume,"climb_metres":peak-initial_height,"max_pitch_step_radians":max_pitch_step,"max_height_step_metres":max_height_step,"initial_house_screen_y":initial_house.y,"final_house_screen_y":final_house.y,"gpu":RenderingServer.get_video_adapter_name()}
 report["lamp_minimum"]=lowest; report["lamp_maximum"]=highest; report["lamp_max_step_at_60hz"]=biggest_jump
 report["moon_pan_screen_displacement"]=moon_screen.distance_to(moon_after)
 report["moon_world_anchor"]=str(moon_world)
 var file:=FileAccess.open(output+"/report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
 print(JSON.stringify(report))
 view.queue_free(); await process_frame
 var display: Control=load("res://scenes/preview/night_coast_display.tscn").instantiate()
 root.add_child(display)
 await process_frame
 check(display.view.size==Vector2i(640,360),"standalone entry keeps fixed pixel viewport")
 var key:=InputEventKey.new(); key.keycode=KEY_SPACE; key.pressed=true
 display._unhandled_input(key)
 check(display.coast.paused,"standalone entry forwards pause input")
 var click:=InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=true
 var target: Vector2=display.coast.camera.unproject_position(Vector3(-2,0,1))
 var factor:=minf(display.size.x/640.0,display.size.y/360.0)
 click.position=target*factor+(display.size-Vector2(640,360)*factor)*.5
 display.coast.paused=false
 display.coast.player_position=Vector3(-3,0,6.3)
 display.coast._place_character(); display.coast.update_camera(0,true)
 target=display.coast.camera.unproject_position(Vector3(-2,0,1))
 click.position=target*factor+(display.size-Vector2(640,360)*factor)*.5
 display._unhandled_input(click)
 check(display.coast.injected_volume>.5,"standalone entry maps mouse to real flow injection")
 report.checks=checks; report.failures=failures
 file=FileAccess.open(output+"/report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
 display.queue_free(); await process_frame
 print("FINAL checks=",checks," failures=",failures)
 quit(failures)
