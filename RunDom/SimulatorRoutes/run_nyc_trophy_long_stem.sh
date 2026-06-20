#!/usr/bin/env bash
set -euo pipefail

DEVICE="${1:-booted}"
SPEED_METERS_PER_SECOND="${2:-4.5}"
UPDATE_DISTANCE_METERS="${3:-5}"

ROUTE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAYPOINTS_FILE="$ROUTE_DIR/nyc_trophy_long_stem_dense_waypoints.txt"

xcrun simctl location "$DEVICE" clear >/dev/null 2>&1 || true
xcrun simctl location "$DEVICE" start \
  --speed="$SPEED_METERS_PER_SECOND" \
  --distance="$UPDATE_DISTANCE_METERS" \
  - < "$WAYPOINTS_FILE"
