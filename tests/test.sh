#!/usr/bin/env bash

set -uo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
app="$repo_dir/omarchy-motion"
tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT

passed=0
failed=0

pass() {
  printf 'ok - %s\n' "$1"
  passed=$((passed + 1))
}

fail() {
  printf 'not ok - %s\n' "$1" >&2
  failed=$((failed + 1))
}

assert_contains() {
  local name="$1"
  local haystack="$2"
  local needle="$3"

  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$name"
  else
    printf '  expected output to contain: %s\n' "$needle" >&2
    printf '  actual output: %s\n' "$haystack" >&2
    fail "$name"
  fi
}

assert_not_contains() {
  local name="$1"
  local haystack="$2"
  local needle="$3"

  if [[ "$haystack" != *"$needle"* ]]; then
    pass "$name"
  else
    printf '  expected output not to contain: %s\n' "$needle" >&2
    printf '  actual output: %s\n' "$haystack" >&2
    fail "$name"
  fi
}

assert_status() {
  local name="$1"
  local expected="$2"
  local actual="$3"

  if [[ "$actual" == "$expected" ]]; then
    pass "$name"
  else
    printf '  expected status: %s; actual: %s\n' "$expected" "$actual" >&2
    fail "$name"
  fi
}

media_file="$tmp_dir/video with spaces.mp4"
touch "$media_file"

output="$($app --version)"
assert_contains "reports the packaged version" "$output" "omarchy-motion 1.2.1"

output="$($app --dry-run "$media_file")"
assert_contains "uses the bottom layer" "$output" "--layer bottom"
assert_contains "retains audio" "$output" "audio=auto"
assert_contains "uses copy-back decoding for the default transition" "$output" "hwdec=auto-copy-safe"
assert_contains "fades in from the existing background by default" "$output" "transition=fade:duration=0.8"
assert_contains "keeps the transition surface transparent" "$output" "background=none"
assert_contains "fades audio with the default transition" "$output" "afade=t=in:st=0:d=0.8"
assert_contains "loops by default" "$output" "loop-file=inf"
assert_contains "covers by default" "$output" "panscan=1.0"
assert_contains "resolves local path" "$output" "video\\ with\\ spaces.mp4"
if [[ "$output" != *"drawbox"* ]]; then
  pass "dimming is disabled by default"
else
  fail "dimming is disabled by default"
fi

output="$($app --dry-run --no-transition "$media_file")"
assert_contains "no-transition restores the normal decode path" "$output" "hwdec=auto-safe"
assert_not_contains "no-transition omits the transition graph" "$output" "xfade="
assert_not_contains "no-transition omits audio fading" "$output" "afade="

output="$($app --dry-run --fit contain --volume 42 --once --output DP-1 "$media_file")"
assert_contains "contain mode does not crop" "$output" "panscan=0.0"
assert_contains "passes requested volume" "$output" "volume=42"
assert_contains "passes requested output" "$output" "DP-1"
if [[ "$output" != *"loop-file=inf"* ]]; then
  pass "once mode disables looping"
else
  fail "once mode disables looping"
fi

output="$($app --dry-run --mute --no-loop --display HDMI-A-1 --contain "$media_file")"
assert_contains "mute alias disables audio" "$output" "audio=no"
assert_contains "display alias selects an output" "$output" "HDMI-A-1"
assert_contains "contain alias does not crop" "$output" "panscan=0.0"
if [[ "$output" != *"loop-file=inf"* ]]; then
  pass "no-loop alias disables looping"
else
  fail "no-loop alias disables looping"
fi

output="$($app --dry-run --no-audio --unmute --once --loop --cover "$media_file")"
assert_contains "unmute alias can re-enable audio" "$output" "audio=auto"
assert_contains "cover alias fills the display" "$output" "panscan=1.0"
assert_contains "loop flag can re-enable looping" "$output" "loop-file=inf"

output="$($app --dry-run --transition omarchy --transition-duration 1.2 "$media_file")"
assert_contains "omarchy transition opens from the center" "$output" "transition=vertopen:duration=1.2"
assert_contains "custom transition duration also fades audio" "$output" "afade=t=in:st=0:d=1.2"

