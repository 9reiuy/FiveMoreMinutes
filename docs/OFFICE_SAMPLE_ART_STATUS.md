# Office sample art — 2026-09-22

Status: PARTIAL. Visual legibility and two input-level traversal defects were
addressed; full ten-room human play/art acceptance is still outstanding.

## Implemented

- Default Random Dream entry uses the authored ten-room sample. `use_authored_office_sample=false` retains the previous generator for development; old resources remain.
- Walls and permanent window sills occupy one logical tile. Upper window components are half-depth, centred.
- Room door slabs and elevator panels are half a tile deep. Room-door upper wall geometry and elevator header bar are no longer instantiated. Room-door 2D/3D colliders use the slab depth.
- Five shared 32×32 pixel swatches (paint, wood, fabric, tile, metal), nearest sampling, 32 texels per world unit. Imported furniture remains geometry only; no global mosaic filter or additional lights.
- Room floors/walls, furniture, door finish and elevator panels use the revised materials. Camera and Dash values unchanged.
- South cutaway state follows the active room. Walls use stepped lower-30% wave geometry; doors and breakable windows share static world-space dither clipping. Window collision is unaffected.
- Architectural cap marker resolves to #080808 in the existing final semantic pass. Pantry capture pixel (400,530) verified RGB(8,8,8) both Palette OFF and Palette 1.

## Verified

- `office_sample_test.gd`: 0 failures, all authored furniture instantiated.
- `office_architecture_scale_test.gd`: 354 generated wall colliders, 0 failures; half-depth doors/no upper mesh; external-window geometry bounds.
- `office_window_sill_test.gd`: 0 failures; permanent sill, full/half-depth bullet regions and crossing event.
- `office_furniture_height_test.gd`: 0 failures.
- Compatibility render capture of office, conference, pantry, restroom; shader compilation had no shader errors. Art capture runner also supports the remaining sample rooms.
- The manager, archive, server, lounge, reception and lift now have authored furniture groupings and a shared-atlas detail pass. The lounge's former dark 3x3 accent is replaced by a muted rug aligned with its seating group. The south-facing sample lift cab uses the same lower-wall visual cutaway as the room frontage, leaving the player visible; its 2D collision remains unchanged.
- `office_art_review_test.gd` now covers all ten functional spaces: furniture footprints, door clearance, walkability, a three-cell-wide full-Dash lane, room-owned decoration and matching furniture detail attachments. It reports zero failures. Sample, architecture, window-sill, furniture-height, elevator-animation and elevator/weapon parity tests also pass.
- Compatibility captures for all ten spaces exist at `.runtime/sample_pixel_<room>.png` and `_palette1.png`. For the six newly completed spaces, the previous same-camera captures are retained as `.runtime/office_before_<room>.png`. These are scripted captures, not a claim of manual gameplay acceptance.
- Main headless boot completed. Targeted tracked-file `git diff --check` passed.
- Environment emits certificate/tablet/cache-write warnings; forced test shutdown sometimes reports retained objects/resources. These are not reported as clean shutdown passes.

## Still required

- Full playable art acceptance, room-by-room route width and thick-door swing clearance checks.
- Actual continuous/cross-room Space vault and furniture/landing obstruction tests, not only isolated window event tests.
- Human-directed normal-entry run through all ten rooms, including combat,
  carrier defeat and physical badge pickup, is still required. The current
  recordings are engine-driven input tests, not evidence of a human playthrough.
- A full-room performance pass remains open: fixed-seed rendered process-frame
  samples are high, especially the server room (details below).
- Final visual approval for the Prison Architect/RimWorld-inspired 3D direction. This is not a completed redesign of the five random silhouettes.
- The five-shape runner now tests the optional generator directly, and checks
  the authored sample separately as the production default; 1210 checks pass.
- A full-worktree `git diff --check` still reports the pre-existing trailing blank line in `scenes/ui/dream_hud.tscn`; this art pass does not modify that unrelated UI file.

Do not promote screenshots from the scripted capture runner to a claim of normal-entry gameplay validation. The old door regression runner did not reach its completion marker within the bounded smoke run; it is not counted as passed.

## 2026-09-23 acceptance follow-up

- The authored server/archive floor inputs are brighter without changing the
  optional pack. Their existing two ceiling lights now sit over the equipment
  banks instead of clustering in the central aisle; no lights were added.
  Authored server-rack metal is lighter than the optional pack's rack finish.
  Palette-1 server captures now separate floor, racks, enemies and doorway.
- Shared door/window cut caps now have shallow front, back and end skirts under
  the world-aligned black pixel wave, closing the open clipped cross-section.
  Hinges, permanent window sill and physics were unchanged.
- Actual Player input from the fixed-seed lift exposed an early-trigger bug:
  the player physically left the cab but `player_has_left_elevator_cab` stayed
  false. Departure is now committed when exiting the corridor-side approach
  sensor past the existing door-relative threshold. Input traversal and
  badge-enabled input return reach floor 2. The badge was granted through the
  World API in this isolated input test; it was not acquired through combat.
- At the sample glass, Dash preview originally ignored a breakable pane and
  showed a straight path through its permanent sill. The shared resolver now
  treats windows as Vault targets. Input-event Space crosses the pane and
  breaks it at the Vault contact. The independent sill-height test still passes.
  The first probe sampled at the end of the Vault segment and appeared to be
  100 px short; after waiting for the entire Dash to finish, the same fixed-
  seed test reaches the Preview end exactly (Y=108.5, delta=0). No room
  transition or arrow offset was changed to mask a discrepancy.
- Main's standard Dream-entry method, launched from the Main scene with a
  deterministic RNG, generates the authored sample and elevator. Same-camera
  entrance screenshots: `.runtime/main_entry_palette_off.png` and
  `.runtime/main_entry_palette1.png`. All ten room captures are at
  `.runtime/sample_pixel_<room>.png` and `_palette1.png`.
- Engine-generated input recordings: `.runtime/office_elevator_input.avi`
  (walk out, return with API-granted badge, floor transition) and
  `.runtime/office_window_vault_input_final.avi` (walk to glass, Space Vault
  through the full Preview endpoint).
  These are not manual playthroughs or combat footage.
- Separate fixed-seed, warmed, rendered samples after 120 warm frames and 120
  measured frames: server `TIME_PROCESS` mean 79.477 ms, p95 91.379 ms,
  4 room-owned visible lights/52 visible in the full scene; archive mean
  25.301 ms, p95 26.966 ms, 5 room-owned/56 full-scene. These diagnostic
  process-frame figures are not a stable shipped-game FPS claim. The server
  figure requires further profiling rather than being marked performant.
- Godot editor parse, Main boot/entry, sample/art review, architecture,
  cut-section mesh, window-sill, furniture height, elevator/weapon parity,
  input-level return/Vault and optional-pack tests pass. The unrelated
  HUD trailing blank line at `scenes/ui/dream_hud.tscn:86` remains untouched;
  therefore full-worktree `git diff --check` still fails.
