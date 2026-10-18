# Sample dressing refresh: remove quadratic identity scans

## Scope

This change is confined to `sample_wall_and_desktop_review.gd`, used by the
independent FurnitureTextureReview sample. It does not remove buildings,
furniture, window lighting, shadows, gameplay updates, or desktop detail.
It is not a claim that all production random-floor stutter is fixed.

The existing half-second discovery cadence is retained. Each refresh builds a
temporary dictionary of live node instance IDs; newly discovered records are
added to that dictionary immediately. Original weak-reference records remain
the authority for material restoration, mode switches and geometry. Dead
records are still filtered on every refresh, so no cross-floor persistent ID
cache is introduced.

## Diagnosis

RTX 5070 Ti / Godot 4.7.1 Compatibility, NVIDIA 610.74, muted runs.

- Frozen formal camera, city off/on: median 3.081 / 2.988 ms, P95 4.161 /
  3.920 ms, 1156 / 1159 draw calls. This is only a static isolation result;
  it does not prove live city rendering is free.
- Connected native profiler recorded 117 dressing refreshes in 60 seconds,
  over 4.5 million linear membership callbacks. Profiling adds overhead;
  the instrumented frame timings are not the live-performance baseline.
- Existing `walls.any` inside a per-wall loop made discovery quadratic even
  after the entire layout was already registered.

## GPU parity and local CPU result

`tests/review_refresh_index_test.gd`: 28 checks, 0 failures, exit 0. Three
generated sample lifecycles, 278 walls, 15 windows, 7 doors each. All four
pixelation/Palette combinations have byte-identical formal-camera GPU images
between original and indexed membership. Repeated refreshes do not duplicate
records; invalid weak references are discarded.

| Sample | Original median | Indexed median | Original repeat median |
| --- | ---: | ---: | ---: |
| 0 | 10.314 ms | 0.399 ms | 9.749 ms |
| 1 | 9.635 ms | 0.363 ms | 9.409 ms |
| 2 | 10.194 ms | 0.495 ms | 9.787 ms |

Each column is 30 direct refresh calls, not FPS. Full-game validation must be
reported separately. GPU before/after: `.runtime/review_index_before.png` and
`.runtime/review_index_after.png`. Evidence: `.runtime/review_index_gpu.log`.

The legacy comparison is reconstructed in memory by diagnostic tests only;
the production script has no legacy mode and no new settings.

The parity test was repeated with the arrival animation disabled and the
formal camera inside the furnished office (not the arrival mask): again
28 checks / 0 failures / exit 0. Three indexed medians: 0.368, 0.373,
0.409 ms; original/repeat medians 9.113–11.801 ms. Evidence:
`.runtime/review_index_gpu_office.log`. Saved before/after images now show
this office camera. Certificate-store warning is environmental, not an
assertion failure.

## Same-live-world verification

Separate 60-second runs did **not** establish a whole-session speedup:
baseline median/P95 13.750/26.573 ms (6 enemy shooters, 525 enemy shots),
candidate 17.615/31.673 ms (7 shooters, 428 enemy shots, more blood/death
updates). Do not present this pair as a performance win.

To isolate the actual periodic stall without changing AI, weapons, light
budgets or damage, `--review-refresh-ab` alternates original/indexed lookup
on successive scheduled refreshes within one uninterrupted live session.
Both branches run the same refresh work and register the same objects. Frame
timings are matched to the process-frame ID of the refresh.

| Same session, refresh-frame samples | Original | Indexed |
| --- | ---: | ---: |
| Samples | 59 | 60 |
| Refresh CPU median / P95 | 9.258 / 12.148 ms | 0.713 / 1.015 ms |
| Whole refresh-frame median / P95 | 22.651 / 26.815 ms | 13.760 / 16.781 ms |

Actual live workload: 3 enemy shooters, 366 enemy shots, 431 player shots,
10-second warmup and 60-second sampling, 640x360 world. Earlier logs' output
size came from `ViewportTexture.get_size()` and must not be treated as the
physical GPU image size (see correction below).
The mixed-session P95 15.437 ms is **not** a candidate-only whole-game result.
This demonstrates removal of about 9 ms from the periodic refresh frame,
not resolution of every occasional rendering/driver stall. RTX 3060/RX 6600
and production random-floor whole-session performance remain unverified.

Evidence: `.runtime/city_review_same_world_ab.log`. Exit resource warnings
(4 ObjectDB / 2 resources) remain separately reported; all live-run assertions
passed. No background geometry/light/detail was removed to obtain the result.

## Engineering regression boundary

- Editor parse: exit 0, no script/parse errors.
- `office_art_review_test.gd` is **not green**: 13 failures involving pantry,
  archive, server and lounge counts/details plus regenerated decoration count.
  Temporarily restoring the original three membership searches and rerunning
  gives the same 13 assertion labels, exit 1. The indexed production logic was
  restored immediately afterwards. These failures are not hidden or fixed by
  weakening assertions. Baseline and current logs:
  `.runtime/review_index_art_baseline.log`,
  `.runtime/review_index_art_regression.log`.
- Headless dummy-material and shutdown resource warnings are separate from
  assertion failures. This change does not claim complete shutdown cleanup.

## Output-resolution measurement correction

This Godot/runtime combination reports a stretch-multiplied value from
`root.get_texture().get_size()`: setting the Window to 1920x1080 yielded a
reported 5760x3240, but the actual `get_image().get_size()` and PNG dimensions
were 1920x1080. This is an observed diagnostic discrepancy, not evidence that
the GPU rendered 5760x3240. Output labels now use the actual GPU image outside
the timed sampling loop. `--output-1080` verifies that image size before
generation and aborts rather than silently claiming an incorrect resolution.

The first purported 1080p run actually **was** 1080p: metadata label was wrong.
59 refresh-frame samples per arm; legacy/indexed median 21.505/12.222 ms,
P95 27.340/17.078 ms, refresh CPU medians 9.208/0.734 ms. 5 enemy shooters,
534 enemy shots, 431 player shots; 23 checks / 0 failures, exit 0.
Evidence: `.runtime/city_review_same_world_1080.log` and
`.runtime/city_output_size_probe.log`. A further run uses image-verified output
reporting. The formal world remains 640x360; this work does not alter the
approved production pixel grid to 480x270.

Image-verified 1080p repeat: 24 checks / 0 failures / exit 0,
59 legacy / 60 indexed scheduled refreshes in one live world. Refresh CPU
median 9.337 / 0.752 ms; whole refresh-frame median 22.810 / 13.895 ms,
P95 27.692 / 19.702 ms. 3 enemy shooters, 377 enemy shots, 428 player shots.
Mixed-session median/P95 12.108/17.319 ms is not a candidate-only claim.
Evidence: `.runtime/city_review_same_world_1080_image_verified.log`.

The random-floor performance reporter was also corrected to read GPU image
dimensions after its timed loop. This changes reporting only, not resolution,
gameplay or the sampling workload. Old output-size labels are not trustworthy
without checking their associated GPU images.