output="$($app --dry-run --transition circle --no-audio-fade "$media_file")"
assert_contains "circle transition uses an opening iris" "$output" "transition=circleopen"
assert_not_contains "audio fading can be disabled" "$output" "afade="

for transition_case in dissolve pixelize; do
  output="$($app --dry-run --transition "$transition_case" "$media_file")"
  assert_contains "$transition_case transition is available" "$output" "transition=$transition_case"
done

output="$($app --dry-run --transition blur "$media_file")"
assert_contains "blur transition uses horizontal blur" "$output" "transition=hblur"

output="$($app --dry-run --fade-in "$media_file")"
assert_contains "fade-in alias selects fade" "$output" "transition=fade"

probe_bin="$tmp_dir/probe-bin"
mkdir -p "$probe_bin"
cat >"$probe_bin/ffprobe" <<'FAKE_FFPROBE'
#!/usr/bin/env bash
printf 'codec_name=h264\npix_fmt=yuv444p\n'
FAKE_FFPROBE
chmod +x "$probe_bin/ffprobe"
mov_file="$tmp_dir/h264-444.mov"
touch "$mov_file"
output="$(PATH="$probe_bin:$PATH" $app --dry-run --transition pixelize "$mov_file")"
assert_contains "selects software decoding for H.264 4:4:4 media" "$output" "hwdec=no"
assert_not_contains "does not probe incompatible copy-back decoders" "$output" "hwdec=auto-copy-safe"

cat >"$probe_bin/ffprobe" <<'FAKE_FFPROBE'
#!/usr/bin/env bash
printf 'codec_name=h264\npix_fmt=yuv420p\n'
FAKE_FFPROBE
output="$(PATH="$probe_bin:$PATH" $app --dry-run --transition pixelize "$mov_file")"
assert_contains "retains hardware decoding for H.264 4:2:0 media" "$output" "hwdec=auto-copy-safe"

output="$($app --dry-run --volume 08 "$media_file")"
assert_contains "accepts decimal values with a leading zero" "$output" "volume=8"

output="$($app --dry-run --dim 35 "$media_file")"
assert_contains "dims toward black by default" "$output" "color=0x000000@0.35:t=fill"
assert_contains "uses copy-back hardware decoding when dimmed" "$output" "hwdec=auto-copy-safe"

output="$($app --dry-run --no-transition --dim 35 "$media_file")"
assert_contains "dimming without a transition retains its video filter" "$output" "vf=lavfi="
assert_not_contains "dimming without a transition omits xfade" "$output" "xfade="

theme_colors="$tmp_dir/colors.toml"
printf 'background = "#070303"\n' >"$theme_colors"
output="$(OMARCHY_MOTION_THEME_COLORS="$theme_colors" $app --dry-run --dim 45 --dim-color theme "$media_file")"
assert_contains "dims toward the solid theme background" "$output" "color=0x070303@0.45:t=fill"

output="$($app --dry-run --dim 100 "$media_file")"
assert_contains "supports a fully opaque overlay" "$output" "color=0x000000@1.0:t=fill"

output="$($app --dry-run --quality 720 --dim 20 'https://youtu.be/jNQXAC9IVRw')"
assert_contains "caps web video quality" "$output" "height\\<=720"
assert_contains "requests a separate audio stream" "$output" "+bestaudio"
assert_contains "dims web video without changing its audio stream" "$output" "color=0x000000@0.20:t=fill"
assert_contains "uses copy-back decoding for dimmed web video" "$output" "hwdec=auto-copy-safe"

output="$($app 'https://youtu.be/jNQXAC9IVRw' --dim 25 --dry-run)"
assert_contains "accepts options after a web URL" "$output" "color=0x000000@0.25:t=fill"

set +e
output="$($app --volume 101 --dry-run "$media_file" 2>&1)"
status=$?
set -e
assert_status "rejects invalid volume" 1 "$status"
assert_contains "explains invalid volume" "$output" "--volume must be an integer from 0 to 100"

set +e
output="$($app --dim 101 --dry-run "$media_file" 2>&1)"
status=$?
set -e
assert_status "rejects invalid dim percentage" 1 "$status"
assert_contains "explains invalid dim percentage" "$output" "--dim must be an integer from 0 to 100"

