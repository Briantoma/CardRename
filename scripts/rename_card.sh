#!/bin/bash
# Rename a camera card from the clips it holds.
#
#   Reel-ID cameras (name taken from the clips, any subfolder):
#     Sony XDCAM / ARRI / Canon / DJI Ronin   D902C001_260916JN.MXF      -> D902
#     RED                                     A001_C001_0916AB_001.R3D   -> A001
#     Blackmagic                              A001_09161234_C001.braw    -> A001
#   Cameras without a reel ID (Sony C0001.MP4, DJI, GoPro, Lumix, DCIM...):
#     name built as MODEL_YYMMDD (date of the oldest clip), e.g. FX3_260916,
#     DJI_260916, then shown in a dialog so it can be edited or skipped.
#
# Commands (Terminal):
#   bash rename_card.sh on        start renaming automatically when a card is mounted
#   bash rename_card.sh off       stop it
#   bash rename_card.sh status    on or off, and the last renames
#   bash rename_card.sh undo      give the last renamed card its old name back
#   bash rename_card.sh undo E003 same, for a given card
#   bash rename_card.sh [paths]   rename now (no path: every card in /Volumes)
#
# Automatic mode: launchd leaves a flag on each mount and wakes the SwiftBar
# menu (cardrename.1m.sh), which runs this script. Card access is then granted
# to SwiftBar once, instead of giving bash Full Disk Access.
#
# Also usable as an Automator Quick Action (Run Shell Script, shell /bin/bash,
# pass input as arguments).
#
# Test without touching anything:  DRY_RUN=1 bash rename_card.sh /path/to/card

ONLY_UNTITLED=${ONLY_UNTITLED:-1}        # 1 = only rename cards still carrying a default name (below)
DEFAULT_NAMES='UNTITLED|NO NAME|NONAME|DJI'   # default volume names, "UNTITLED 2", "DJI1"... included
ASK_WHEN_NO_REEL=${ASK_WHEN_NO_REEL:-1}  # 1 = confirm the MODEL_YYMMDD name in a dialog, 0 = rename directly
UNDO_SECONDS=${UNDO_SECONDS:-30}         # how long the Undo button stays on screen after a rename
DRY_RUN=${DRY_RUN:-0}                    # 1 = print what would happen, rename nothing
MAX_DEPTH=5                              # how deep to look for clips below the card root

MEDIA_EXT='mxf|mp4|mov|braw|r3d|ari|arx|crm|mts|m2ts|avi|mkv|insv|360'

LABEL=local.cardrename
INSTALL_DIR="${CARDRENAME_DIR:-$HOME/Library/Scripts/CardRename}"
INSTALLED="$INSTALL_DIR/rename_card.sh"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="${CARDRENAME_LOG:-$HOME/Library/Logs/CardRename.log}"   # date, old name, new name, volume UUID
IGNORE="$INSTALL_DIR/undone.txt"                   # volume UUIDs the automation must leave alone
MOUNT_FLAG="$INSTALL_DIR/mounted.flag"             # left by launchd on each mount, picked up by the SwiftBar menu
AUTO=0                                             # 1 = automatic run, stay silent unless something happens

notify () {
  if [ "$DRY_RUN" -eq 1 ]; then echo "[notify] $1: $2"; return; fi
  /usr/bin/osascript - "$1" "$2" >/dev/null 2>&1 <<'EOF'
on run argv
  display notification (item 2 of argv) with title (item 1 of argv)
end run
EOF
}

# Routine messages (skipped, already correct...) only when run by hand.
info () {
  [ "$AUTO" -eq 1 ] || notify "Card rename" "$1"
}

alert () {
  if [ "$DRY_RUN" -eq 1 ]; then echo "[alert] $1"; return; fi
  /usr/bin/osascript - "$1" >/dev/null 2>&1 <<'EOF'
on run argv
  display dialog (item 1 of argv) buttons {"OK"} default button 1 with icon caution with title "Card rename"
end run
EOF
}

# Prints the edited name, or fails if the user clicked Skip.
ask_name () {
  if [ "$DRY_RUN" -eq 1 ]; then echo "$2"; return 0; fi
  /usr/bin/osascript - "$1" "$2" 2>/dev/null <<'EOF'
on run argv
  set r to display dialog (item 1 of argv) default answer (item 2 of argv) buttons {"Skip", "Rename"} default button "Rename" cancel button "Skip" with title "Card rename"
  return text returned of r
end run
EOF
}

