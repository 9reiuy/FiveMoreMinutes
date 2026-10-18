extends SceneTree
const WORLD = preload("res://scenes/dream/preview/FurnitureTextureReview.tscn")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks+=1
	if not value: failures+=1; push_error(message)
func frames(count: int) -> void:
	for frame in count: await process_frame
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var settings = root.get_node("SettingsManager")
	var saved: Dictionary=settings.values.duplicate(true)
	settings.values["palette_enabled"]=false
	var world= WORLD.instantiate()
	world.generate_on_ready=false
	root.add_child(world)
	check(world.regenerate(120),"Sample generation failed")
	await frames(15)
	var city=world.get_node("SampleNeonCity")
	check(city.buildings>200 and city.buildings<1000,"Night skyline is missing or unbounded")
	check(city.scene_root.find_children("*","MeshInstance3D",false,false).size()==3,"City geometry was not batched")
	check(city.scene_root.find_children("*","CollisionObject3D",true,false).is_empty(),"City scenery added gameplay collision")
	check(city.window_lights.size()==4 and city.scene_root.find_children("*","Light3D",true,false).size()==4,"Exterior window light budget changed")
	check(city.window_lights.all(func(light: OmniLight3D) -> bool: return light.light_cull_mask==city.CITY_LAYER and not light.shadow_enabled),"City window lights can reach the indoor world or added shadow cost")
	check(city.scene_root.find_children("*","MeshInstance3D",false,false).all(func(mesh: MeshInstance3D) -> bool: return mesh.layers==city.CITY_LAYER),"Exterior surfaces share indoor lighting layers")
	check((world.camera_3d.cull_mask & city.CITY_LAYER)!=0,"Formal camera cannot see the city layer")
	check(city.find_children("*","SubViewport",true,false).is_empty(),"City retained the depth-blind overlay viewport")
	city._sync_render_snapshot()
	check(city.render_materials.all(func(mat: ShaderMaterial) -> bool: return mat.get_shader_parameter("ray_origin_tl")==world.room_visibility.outside_mask_material.get_shader_parameter("ray_origin_tl")),"City clipping does not use the formal camera rays")
	check(city.near_towers.size()>=12 and city.near_towers.size()<60 and city.near_towers.all(func(tower: Dictionary) -> bool: return tower.top>=18),"Nearby towers remain sparse or lower than the occupied floor")
	var city_sides: Dictionary={}
	for tower in city.near_towers:
		city_sides[tower.side]=true
		check(tower.gap>=3 and tower.gap<=4,"Near building edge gap is not three to four cells")
		check(not world.floor_cells.keys().any(func(cell: Vector2i) -> bool: return tower.footprint.grow(2.99).intersects(Rect2(Vector2(cell)-Vector2(.5,.5),Vector2.ONE))),"Near tower intersects the building clearance")
		check(city.near_towers.all(func(other: Dictionary) -> bool: return other==tower or not other.footprint.grow(2.99).intersects(tower.footprint)),"Near towers overlap or close their narrow gaps")
	check(city_sides.size()==4,"Near buildings leave a whole facade side empty")
	var repeated_rng := RandomNumberGenerator.new(); repeated_rng.seed=world.active_seed+88211
	check(city.near_layout(world.floor_cells,city.topology.external,repeated_rng)==city.near_towers,"Near tower arrangement is not deterministic")
	for candidate in city.light_candidates:
		check(city.window_tone(candidate.cell,candidate.tower%251)>=5,"Exterior light is not positioned at a lit window")
	check(city.render_materials.all(func(mat: ShaderMaterial) -> bool: return mat.shader.code.contains("void light()") and mat.shader.code.contains("city_height = VERTEX.y")),"City windows are unlit or haze follows the camera instead of building height")
	print("CITY_LAYOUT towers=",city.near_towers.size()," window_lights=",city.window_lights.size()," buildings=",city.buildings)
	check(city.facade_segments>0,"Current building has no downward exterior skin")
	var self_facade: MeshInstance3D=city.scene_root.get_node("CurrentBuildingFacade")
	check(self_facade.mesh.get_aabb().end.y<0 and self_facade.mesh.get_aabb().position.y< -40,"Current building skin invades the floor instead of extending downward")
	check(city.attached_mask!=null and not city.attached_mask.shader.code.contains("texture(city_background"),"City overlay still paints over the wall depth")
	var ring: Dictionary={}
	for y in 9:
		for x in 9:
			if x==0 or y==0 or x==8 or y==8: ring[Vector2i(x,y)]=true
	var classified: Dictionary=city.classify_void(ring,Rect2i(0,0,9,9))
	check(not classified.external.has(Vector2i(4,4)),"Enclosed courtyard leaks the skyline")
	check(classified.external.has(Vector2i(-1,4)),"True building exterior remains black")
	ring.erase(Vector2i(0,4))
	classified=city.classify_void(ring,Rect2i(0,0,9,9))
	check(classified.external.has(Vector2i(4,4)),"Open exterior recess was classified as an enclosed courtyard")
	var review=world.get_node("FurnitureTextureReviewCoordinator")
	review.refresh_assets()
	var floors=world.get_node("SampleFloorTextureReview")
	floors.refresh_assets(); review.refresh_assets()
	check(not floors.records.is_empty(),"Floor review failed to attach")
	var floor_signatures: Dictionary={}
	for floor_kind in ["office","conference","manager","archive","server","pantry","restroom","lounge","reception","lift","corridor"]:
		for variant in 3:
			var tile: Image=floors.floor_image(floor_kind,variant)
			check(tile.get_size()==Vector2i(64,64) and not tile.has_mipmaps(),"Floor texture density/filtering changed")
			var signature: String=tile.get_data().hex_encode().sha256_text()
			check(not floor_signatures.has(signature),"Repeated floor style/variant: "+floor_kind)
			floor_signatures[signature]=true
	for variant in 3:
		var terrazzo: Image=floors.floor_image("corridor",variant)
		var base := Color("d4d9d8").darkened(.018*variant)
		var chips := 0
		for y in range(1,64):
			for x in range(1,64):
				var pixel := terrazzo.get_pixel(x,y)
				if absf(pixel.r-base.r)>.006: chips+=1
				check(absf(pixel.r-base.r)<.08,"Corridor terrazzo has high-contrast noise")
		check(chips>50 and chips<300,"Corridor stone chips are missing or too dense")
		check(terrazzo.get_data()==floors.floor_image("corridor",variant).get_data(),"Terrazzo generation is not deterministic")
	for record in floors.records:
		check(record.old.get_aabb()==record.new.get_aabb(),"Floor presentation changed geometry bounds")
		for surface in record.new.get_surface_count():
			var arrays: Array=record.new.surface_get_arrays(surface)
			check(arrays[Mesh.ARRAY_TANGENT].size()==arrays[Mesh.ARRAY_VERTEX].size()*4,"Floor bevel is missing its rotated tangent basis")
	for kind in ["office","conference","manager","lounge","corridor","reception","pantry","restroom","server","archive","lift"]:
		var material: ShaderMaterial=floors.floor_material({"sample_key":kind})
		check(material.shader.code.contains("NORMAL_MAP =")== (kind!="office"),"Carpet received bevels or hard floor lost bevels")
		var normal: Image=floors.floor_normal_image(kind,0)
		check(normal.get_size()==Vector2i(64,64) and not normal.has_mipmaps(),"Bevel normal texture density changed")
		check(normal.get_pixel(8,8).b>.99,"Floor center normal is not flat")
		if kind!="office":
			check(normal.get_pixel(1,8).r<.49 and normal.get_pixel(8,1).g<.49,"Floor bevel normals have no edge slope")
	var seam_sample: Image=floors.floor_image("corridor",0)
	check(absf(seam_sample.get_pixel(0,30).r-Color("d4d9d8").r)<.05,"Corridor seam is too dark")
	check(seam_sample.get_pixel(30,30).get_luminance()>.75,"Corridor terrazzo is not cool white")
	seam_sample=floors.floor_image("reception",0)
	check(absf(seam_sample.get_pixel(0,30).r-Color("bdbcb5").r)<.05,"Marble seam is too dark")
	var corridor_count := 0
	for room in world.rooms:
		if String(room.get("room_type",""))!="corridor": continue
		corridor_count+=1
		var material: ShaderMaterial=floors.floor_material(room)
		var texture: Texture2D=material.get_shader_parameter("atlas")
		var variant := posmod((str(world.active_seed)+"corridor").hash(),3)
		check(texture.get_image().get_data()==floors.floor_image("corridor",variant).get_data(),"Named sample corridor failed to receive terrazzo")
	check(corridor_count==4,"Sample corridor coverage changed")
	var plant_count: int=floors.plants.size()
	check(plant_count>=3 and plant_count<=4,"Missing safe corner plants: "+str(plant_count))
	check(floors.extras.get_ref().get_child_count()==4,"Missing local seating/meeting rugs")
	check(floors.extras.get_ref().get_node_or_null("ReviewRug_office")==null,"Office strip carpet has an unwanted extra rug")
	for reference in floors.plants:
		var plant: Node2D=reference.get_ref()
		var reserves: Array=preload("res://scripts/dream/otxo_room_layout_planner.gd").get_doorway_reservation_rects(world._get_room_doors(plant.get_meta(&"dream_room_id")))
		check(reserves.all(func(box: Rect2) -> bool: return not box.grow(16).has_point(plant.position)),"Plant blocks a doorway reservation")
	floors.set_mode(false)
	check(not floors.extras.get_ref().visible,"Old mode retained the new rugs")
	floors.set_mode(true)
	var dressing=world.get_node("SampleWallAndDesktopReview")
	dressing.refresh_assets()
	var window_count: int=dressing.windows.size()
	check(window_count>0,"Exterior window appearance did not attach")
	for record in dressing.windows:
		var wall: Node3D=record.wall.get_ref()
		check(wall.window_variant and record.new_mesh is QuadMesh,"Exterior window is no longer a floor-to-ceiling pane")
		var texture: Texture2D=record.new_mat.get_shader_parameter("glass_pixels")
		check(texture.get_size()==Vector2(roundi(record.new_mesh.size.x*32),roundi(record.new_mesh.size.y*32)),"Exterior glass pixel density changed")
		check(texture.get_image().get_pixel(4,4).a<.1,"Exterior glass is opaque")
		check(record.pane.get_ref().cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Exterior glass blocks sunlight with a solid shadow")
	dressing.set_mode(false)
	for record in dressing.windows: check(record.pane.get_ref().mesh==record.old_mesh,"Original exterior pane was not restored")
	dressing.set_mode(true)
	var archive_floor: Image=floors.floor_image("archive",0)
	var archive_wall: Image=dressing.wall_image("archive",world.wall_height)
	check(archive_wall.get_pixel(8,8).get_luminance()-archive_floor.get_pixel(8,8).get_luminance()>.15,"Archive walls and floor are too similar")
	var restroom: Image=floors.floor_image("restroom",0)
	check(restroom.get_pixel(0,0).get_luminance()<restroom.get_pixel(8,8).get_luminance()*.85,"Restroom reference corner inserts are missing")
	check(absf(restroom.get_pixel(8,8).r-restroom.get_pixel(8,8).b)<.06,"Restroom tiles are not neutral gray")
	for style in ["solid","glass","window"]:
		var door_tile: Image=dressing.door_image(Vector3(1.0,2.0,.1),style,0)
		check(door_tile.get_size()==Vector2i(32,64) and not door_tile.has_mipmaps(),"Door pixel density changed")
		var colors: Dictionary={}
		for y in 64:
			for x in 32: colors[door_tile.get_pixel(x,y).to_rgba32()]=true
		check(colors.size()>=7,"Door is missing pixel rim and hardware detail")
		check(door_tile.get_pixel(0,4)!=door_tile.get_pixel(1,4),"Door rim has no inset edge layers")
	var door_styles: Dictionary={}
	var door_count: int=dressing.doors.size()
	for record in dressing.doors:
		door_styles[record.style]=true
		var door: PhysicalDoor3D=record.door.get_ref()
		var collision: BoxShape3D=door.left_leaf.get_node("CollisionShape3D").shape
		check(collision.size==Vector3(door.leaf_width,door.door_height,door.wall_thickness),"Door appearance changed its collision dimensions")
		for leaf in record.leaves:
			check(leaf.node.get_ref().transform==Transform3D.IDENTITY,"Review door did not use leaf-local geometry")
			if leaf.glass!=null:
				var texture: Texture2D=leaf.glass.material_override.get_shader_parameter("glass_pixels")
				check(not texture.get_image().has_mipmaps() and texture.get_image().get_pixel(1,1).a<.1,"Door glass is opaque or filtered")
				check(leaf.glass.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"Transparent glass casts a solid shadow")
	check(door_styles.size()==3,"Missing glass/window/solid door styles")
	dressing.set_mode(false)
	for record in dressing.doors:
		for leaf in record.leaves:
			check(leaf.node.get_ref().mesh==leaf.old_mesh and leaf.node.get_ref().transform==leaf.old_transform,"Original door display was not restored")
	dressing.set_mode(true)
	check(not dressing.walls.is_empty(),"Room wall preview did not attach")
	var wall_signatures: Dictionary={}
	var corridor_wall: Image=dressing.wall_image("corridor",world.wall_height)
	var wall_split := floori(corridor_wall.get_height()*2.0/3.0)
	var skirting_height := maxi(1,roundi(corridor_wall.get_height()*.10))
	for y in corridor_wall.get_height():
		check((corridor_wall.get_pixel(20,y)==Color("424d50"))==(y>=corridor_wall.get_height()-skirting_height),"Corridor skirting does not cover the bottom ten percent")
	for x in 64:
		check(corridor_wall.get_pixel(x,10)==corridor_wall.get_pixel(1,10),"Corridor upper wall retained repeated vertical grooves")
	check(corridor_wall.get_pixel(1,10).get_luminance()>corridor_wall.get_pixel(1,wall_split+4).get_luminance(),"Corridor wall lost its light upper/dark lower separation")
	var corridor_faces := 0
	for record in dressing.walls:
		var cells: Array=world._edge_side_cells(record.node.get_ref().get_meta(&"edge"))
		for side in 2:
			var room_id: int=world.room_cells.get(cells[side],-1)
			if room_id<0 or String(world.rooms[room_id].get("room_type",""))!="corridor": continue
			corridor_faces+=1
			var material: ShaderMaterial=record.new_back if side==0 else record.new_front
			var texture: Texture2D=material.get_shader_parameter("atlas")
			check(texture.get_image().get_data()==corridor_wall.get_data(),"Corridor-facing wall received another room's texture")
	check(corridor_faces>0,"No corridor-facing walls were verified")
	for wall_kind in ["office","conference","manager","archive","server","pantry","restroom","lounge","reception","lift","corridor"]:
		var tile: Image=dressing.wall_image(wall_kind,world.wall_height)
		check(tile.get_size()==Vector2i(64,roundi(world.wall_height*32)),"Wall texel density changed")
		var signature: String=tile.get_data().hex_encode().sha256_text()
		check(not wall_signatures.has(signature),"Repeated room wall texture")
		wall_signatures[signature]=true
	var detail_count: int=dressing.props.size()
	var water_count := 0; var desktop_count := 0
	for reference in dressing.props:
		var detail: Node3D=reference.get_ref()
		check(detail.find_children("*","CollisionObject3D",true,false).is_empty(),"Display-only detail added physics")
		if detail.name=="ReviewWaterBarrel":
			water_count+=1
			var bucket: MeshInstance3D=detail.get_node("TransparentBucket")
			check(bucket.mesh.radial_segments==8,"Water barrel is not eight-sided")
			check(is_equal_approx(bucket.mesh.top_radius,.2295) and is_equal_approx(bucket.mesh.height,.529),"Water barrel did not grow by the agreed proportions")
			check(is_equal_approx(bucket.position.y-bucket.mesh.height*.5,.92),"Larger water barrel no longer meets the dispenser neck")
			check(detail.get_node("WaterSurface").position.y<bucket.position.y+bucket.mesh.height*.5,"Waterline escapes the enlarged bucket")
			check(bucket.material_override.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA,"Bucket is not transparent")
			check(not bucket.mesh.cap_top and not bucket.mesh.cap_bottom,"Bucket has unwanted closed transparent caps")
			check(detail.has_node("WaterInside") and detail.has_node("WaterSurface"),"Bucket lacks water/waterline")
		else:
			desktop_count+=1
			var height: float=detail.get_meta(&"surface_height")
			check(is_equal_approx(detail.get_child(0).position.y,height),"Cup floats above its table")
	check(water_count==1 and desktop_count>=10,"Missing water/desktop sample subjects")
	dressing.set_mode(false)
	check(dressing.props.all(func(r: WeakRef) -> bool: return not r.get_ref().visible),"New tabletop/barrel remained in original mode")
	dressing.set_mode(true)
	check(not review.records.is_empty(),"No texture review subjects")
	var kinds: Dictionary={}
	DirAccess.make_dir_recursive_absolute("res://.runtime/furniture_face_review")
	for record in review.records:
		kinds[record.kind]=true
		check(not record.new_material.shader.code.contains("filter_nearest_mipmap"),"Review atlas is not strict nearest")
		check(not record.result.image.has_mipmaps(),"Review atlas unexpectedly smoothed")
		var display: MeshInstance3D=record.node.get_ref()
		var original_transform := display.transform
		var original_parent := display.get_parent()
		review.set_texture_mode(false); review.set_texture_mode(true)
		check(display.transform==original_transform and display.get_parent()==original_parent,"Texture switch changed furniture or chair articulation transform")
		if record.kind!="water_dispenser": check(record.mesh.get_aabb()==record.new_mesh.get_aabb(),"Rebake changed silhouette bounds")
		else: check(record.new_mesh.get_aabb().end.y<=.901,"Old square barrel remains in the review mesh")
		var old_triangles := 0
		for surface in record.mesh.get_surface_count():
			var arrays=record.mesh.surface_get_arrays(surface)
			old_triangles+=(arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
		if record.kind!="water_dispenser": check(record.new_mesh.surface_get_array_index_len(0)/3==old_triangles,"Rebake changed topology")
		var source_points: Dictionary={}
		for surface in record.mesh.get_surface_count():
			for point in record.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]: source_points[point]=true
		var target_points: Dictionary={}
		for point in record.new_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]: target_points[point]=true
		if record.kind!="water_dispenser": check(source_points==target_points,"Rebake moved original vertices")
		else:
			check(target_points.keys().all(func(p: Vector3) -> bool: return source_points.has(p)),"Water dispenser base was moved")
		for face in record.result.faces:
			var expected := Vector2i(maxi(1,roundi(face.world_size.x*32.0)),maxi(1,roundi(face.world_size.y*32.0)))
			check(face.size==expected,"Nonuniform texel density (including one-texel minimum for subtexel faces)")
		record.result.image.save_png("res://.runtime/furniture_face_review/%s_atlas.png" % record.kind)
	for kind in review.FOCUS_KINDS:
		check(kinds.has(kind),"Missing texture subject: "+kind)
	var count: int = world.furniture_root.get_child_count()
	for i in 5: review.set_texture_mode(false); review.set_texture_mode(true)
	check(count==world.furniture_root.get_child_count(),"Texture switch regenerated gameplay objects")
	var assignment: Dictionary={}
	var representatives: Dictionary={}
	for record in review.records:
		assignment[record.identity]=record.assigned_variant
		if not representatives.has(record.kind) or (record.kind=="chair" and record.result.faces.any(func(face: Dictionary) -> bool: return face.tile=="chair_seat")):
			representatives[record.kind]=record
	for kind in representatives:
		var record: Dictionary=representatives[kind]
		var signatures: Dictionary={}
		var texture: Texture2D=record.material.get_shader_parameter("atlas")
		for variant in review.ART.VARIANT_COUNT:
			var result: Dictionary=review.ART.build(record.mesh,texture,kind,variant)
			var signature: String=result.image.get_data().hex_encode().sha256_text()
			check(not signatures.has(signature),"Duplicate variant: "+kind)
			signatures[signature]=true
			check(review.ART.build(record.mesh,texture,kind,variant).texture==result.texture,"Variant cache is not stable")
			check(result.mesh.get_aabb()==record.new_mesh.get_aabb(),"Variant changed geometry")
			if kind=="sofa":
				var no_white_patches := true
				for face in result.faces:
					for py in face.image.get_height():
						for px in face.image.get_width():
							var pixel: Color=face.image.get_pixel(px,py)
							if pixel.r>.80 and pixel.g>.80 and pixel.b>.75: no_white_patches=false
				check(no_white_patches,"Sofa variant contains a white paper/patch decal")
			result.image.save_png("res://.runtime/furniture_face_review/%s_variant%d_atlas.png" % [kind,variant+1])
	for variant in range(-1,4): review.set_variant_override(variant)
	review.set_variant_override(-1); review.refresh_assets()
	for record in review.records: check(record.result.variant==assignment[record.identity],"Variant override failed to restore stable assignment")
	var moved_subject: Node2D=world.furniture_root.get_children().filter(func(node: Node) -> bool: return node.has_meta(&"texture_review_identity"))[0]
	var old_position := moved_subject.position
	var moved_kind: String=String(moved_subject.get_meta(&"office_furniture_kind"))
	var stable: int=review.assigned_variant(moved_subject,moved_kind)
	moved_subject.position+=Vector2(11,7)
	check(review.assigned_variant(moved_subject,moved_kind)==stable,"Physical movement changed variant")
	moved_subject.position=old_position
	if "--capture" in OS.get_cmdline_user_args():
		for enemy in world.enemy_root.get_children(): enemy.process_mode=Node.PROCESS_MODE_DISABLED
		world.player.invulnerability_left=0.0
		if not dressing.windows.is_empty():
			var window: Node3D=dressing.windows[0].wall.get_ref()
			var origin := Vector2(window.position.x,window.position.z)*32.0
			for offset in [window.window_inward_normal*80.0,Vector2(0,80),Vector2(0,-80),Vector2(80,0),Vector2(-80,0)]:
				if world._content_position_is_clear(origin+offset,12.0): world.player.global_position=origin+offset; break
			await frames(25); world.set_process(false); world.camera_aim_offset=Vector3.ZERO
			world._update_camera_and_actor_projection(0.0)
			for active in [false,true]:
				city.enabled=active; city._sync_render_snapshot(); await frames(3)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.runtime/furniture_face_review/city_depth_%s.png" % ["on" if active else "off"])
			for light_mode in [false,true]:
				city.window_lights_enabled=light_mode; city._sync_render_snapshot(); await frames(3)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.runtime/furniture_face_review/city_window_light_%s.png" % ["on" if light_mode else "off"])
			for fog_mode in [false,true]:
				city.height_fog_enabled=fog_mode; city._sync_render_snapshot(); await frames(3)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.runtime/furniture_face_review/city_height_fog_%s.png" % ["on" if fog_mode else "off"])
			for mode in [false,true]:
				review.set_texture_mode(mode); await frames(3)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.runtime/furniture_face_review/exterior_window_%s.png" % ["after" if mode else "before"])
			world.set_process(true)
		var captured_doors: Dictionary={}
		for record in dressing.doors:
			if captured_doors.has(record.style): continue
			var door: PhysicalDoor3D=record.door.get_ref()
			var point := Vector2(door.position.x,door.position.z)*32.0
			for offset in [Vector2(0,80),Vector2(0,-80),Vector2(80,0),Vector2(-80,0)]:
				if world._content_position_is_clear(point+offset,12.0):
					world.player.global_position=point+offset; break
			await frames(25)
			world.set_process(false); world.camera_aim_offset=Vector3.ZERO
			world._update_camera_and_actor_projection(0.0)
			for mode in [false,true]:
				review.set_texture_mode(mode); await frames(3)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.runtime/furniture_face_review/door_%s_%s.png" % [record.style,"after" if mode else "before"])
			# Supplementary full-leaf view under the same camera; normal captures above
			# retain production cutaway. This is not a replacement for gameplay acceptance.
			for frame in 3:
				await process_frame
				door.set_architectural_cutaway(false,world.wall_height)
				for leaf in record.leaves:
					if leaf.glass!=null: leaf.glass.material_override.set_shader_parameter("architecture_cutaway",false)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.runtime/furniture_face_review/door_%s_uncut.png" % record.style)
			world.set_process(true); captured_doors[record.style]=true
		var corridor_point := Vector2(0,-320)
		check(world._content_position_is_clear(corridor_point,12.0),"Corridor capture point is blocked")
		world.player.global_position=corridor_point
		await frames(30)
		world.set_process(false)
		world.camera_aim_offset=Vector3.ZERO
		world._update_camera_and_actor_projection(0.0)
		for mode in [false,true]:
			review.set_texture_mode(mode)
			await frames(3)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.runtime/furniture_face_review/corridor_%s.png" % ["after" if mode else "before"])
		world.set_process(true)
		for kind in review.FOCUS_KINDS:
			check(review.focus_kind(kind),"Cannot focus review subject")
			await frames(30)
			world.set_process(false)
			world.camera_aim_offset=Vector3.ZERO
			world._update_camera_and_actor_projection(0.0)
			for mode in [false,true]:
				review.set_texture_mode(mode)
				await frames(3)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.runtime/furniture_face_review/%s_%s.png" % [kind,"after" if mode else "before"])
			world.set_process(true)
		# Same gameplay state/camera for four variants, no random-room recreation.
		for subject in ["workstation","shelf","server","sofa","table","fridge","whiteboard","toilet"]:
			review.focus_kind(subject); await frames(20)
			world.set_process(false)
			world.camera_aim_offset=Vector3.ZERO
			world._update_camera_and_actor_projection(0.0)
			for variant in 4:
				review.set_variant_override(variant); await frames(3)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://.runtime/furniture_face_review/%s_variant%d.png" % [subject,variant+1])
			world.set_process(true)
		review.set_variant_override(-1)
		# Keep settings changes in memory: never write the player's saved preference.
		settings.values["palette_enabled"]=true
		settings.setting_changed.emit(&"palette_enabled",true)
		review.focus_kind("workstation")
		await frames(30)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/furniture_face_review/workstation_palette1.png")
		world.night_lighting.set_flashlight_enabled(true)
		await frames(15)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.runtime/furniture_face_review/workstation_flashlight.png")
		world.night_lighting.set_flashlight_enabled(false)
		var start: Vector2=world.player.global_position
		Input.action_press("move_right")
		for sample in 20:
			await physics_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.runtime/furniture_face_review/motion_%03d.png" % sample)
		Input.action_release("move_right")
		check(world.player.global_position.distance_to(start)>1.0,"Texture review blocked player movement")
	for seed in [120,121,122]:
		check(world.regenerate(seed),"Sample rebuild failed")
		await frames(15)
		check(world.find_children("SampleNeonCityGeometry","Node3D",false,false).size()==1,"City scenery leaked across sample rebuilds")
		check(city.build_seed==seed and city.scene_root.get_child_count()==4 and city.window_lights.size()==4,"City generation did not follow the rebuilt sample or leaked light slots")
		review.refresh_assets()
		floors.refresh_assets(); review.refresh_assets()
		dressing.refresh_assets()
		check(dressing.windows.size()==window_count,"Exterior window display records leaked across rebuilds")
		check(dressing.doors.size()==door_count,"Door appearance instances leaked across rebuilds")
		check(dressing.props.size()==detail_count,"Duplicate or missing water/tabletop groups after rebuilding")
		check(dressing.walls.all(func(r: Dictionary) -> bool: return is_instance_valid(r.node.get_ref())),"Stale wall material bindings")
		check(floors.plants.size()==plant_count and floors.extras.get_ref().get_child_count()==4,"Floor rebuild duplicated/lost plants or rugs")
		check(floors.records.all(func(record: Dictionary) -> bool: return is_instance_valid(record.node.get_ref())),"Stale floor texture binding")
		if seed==120:
			var repeated: Dictionary={}
			for record in review.records: repeated[record.identity]=record.assigned_variant
			check(repeated==assignment,"Same seed rebuild changed texture assignment")
		check(review.records.all(func(record: Dictionary) -> bool: return is_instance_valid(record.node.get_ref())),"Stale review material record")
		check(world.furniture_root.get_children().filter(func(node: Node) -> bool: return bool(node.get_meta(&"texture_review_prop",false))).size()==1,"Water sample duplicated after rebuild")
	settings.values=saved
	settings.setting_changed.emit(&"palette_enabled",settings.get_palette_enabled())
	world.queue_free(); await frames(3)
	print("FACE_TEXTURE_RESULT checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)
