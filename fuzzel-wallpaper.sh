#!/usr/bin/env bash
# Pick a wallpaper via fuzzel, then set it live with swaybg

set -euo pipefail

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
THUMB_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-thumbnails"
LOG_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/fuzzel-wallpaper.log"

log() {
  printf '[%s] %s\n' "$(date '+%F %T')" "$*" >> "$LOG_FILE"
}

log "=== run start ==="
log "WALLPAPER_DIR=$WALLPAPER_DIR"

# Patterns for image files
exts=(-iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o \
      -iname '*.gif' -o -iname '*.webp' -o -iname '*.bmp')

# Generate missing thumbnails in parallel (skips cached ones)
mkdir -p "$THUMB_DIR"
new_thumb=0
for f in "$WALLPAPER_DIR"/*.{png,jpg,jpeg,gif,webp,bmp}; do
  [ -f "$f" ] || continue
  t="$THUMB_DIR/$(basename "$f").thumb.png"
  [ -f "$t" ] && continue
  convert "$f" -thumbnail 150x150 "$t" 2>/dev/null &
  new_thumb=$((new_thumb + 1))
done
wait || true
log "thumbnails generated: $new_thumb"

# Pick wallpaper via fuzzel with cached PNG thumbnails
pick=$(
  find "$WALLPAPER_DIR" -maxdepth 1 -type f \( "${exts[@]}" \) -printf '%f\n' |
    sort |
    gawk -v thumb="$THUMB_DIR" '{print $0"\0icon\x1f"thumb"/"$0".thumb.png"}' |
    fuzzel --dmenu --prompt="Wallpaper: "
)

log "picked: ${pick:-<none>}"
[[ -z "$pick" ]] && log "cancelled, exiting" && exit 0

SRC="$WALLPAPER_DIR/$pick"
log "SRC=$SRC"

if [ ! -f "$SRC" ]; then
  log "ERROR: file not found: $SRC"
  echo "File not found: $SRC"
  exit 1
fi

# Persist system-wide for instant load on next Hyprland startup
for i in 0 1 2; do
  cp -f "$SRC" "/usr/share/hypr/wall$i.png"
done
log "persisted to /usr/share/hypr/wall{0,1,2}.png"

# Set live with swaybg for the current session
OLD_PIDS=$(pgrep -x swaybg 2>/dev/null || true)
log "existing swaybg pids before kill: ${OLD_PIDS:-<none>}"
swaybg -i "$SRC" -m fill &
NEW_PID=$!
disown
log "new swaybg started pid=$NEW_PID"
for p in $OLD_PIDS; do
  if kill -9 "$p" 2>/dev/null; then
    log "killed old swaybg pid=$p (SIGKILL)"
  else
    log "kill old swaybg pid=$p FAILED (already gone?)"
  fi
done
log "remaining swaybg: $(pgrep -x swaybg 2>/dev/null | tr '\n' ' ')"
log "=== run end ==="
