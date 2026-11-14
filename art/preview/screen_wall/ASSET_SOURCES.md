# Screen wall model — sources and scope

Created 2026-11-06 for the independent FiveMinuteMore screen-wall preview.

The subsequently added user-supplied VRM avatar has separate source metadata,
editable/portable files and lighting notes in [avatar/ASSET_SOURCES.md](avatar/ASSET_SOURCES.md).

The matching single-CRT pause interface reuses the same television; see
[pause/ASSET_SOURCES.md](pause/ASSET_SOURCES.md) for its local UI and asset scope.

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
- `tools/preview_screen_wall.cmd`: now opens the formal game entry at 1280×720
  with private preview user data. New Game / Continue use real game flow in
  that private profile. The existing normal player profile is kept separate.
- `scripts/ui/screen_wall_main_menu.gd`: embeds the wall in the formal
  `scenes/ui/main_menu.tscn` and retains its existing settings, save-overwrite,
  exit confirmation, version announcement and community-link behavior.

Each television exposes model metadata `action_id`, `option_text`,
`screen_size`, `screen_tint` and `navigation_order`. The menu follows the
annotated layout supplied on 2026-11-07:

| Position | Television | Action | Label |
|---|---|---|---|
| Upper left | `TV_01` | `continue` | 继续 |
| Enlarged central eye screen | `TV_07` | `new_game` | 新游戏 |
| Middle left | `TV_06` | `settings` | 设置 |
| Lower left | `TV_09` | `quit` | 退出 |

Keyboard navigation follows this same order. The remaining screens are
independent, unbound display slots. They also react to mouse proximity.
Optional `option_center_uv` and `show_option_caption` metadata control label
placement. Settings uses the exposed lower-left glass area so the enlarged
foreground television cannot obscure its text.

The idle picture uses camera-space crop coordinates. Eleven screens retain
the previously accepted wide picture (crop scale 0.55), independently of the
eye close-up. `mosaic_anchor_position` retains that picture's original anchor.
The central `TV_07` glass is widened to 2.75 × 1.90 and shifted left to match
the user's red outline. The two screens below remain gathered up to maintain
the central stack. Only `TV_07` gets an independent close-up, with the full
eye occupying approximately 86% of its glass width, subject to vertical
clearance. The eye framing is shifted right by 5% of the glass width. Its
zoom and offset follow the projected glass; `eye_monitor_path` selects this
monitor. The original eye texture moves
under its fixed alpha mask and follows the mouse with the existing game's
asymmetric -4/+6 horizontal and -4/+4 vertical source-pixel limits, smooth
response, and a three-second idle return. Its original eye colours are kept.

The glass carries animated fine monochrome snow at idle, reduced over menu
lettering. Proximity still produces a stronger short static transition.
A screen-reading canvas pass adds a soft halo around bright glass while
preserving the base pixel image and outer darkness. This effect uses the
existing Compatibility renderer and adds no room or ambient lights. The
canvas mipmap sampling follows Godot's
[screen-reading shader documentation](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html).

Physical depth raycasts
keep the visible glass clickable and reject foreground occluders. Approach
reveals the screen; clicking outside the glass cannot activate it. Keyboard
navigation reaches the four configured menu options.

The direct `screen_wall_review.tscn` art preview remains isolated. In contrast,
the formal main-menu adapter connects the four televisions to existing game
actions, disables Continue when there is no valid save, and blocks the wall
while a modal is open. The user authorized formal integration on 2026-11-07
after confirming the resource-cap fix. Independent GameTestLab admission ran
before the formal scene was switched; evidence is in
`.runtime/screen_wall_menu_promotion_20261107/`.

The footer shows the configured version and community number. Ordinary game
and preview entries share a 60 FPS foreground / 30 FPS background budget,
including while gameplay is paused. Scripted diagnostics can opt in using
`-- --enforce-frame-budget` when their measurement requires the normal budget.

Starting or continuing a game now closes the televisions from the projected
perimeter inward. Each screen contracts to a line and dot over 0.22 seconds,
including its screen spill. After all eleven other screens are off, the eye
remains intact for 0.55 seconds before switching off. Only then is the game
request emitted. The existing save-overwrite confirmation precedes the
sequence. A single quiet power-off audio player shares the hover gain and
UI bus; source/level information is in the audio source document.

The final CRT revision uses a brighter, more saturated palette led by
`#396FE2`, cyan and violet, with a few amber accents. Per-glass projected
barrel distortion bends the picture, menu text and horizontal raster inside
the convex glass. A dark curved overscan edge, fine 24 Hz reception grain,
subtle RGB phosphor columns and glass glare complete the tube effect. The
iris retains its original texture colors and tracking limits. All placements,
glass dimensions, mesh vertices and collision shapes were checked against
the previous model before saving the updated color metadata and static
materials: 955 nodes / 833 mesh surfaces, zero geometry differences.

Entering a screen also plays the 0.800-second user-selected Neon Breathe tail in
`sfx/preview/screen_wall_hover.wav`. It uses the existing UI/SFX volume route,
does not loop while hovering, and replaces the prior cue on a rapid switch.
Its user-supplied library source and reproducible edit recipe are recorded
in `sfx/preview/SCREEN_WALL_AUDIO_SOURCES.md`.

All room illumination is emitted by short-range lights parented to the
television screens. Each light directly uses that screen's saturated tint,
with no white blend. Global ambient energy is zero and there are no overhead
or directional lights. In Compatibility these lights approximate screen
emission, rather than relying on unsupported emissive global illumination.

To regenerate the baked model after editing the builder, run the review
scene with `-- --rebuild-screen-wall --export-screen-wall`. Normal launches
use the saved model so manual placement edits remain visible.
