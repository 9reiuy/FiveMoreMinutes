# Screen-wall hover cue

`screen_wall_hover.wav` is a 0.800-second, 48 kHz, stereo, 16-bit PCM excerpt
of the user-supplied **Deep Tech_DS_Scifi_UI_Modern Neon Breathe.wav**,
revised on 2026-11-07 to match the marked waveform screenshot.

Source creator: **Kenno**, from the source WAV's embedded artist metadata.
The asset was provided from the user's material library; its original rights
remain with its creator.

Source provided by the user:
`C:/Users/Administrator/OneDrive/藤條素材库.library/images/MW645HENC7I0X.info/Deep Tech_DS_Scifi_UI_Modern Neon Breathe.wav`.
Original duration: approximately 1.30727 seconds, 48 kHz stereo float PCM.

## Edit recipe

- Screenshot-matched range: **0.340–1.140 seconds**, total **0.800 seconds**.
- Preserve original playback rate, pitch, stereo and gain.
- Only 4 ms fades at the two cut edges to avoid discontinuities.
- No other layers or filters. Export to 16-bit PCM for the game.
- Output sample peak −13.07 dBFS, RMS −25.61 dBFS, no clipping or loop.
- In the menu and art preview, playback is trimmed by a further 9 dB and routed through
  `UI → SFX → Master`, so the existing volume controls apply.

Rebuild with `tools/build_screen_wall_hover_audio.py`, passing the local source
and output paths. `--start` and `--end` can adjust the cut. `clip_recipe.json`
records the exact edit and hashes under `.runtime/screen_wall_audio_neon_tail_20261107/`.
`modern_neon_breathe_tail.wav` is the identical standalone listening preview.

Source SHA-256:

- User-supplied original: `d933f6d048a499938cee1b17eb32e1ed36ac46c05e8a4184a0aec240e9fe8554`
- Final WAV: `f4e2e95bacf2fbce6f9b5dfc1b7d678dbbdd8a55eb31511369c2e9a2a4b0d1d3`

The cue plays once when focus enters a new television, including keyboard
focus. Staying on that screen does not repeat it. Switching screens rapidly
fades and replaces the current cue instead of stacking multiple voices.
The same cue is used by the formal main menu following the user's 2026-11-07
integration approval. The original 0.800-second edit is unchanged.

## CRT power-off cue

`screen_wall_power_off.wav` is the switch at 3.590 seconds in TRP's CC0
recording of a CRT being turned on and off. The excerpt runs to 3.820 seconds
and is otherwise unprocessed. Duration is **0.230 seconds**, 48 kHz, stereo
16-bit PCM; looping is disabled.
Source: <https://freesound.org/people/TRP/sounds/616850/>.
License: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).

The click peak is set to the previous menu cue. The rest of the excerpt is unchanged:

| Level | Hover | Power off |
|---|---:|---:|
| Average RMS | -25.6051 dBFS | -33.29 dBFS |
| Peak | -13.0664 dBFS | -13.20 dBFS |

The runtime player uses the same `UI` bus and `hover_volume_db` trim (-9 dB)
as hover. A single player with maximum polyphony 1 replaces the previous
switch sound at each television, preventing overlapping voices from increasing
the level. Entering the closing sequence stops the preceding hover sound.

The export-safe `screen_wall_power_off.res` stores the same PCM as an
AudioStreamWAV resource, avoiding a full editor asset scan. Run
`tools/encode_screen_wall_shutdown_audio.gd` with Godot to save the `.res`.
The measured levels are in `screen_wall_power_off.json`.

## Main-menu dream ambience

`screen_wall_ambience.res` embeds the **complete 607.988-second** Quasi Drone
recording by **bassimat**, selected by the user for the main-menu television wall
on 2026-11-08. Source: <https://freesound.org/people/bassimat/sounds/840934/>.
License: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/), including
commercial use and modification without attribution requirements.

The user supplied the original download, not the website's low-quality preview:
`C:/Users/Administrator/Downloads/840934__bassimat__quasi-drone-a-low-frequency-ambient-drone-soundscape.wav`.
It is 233,471,488 bytes, 48 kHz stereo, 32-bit float WAV. Source SHA-256:
`5612aecb92aaa98c291889a6afa4e469b4b6b8431cbe8864ede730c751478eea`.

