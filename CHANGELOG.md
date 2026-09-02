# Changelog

## 1.2.1 - 2026-09-01

- Detect local H.264 files outside the hardware-friendly 8-bit 4:2:0 formats
  and select software decoding immediately, avoiding noisy Vulkan/CUDA probe
  failures before mpv's otherwise successful fallback.

## 1.2.0 - 2026-09-01

- Reveal video over the unchanged Omarchy background with transparent startup
  transitions: fade, Omarchy-style center opening, circle, dissolve, pixelize,
  and blur.
- Add transition duration controls, transition aliases, and synchronized audio
  fading.
- Remove the temporary transition graph after startup so hardware-decoded
  playback resumes normally and loops do not replay the effect.
- Preserve black and theme-color dimming across the transition handoff.

## 1.1.0 - 2026-09-01

- Add explicit `--audio` / `--no-audio` and `--loop` / `--no-loop` toggles.
- Retain `--once` and add `--mute` and `--unmute` as friendly aliases.
- Add `--display`, `--cover`, and `--contain` convenience aliases.

## 1.0.0 - 2026-09-01

- Play local files and web videos as a chrome-free Omarchy wallpaper with
  retained audio.
- Support cover/contain placement, display selection, looping, volume, and web
  quality limits.
- Add black or active-theme-base dimming, including copy-back decoding for
  GPU-decoded YouTube streams.
- Prevent concurrent wallpaper players with a per-user runtime lock.
