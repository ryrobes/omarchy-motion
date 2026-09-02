# omarchy-motion

`omarchy-motion` plays a local video or web video as the Omarchy desktop
background while retaining its audio. It is deliberately just content: no
window, controls, borders, tray icon, or other chrome.

It does not change the current Omarchy theme, background symlink, Hyprland
configuration, or shell configuration. The video runs on the Wayland `bottom`
layer above Omarchy's existing static background and below normal windows.
When the process exits, the existing background is visible again immediately.

## Install

### Local package build with yay

Until `omarchy-motion` can be uploaded to the AUR, install it directly from
this repository. `yay` resolves the dependencies, builds the checked-in
`PKGBUILD`, and installs the resulting package through pacman:

#### Option 1: keep a local clone

```bash
git clone https://github.com/ryrobes/omarchy-motion.git
cd omarchy-motion
yay -Bi packaging/aur
```

To update this installation later, pull the latest packaging metadata and
build it again:

```bash
cd omarchy-motion
git pull --ff-only
yay -Bi packaging/aur
```

#### Option 2: temporary one-shot build

If you do not want to keep a clone, this performs the same build in a temporary
directory and removes that directory afterward:

```bash
(
  dir="$(mktemp -d)"
  trap 'rm -rf -- "$dir"' EXIT

  git clone --depth=1 https://github.com/ryrobes/omarchy-motion.git "$dir"
  yay -Bi "$dir/packaging/aur"
)
```

The subshell keeps the temporary variable and cleanup trap isolated from your
terminal. The commands are written out explicitly so they can be inspected
before running; this is not a remote `curl | bash` installer.

This is still a normal tracked Arch package: inspect it with `pacman -Qi
omarchy-motion` and remove it with `omarchy pkg drop omarchy-motion`.

### From source

The application is one Bash executable. Clone or download a release, then
install it for the current user:

```bash
install -Dm755 omarchy-motion "$HOME/.local/bin/omarchy-motion"
```

Confirm the installed version:

```bash
omarchy-motion --version
```

## Requirements

- Omarchy 4.x / Hyprland
- `mpvpaper`
- `mpv`
- `yt-dlp` for web video

The local package declares these runtime dependencies. For a manual source
install, they can be installed through Omarchy:

```bash
omarchy pkg add mpv mpvpaper yt-dlp
```

## Run

From this repository:

```bash
./omarchy-motion ~/Videos/ambient.mp4
```

Or use a YouTube URL:

```bash
./omarchy-motion 'https://www.youtube.com/watch?v=VIDEO_ID'
```

The player stays attached to the terminal. Press `Ctrl-C` to stop it and reveal
the unchanged Omarchy background.

By default the source loops, covers all displays, crops to fill, retains audio
at 100%, uses hardware decoding when available, and caps web video at 1080p.

Disable audio or looping with the friendly toggles:

```bash
./omarchy-motion --mute --no-loop ~/Videos/ambient.mp4
```

`--no-audio` is equivalent to `--mute`, `--unmute` is equivalent to `--audio`,
and the existing `--once` option is equivalent to `--no-loop`. Explicit audio
and loop flags are useful when building commands dynamically.

Dim toward black with `--dim`:

```bash
./omarchy-motion --dim 35 ~/Videos/ambient.mp4
```

Or tint the dimming overlay with the active theme's solid `background` color:

```bash
./omarchy-motion --dim 35 --dim-color theme ~/Videos/ambient.mp4
```

`--dim-color theme` reads the current staged theme's `colors.toml` when the app
starts. It uses only that solid color—not the theme's existing background
image—and it does not change any theme files or symlinks. Dimmed playback uses
copy-back hardware decoding so the overlay also works with GPU-decoded YouTube
formats such as AV1.

```text
Usage: omarchy-motion [OPTIONS] SOURCE

Options:
  -o, --output OUTPUT     Display to cover (default: ALL; alias: --display)
      --fit MODE          cover or contain (default: cover)
      --cover             Fill the display, cropping as needed
      --contain           Fit the whole video without cropping
  -v, --volume PERCENT    Playback volume, 0-100 (default: 100)
      --audio, --unmute   Enable audio (default)
      --no-audio, --mute  Disable audio
      --dim PERCENT       Overlay opacity, 0-100 (default: 0)
      --dim-color MODE    Dim toward black or theme (default: black)
      --quality HEIGHT    Maximum web-video height; 0 disables cap (default: 1080)
      --loop              Loop playback (default)
      --no-loop, --once   Play once instead of looping
      --dry-run           Print the mpvpaper command without starting it
      --version           Show the program version
  -h, --help              Show help
```

Examples:

```bash
# Contain instead of crop, at 60% volume
./omarchy-motion --fit contain --volume 60 ~/Videos/film.mp4

# Cover one display
./omarchy-motion --display DP-1 ~/Videos/ambient.mp4

# Fit the whole video, mute it, and play it once
./omarchy-motion --contain --mute --no-loop ~/Videos/ambient.mp4

# Dim 45% toward the active theme's solid base color
./omarchy-motion --dim 45 --dim-color theme ~/Videos/ambient.mp4

# Play once and leave YouTube quality uncapped
./omarchy-motion --once --quality 0 'https://youtu.be/VIDEO_ID'

# Options may also follow a quoted URL
./omarchy-motion 'https://youtu.be/VIDEO_ID' --dim 35 --dim-color theme
```

Use `mpvpaper --help-output` to list the available output names.

## Notes

- Only one `omarchy-motion` process may run at a time, preventing invisible
  wallpaper players and duplicate audio from stacking.
- YouTube playback depends on the network and `yt-dlp`. Private, restricted, or
  authenticated videos may not work without additional mpv/yt-dlp setup.
- A continuously decoding video uses more power than a static background.
- This app is manually started and does not install an autostart entry.

## Security and privacy

`omarchy-motion` runs as the current desktop user and does not request elevated
access, install packages, create services, or modify Omarchy/Hyprland
configuration. Local sources stay local. For web sources, mpv delegates URL
resolution and media retrieval to `yt-dlp`; normal network access is therefore
required for that playback mode.

See [SECURITY.md](SECURITY.md) for the complete runtime boundary.

## License

[MIT](LICENSE)
