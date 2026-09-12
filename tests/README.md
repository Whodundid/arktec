# Tests

Keep lightweight gameplay and data validation tests here as systems are added.

Run the multiplayer foundation regression test with:

`Godot_v4.7.2-stable_win64_console.exe --headless --path C:\Users\Hunter\QoT-Workspace\ArtifactRun res://tests/network_foundation_test.tscn`

Run the opt-in deep-profiler output test with:

`Godot_v4.7.2-stable_win64_console.exe --headless --path C:\Users\Hunter\QoT-Workspace\ArtifactRun res://tests/deep_profiler_test.tscn`

The mission-site visual probe requires a graphics context and writes ship and artifact screenshots to the operating system's temporary directory:

`Godot_v4.7.2-stable_win64_console.exe --path C:\Users\Hunter\QoT-Workspace\ArtifactRun --rendering-method gl_compatibility res://tests/mission_sites_visual_probe.tscn`

Rail placement, construction, junction connectivity, breakage, repair, and artifact adjacency:

`Godot_v4.7.2-stable_win64_console.exe --headless --path C:\Users\Hunter\QoT-Workspace\ArtifactRun res://tests/rail_construction_test.tscn`

The deep movement profiler is disabled by default. Enable it from
`ESC > Settings > Performance Capture` only for a diagnostic run. Samples are
written once per second to `profile_*.jsonl` in that run's diagnostics folder.
`navigation.find_path` is the inclusive pathfinding total. Metrics such as
`navigation.find_path.movement`, `.building_approach`, `.wander_precheck`,
`.stuck_escape`, `.expansion_site`, and `.ore_spawn` attribute that same work
to callers, so do not add them to the inclusive total. Building return-site
selection and its physics queries are tracked separately under
`navigation.building_approach` and `physics_query.*`.

Run the autonomous two-faction battle sandbox from the editor by opening
`res://scenes/battle_sandbox.tscn` and pressing Play Scene. It contains three
spawners per faction, producing 3, 4, and 5 units, with attack waves launched
automatically every eight seconds.
