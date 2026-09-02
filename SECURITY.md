# Security and privacy

`omarchy-motion` is a foreground Bash wrapper around the locally installed
`mpvpaper` player. It runs entirely as the current desktop user.

## Runtime boundary

- It does not request administrator or root access.
- It does not install packages, create services, or add an autostart entry.
- It does not modify Omarchy themes, wallpaper links, Hyprland configuration,
  or shell configuration.
- It opens one owner-scoped runtime lock and launches one `mpvpaper` child.
- Local media paths are passed directly to the local player and are not
  uploaded or transmitted.
- HTTP(S) sources require network access. mpv and `yt-dlp` resolve and retrieve
  those sources according to their own configuration and upstream behavior.
- `--dim-color theme` reads only the active theme's solid `background` value
  from `colors.toml`; it does not read or sample the wallpaper image.

Pressing Ctrl-C terminates the player and reveals the unchanged static
wallpaper underneath.

## Reporting

Please report a security or privacy concern through a private GitHub security
advisory for this repository. Do not include private media URLs in a public
issue.
