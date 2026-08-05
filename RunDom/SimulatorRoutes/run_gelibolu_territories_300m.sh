#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-start}"
DEVICE="${2:-booted}"
SPEED_METERS_PER_SECOND="${3:-3.0}"
UPDATE_DISTANCE_METERS="${4:-5}"

ROUTE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAYPOINTS_FILE="$ROUTE_DIR/gelibolu_territories_300m_waypoints.txt"

case "$ACTION" in
  start)
    xcrun simctl location "$DEVICE" clear >/dev/null 2>&1 || true
    xcrun simctl location "$DEVICE" start \
      --speed="$SPEED_METERS_PER_SECOND" \
      --distance="$UPDATE_DISTANCE_METERS" \
      - < "$WAYPOINTS_FILE"
    ;;
  stop|clear)
    xcrun simctl location "$DEVICE" clear
    ;;
  *)
    echo "Usage: $0 {start|stop} [device-or-booted] [speed-m/s] [update-distance-m]" >&2
    exit 64
    ;;
esac
