# Screen-wall avatar

User-supplied source: `C:/Users/Administrator/Desktop/Tools/Model/A/ung3.5wumao.vrm`.
The original file is unchanged; SHA-256:
`a9d8f4883a7b6180b27f0ea4db8ebf09772a10180b5b1f20dd41653adabfea42`.

Metadata embedded in that VRM identifies **NKOMIPRODUCTION**, model version 1,
with [creator reference and licence URL](https://skd-noratama.booth.pm/items/2313554).
Its embedded licence fields are `Other` and `ExplicitlyLicensedPerson`.
These fields describe the supplied avatar; the television/server CC0 credits
remain in the parent directory's `ASSET_SOURCES.md`.

## Editable and runtime files

| File | Purpose |
|---|---|
| `ung35_editable_pose.scn` | Native editable rig, 111 bones, original skinning and posed joints |
| `ung35_folded_pose.scn` | Self-contained baked runtime geometry, 11 meshes, no skeleton processing |
| `ung35_folded_pose.glb` | Independently reimported portable copy of the same posed geometry |
| `screen_wall_avatar.tscn` | Runtime placement and lighting/occlusion script |
| `pose_manifest.json` | Source hash, pose anchors and export results |

`tools/build_screen_wall_avatar.gd` imports the VRM through Godot's GLTFDocument,
poses the native rig and bakes its skin transforms into positions, normals and
tangents. Eight original albedo textures are retained, limited to 1024 pixels
on their longest side. Source UVs and face/eye textures are retained.

The seated pelvis turns 55 degrees toward the legs while the torso counter-turns
toward the screens. The legs retain the user-selected asymmetric, tucked pose.
Kneecaps and calves share a bending plane; the flat soles follow the pelvis
instead of being counter-rotated toward the camera. Forearms remain crossed
under the head, with the hand backs turned toward the rear screen light.

## Runtime lighting

All character surfaces use per-pixel `StandardMaterial3D` scene lighting with
Lambert diffuse, high roughness and low specular. Emission, rim and backlight
are disabled. There is no character outline shader or screen-space mask.

The existing twelve coloured screen lights remain the only light sources;
ambient energy stays zero. The eye CRT's existing light reaches 4.3 units;
the existing side CRT lights TV_04/TV_05 reach 4.4 units and cast hard shadows.
Their energies and screen colours retain the original settings. The character
uses layer 16; face/eye geometry uses layer 32 and remains outside screen-light
cull masks so the requested front face stays dark. The foreground support CRT
TV_10 does not illuminate the character. Its runtime instance moves to
`(0.20, 1.83, 3.85)` to clear the seated thighs; the saved base wall model is
unchanged by the avatar addition. No new light nodes are created.

All character meshes supply triangle collision for menu occlusion. The runtime
scene is enabled by `scenes/preview/screen_wall_review.tscn`, which is also
embedded by the formal main menu. The existing playable entry remains
`tools/preview_screen_wall.cmd`.
