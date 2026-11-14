extends SceneTree
const SCENE=preload("res://scenes/dream/Dream3D_ReceptionRoom.tscn")
var checks:=0
var failures:=0
var out:="user://reference_lobby_layout"
func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--artifact-dir="):out=arg.trim_prefix("--artifact-dir=")
 call_deferred("run")
func check(ok: bool,label: String) -> void:
 checks+=1;print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func sweep(room: Node,start: Vector2,finish: Vector2) -> bool:
 var query:=PhysicsShapeQueryParameters2D.new();var shape:=CircleShape2D.new();shape.radius=8
 query.shape=shape;query.transform=Transform2D(0,start*32);query.motion=(finish-start)*32;query.collision_mask=4
 var result: PackedFloat32Array=room.player.get_world_2d().direct_space_state.cast_motion(query)
 return result[0]>=.9999
func run() -> void:
 if not AudioServer.is_bus_mute(0):AudioServer.set_bus_mute(0,true);quit(2);return
 var room=SCENE.instantiate();root.add_child(room);await physics_frame;await physics_frame
 check(room.floor_cells.size()==383,"Wide foreground and contracted lift hall form the marked T-shaped footprint")
 check(room.RECEPTION_DESK_POS_3D.x<12 and room.RECEPTION_DESK_POS_3D.z>room.STAIR_BOTTOM_Z,"Service counter is in the left foreground")
 check(room.waitress_npc.global_position==room.WAITRESS_NPC_POS_2D,"Requested NPC remains behind the relocated counter")
 check(get_nodes_in_group(&"reception_npc").size()==1,"Exactly one reception NPC")
 check(room.door_root.get_child_count()==6 and room.elevator_floor_door.current_state==ElevatorFloorDoor3D.State.UNLOCKED,"Six inner-bank elevators remain functional")
 var counts: Dictionary={};var gates:=0;var piers:=0
 for item in room.props_root.get_children():
  var kind: String=String(item.get_meta(&"lobby_kind",""));counts[kind]=int(counts.get(kind,0))+1
  if item.has_meta(&"reference_access_gate"):gates+=1
  if item.has_meta(&"reference_stone_pier"):piers+=1
 check(counts.get("sofa",0)==2 and counts.get("coffee_table",0)==2,"Both waiting bays remain inside the wide foreground")
 check(counts.get("plant",0)==2,"Two planters flank the raised bays")
 check(room.reception_desk.get_node("Structure").find_children("Counter*","MeshInstance3D",false,false).size()==4,"Counter has four separate ring segments")
 check(sweep(room,Vector2(5,16.1),Vector2(9.4,16.1)),"Counter centre is a genuinely empty staff well")
 check(not sweep(room,Vector2(7.2,16.1),Vector2(7.2,19.1)),"The ring closes across the front rather than forming a U")
 check(gates==4,"Four gate bodies form the reference's three rear access lanes")
 check(piers==4,"Two pairs of freestanding stone columns frame the atrium")
 check(room.props_root.has_node("RearMezzanineSlab") and room.props_root.has_node("RearStoneParapet"),"Raised rear balcony and solid parapet are present")
 check(is_equal_approx(room.get_lobby_floor_height(Vector2(13,4)),.6) and is_zero_approx(room.get_lobby_floor_height(Vector2(13,19))),"Rear hall and foreground have distinct floor heights")
 for index in room.STAIR_COUNT:
  var stair: MeshInstance3D=room.floor_root.get_node("BroadStair%02d"%index)
  var top: float=stair.position.y+stair.get_aabb().end.y
  check(absf(top-room.get_lobby_floor_height(Vector2(13,stair.position.z)))<.001,"Stair %d mesh and actor-ground height agree"%index)
 check(not room.floor_cells.has(Vector2i(1,5)) and not room.floor_cells.has(Vector2i(22,5)),"Former outer lift wings have actually been removed")
 check(room.floor_cells.has(Vector2i(1,12)) and room.floor_cells.has(Vector2i(22,12)),"Foreground width is retained below the returns")
 var aligned:=0
 for gate in room.props_root.get_children():
  if gate.has_meta(&"reference_access_gate") and is_equal_approx(gate.position.z,9.7) and gate.position.z+.775<=room.STAIR_TOP_Z:aligned+=1
 check(aligned==4,"All four gates are planted at the stair's upper edge without overhang")
 check(is_zero_approx(room.get_lobby_floor_height(Vector2(2,11.5))),"Outer foreground wings stay flat beside the narrowed stairs")
 check(not sweep(room,Vector2(.8,12),Vector2(.8,9)),"New left outer return stops movement into the removed wing")
 check(not sweep(room,Vector2(22.7,12),Vector2(22.7,9)),"New right outer return stops movement into the removed wing")
 check(sweep(room,Vector2(9,4.8),Vector2(17,4.8)),"The former rear gate location is clear")
 for segment in [[Vector2(17.5,19.1),Vector2(7.2,19.1)],[Vector2(7.2,19.1),Vector2(13.2,19.1)],[Vector2(13.2,19.1),Vector2(13.2,16)],[Vector2(13.2,16),Vector2(12,14)],[Vector2(12,14),Vector2(12,8.4)],[Vector2(12,8.4),Vector2(7,8.4)]]:
  check(sweep(room,segment[0],segment[1]),"Playable reference route %s to %s is clear"%[segment[0],segment[1]])
 check(not sweep(room,Vector2(7.2,19.1),Vector2(7.2,17.8)),"Wide stone counter has matching solid collision")
 check(not sweep(room,Vector2(9.3,9.7),Vector2(8.55,9.7)),"Access gate body is solid")
 check(not sweep(room,Vector2(6.4,10.5),Vector2(5.5,10.5)),"Freestanding pier is solid")
 check(not sweep(room,Vector2(6.5,11.5),Vector2(5.7,11.5)),"Stair handrail has solid collision")
 room.player.global_position=Vector2(7.2,19.1)*32
 check(room.interaction_resolver.update_target()==room.waitress_npc,"Relocated counter front selects the NPC")
 room.player.global_position=Vector2(12,8.4)*32;await process_frame;await process_frame
 check(absf(room.player_depth_bridge._character_ground().y-.6)<.001,"Actor depth carrier contacts the raised floor")
 check(AudioServer.is_bus_mute(0),"Private test audio remains muted")
 DirAccess.make_dir_recursive_absolute(out)
 FileAccess.open(out.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"audio":AudioServer.get_driver_name(),"checks":checks,"failures":failures},"\t"))
 room.queue_free();await process_frame;preload("res://scripts/audio/sfx_manager.gd").stop_music(0.0);await process_frame;print("TAROT_RECEPTION_LAYOUT checks=",checks," failures=",failures);quit(1 if failures else 0)
