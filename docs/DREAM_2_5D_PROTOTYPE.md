# Dream 2.5D — Editable 3D Environment / Formal 2D Actors

The hand-editable scene is:

`res://scenes/dream/Dream3D_Editable.tscn`

The former `dream_2_5d_prototype.tscn` is now only a compatibility entry that
instances this scene. It no longer owns a runtime environment/furniture
generator. `project.godot`, the formal `DreamWorld`, and all 2D gameplay scenes
remain unchanged.

## Scene tree

```text
Dream3D_Editable
├─ EditableEnvironment
│  ├─ FloorRoot/Floor_Main
│  ├─ Walls/Wall_01 ... Wall_06
│  ├─ Doors/Door_01
│  └─ Furniture
│     ├─ Desk_01 / Desk_02
│     ├─ Cabinet_01 / Cabinet_02
│     └─ TrashCan_01 / TrashCan_02
├─ RuntimeBridges/Actors
│  ├─ PlayerVisualBridge
│  └─ EnemyVisualBridge
└─ CameraRig/Camera3D
```

Every static environment object is a saved Scene Tree node. It can be moved,
rotated, scaled, hidden, duplicated, or deleted in the editor. Running the
scene does not recalculate its saved positions or recreate deleted furniture.

## Reusable modules

| Module | Scene |
| --- | --- |
| Floor | `res://scenes/dream/3d/Floor3DVisual.tscn` |
| Wall segment | `res://scenes/dream/3d/WallSegment3D.tscn` |
| Physical door leaf | `res://scenes/dream/3d/PhysicalDoor3D.tscn` |
| Desk | `res://scenes/dream/3d/Desk3DVisual.tscn` |
| Cabinet | `res://scenes/dream/3d/Cabinet3DVisual.tscn` |
| Trash can | `res://scenes/dream/3d/TrashCan3DVisual.tscn` |
| 2D actor depth bridge | `res://scripts/dream/dream_3d_actor_depth_bridge.gd` |

The editable environment meshes are intentionally simple depth carriers and
contain no hidden `StaticBody3D`, `CylinderMesh`, `SphereMesh`, or
`CapsuleMesh` test props. Formal Dream gameplay collision remains in the
existing 2D scenes; the generated random prototype additionally uses only the
explicit `PhysicalDoor3D` leaf collision and its synchronized 2D bridge.

## Materials and exact formal regions

Each module exposes a `MeshInstance3D` named `Visual`. Its `material_override`
points to an independent material resource, and that material contains an
editable `AtlasTexture`. Select `Visual` in the editor to replace the material,
texture, or atlas `region` without editing GDScript.

| Visual | Material | Formal source region |
| --- | --- | --- |
| Floor | `res://materials/dream3d/floor_material.tres` | `Office_Terrain_32x32.png`, `(7,1)` = `Rect2(112,16,16,16)` |
| Wall | `res://materials/dream3d/wall_material.tres` | `Office_Walls_32x32.png`, `(12,14)` = `Rect2(192,224,16,16)` |
| Door leaf | `res://materials/dream3d/door_material.tres` | `Office_Exterior_32x32.png`, `(8,13)` |
| Desk | `res://materials/dream3d/desk_material.tres` | `Office_Furniture_32x32.png`, `Rect2(424,87,48,40)` |
| Filing cabinet | `res://materials/dream3d/filing_cabinet_material.tres` | `Office_Furniture_32x32.png`, `Rect2(485,131,22,60)` |
| Storage cabinet | `res://materials/dream3d/storage_cabinet_material.tres` | `Office_Furniture_32x32.png`, `Rect2(138,32,44,64)` |
| Trash can | `res://materials/dream3d/trash_can_material.tres` | `Office_Furniture_32x32.png`, `Rect2(168,388,16,26)` |

The previous full-atlas error came from assigning an entire Office spritesheet
as `albedo_texture` and allowing the mesh's default UV range to sample `0..1`
of that complete sheet. The current materials use a region-bounded
`AtlasTexture` with `filter_clip = true`, `texture_filter = Nearest`, and no
color tint. Floor/wall repetition uses the bounded tile only; it never repeats
the whole atlas, so neighboring-cell bleeding is avoided without changing any
source PNG.

## Camera and actors

`CameraRig/Camera3D` remains a fixed Orthographic Camera3D at rotation
`(-45°, 0°, 0°)` and size `13.5`. The editable scene contains no script that
overwrites camera angle, size, or environment transforms. Player, Enemy, and
Weapon remain the formal 2D systems; the bridge placeholders are intentionally
empty targets for a later projection helper and do not create duplicate actors
or gameplay collision.

