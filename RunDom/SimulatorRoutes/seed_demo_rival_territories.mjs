#!/usr/bin/env node
import { readFileSync, writeFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const resolution = 9;
const factor = 580;
const defaultProject = "rundom-e7aad";
const defaultInstance = "rundom-e7aad-default-rtdb";

const args = new Map();
for (let i = 2; i < process.argv.length; i += 1) {
  const arg = process.argv[i];
  if (arg.startsWith("--")) {
    const key = arg.slice(2);
    const next = process.argv[i + 1];
    if (!next || next.startsWith("--")) {
      args.set(key, true);
    } else {
      args.set(key, next);
      i += 1;
    }
  }
}

if (args.has("help")) {
  console.log(`Usage:
  node SimulatorRoutes/seed_demo_rival_territories.mjs
  node SimulatorRoutes/seed_demo_rival_territories.mjs --write
  node SimulatorRoutes/seed_demo_rival_territories.mjs --delete

Options:
  --season <id>      Defaults to the current UTC ISO week, e.g. season_2026_w25
  --out <path>       JSON output path
  --project <id>     Firebase project id, defaults to ${defaultProject}
  --instance <id>    Realtime Database instance, defaults to ${defaultInstance}
  --write            Patch generated demo territories to Firebase using firebase-tools
  --delete           Remove only the generated demo territories from Firebase
`);
  process.exit(0);
}

const seasonId = args.get("season") || currentSeasonId();
const outputPath = args.get("out") || join(scriptDir, `demo_rival_territories_${seasonId}.json`);
const deleteOutputPath = outputPath.replace(/\.json$/, ".delete.json");
const project = args.get("project") || defaultProject;
const instance = args.get("instance") || defaultInstance;

const rivals = [
  {
    ownerId: "demo_rival_hudson_blue",
    ownerColor: "#38BDF8",
    defenseLevel: 740,
    totalDistance: 4200,
    routes: [
      [[40.7603, -73.9980], [40.7520, -74.0040], [40.7440, -74.0072], [40.7395, -74.0045]],
      [[40.7565, -73.9962], [40.7488, -74.0017], [40.7428, -74.0037]],
      [[40.7515, -74.0037], [40.7462, -73.9999], [40.7412, -73.9960]]
    ]
  },
  {
    ownerId: "demo_rival_midtown_gold",
    ownerColor: "#F59E0B",
    defenseLevel: 680,
    totalDistance: 3900,
    routes: [
      [[40.7590, -73.9902], [40.7535, -73.9859], [40.7478, -73.9820], [40.7420, -73.9862]],
      [[40.7559, -73.9837], [40.7501, -73.9882], [40.7447, -73.9918]],
      [[40.7518, -73.9816], [40.7475, -73.9869], [40.7432, -73.9902]]
    ]
  },
  {
    ownerId: "demo_rival_gramercy_green",
    ownerColor: "#22C55E",
    defenseLevel: 620,
    totalDistance: 3600,
    routes: [
      [[40.7417, -73.9870], [40.7365, -73.9828], [40.7310, -73.9862], [40.7273, -73.9914]],
      [[40.7395, -73.9814], [40.7340, -73.9859], [40.7288, -73.9898]],
      [[40.7367, -73.9906], [40.7321, -73.9944], [40.7278, -73.9984]]
    ]
  },
  {
    ownerId: "demo_rival_village_purple",
    ownerColor: "#A855F7",
    defenseLevel: 710,
    totalDistance: 4100,
    routes: [
      [[40.7373, -74.0022], [40.7330, -74.0059], [40.7280, -74.0027], [40.7242, -73.9984]],
      [[40.7356, -73.9980], [40.7312, -74.0015], [40.7266, -74.0051]],
      [[40.7323, -73.9960], [40.7280, -73.9992], [40.7245, -74.0038]]
    ]
  }
];

const protectedCells = loadProtectedTrophyCells();
const generated = new Map();
const deletePayload = {};
const sampledRouteSpacingMeters = 32;
const routeWidthOffsets = [
  [0, 0],
  [1, 0],
  [0, 1]
];

for (const rival of rivals) {
  for (const route of rival.routes) {
    for (const [lat, lon] of sampleRoute(route, sampledRouteSpacingMeters)) {
      const [qLat, qLon] = quantize(lat, lon);
      for (const [dLat, dLon] of routeWidthOffsets) {
        const h3Index = `${resolution}_${qLat + dLat}_${qLon + dLon}`;
        if (protectedCells.has(h3Index)) continue;
        generated.set(h3Index, {
          h3Index,
          ownerId: rival.ownerId,
          ownerColor: rival.ownerColor,
          defenseLevel: rival.defenseLevel,
          totalDistance: rival.totalDistance,
          lastRunDate: new Date().toISOString()
        });
      }
    }
  }
}

const payload = Object.fromEntries([...generated.entries()].sort(([a], [b]) => a.localeCompare(b)));
for (const h3Index of generated.keys()) {
  deletePayload[h3Index] = null;
}

writeFileSync(outputPath, `${JSON.stringify(payload, null, 2)}\n`);
writeFileSync(deleteOutputPath, `${JSON.stringify(deletePayload, null, 2)}\n`);
console.log(`Generated ${generated.size} demo rival territories for ${seasonId}`);
console.log(`Wrote ${outputPath}`);
console.log(`Wrote ${deleteOutputPath}`);
console.log(rivals.map((r) => `${r.ownerId}: ${r.ownerColor}`).join("\n"));

if (args.has("write") || args.has("delete")) {
  const firebaseArgs = [
    "database:update",
    `/territories/${seasonId}`,
    args.has("delete") ? deleteOutputPath : outputPath,
    "--project",
    project,
    "--instance",
    instance,
    "--force"
  ];
  const result = spawnSync("firebase", firebaseArgs, { stdio: "inherit" });
  process.exit(result.status ?? 1);
}

function currentSeasonId() {
  const now = new Date();
  const day = now.getUTCDay() || 7;
  const thursday = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 4 - day));
  const yearStart = new Date(Date.UTC(thursday.getUTCFullYear(), 0, 1));
  const week = Math.ceil((((thursday - yearStart) / 86400000) + 1) / 7);
  return `season_${thursday.getUTCFullYear()}_w${week}`;
}

function loadProtectedTrophyCells() {
  const cells = new Set();
  const path = join(scriptDir, "nyc_trophy_long_stem_dense_waypoints.txt");
  const text = readFileSync(path, "utf8");
  for (const line of text.split(/\r?\n/)) {
    if (!line.trim()) continue;
    const [lat, lon] = line.split(",").map(Number);
    const [qLat, qLon] = quantize(lat, lon);
    cells.add(`${resolution}_${qLat}_${qLon}`);
  }
  return cells;
}

function quantize(lat, lon) {
  return [Math.floor(lat * factor), Math.floor(lon * factor)];
}

function sampleRoute(points, spacingMeters) {
  const samples = [];
  for (let i = 0; i < points.length - 1; i += 1) {
    const [lat1, lon1] = points[i];
    const [lat2, lon2] = points[i + 1];
    const distance = haversineMeters(lat1, lon1, lat2, lon2);
    const steps = Math.max(1, Math.ceil(distance / spacingMeters));
    for (let step = 0; step <= steps; step += 1) {
      const t = step / steps;
      samples.push([
        lat1 + (lat2 - lat1) * t,
        lon1 + (lon2 - lon1) * t
      ]);
    }
  }
  return samples;
}

function haversineMeters(lat1, lon1, lat2, lon2) {
  const toRad = (value) => value * Math.PI / 180;
  const r = 6371000;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2
    + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * r * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}
