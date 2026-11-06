# Screen wall model — sources and scope

Created 2026-11-06 for the independent FiveMinuteMore screen-wall preview.

| Asset | Author / publisher | Licence | Source |
|---|---|---|---|
| `cc0/televisionvintage.glb`, `cc0/televisionantenna.glb` | Kenney | CC0 1.0 | https://kenney.nl/assets/furniture-kit |
| `cc0/televisionmodern.glb` (downloaded spare; not used in the current composition) | Kenney | CC0 1.0 | https://kenney.nl/assets/furniture-kit |
| `cc0/server_rack.glb` | 3D Assets | CC0 1.0 | https://3dassets.dev/assets/pixel-modern-office-server-rack-477c84f8 |

Kenney's asset page explicitly lists CC0. The direct archive request returned
HTML, so the individual GLBs were downloaded from the public CC0 mirror:
https://github.com/Hidencod/tge-assets . The mirror's licence is preserved as
`cc0/Kenney-LICENSE.txt`. Exact download URLs and original SHA-256 hashes are
recorded in `cc0/asset_sources.json`.

The server publisher identifies the model as its original design, CC0 1.0,
600 triangles, with AI-assisted creation. The downloaded file used
`KHR_mesh_quantization` and WebP texture extensions unsupported by this
project's importer. `tools/prepare_screen_wall_assets.py` converts normalized
geometry attributes to float and losslessly decodes the texture to PNG;
geometry, transforms and animation data are preserved. Converted GLB SHA-256:
`bc052e4db401b17e2b489917f1e6ca5943066de98c73e53b2690ae9d178e41e5`.
Original download and source-page snapshots are retained under
`.runtime/screen_wall_sources_20261106/`.

Licence text: https://creativecommons.org/publicdomain/zero/1.0/

## Project-authored additions

The composition, cable meshes, support frame, supplementary rack drawers,
screen glass, collision shapes, effects and interaction code are new project
work. The vintage CRT geometry is reshaped to vary the screen proportions and
compress its side control panel. Housings use individual charcoal, black and
aged grey finishes; screen colours are independent of casing colours.

The shared picture uses the project's existing `art/Home Screen/` character,
eye and eye-mask assets. The menu uses the project's existing pixel bold font.
These existing game assets are **not** relicensed as CC0 by this manifest.

## Editing and playing

- `screen_wall_model.tscn`: editable Godot model, twelve individually named
  `Televisions/TV_01` … `TV_12` groups, six server racks and separate cable meshes.
- `screen_wall_model.glb`: portable geometry and static material version;
  the Godot CRT shader and interaction do not travel inside GLB.
- `scenes/preview/screen_wall_review.tscn`: runnable interactive sample. It loads
  the editable model scene and installs per-screen effects and input.
- `tools/preview_screen_wall.cmd`: opens the 1280×720 sample with private user
  data; production menus and player saves are not changed.

Each television exposes model metadata `action_id`, `option_text`,
`screen_size` and `screen_tint`. Four screens currently demonstrate
`new_game`, `continue`, `settings` and `quit`; the remaining screens are
independent, unbound display slots. They also react to mouse proximity.

The idle image uses camera-space crop coordinates, so the pieces form one
continuous image even on differently angled screens. The enlarged `TV_07`
is raised into the upper central gap; the two screens below are gathered up
to maintain the central stack. The entire shared crop is anchored to the eye
monitor, so repositioning it keeps the full eye visible without breaking
the common picture into mismatched close-ups. The original eye texture moves
under its fixed alpha mask and follows the mouse with the existing game's
asymmetric -4/+6 horizontal and -4/+4 vertical source-pixel limits, smooth
response, and a three-second idle return. Its original eye colours are kept.

Physical depth raycasts
keep the visible glass clickable and reject foreground occluders. Approach
reveals the screen; clicking outside the glass cannot activate it. Keyboard
navigation reaches the four configured menu options.

The independent preview opens the existing settings panel, and Exit closes
only the preview. New Game / Continue emit distinct signals and acknowledge
the selection; they do not start or overwrite a game. Integration into the
production entry point is pending visual acceptance, as required by AGENTS.md.

All room illumination is emitted by short-range lights parented to the
television screens; global ambient energy is zero and there are no overhead
or directional lights. In Compatibility these lights approximate screen
emission, rather than relying on unsupported emissive global illumination.

To regenerate the baked model after editing the builder, run the review
scene with `-- --rebuild-screen-wall --export-screen-wall`. Normal launches
use the saved model so manual placement edits remain visible.
