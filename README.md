# Marine Outpost

A sci-fi incremental tower-defense prototype for Windows, built with Godot 4.6. The default scene is now a top-down 3D colony with an angled orthographic camera.

Open `project.godot` in Godot and press **F5**. Waves start automatically after 12 seconds, then 8 seconds after each cleared wave. Choose Marine ($60), Mortar ($110), or Cryo ($85), then click a pad to build. Select a turret to upgrade it or sell it for 70% of its invested cost. Pause freezes the countdown and combat; Tempo toggles 1×/2× speed. Defend your 30 lives against growing zombie waves. Best completed wave saves locally.

See [the roadmap](docs/ROADMAP.md) for controls, multiplayer plans, and development milestones. Current gameplay is single-player with original procedural low-poly 3D models, a colony map, walking zombies, rotating turrets, beam shots, mortar blasts, lighting, and shadows. Use the mouse wheel to zoom. Multiplayer and Steam support are planned. The in-game interface is German. The previous 2D version remains available at `game/main.tscn` (open it and press F6); F5 launches the new 3D version.

Run the gameplay smoke test:

```sh
godot --headless --path . --script res://game/smoke_test.gd
```

In a cloud sandbox with a read-only home directory, set `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, and `XDG_CACHE_HOME` to writable directories before running Godot. Tests write a local highscore; use an isolated data directory to avoid changing your personal record.

New enemy types: sprinters from wave 2, armored zombies from wave 3, and a Titan every fifth wave. Mortars deal splash damage and bypass armor; cryo halves enemy movement for 2.5 seconds. Titans cost five lives when they escape. All others cost one. You can trigger the next wave early during the build countdown.

3D integration checks (camera picking, models, selling, boss scaling, reset, and automatic waves):

```sh
godot --headless --path . --script res://game/smoke_3d.gd
```

The 3D models are constructed from simple geometric meshes, not finished character art. No external model downloads or paid assets are required. Headless checks verify integration; Windows rendering quality and performance still need playtesting.
