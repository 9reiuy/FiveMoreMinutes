extends SceneTree
const OUTPUT="res://.runtime/night_coast_surf_crane_walk_20261029"
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures+=1; push_error(label)
 print("PASS " if ok else "FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 preload("res://tests/support/background_gpu.gd").start(self)
 create_timer(120).timeout.connect(func(): quit(2))
 var view:=SubViewport.new(); view.size=Vector2i(640,360)
 view.own_world_3d=true; view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
 var coast: Node3D=load("res://scenes/preview/night_coast.tscn").instantiate()
 coast.external_step=true
 var saved_nodes:=coast.find_children("*","",true,false).size()
 check(coast.get_node("WaveBreakers").find_children("TowerCrane","Node3D",false,false).size()==1,"exactly one authored water tower crane")
 var crane: Node3D=coast.get_node("WaveBreakers/TowerCrane")
 check(crane.position.y<0 and coast.coast_distance(crane.position.x,crane.position.z)>2,"crane stands in water off walking land")
 check(crane.get_node("Mast").mesh.get_faces().size()>500 and crane.has_node("LongJib") and crane.has_node("Cables") and crane.has_node("Hook"),"real trussed mast jib rigging cabin and hook saved in scene")
 view.add_child(coast)
 await process_frame; await RenderingServer.frame_post_draw
 check(coast.find_children("*","",true,false).size()==saved_nodes,"runtime preserves authored layout with no replacement geometry")
 check(coast.walker.left.texture.resource_path.ends_with("dream_chr_32x32.png"),"walk uses original character art")
 check(coast.walker.left.position==Vector2(-5,-9),"standing feet reset to original rig pose")
 coast.clock=9.; coast._update_light()
 for i in 12:
  coast.advance(.1,Vector2.UP)
  await process_frame; await RenderingServer.frame_post_draw
  view.get_texture().get_image().save_png(OUTPUT+"/opening_%03d.png"%i)
 var left_positions: Array[Vector2]=[]; var right_positions: Array[Vector2]=[]; var body_positions: Array[Vector2]=[]
 coast.player_position=Vector3(-3,0,23)
 coast.walker.phase=0; coast.walker.moving=false; coast.walker.pose()
 coast._place_character(); coast.update_camera(0,true); coast.clock=9
 for i in 180:
  coast.advance(.1,Vector2.UP if i<118 else Vector2.ZERO)
  if i<24:
   if not left_positions.has(coast.walker.left.position): left_positions.append(coast.walker.left.position)
   if not right_positions.has(coast.walker.right.position): right_positions.append(coast.walker.right.position)
   if not body_positions.has(coast.walker.body.position): body_positions.append(coast.walker.body.position)
  await process_frame; await RenderingServer.frame_post_draw
  view.get_texture().get_image().save_png(OUTPUT+"/walk_%03d.png"%i)
  var actor_screen: Vector2=coast.camera.unproject_position(coast.character.global_position)
  if i<40:
   var image:=view.get_texture().get_image()
   var rect:=Rect2i(Vector2i(actor_screen)-Vector2i(24,28),Vector2i(48,56))
   image.get_region(rect).save_png(OUTPUT+"/actor_%03d.png"%i)
 check(left_positions.size()>=5 and right_positions.size()>=5 and body_positions.size()>=3,"walking alternates both feet with visible body bob")
 check(coast.walker.left.position==Vector2(-5,-9) and coast.walker.right.position==Vector2(0,-9),"stopping returns both feet to rest")
 check(coast.walker.facing_back,"walking uphill shows back-facing art")
 var capture: SubViewport=coast.get_node("WalkerCapture")
 var art:=capture.get_texture().get_image()
 art.save_png(OUTPUT+"/walker_capture.png")
 var occupied:=0
 for y in art.get_height():
  for x in art.get_width():
   if art.get_pixel(x,y).a>.5: occupied+=1
 check(occupied>200 and occupied<1000,"isolated transparent character capture contains only complete actor")
 coast.player_position=Vector3(-3,0,6.3); coast._place_character(); coast.update_camera(0,true)
 coast.clock=21.6; coast._update_light()
 await process_frame; await RenderingServer.frame_post_draw
 var after:=view.get_texture().get_image(); after.save_png(OUTPUT+"/after_lookout.png")
 var cap_count:=0; var cap_without:=0; var white_samples:=0
 var side_caps: Array[int]=[0,0]
 coast.water_material.set_shader_parameter("whitecap_strength",0.)
 await process_frame; await RenderingServer.frame_post_draw
 var no_caps:=view.get_texture().get_image(); no_caps.save_png(OUTPUT+"/whitecaps_off.png")
 for y in range(135,350):
  for x in range(8,632):
   var screen:=Vector2(x,y)
   var ray: Vector3=coast.camera.project_ray_normal(screen)
   if ray.y>=-.005: continue
   var p: Vector3=coast.camera.global_position+ray*(-coast.camera.global_position.y/ray.y)
   if coast.coast_distance(p.x,p.z)<3 or p.distance_to(coast.camera.global_position)>110: continue
   var on:=after.get_pixel(x,y); var off:=no_caps.get_pixel(x,y)
   if on.r>.48 and on.g>.38 and on.b>.38 and on.get_luminance()>off.get_luminance()+.12:
    cap_count+=1
    if x<200 and p.x<-6: side_caps[0]+=1
    if x>440 and p.x>1: side_caps[1]+=1
   if off.r>.48 and off.g>.38 and off.b>.38: cap_without+=1
   white_samples+=1
 check(cap_count>35 and cap_count<6000,"middle near sea has separated pale crests (%d added pixels)"%cap_count)
 check(float(cap_count)/maxi(white_samples,1)<.08,"red water remains visible between separated crests")
 check(side_caps[0]>12 and side_caps[1]>12,"both visible flanks have their own wave crests (%s)"%str(side_caps))
 var side_conserved:=true
 for patch in coast.side_surf.patches:
  var f: RefCounted=patch.flow
  var ledger: float=f.source_volume-f.sink_volume-f.evaporated_volume
  if absf(f.total_volume()-ledger)/maxf(f.total_volume(),1.)>.000003: side_conserved=false
 check(side_conserved,"continuous near-water patch retains its volume ledger within 3ppm")
 var far_changes:=0
 for y in range(125,240):
  for x in range(8,632):
   var ray: Vector3=coast.camera.project_ray_normal(Vector2(x,y))
   if ray.y>=-.005: continue
   var p: Vector3=coast.camera.global_position+ray*(-coast.camera.global_position.y/ray.y)
   if p.distance_to(coast.camera.global_position)<125 or coast.coast_distance(p.x,p.z)<3: continue
   if absf(after.get_pixel(x,y).get_luminance()-no_caps.get_pixel(x,y).get_luminance())>.04: far_changes+=1
 check(far_changes<8,"far sea has no added whitecap field")
 coast.water_material.set_shader_parameter("whitecap_strength",.9)
 var turbines: Array[Node]=coast.atmosphere.root.find_children("Turbine_*","Node3D",false,false)
 var side_clear:=true; var nearest_height:=0.; var rotor_diameter:=0.
 for turbine in turbines:
  var rotor: Node3D=turbine.get_node("Rotor")
  var center: Vector2=coast.camera.unproject_position(rotor.global_position)
  var radius: float=rotor.position.y*.42*rotor.global_basis.x.length()
  var edge: Vector2=coast.camera.unproject_position(rotor.global_position+coast.camera.global_basis.x*radius)
  if not (center.x+absf(edge.x-center.x)<230 or center.x-absf(edge.x-center.x)>410): side_clear=false
  if turbine.name==&"Turbine_00":
   nearest_height=rotor.global_position.y
   rotor_diameter=radius*2.
 check(nearest_height>30 and rotor_diameter>34,"wind turbines have enlarged towers and broad rotors")
 check(side_clear,"enlarged rotor extents leave center horizon clear")
 var crane_center: Vector2=coast.camera.unproject_position(crane.global_position+Vector3(0,6,0))
 crane.visible=false
 await process_frame; await RenderingServer.frame_post_draw
 var no_crane:=view.get_texture().get_image(); no_crane.save_png(OUTPUT+"/crane_hidden.png")
 crane.visible=true
 await process_frame; await RenderingServer.frame_post_draw
 var with_crane:=view.get_texture().get_image(); with_crane.save_png(OUTPUT+"/crane_visible.png")
 var crane_pixels:=0
 for y in 360:
  for x in 640:
   if absf(with_crane.get_pixel(x,y).r-no_crane.get_pixel(x,y).r)>.025: crane_pixels+=1
 check(crane_pixels>350 and (crane_center.x<230 or crane_center.x>410),"single crane reads clearly on side in actual camera (%d pixels)"%crane_pixels)
 check(crane.basis.get_scale().x>2.1,"tower crane uses enlarged physical scale")
 for i in 80:
  coast.clock+=.1; coast._update_light()
  await process_frame; await RenderingServer.frame_post_draw
  view.get_texture().get_image().save_png(OUTPUT+"/sea_%03d.png"%i)
 var phase: float=coast.walker.phase
 var rotor_z: float=coast.atmosphere.rotors[0].rotation.z
 var foam_before: PackedFloat32Array=coast.surface_foam.density.duplicate()
 coast.paused=true; coast.advance(.1,Vector2.DOWN)
 check(coast.walker.phase==phase and coast.atmosphere.rotors[0].rotation.z==rotor_z and coast.surface_foam.density==foam_before,"pause freezes walking wind and physical foam")
 coast.paused=false
 coast.advance(.1,Vector2.DOWN)
 check(not coast.walker.facing_back,"return walk switches to front art")
 coast.advance(.1,Vector2.RIGHT)
 check(coast.walker.facing_right,"right walk selects right facing head art")
 var report={"checks":checks,"failures":failures,"saved_nodes":saved_nodes,"whitecap_pixels":cap_count,"side_whitecap_pixels":side_caps,"water_samples":white_samples,"without_whitecap_white_pixels":cap_without,"nearest_tower_height":nearest_height,"nearest_rotor_diameter":rotor_diameter,"crane_pixels":crane_pixels,"gpu":RenderingServer.get_video_adapter_name(),"scope":"640x360 real GPU Camera; normal 0.1s stepping; no full-frame performance claim"}
 FileAccess.open(OUTPUT+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 view.queue_free(); await process_frame
 print("FINAL ",JSON.stringify(report)); quit(failures)
