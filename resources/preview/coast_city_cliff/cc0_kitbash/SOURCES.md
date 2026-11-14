# Coastal kitbash sources — 2026-11-11

This folder contains optimized native Godot derivatives of the following
Poly Haven assets. The asset pages and Poly Haven's
[license statement](https://polyhaven.com/license) identify these assets as
**CC0 1.0**. Source files, API metadata, source MD5 checks, SHA-256 receipts,
and conversion scripts are retained in `.runtime/coast_cc0_20261111`.

| Asset | Author(s) | Use / changes |
| --- | --- | --- |
| [Coast Rocks 03](https://polyhaven.com/a/coast_rocks_03) | Rob Tuytel, Rico Cilliers | Coastal scan reduced from 813,464 triangles in the downloaded glTF to 8,000; UVs and 1K colour/normal/roughness maps retained. Seven scaled/rotated shoreline placements; source maps also shade the existing continuous terrain. |
| [Modular Urban Apartments Facade](https://polyhaven.com/a/modular_urban_apartments_facade) | James Ray Cock | Selected windows, door, base and cornice modules rearranged on coastal structures. Source UVs retained; 256px derivative atlases and original normal/roughness information. Repeated windows use MultiMesh. |
| [Modular Industrial Pipes 01](https://polyhaven.com/a/modular_industrial_pipes_01) | Jorge Camacho | Rusted pipe segments, elbows, tee and valve arranged as wall-mounted utilities; the valve reduced to 1,400 triangles. 256px derivative maps. |
| [Ribbed Concrete Wall](https://polyhaven.com/a/ribbed_concrete_wall) | Charlotte Baglioni | Colour, OpenGL normal and ARM maps, reduced to 128px and repeated every four metres on structural concrete. |
| [Worn Cracked Plaster](https://polyhaven.com/a/worn_cracked_plaster) | Amal Kumar | Colour, OpenGL normal and ARM maps, reduced to 128px and repeated every four metres on wall panels. |
| [Kloppenheim 07 (Pure Sky)](https://polyhaven.com/a/kloppenheim_07_puresky) | Greg Zaal, Jarod Guest | 1K HDR night-sky panorama, sampled in world direction and graded to the scene's dark teal sky. Used as background, not claimed as a real-time GI solution. |

The concrete supports, cladding ribs, service cabinets, abstract sign graphics,
their arrangement, and the scene shaders are original project work. Near
surfaces use actual scene lights and real material normals, high roughness,
low specular and zero metallic. The material bank stores nearest/mipmap
defaults. Following the user's removal of pixelization, the right-shore
preview renders at window resolution and clones these materials with linear
anisotropic filtering; its environment shaders likewise use linear mipmaps.
The sky uses linear sampling. Concrete/plaster tiles are 32 texels/metre;
scan and UV-atlas densities depend on their retained source UVs and placement.

**The complete scene is not wholly CC0.** The existing seven large city-body
shapes are derivatives of *Blade runner style Cityscapes* by **Suraj99**,
CC BY 4.0, as documented in `../silhouette_city/SOURCES.md` and
`art/Dream/CityDepthShape/SOURCES.md`. Existing project characters and other
retained assets keep their original rights and provenance.

The right-shore scene is a visual preview. Its CC0 materials and geometry are
not automatically promoted into the chapter's default/formal coastal scene.