# "Card renamed" box with an Undo button, closes itself after UNDO_SECONDS.
# Prints Undo or OK.
ask_undo () {
  /usr/bin/osascript - "$1" "$2" "$UNDO_SECONDS" 2>/dev/null <<'EOF'
on run argv
  set r to display dialog ("Card " & item 1 of argv & " renamed " & item 2 of argv & ".") buttons {"Undo", "OK"} default button "OK" giving up after ((item 3 of argv) as integer) with title "Card rename"
  if gave up of r then return "OK"
  return button returned of r
end run
EOF
}

vol_info () {
  /usr/sbin/diskutil info "$1" 2>/dev/null | /usr/bin/awk -F': *' -v k="$2" '$1 ~ "^ *" k "$" {print $2; exit}'
}

# Stable id of the file system: changes when the card is reformatted.
vol_uuid () {
  local u; u=$(vol_info "$1" 'Volume UUID')
  [ -n "$u" ] || u=$(vol_info "$1" 'Disk / Partition UUID')
  printf '%s' "$u"
}

is_ignored () {
  [ -n "$1" ] && [ -f "$IGNORE" ] && /usr/bin/grep -qxF "$1" "$IGNORE"
}

# Give a volume its old name back and keep the automation off it.
undo_rename () {
  local target="$1" old="$2" new="$3" uuid
  uuid=$(vol_uuid "$target")
  if [ -n "$uuid" ] && ! is_ignored "$uuid"; then
    /bin/mkdir -p "$INSTALL_DIR"; echo "$uuid" >> "$IGNORE"
  fi
  if out=$(/usr/sbin/diskutil rename "$target" "$old" 2>&1); then
    printf '%s\t%s\t%s\t%s\tundo\n' "$(/bin/date '+%Y-%m-%d %H:%M:%S')" "$new" "$old" "$uuid" >> "$LOG"
    notify "Card rename undone" "$new is $old again"
  else
    alert "Undo failed for $new
$out"
  fi
}

# Media files on the card, one path per line, hidden folders and ._ files skipped.
list_media () {
  /usr/bin/find -E "$1" -mindepth 1 -maxdepth "$MAX_DEPTH" \
    -name '.*' -prune -o \
    -type f -iregex ".*\.($MEDIA_EXT)$" -print 2>/dev/null
}

# Reel IDs found in clip names, unique, one per line.
reels_from () {
  /usr/bin/sed 's#.*/##' "$1" \
    | /usr/bin/tr 'a-z' 'A-Z' \
    | /usr/bin/sed -nE \
        -e 's/^([A-Z0-9]{4})C[0-9]{3,4}_.*/\1/p' \
        -e 's/^([A-Z][0-9]{3})_C[0-9]{3}_.*/\1/p' \
        -e 's/^([A-Z][0-9]{3})_[0-9]{8}_C[0-9]{3}.*/\1/p' \
    | /usr/bin/sort -u
}

# Short camera tag for cards without a reel ID.
camera_tag () {
  local mp="$1" list="$2" model d

  # Sony XAVC S / XAVC HS: model in the clip XML (<Device ... modelName="ILME-FX3">)
  if [ -d "$mp/PRIVATE/M4ROOT" ]; then
    model=$(/usr/bin/grep -rhoE 'modelName="[^"]+"' "$mp/PRIVATE/M4ROOT/Clip" 2>/dev/null \
      | /usr/bin/head -1 | /usr/bin/sed -E 's/modelName="([^"]*)"/\1/; s/^[A-Za-z]+-//')
    echo "${model:-SONY}"; return
  fi

  if /usr/bin/sed 's#.*/##' "$list" | /usr/bin/grep -qi '^DJI_'; then echo DJI; return; fi
  if [ -d "$mp/PRIVATE/PANA_GRP" ]; then echo LUMIX; return; fi

  # DCIM/100GOPRO, DCIM/100CANON, DCIM/100_PANA... -> GOPRO, CANON, PANA
  for d in "$mp"/DCIM/[0-9][0-9][0-9]*; do
    [ -d "$d" ] || continue
    model=$(/usr/bin/basename "$d" | /usr/bin/cut -c4- | /usr/bin/tr -cd 'A-Za-z0-9')
    case "$model" in ''|MEDIA) ;; *) echo "$model"; return ;; esac
  done

  echo CARD
}

# Date of the oldest clip, YYMMDD.
oldest_date () {
  /usr/bin/tr '\n' '\0' < "$1" \
    | /usr/bin/xargs -0 /usr/bin/stat -f '%m %Sm' -t '%y%m%d' 2>/dev/null \
    | /usr/bin/sort -n | /usr/bin/head -1 | /usr/bin/cut -d' ' -f2
}