The runtime copy uses Vorbis quality 5 with its complete timeline, original
pitch, stereo and gain preserved. Only the first and last 10 ms are faded to
avoid a click when the full track loops. The Ogg master is 7,083,958 bytes;
SHA-256 `1ca7cc30ede418f13d339d45687ca8c2e8c281c512f565148ca5376a8e397932`.
Its measured mean level is -14.3 dBFS, matching the source to 0.1 dB.

The menu owns one player at **-30 dB** (3.16% amplitude), routed through the
existing **SFX → Master** controls without changing saved volume settings.
The bed fades in over 2 seconds, keeps playing while menu settings are open,
and fades out over 1.2 seconds during television shutdown. The player is freed
when gameplay starts and recreated once when returning to the menu.
At full bus gain the bed averages approximately -44.3 dBFS, below the existing
hover/power-off cues at approximately -34.6 dBFS after their player trims.

Rebuild with `tools/build_screen_wall_ambience.py --source <original WAV>`,
then run `tools/encode_screen_wall_ambience.gd` with Godot. The Ogg master,
recipe, hashes and validation evidence live in
`.runtime/screen_wall_ambience_20261108/`; the runtime `.res` is self-contained
and does not depend on Downloads or `.runtime`.

## Television snow / static

`screen_wall_static.res` uses **TV Static.wav** by **DiArchangeli**, selected by
the user for the main menu's visible snow on 2026-11-08.
Source: <https://freesound.org/people/DiArchangeli/sounds/116395/>.
License: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).

The downloaded source is Freesound's publicly available **HQ MP3 rendition**,
not the login-only original 96 kHz WAV:
<https://cdn.freesound.org/previews/116/116395_1779874-hq.mp3>.
The source copy is 1,142,592 bytes; SHA-256:
`274618207870ca3eabf2987c441d91607f2023b9e85d7b7ce3544c4dd30a2f49`.

The runtime loop takes seconds **4.000–8.000**, preserves speed, pitch and gain,
and decodes to 48 kHz stereo 16-bit PCM with 2 ms fades at both ends.
PCM master SHA-256:
`41d0efc7a4dca29a83d59af005013cb2f0c1c00fc38b0527ec3e30f59eb8d94b`.
The four-second excerpt measures **−17.83 dBFS RMS / −5.17 dBFS peak**.

The formal main menu owns a dedicated player. Its **−26 dB** trim produces
approximately **−43.83 dBFS RMS** before the existing `UI → SFX → Master` gains.
Actual snow visibility, including hover snow and random full-screen snow,
starts the sound. The last visible snow ending stops it with a 12 ms
anti-click release. Multiple snowy televisions share one continuous voice;
color bars and fine idle grain do not add a static bed. Opening settings
suspends the hidden wall's static sound; closing settings resynchronizes it.
Power-off and menu deletion clear the corresponding sound lifecycle.

The source, decoded master and recipe are preserved under
`.runtime/screen_wall_static_20261108/`. To rebuild the master with FFmpeg:

```text
ffmpeg -ss 4 -i 116395__diarchangeli__tv-static_hq.mp3 -t 4 -af "afade=t=in:d=0.002,afade=t=out:st=3.998:d=0.002" -ar 48000 -ac 2 -c:a pcm_s16le screen_wall_static_loop.wav
```

Place that WAV in the evidence directory and run
`tools/encode_screen_wall_static_audio.gd` with Godot to regenerate the
self-contained runtime `.res`. The existing dream drone, Neon Breathe hover
cue and CRT power-off cue retain their independent playback and levels.

### Tutorial television speech

On 2026-11-08 the user also selected this static sound to replace the tutorial
televisions' old typewriter blips. `tutorial_tv_speech_audio.gd` reuses the same
runtime `.res`, **−26 dB** trim, original pitch and `UI → SFX → Master` route.
One player belongs to the tutorial world; multiple television lines do not
stack voices or create extra copies of the audio asset.

The existing dialogue clock enables the sound only while text is being typed.
Reading time and line-transition gaps stay quiet. The repeated television
calls use the existing call-visibility window and stop in its silent interval.
The television must be on and powered. The 交谈 interaction hint stays silent;
cancellation, death, power loss, tutorial exit and scene removal stop speech.
The player pauses with the lesson and uses 12 ms anti-click edges.

Tutorial sequences explicitly set `blip_sound` to an empty event ID, disabling
their former text blips. Shared NPC dialogue keeps its original default sound.
Validation and measured playback levels are recorded in
`docs/reports/tutorial-tv-speech-static-20261108.md`.
