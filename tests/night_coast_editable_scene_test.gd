extends SceneTree
const SCENE="res://scenes/preview/night_coast.tscn"
const OUTPUT="res://.runtime/night_coast_surf_crane_walk_20261029/editable"
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures+=1; push_error(label)
 print("PASS " if ok else "FAIL ",label)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 preload("res://tests/support/background_gpu.gd").start(self)
 # Also bounds failures before a broken _ready can leave a background test alive.
 create_timer(90).timeout.connect(func(): quit(2))
 DirAccess.make_dir_recursive_absolute(OUTPUT)
 var coast: Node3D=load(SCENE).instantiate()
 var authored_count:=coast.find_children("*","",true,false).size()
 check(authored_count>300,"geometry is present before entering scene tree")
 var all_owned:=true
 for node in coast.find_children("*","",true,false):
  if node.owner!=coast: all_owned=false
 check(all_owned,"all layout nodes are owned and can be saved in editor")
 check(coast.get_node("SandRidge").mesh.get_surface_count()==1,"terrain mesh is a saved resource")
 check(coast.get_node("Water").material_override is ShaderMaterial,"water material is available in inspector")
 check(coast.get_node("OffshoreAtmosphere/Turbine_00/Rotor").get_child_count()==3,"wind turbine blades are saved children")
 var view:=SubViewport.new(); view.size=Vector2i(640,360); view.own_world_3d=true
 view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(view)
 coast.external_step=true; view.add_child(coast)
 await process_frame; await RenderingServer.frame_post_draw
 check(coast.find_children("*","",true,false).size()==authored_count,"runtime adds no replacement geometry")
 var image:=view.get_texture().get_image(); image.save_png(OUTPUT+"/after.png")
 var difference:=0.0; var changed:=0
 # The original migration required visual equality. Later art revisions are
 # intentional; only run that historical assertion when explicitly requested.
 var original_look: bool="--check-original-migration-look" in OS.get_cmdline_user_args()
 if original_look:
  var before:=Image.load_from_file("res://.runtime/night_coast_editable_20261029/before.png")
  for y in 360:
   for x in 640:
    var a:=before.get_pixel(x,y); var b:=image.get_pixel(x,y)
    var diff:=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
    difference+=diff
    if diff>.04: changed+=1
  difference/=640.*360.
  check(difference<.012,"original migration retains Camera appearance (mean difference %.5f)"%difference)
 var fixture: Node3D=load(SCENE).instantiate()
 fixture.external_step=true
 var rock: Node3D=fixture.get_node("WaveBreakers").get_child(0)
 var rock_path: NodePath=fixture.get_path_to(rock)
 var old_rock:=rock.position
 rock.position=Vector3(-2,0,1)
 var turbine: Node3D=fixture.get_node("OffshoreAtmosphere/Turbine_00")
 turbine.position.x-=8; turbine.rotate_y(.25)
 var turbine_transform:=turbine.transform
 var rotor: Node3D=turbine.get_node("Rotor"); rotor.rotation.z=.4
 fixture.get_node("WorldMoon").position+=Vector3(80,10,0)
 var moon: Vector3=fixture.get_node("WorldMoon").position
 fixture.get_node("CoastCamera").position+=Vector3(.7,.4,0)
 fixture.get_node("CoastCamera").fov=61
 fixture.get_node("MoonLight").light_energy=.42
 var boulder: Node3D=fixture.get_node("DuneDressing").get_child(0)
 var boulder_path:=fixture.get_path_to(boulder)
 boulder.position=Vector3(-6,1,22)
 var terrain: MeshInstance3D=fixture.get_node("SandRidge")
 terrain.position.y=.25
 var new_material: ShaderMaterial=boulder.material_override.duplicate()
 new_material.set_shader_parameter("base_color",Color(.23,.31,.26))
 boulder.material_override=new_material
 # Roundtrip in an actual saved fixture, not merely editing a live instance.
 var fixture_path:=OUTPUT+"/edited_fixture.tscn"
 var packed:=PackedScene.new(); packed.pack(fixture)
 check(ResourceSaver.save(packed,fixture_path)==OK,"modified layout saves to disk")
 fixture.free()
 var edited: Node3D=load(fixture_path).instantiate(); edited.external_step=true
 check(edited.get_node(rock_path).position==Vector3(-2,0,1),"rock position persists after closing and reopening")
 check(edited.get_node("OffshoreAtmosphere/Turbine_00").transform.is_equal_approx(turbine_transform),"turbine transform persists after reopening")
 check(edited.get_node(boulder_path).material_override.get_shader_parameter("base_color")==Color(.23,.31,.26),"edited material persists after reopening")
 var expected_nodes:=edited.find_children("*","",true,false).size()
 view.remove_child(coast)
 coast.free()
 view.add_child(edited)
 await process_frame; await RenderingServer.frame_post_draw
 check(edited.find_children("*","",true,false).size()==expected_nodes,"startup preserves saved node count")
 check(edited.get_node(rock_path).position==Vector3(-2,0,1),"startup does not reset edited rock placement")
 check(edited.wave_breakers[0].p==Vector2(-2,1) and edited.obstacle_distance(Vector2(-2,1))<-.4,"water obstacle reads edited rock placement")
 check(edited.flow.solid[34*48+20]!=0,"flow simulation blocks moved rock at its new cell")
 var texture_pixel: Color=edited.coast_shape_texture.get_image().get_pixel(int(26.*256./56.),int(23.*256./70.))
 check(texture_pixel.b<0,"foam obstacle texture follows edited rock")
 check(edited.slope_dressing.footprints[0].x==-6 and edited.slope_dressing.footprints[0].y==22,"walking collision reads edited boulder placement")
 check(edited.get_node("OffshoreAtmosphere/Turbine_00").transform.is_equal_approx(turbine_transform),"runtime preserves authored wind turbine transform")
 check(is_equal_approx(edited.atmosphere.rotors[0].rotation.z,.4+edited.clock*.065),"blade animation retains authored starting angle")
 check(edited.moon_anchor.position==moon,"runtime preserves edited moon position")
 check(edited.camera.fov==61 and edited.camera_position_adjustment.is_equal_approx(Vector3(.7,.4,0)),"camera retains authored field of view and offset")
 check(is_equal_approx(edited.moon_base_energy,.42),"cloud controller retains edited moon energy")
 check(absf(edited.surface_height(-3,23)-edited.terrain_height(-3,23)-.25)<.05,"walking height follows saved terrain surface transform")
 edited.clock=21.6; edited.player_position=Vector3(-3,0,6.3)
 edited._place_character(); edited.update_camera(0,true); edited._update_light()
 await process_frame; await RenderingServer.frame_post_draw
 view.get_texture().get_image().save_png(OUTPUT+"/edited_camera.png")
 edited.paused=true
 var frozen_time: float=edited.clock; edited.advance(.1)
 check(edited.clock==frozen_time,"pause still freezes simulation")
 edited.paused=false
 var original_rotation: float=edited.atmosphere.rotors[0].rotation.z
 edited.advance(.2)
 check(edited.atmosphere.rotors[0].rotation.z!=original_rotation,"authored turbine still animates")
 # A second instance must not share per-instance flow or animated materials.
 var independent: Node3D=load(SCENE).instantiate(); independent.external_step=true
 view.add_child(independent)
 check(independent.water_material!=edited.water_material and independent.flow_texture!=edited.flow_texture,"separate instances own their animated material and water state")
 var old_power: float=edited.water_material.get_shader_parameter("scene_time")
 independent.clock=37; independent._update_light()
 check(edited.water_material.get_shader_parameter("scene_time")==old_power,"second scene cannot overwrite first scene animation")
 view.queue_free(); await process_frame
 var report={"checks":checks,"failures":failures,"authored_nodes":authored_count,"original_migration_appearance_checked":original_look,"mean_max_rgb_difference":difference if original_look else null,"changed_pixels_over_0_04":changed if original_look else null,"gpu":RenderingServer.get_video_adapter_name(),"scope":"Saved-node roundtrip plus real 640x360 GPU Camera; no FPS claim"}
 FileAccess.open(OUTPUT+"/editable_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("FINAL ",JSON.stringify(report)); quit(failures)
