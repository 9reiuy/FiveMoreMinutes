# Quaternius Modular Sci-Fi Megakit — free Standard tier

- Author: Quaternius.
- Official pack: https://quaternius.com/packs/modularscifimegakit.html
- Author's download page: https://quaternius.itch.io/modular-sci-fi-megakit
- License: CC0 1.0 Universal, preserved verbatim in `License_Standard.txt`.
- Acquired 2026-11-15; original Standard archive SHA256 and official download are recorded in `ACQUISITION.json`. No paid Pro/Source files are used.
- `ASSET_MANIFEST.json` maps selected files to their original glTF files and hashes. `CONVERSION.json` records native Godot bounds, surface names and triangle counts.
- Godot converts the existing geometry to compressed `.scn` resources and shares identical original textures/materials. No mesh vertices, topology or UVs are modeled or changed.
- `OriginalGlassSurface.scn` is the original `M_Glass` surface 2 from `WallWindow_Straight`, copied verbatim, with 2 source triangles. It removes the unrelated opaque window cladding by selecting the existing glass surface; it does not generate new glass geometry.
- The level assembles these modules using transforms and chooses transparent glass. Following the user's style correction, architectural finishes directly reuse `maintenance_concrete.gdshader` from 0-1/0-2 and `transit_surfaces.gdshader` from 0-4/0-5. The same 32-texel density, local lighting, optics and top-black treatment are used. The rejected standalone photographic shader is removed.

The original acquisition ZIP, extracted pack, raw glTF dependencies and conversion scripts are retained under `.runtime/research_atrium_cc0_20261115` for audit. Author preview images are research references, not game textures.
