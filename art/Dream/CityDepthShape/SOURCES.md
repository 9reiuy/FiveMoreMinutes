# City Depth + Shape assets

These distributable native resources carry the exterior approved in DepthShape03
(parent manifest SHA256 `FD99B71BF4C17E4AD64CFE379B5644CB609BC6B54D9C950A82AF624771FB35DD`).

- `source_city_bank.res`: original connected building meshes from **Blade runner
  style Cityscapes**, **Suraj99**, [Blend Swap 24947](https://blendswap.com/blend/24947).
  The supplied archive records **CC BY 4.0**. This project normalizes source
  orientation, bakes the original procedural materials and supplies cold material
  derivatives. Geometry/UV associations are retained. Fictional sign artwork and
  large wordmark derivatives were authored for this project.
- `own_facade_bank.res`: selected facade components and original material/texture
  bindings derived from the project-supplied **Neo City** asset by **KitBash3D**.
  This project-supplied KitBash3D asset is used under its applicable license.
  The game uses only the necessary converted component bank,
  source textures and separately identified cut-return geometry. No source MAX
  or authoring archive is included here.
- `reference_layout.res`: exact approved 537 local building placements and six
  physical advertisement installations. It is used only when the actual reference
  topology matches, rather than copied onto arbitrary production floors.
- `rigid_modules.res`: five previously checked building/advertisement pairs and
  one separately checked complete eight-metre own-facade advertisement host.
  Production adaptation uses rigid transforms and disjoint placement envelopes.
  Source meshes, UVs and advertised products are not regenerated at runtime.
- `upper_seam_profiles.tres`: 133 upper-profile points from the same 21 selected
  own-facade modules, bound to the unchanged native bank digest. They close the
  seam between the source facade and the actual floor edge below the playable
  surface. This is separately identified adaptation geometry, with no collision
  or source-model replacement.

The native banks bundle their meshes, materials and images. ResourceLoader
dependency inspection found no external paths in any of the four resources.
The upper-profile resource likewise contains only numeric data and attribution
metadata, with no external dependencies.
Runtime shaders and scripts are under `res://shaders/dream3d/city/` and
`res://scripts/dream/city/`. Source archives, experimental caches and machine-local
directories are not runtime dependencies.