# Keep A-Z 0-9 _ - and fit the file system label limit (FAT32 11, exFAT 15).
clean_name () {
  local name max="$2"
  name=$(printf '%s' "$1" | /usr/bin/tr 'a-z' 'A-Z' | /usr/bin/tr -cd 'A-Z0-9_-')
  if [ ${#name} -gt "$max" ]; then name=$(printf '%s' "$name" | /usr/bin/tr -d '_-'); fi
  printf '%s' "${name:0:$max}"
}

label_max () {
  case "$(vol_info "$1" 'File System Personality')" in
    *ExFAT*|*exFAT*) echo 15 ;;
    *APFS*|*HFS*)    echo 27 ;;
    *)               echo 11 ;;   # MS-DOS FAT32 or unknown
  esac
}

has_default_name () {
  printf '%s' "$1" | /usr/bin/tr 'a-z' 'A-Z' | /usr/bin/grep -qxE "($DEFAULT_NAMES) ?[0-9]{0,2}"
}

looks_like_card () {
  local v="$1"
  for d in XDROOT PRIVATE DCIM CONTENTS CLIPS001; do
    [ -d "$v/$d" ] && return 0
  done
  # RED / ARRI / Blackmagic / Ronin cards have no fixed folder: look for reel-named clips
  local tmp; tmp=$(/usr/bin/mktemp)
  MAX_DEPTH=3 list_media "$v" | /usr/bin/head -50 > "$tmp"
  [ -n "$(reels_from "$tmp")" ]; local rc=$?
  /bin/rm -f "$tmp"; return $rc
}

write_plist () {
  /bin/cat > "$1" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/sh</string>
    <string>-c</string>
    <string>/usr/bin/touch "\$0"; /usr/bin/open -g "swiftbar://refreshplugin?name=cardrename"</string>
    <string>$MOUNT_FLAG</string>
  </array>
  <key>StartOnMount</key><true/>
  <key>AbandonProcessGroup</key><true/>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/CardRename.out.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/CardRename.out.log</string>
</dict>
</plist>
EOF
}

is_on () {
  /bin/launchctl print "gui/$(/usr/bin/id -u)/$LABEL" >/dev/null 2>&1
}

case "$1" in
  on)
    /bin/mkdir -p "$INSTALL_DIR" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
    src=$(cd "$(/usr/bin/dirname "$0")" && pwd)/$(/usr/bin/basename "$0")
    [ "$src" = "$INSTALLED" ] || /bin/cp "$src" "$INSTALLED"
    write_plist "$PLIST"
    /bin/launchctl bootout "gui/$(/usr/bin/id -u)/$LABEL" 2>/dev/null
    if /bin/launchctl bootstrap "gui/$(/usr/bin/id -u)" "$PLIST"; then
      echo "Card rename is ON. Script in use: $INSTALLED"
    else
      echo "Could not start the automation."; exit 1
    fi
    exit 0 ;;
  off)
    /bin/launchctl bootout "gui/$(/usr/bin/id -u)/$LABEL" 2>/dev/null
    /bin/rm -f "$PLIST" "$MOUNT_FLAG"
    echo "Card rename is OFF."
    exit 0 ;;
  status)
    if is_on; then echo "Card rename is ON."; else echo "Card rename is OFF."; fi
    if [ -f "$LOG" ]; then echo "Last renames:"; /usr/bin/tail -5 "$LOG"; fi
    exit 0 ;;
  undo)
    [ -f "$LOG" ] || { echo "Nothing to undo."; exit 1; }
    want=$(printf '%s' "$2" | /usr/bin/tr 'a-z' 'A-Z')
    line=$(/usr/bin/awk -F'\t' -v w="$want" '$5 != "undo" && (w == "" || $3 == w)' "$LOG" | /usr/bin/tail -1)
    [ -n "$line" ] || { echo "No rename to $2 in the log."; exit 1; }
    old=$(printf '%s' "$line" | /usr/bin/cut -f2)
    new=$(printf '%s' "$line" | /usr/bin/cut -f3)
    [ -d "/Volumes/$new" ] || { echo "/Volumes/$new is not mounted."; exit 1; }
    undo_rename "/Volumes/$new" "$old" "$new"
    exit 0 ;;
  --auto)
    AUTO=1; ONLY_UNTITLED=1; shift ;;
esac

targets=("$@")

