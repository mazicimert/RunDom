# NYC Trophy Simulator Route

This route draws a blocky trophy outline in Manhattan around Chelsea, NoMad, and Midtown.
The stem is intentionally long: it runs between roughly W 26 St and W 33 St, with the base on W 23 St and the cup up near W 40 St.

Files:

- `nyc_trophy_long_stem_waypoints.txt`: raw `lat,lon` waypoints for `simctl`.
- `nyc_trophy_long_stem_dense_waypoints.txt`: dense `lat,lon` waypoints at about 8 m spacing for smoother simulator movement.
- `nyc_trophy_long_stem.gpx`: GPX preview/export version of the same route.
- `nyc_trophy_long_stem_dense.gpx`: dense GPX preview/export version of the same route.
- `run_nyc_trophy_long_stem.sh`: helper for feeding the route into a booted simulator.

Usage:

```sh
chmod +x SimulatorRoutes/run_nyc_trophy_long_stem.sh
SimulatorRoutes/run_nyc_trophy_long_stem.sh booted 4.5 5
```

Arguments:

1. Simulator device id, or `booted`.
2. Speed in meters per second. `4.5` is a fast but plausible run and takes about 24.5 minutes.
3. Location update spacing in meters. `5` matches the app's active tracking distance filter.

The helper uses the dense waypoint file by default. It contains 839 points, compared with 22 control points in the original route, so long straight sections stay visually locked to the intended line during recording.

For a shorter recording pass, use a higher speed:

```sh
SimulatorRoutes/run_nyc_trophy_long_stem.sh booted 8 5
```
