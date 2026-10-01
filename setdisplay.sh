#!/bin/bash
set -euo pipefail

DISPLAYPLACER="/usr/local/bin/displayplacer"
MONITOR_27="0B524B77-F683-4945-8600-2E4830D3BC30"
MONITOR_22="1E19A853-5FD8-412A-885E-F9B67C156241"

usage() {
  cat <<'EOF'
Usage: setdisplay.sh switch-to-27|switch-to-22|mirror-to-22|extend-to-27 [--yes]

  switch-to-27  Mirror both displays, optimized for the 27-inch display.
  switch-to-22  Mirror both displays, optimized for the 22-inch display.
  mirror-to-22  Mirror the 22-inch display on the 27-inch display.
  extend-to-27  Extended desktop: 27-inch primary at native resolution,
                22-inch secondary to its right.

The mirror layout is applied as one atomic displayplacer command; nothing is
disconnected or disabled. It asks for confirmation unless --yes is supplied.
EOF
}

[[ -x "$DISPLAYPLACER" ]] || {
  printf 'displayplacer was not found at %s\n' "$DISPLAYPLACER" >&2
  exit 1
}

[[ $# -ge 1 && $# -le 2 ]] || {
  usage >&2
  exit 64
}

case "$1" in
  switch-to-22)
    primary_id="$MONITOR_22"
    secondary_id="$MONITOR_27"
    profile_args=("id:$MONITOR_22+$MONITOR_27 res:1920x1080 hz:60 color_depth:8 enabled:true scaling:off origin:(0,0) degree:0")
    description="mirror both displays, optimized for the 22-inch display"
    ;;
  switch-to-27)
    primary_id="$MONITOR_27"
    secondary_id="$MONITOR_22"
    profile_args=("id:$MONITOR_27+$MONITOR_22 res:1920x1080 hz:60 color_depth:8 enabled:true scaling:off origin:(0,0) degree:0")
    description="mirror both displays, optimized for the 27-inch display"
    ;;
  mirror-to-22)
    primary_id="$MONITOR_22"
    secondary_id="$MONITOR_27"
    profile_args=("id:$MONITOR_22+$MONITOR_27 res:1920x1080 hz:60 color_depth:8 enabled:true scaling:off origin:(0,0) degree:0")
    description="mirror the 22-inch display on the 27-inch display"
    ;;
  extend-to-27)
    primary_id="$MONITOR_27"
    secondary_id="$MONITOR_22"
    profile_args=(
      "id:$MONITOR_27 res:2560x1440 hz:144 color_depth:8 enabled:true scaling:off origin:(0,0) degree:0"
      "id:$MONITOR_22 res:1920x1080 hz:60 color_depth:8 enabled:true scaling:off origin:(2560,360) degree:0"
    )
    description="restore the extended desktop: 27-inch display primary, 22-inch display secondary"
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 64
    ;;
esac

[[ ${2:-} == "" || ${2:-} == "--yes" ]] || {
  usage >&2
  exit 64
}

current_layout="$($DISPLAYPLACER list)"
if ! grep -Fq "Persistent screen id: $primary_id" <<<"$current_layout" &&
  ! grep -Fq "Persistent screen id: $secondary_id" <<<"$current_layout"; then
  printf 'Neither expected display is visible; no changes were made.\n' >&2
  exit 1
fi

printf 'About to %s.\n' "$description"
printf 'Primary:   %s\nOther:     %s\n' "$primary_id" "$secondary_id"

if [[ ${2:-} != "--yes" ]]; then
  read -r -p 'Type yes to apply: ' confirmation
  [[ "$confirmation" == "yes" ]] || {
    printf 'Cancelled; no changes were made.\n'
    exit 0
  }
fi

# Apply the full profile as one atomic command. displayplacer unsets any old
# mirror config itself; partial "enabled:true" restore calls are unreliable.
"$DISPLAYPLACER" "${profile_args[@]}"
