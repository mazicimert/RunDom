#!/usr/bin/env bash
set -euo pipefail

DEVICE="${1:-booted}"
SPEED_METERS_PER_SECOND="${2:-4.5}"
UPDATE_DISTANCE_METERS="${3:-5}"

# Venice Beach / Ocean Front Walk tarafinda yaklasik 2 dakikalik duz sahil rotasi.
# Start: Santa Monica/Venice sahil hatti kuzeyi
# End: Venice Beach tarafina dogru tek duz segment
START_LAT=33.984700
START_LON=-118.472100
END_LAT=33.980500
END_LON=-118.468800

xcrun simctl location "$DEVICE" clear >/dev/null 2>&1 || true
xcrun simctl location "$DEVICE" set "$START_LAT,$START_LON"

node - "$START_LAT" "$START_LON" "$END_LAT" "$END_LON" "$UPDATE_DISTANCE_METERS" <<'NODE' \
  | xcrun simctl location "$DEVICE" start \
    --speed="$SPEED_METERS_PER_SECOND" \
    --distance="$UPDATE_DISTANCE_METERS" \
    -
const [startLat, startLon, endLat, endLon, spacing] = process.argv.slice(2).map(Number);
const start = [startLat, startLon];
const end = [endLat, endLon];

function meters(a, b) {
  const radius = 6371000;
  const toRad = (value) => value * Math.PI / 180;
  const dLat = toRad(b[0] - a[0]);
  const dLon = toRad(b[1] - a[1]);
  const lat1 = toRad(a[0]);
  const lat2 = toRad(b[0]);
  const h = Math.sin(dLat / 2) ** 2
    + Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  return 2 * radius * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
}

const distance = meters(start, end);
const steps = Math.max(1, Math.ceil(distance / spacing));
console.error(`LA beach route: ${Math.round(distance)}m`);

for (let step = 0; step <= steps; step += 1) {
  const t = step / steps;
  const lat = start[0] + (end[0] - start[0]) * t;
  const lon = start[1] + (end[1] - start[1]) * t;
  console.log(`${lat.toFixed(7)},${lon.toFixed(7)}`);
}
NODE