set +e
output="$($app --dim-color wallpaper --dry-run "$media_file" 2>&1)"
status=$?
set -e
assert_status "rejects invalid dim color mode" 1 "$status"
assert_contains "explains invalid dim color mode" "$output" "--dim-color must be 'black' or 'theme'"

set +e
output="$($app --transition warp --dry-run "$media_file" 2>&1)"
status=$?
set -e
assert_status "rejects an unknown transition" 1 "$status"
assert_contains "lists valid transitions" "$output" "none, fade, omarchy, circle, dissolve, pixelize, blur"

for invalid_duration in 0 60.1 fast; do
  set +e
  output="$($app --transition-duration "$invalid_duration" --dry-run "$media_file" 2>&1)"
  status=$?
  set -e
  assert_status "rejects transition duration $invalid_duration" 1 "$status"
  assert_contains "explains transition duration $invalid_duration" "$output" "greater than 0 and at most 60 seconds"
done

set +e
output="$(OMARCHY_MOTION_THEME_COLORS="$tmp_dir/missing-colors.toml" $app --dim 20 --dim-color theme --dry-run "$media_file" 2>&1)"
status=$?
set -e
assert_status "requires theme colors for theme dimming" 1 "$status"
assert_contains "explains missing theme colors" "$output" "could not read the current theme colors"

set +e
output="$($app --output '' --dry-run "$media_file" 2>&1)"
status=$?
set -e
assert_status "rejects an empty output" 1 "$status"
assert_contains "explains an empty output" "$output" "--output must not be empty"

set +e
output="$($app --dry-run "$tmp_dir/missing.mp4" 2>&1)"
status=$?
set -e
assert_status "rejects a missing local file" 1 "$status"
assert_contains "explains a missing local file" "$output" "local media file not found"

fake_bin="$tmp_dir/fake-bin"
fake_runtime="$tmp_dir/runtime"
mkdir -p "$fake_bin" "$fake_runtime"
cat >"$fake_bin/mpvpaper" <<'FAKE_MPVPAPER'
#!/usr/bin/env bash
set -uo pipefail

mpv_options=""
while (($# > 0)); do
  if [[ "$1" == "--mpv-options" ]]; then
    mpv_options="$2"
    break
  fi
  shift
done

transition_script=""
for option in $mpv_options; do
  case "$option" in
    script=*) transition_script="${option#script=}" ;;
  esac
done

printf 'transition-duration=%s\n' "${OMARCHY_MOTION_TRANSITION_DURATION:-}"
printf 'transition-final-vf=%s\n' "${OMARCHY_MOTION_TRANSITION_FINAL_VF:-}"
printf 'transition-clear-af=%s\n' "${OMARCHY_MOTION_TRANSITION_CLEAR_AF:-}"
printf 'transition-script=%s\n' "$transition_script"
[[ -r "$transition_script" ]] && printf 'transition-script-readable=yes\n'
luac -p "$transition_script" && printf 'transition-script-valid=yes\n'
FAKE_MPVPAPER
chmod +x "$fake_bin/mpvpaper"

output="$(PATH="$fake_bin:$PATH" WAYLAND_DISPLAY=wayland-test XDG_RUNTIME_DIR="$fake_runtime" \
  $app --transition circle --transition-duration 0.4 --dim 15 --once "$media_file")"
assert_contains "live launch exports transition duration" "$output" "transition-duration=0.4"
assert_contains "live launch preserves the post-transition dim filter" "$output" "transition-final-vf=lavfi=[drawbox=color=0x000000@0.15:t=fill]"
assert_contains "live launch asks the helper to clear audio fading" "$output" "transition-clear-af=true"
assert_contains "live launch creates a readable transition helper" "$output" "transition-script-readable=yes"
assert_contains "generated transition helper is valid Lua" "$output" "transition-script-valid=yes"
transition_script="$(sed -n 's/^transition-script=//p' <<<"$output")"
if [[ -n "$transition_script" && ! -e "$transition_script" ]]; then
  pass "transition helper is removed after playback"
else
  fail "transition helper is removed after playback"
fi

set +e
output="$($app --dry-run 2>&1)"
status=$?
set -e
assert_status "requires exactly one source" 2 "$status"
assert_contains "prints usage without a source" "$output" "Usage: omarchy-motion"

printf '\n%d passed; %d failed\n' "$passed" "$failed"
((failed == 0))
