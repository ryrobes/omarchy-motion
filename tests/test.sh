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
assert_contains "reports the packaged version" "$output" "omarchy-motion 1.1.0"

output="$($app --dry-run "$media_file")"
assert_contains "uses the bottom layer" "$output" "--layer bottom"
assert_contains "retains audio" "$output" "audio=auto"
assert_contains "uses safe hardware decoding by default" "$output" "hwdec=auto-safe"
assert_contains "loops by default" "$output" "loop-file=inf"
assert_contains "covers by default" "$output" "panscan=1.0"
assert_contains "resolves local path" "$output" "video\\ with\\ spaces.mp4"
if [[ "$output" != *"drawbox"* ]]; then
  pass "dimming is disabled by default"
else
  fail "dimming is disabled by default"
fi

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

output="$($app --dry-run --volume 08 "$media_file")"
assert_contains "accepts decimal values with a leading zero" "$output" "volume=8"

output="$($app --dry-run --dim 35 "$media_file")"
assert_contains "dims toward black by default" "$output" "color=0x000000@0.35:t=fill"
assert_contains "uses copy-back hardware decoding when dimmed" "$output" "hwdec=auto-copy-safe"

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

set +e
output="$($app --dry-run 2>&1)"
status=$?
set -e
assert_status "requires exactly one source" 2 "$status"
assert_contains "prints usage without a source" "$output" "Usage: omarchy-motion"

printf '\n%d passed; %d failed\n' "$passed" "$failed"
((failed == 0))