if [ ${#targets[@]} -eq 0 ]; then
  volumes_before=$(/bin/ls /Volumes)
  for v in /Volumes/*; do
    [ -L "$v" ] && continue   # boot volume symlink
    if [ "$ONLY_UNTITLED" -eq 1 ] && ! has_default_name "$(/usr/bin/basename "$v")"; then continue; fi
    if looks_like_card "$v"; then targets+=("$v"); fi
  done
  if [ ${#targets[@]} -eq 0 ]; then
    [ "$AUTO" -eq 1 ] || alert "No camera card with a default name found in /Volumes."
    exit 0
  fi
fi

list=$(/usr/bin/mktemp)
trap '/bin/rm -f "$list"' EXIT

for target in "${targets[@]}"; do

  if [ "$DRY_RUN" -eq 1 ]; then
    mount_point="$target"
  else
    mount_point=$(/bin/df -P "$target" 2>/dev/null | /usr/bin/awk 'NR==2 {for (i=6; i<=NF; i++) printf "%s%s", $i, (i<NF ? " " : "")}')
    case "$mount_point" in
      /Volumes/*) ;;
      *) alert "Not a mounted volume under /Volumes: $target"; continue ;;
    esac
  fi

  current=$(/usr/bin/basename "$mount_point")

  if [ "$ONLY_UNTITLED" -eq 1 ] && ! has_default_name "$current"; then
    info "Skipped $current (not a default card name)"
    continue
  fi

  uuid=$(vol_uuid "$mount_point")
  if [ "$AUTO" -eq 1 ] && is_ignored "$uuid"; then
    continue   # renaming was undone on this card, leave it until it is reformatted
  fi

  if ! /bin/ls "$mount_point" >/dev/null 2>&1; then
    alert "macOS does not let this script read $current.
In System Settings > Privacy & Security > Files and Folders, allow Removable Volumes for SwiftBar (or for Terminal when run from there), then mount the card again."
    continue
  fi

  list_media "$mount_point" > "$list"

  if [ ! -s "$list" ]; then
    # an empty, freshly formatted card is normal when the automation runs
    [ "$AUTO" -eq 1 ] || alert "No video clip found on $current (searched $MAX_DEPTH folder levels deep)."
    continue
  fi

  max=$(label_max "$mount_point")
  reels=$(reels_from "$list")
  count=$(printf '%s\n' "$reels" | /usr/bin/grep -c '[A-Z0-9]')

  if [ "$count" -gt 1 ]; then
    alert "$current holds more than one reel ID: $(printf '%s' "$reels" | /usr/bin/tr '\n' ' ')
Nothing renamed. Check the card before offloading."
    continue
  fi

  if [ "$count" -eq 1 ]; then
    new=$(clean_name "$reels" "$max")
  else
    suggestion=$(clean_name "$(camera_tag "$mount_point" "$list")_$(oldest_date "$list")" "$max")
    if [ "$ASK_WHEN_NO_REEL" -eq 1 ]; then
      answer=$(ask_name "No reel ID in the clip names on $current.
Name for this card (max $max characters):" "$suggestion") || {
        info "Skipped $current"; continue; }
      new=$(clean_name "$answer" "$max")
    else
      new="$suggestion"
    fi
  fi

  if [ -z "$new" ]; then
    alert "Empty name for $current, nothing renamed."
    continue
  fi

  if [ "$current" = "$new" ]; then
    info "$current already correct"
    continue
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[rename] $current -> $new"
    continue
  fi

  # The device id (disk4s1) survives the rename, the mount point does not.
  device=$(vol_info "$mount_point" 'Device Identifier')

  if out=$(/usr/sbin/diskutil rename "$mount_point" "$new" 2>&1); then
    /bin/mkdir -p "$(/usr/bin/dirname "$LOG")"
    printf '%s\t%s\t%s\t%s\n' "$(/bin/date '+%Y-%m-%d %H:%M:%S')" "$current" "$new" "$uuid" >> "$LOG"
    # Undo box in the background, so the next card is not kept waiting.
    (
      if [ "$(ask_undo "$current" "$new")" = "Undo" ]; then
        undo_rename "${device:-/Volumes/$new}" "$current" "$new"
      fi
    ) </dev/null >/dev/null 2>&1 &
  else
    alert "Rename failed for $current
$out"
  fi

done

# A card mounted while this run was busy fires no new event: scan again.
if [ "$AUTO" -eq 1 ] && [ "$(/bin/ls /Volumes)" != "$volumes_before" ]; then
  exec /bin/bash "$0" --auto
fi
