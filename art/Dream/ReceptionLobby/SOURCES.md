# Lobby material sources

The lobby carpet now uses **Carpet Texture - Red - Seamless Texture with normalmap** by **Keith333**, published on [OpenGameArt](https://opengameart.org/content/carpet-texture-red-seamless-texture-with-normalmap) under [Creative Commons Attribution 3.0 Unported](https://creativecommons.org/licenses/by/3.0/).

The creator explicitly describes their source as their own photographs, made seamless and accompanied by a generated normal map. This is a photographic carpet colour texture plus the author's generated normal, not a claim of a complete measured PBR scan. Original 2048×2035 files `RedCarpet_S.jpg` and `RedCarpet_N.jpg` remain unchanged in `keith333_red_carpet/`. Download URLs, byte counts and SHA-256 values are recorded in `SOURCE.json` there.

Both complete original maps are bound directly to the material. A restrained burgundy tint, matte roughness and folded low-poly binding suit the lobby. There is no cropped/mirrored sample, histogram reconstruction or synthetic nap field. Source images remain unchanged. Nearest with generated mipmaps, stable 32px/m presentation and unsnapped texture gradients retain the current pixel style as the game Camera moves.

Credit, source, license link and adaptation details are included in `keith333_red_carpet/ATTRIBUTION.txt` and in `data/asset_attributions.txt`. Existing export presets include `data/*`; keep these credits with distributions.

The previous **Caban** wool-fabric candidate by Rico Cilliers and colormass ([Poly Haven](https://polyhaven.com/a/caban), CC0) is no longer used by the lobby carpet. Its unchanged maps and original source record remain in `caban/`; the 2026-11-09 furniture revision reuses them for sofa nap detail, as described below.

## Reference-lobby stone, wood and landing-door metal

The 2026-11-08 reference redesign binds these complete original 1K maps:

| Surface | Original material | Maps and license |
| --- | --- | --- |
| Gray tile floor and counter cap | [Grey Matte Tiles 01 — cgbookcase](https://www.cgbookcase.com/textures/grey-matte-tiles-01) | Base color, normal, roughness; CC0 |
| Gray columns, wall cladding and counter body | [Natural Stone 01 — cgbookcase](https://www.cgbookcase.com/textures/natural-stone-01) | Base color, normal, roughness; CC0 |
| Upper wall panels | [Walnut Veneer — Poly Haven](https://polyhaven.com/a/walnut_veneer), Jenelle van Heerden | Diffuse, OpenGL normal, roughness; CC0 |
| Lobby lift landing door | [Brushed Iron 01 — cgbookcase](https://www.cgbookcase.com/textures/brushed-iron-01) | Base color, normal, roughness, metallic; CC0 |

Each directory has a `SOURCE.json` with download URLs, original bytes and SHA-256 values. Original files are unchanged. The cgbookcase normals use DirectX convention and invert Y on import; the Poly Haven OpenGL normal does not. All maps keep nearest/mipmap sampling and the game's existing resolution. Stone vein contrast is restrained in the lobby material; wood is tinted dark walnut. Door grain is rotated vertically in its local coordinates with shallow normal relief and real beveled edges. These are provider-supplied PBR maps; no claim is made that every set is photographically scanned or measured.

The landing door's metallic response reflects the actual lobby through its existing Forward+ screen-space reflections. It has no painted reflection, extra reflection-probe capture or new ambient fill. Screen-space reflections remain limited to information available in the Camera view. The shared elevator cabin and office landing doors use their existing materials.

The final reference layout has a four-sided stone reception counter and six inner side-wall lifts (A1-A3 / B1-B3). Following the marked carpet revision, it uses two continuous photographic carpet surfaces: the entire upper lift hall and the lower-right foreground rectangle. The lower-left rug is removed, and the six individual landing mats are replaced by the upper hall carpet. Both remaining surfaces reuse the same credited original maps.

## Furniture finish separation studied from Metro_Level

The reception furniture now follows the finish-specific material method in `E:/GameProjects/ArtExperiments/MetroStation_20261108/project/scripts/metro_kit.gd`: keep complete sourced maps, preserve roughness variation within a distinct finish range, and distinguish coated surfaces from bare metal.

The four original 1K maps for [Metal012 — ambientCG / Lennart Demes](https://ambientcg.com/a/Metal012), CC0, were copied unchanged from that local project into `metro_metal012/`. Its `SOURCE.json` records the original download, license, authors and SHA-256 values. Maps now use imported Texture2D resources with mipmaps, including normal-map mip generation, so export dependencies are explicit. No source/compiled files in the Metro project are written. The normal is OpenGL +Y.

The reception-only assignments use existing Walnut Veneer for the dark counter body and warmer table caps, existing Natural Stone 01 for the pale counter cap, and Metal012 for coated frames/kickplates and satin metal hardware. Each finish has its own roughness range, normal strength and texture scale. Wood contrast is adjusted inside the material for the game's viewing distance; original source files remain unchanged. At that material-assignment revision, geometry, UV arrays, lights, reflections, carpets and gameplay stayed intact. Sampling remains nearest/mipmap with stable 32 samples per metre, using the existing game Camera and 640×360 resolution.

## Wear over the existing materials — 2026-11-09

The user's supplied reference specifies scratches, worn areas, dirt and joint buildup over the existing lobby materials. All 19 original stone, walnut, iron, Metal012 and red-carpet images still match their source-manifest hashes. The floor and walls retain their original texture bindings and physical mapping. The lobby-only wear layer adds spatially fixed, sparse scuffs, local soil, modest colour variation and roughness changes; it does not replace their photographs or add a screen-space noise filter. Counter slabs gain small closed chamfers, and waiting areas gain local warm wall lighting. The original `art/Dream/shadow.png` is reused for small character foot contacts.

The rejected floor_tiles_08, granite_tile and painted_plaster_wall candidate files are archived under `.runtime/reception_material_depth_20261109/rejected_surface_sources/`; they are not bound to the lobby. Metro's source assets were not modified. See `docs/reports/reception-surface-wear-20261109.md` for actual Main Camera evidence, scope and validation.

## Tables, sofas and access gates — 2026-11-09

The added furniture revision preserves the original meshes, authored sofa atlas/UVs, established grey-green tint, layout, collisions, lights and game Camera. Table caps reuse the complete Walnut Veneer maps at a more readable grain scale, with local finish abrasion and edge wear; the reception counter retains its separate stone/wood finishes.

Both sofas layer neutral fibre variation from the complete Caban diffuse photograph over the existing authored atlas, with its original OpenGL normal and roughness maps. A gentle change in fibre direction and local fading suggests compressed, used cushions; joints and the lower base collect soil. The bitmap files remain unchanged. All three cloth maps now have imported mip levels for minification, while the shader retains nearest sampling and 32 samples per metre.

The four access-gate bodies reuse the existing Brushed Iron 01 base-colour, normal, roughness and metallic maps. Reader housings and plinths reuse Metal012 with separate coating/roughness settings. Local abrasion and touched areas alter the real light response. The green emitters, transparent retracted wings, geometry, collisions and three passage lanes are preserved.

All 22 original image files match their existing source-manifest SHA-256 records. Actual Main Camera, material restoration, light response, room reload and walking-route evidence is recorded in `docs/reports/reception-furniture-age-20261109.md`.
