# Ground Explosion volume

Author: JangaFX. License: CC0; original license is included as `LICENSE.txt`.
Source: https://jangafx.com/software/embergen/download/free-vdb-animations#asset-9
Original archive: GroundExplosionVDB.zip
SHA256: `47c2c1d352b3c0dce31e462d09ede9f8bc95b5333ca9764564073b02113dc7b9`.

`ground_explosion_volume.res` contains 101 immutable RG8 Texture3D frames
from the original 200-frame density/flames sequence. Source frames are
sampled at stride 2 (plus frame 199), area-averaged over 4 source voxels.
Density and heat use square-root encoding with decode scales 2 and 8.
The source motion is retained and retimed by the visual-only burst player.
The local shader grades integrated gas colors; no global palette is used.

The binary resource references its resource script and all embedded textures,
and is preloaded by the shared explosion backend. Runtime has no dependency
on the experiment directory, original VDB files, or external downloads.
Rebuild with `tools/build_explosion_volume.gd -- --source-dir=<converted RG8 directory>`.
