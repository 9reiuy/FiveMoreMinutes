# Pause CRT

The single television reuses the approved Kenney CC0 `televisionVintage` from
the parent screen-wall kit. Original source and licence information are in
`../ASSET_SOURCES.md` and `../cc0/Kenney-LICENSE.txt`. No new external model or
sound was downloaded for this interface.

`tools/build_screen_wall_pause_model.gd` reshapes that same housing and curved
glass into a 5.8 by 4.3 screen and saves the editable
`screen_wall_pause_model.tscn`. Its only external dependency is the permanent
project pixel font. The model contains a cabinet, convex raster surface,
screen/cabinet collision shapes, vents, channel label and power indicator.

The pause view uses one screen-associated light, high-roughness cabinet
materials and zero ambient fill. The native 480 by 360 controls are rendered
into the glass at the final 1280 by 720 camera output. The backdrop is black.
The local CRT phosphor hue is `#82ABBA`, matching the reference slider, with
dark selected lettering. This effect only colours this television's UI.

The existing pixel font and main-menu hover cue are reused. Interface drawing,
drop curve, curved pointer mapping, local glow, striped tracks and the settings
scan are project-authored code. Settings transitions retain the previous GPU
buffer and reveal the live page from top to bottom, without copying images
back to the CPU.