The random prototype now has a presentation-only depth bridge for the formal
Player. The real `CharacterBody2D` remains in the 2D gameplay layer (including
movement, collision and animation), while its `CharacterVisual` and
`WeaponRoot` branches are mirrored into a transparent `SubViewport` and shown
on a depth-tested `Sprite3D`. This is not a second Player and does not replace
the 2D gameplay actor. The source Canvas layer is hidden only in this prototype
so the bridge is the single visible presentation.

## Playable random dungeon prototype

`res://scenes/dream/Dream3D_RandomDungeon.tscn` remains the independent runtime
prototype (the scene name is retained for launch compatibility, while its root
and generator now use the `Dream3D_BuildingLayout` naming).  It does not replace
the hand-editable scene or the formal 2D DreamWorld.  Each generation first
creates one contiguous rectangular Building Footprint, then recursively BSP
splits that footprint into large regions and smaller rooms.  A 3-cell internal
circulation band is carved into the same floor, and each partition receives a
single physical Door edge. Exterior
walls, internal partition walls, the main entrance, and the Spawn/Boss choice
are validated before any visual nodes are created.  Only a valid layout is
turned into instances of the existing `Floortile3D`, `WallStraight3D`, and
`PhysicalDoor3D` modules; the previous Room→Corridor→Room placement algorithm is
no longer used.

The current scale uses a 60–90 cell building width and 44–70 cell height,
with 10×10 minimum leaf rooms.  Floor tiles, wall segments, and doors remain
one grid cell in size; the building is larger because more cells are generated,
not because any visual node is scaled.  Every boundary segment is classified
as `OPEN`, `WALL`, or `DOOR`; only the explicit Door segment is omitted from
the continuous wall.

The real `res://scenes/entities/dream_player.tscn` runs in the prototype's 2D
gameplay layer.  Generated wall edges create physics-layer-4 `StaticBody2D`
colliders in that same coordinate system; each DoorLeaf has a synchronized
thin 2D blocker that rotates with its hinge.  The
fixed orthographic Camera3D is unchanged.  Its rig follows only the Player's
ground position, while the Canvas origin follows the projected ground point so
the Player retains the formal fixed-size 2D pixel presentation.

### Door topology and actor foreground

The generator records every boundary segment as exactly one of `OPEN`, `WALL`,
or `DOOR`.  A Door is created only from a partition adjacency and carries a
unique `door_id`, `connection_id`, `region_a_id`, `region_b_id`, and
`partition_id`.  Internal Doors always join exactly two room regions; the main
entrance is the single exterior exception.  Door candidates keep a configurable
3-cell corner/junction clearance and a 3-cell same-edge Door-to-Door clearance.
If a boundary is too short to satisfy those rules, that generation attempt is
rejected and regenerated.  Validation also checks two-sided floor access,
unique IDs, shared physical edges, and the rendered Wall/Door node mapping.

The former gray `ForegroundOcclusionCanvas` /
`dream_3d_foreground_occlusion.gd` screen-space proxy has been removed. The
Player presentation is now the depth-tested Sprite3D produced by
`dream_3d_actor_depth_bridge.gd`; walls and physical Door leaves are ordinary
3D meshes in the same world, so their depth buffer occludes the character and
held weapon without a gray overlay or extreme z-index. Collision remains the
generated 2D wall topology plus a small synchronized DoorLeaf bridge for the
formal CharacterBody2D Player.

Generated walls use one permanent `wall_height` (the old 1× wall is now 3×,
`3.0` world units) and one shared `wall_thickness` (`0.1`). There is no
room-dependent normal/tall switching. Every Door is a `PhysicalDoor3D` with a
`RigidBody3D` leaf, an edge-mounted `HingeJoint3D`, and an ordinary upper wall
segment that fills the space above the leaf; no Door scene creates left/right/
top frame pieces. A presentation-only `PlayerPhysicsProxy3D` mirrors ground
position so the formal 2D Player can push the physical leaf without creating a
second movement or collision system.

Run the deterministic layout regression with:

```text
Godot_v4.7.1-stable_win64_console.exe --headless --path . \
  --script res://tests/dream_3d_random_dungeon_seed_test.gd
```

The companion runtime regression instantiates the formal DreamPlayer, clears
and regenerates the building, then collision-walks every room center and the
Boss room in five independent seeds:

```text
Godot_v4.7.1-stable_win64_console.exe --headless --path . \
  --script res://tests/dream_3d_random_dungeon_runtime_walk_test.gd
```

The generator also exposes `building_rect`, `partitions`, `corridor_cells`,
`main_entrance`, `spawn_cell`, and `boss_distances` for editor/debug review.
