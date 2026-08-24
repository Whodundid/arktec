# Tests

Keep lightweight gameplay and data validation tests here as systems are added.

Run the multiplayer foundation regression test with:

`Godot_v4.7.2-stable_win64_console.exe --headless --path C:\Users\Hunter\QoT-Workspace\ArtifactRun res://tests/network_foundation_test.tscn`

Run the 3D signpost movement/combat regression test with:

`Godot_v4.7.2-stable_win64_console.exe --headless --path C:\Users\Hunter\QoT-Workspace\ArtifactRun res://tests/terrain_3d_combat_test.tscn`

Run the autonomous two-faction battle sandbox from the editor by opening
`res://scenes/battle_sandbox.tscn` and pressing Play Scene. It contains three
spawners per faction, producing 3, 4, and 5 units, with attack waves launched
automatically every eight seconds.
