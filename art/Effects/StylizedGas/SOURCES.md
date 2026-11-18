# Stylized gas assets

- `cloud_mesh.res`: original UV-sphere/Voronoi cloud mesh generated locally for this project on 2026-11-16. Packaged without changing positions, normals or UVs; 11,904 unindexed vertices / 3,968 triangles, radius approximately 0.58 m. Original generation parameters and raw comparison data remain in the private visual-study evidence.
- `cloud_mesh_indexed.res`: the same visible triangles with 2,143 shared position/normal/UV vertices. Expanding the indices was checked against every original input attribute; no visible geometry was removed.
- `cloud_shadow.res`: a 248-triangle shadow-only LOD generated from that indexed mesh with Godot ImporterMesh. The high-detail visible mesh is retained. Both draws read the same parcel data and motion material; the proxy preserves real shadow projection at a bounded cost.
- `tutorial_noise.png`: the exact `T_Noise_001R.png` supplied by the user in `Stylized Smokes - Tutorial-20250330T144554Z-001.zip`, used at the user's explicit request to reproduce the effect. No license file accompanied the supplied archive. Registered as user-provided reference material; commercial redistribution rights are not asserted by this record.
- `cloud_noise.res`: lossless native ImageTexture serialization of the preceding user-supplied image. No resampling, noise regeneration, mipmaps, recoloring or filtering changes were applied while packaging.
- Cloud material and particle-motion code are project-authored Godot implementations. No SIGNALIS, Midnight Fight Express or other unpacked game assets were imported.

This change packages assets for the user's local game integration; it does not publish or redistribute the project externally.
