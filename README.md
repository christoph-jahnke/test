# Marine Outpost

A sci-fi incremental tower-defense prototype for Windows, built with Godot 4.6.

Open `project.godot` in Godot and press **F5**. Click pads to build turrets, select a turret to upgrade, then launch waves. Defend your 30 lives against growing zombie waves. Best completed wave saves locally.

See [the roadmap](docs/ROADMAP.md) for controls, multiplayer plans, and development milestones. Current gameplay is single-player with placeholder graphics; multiplayer and Steam support are planned.

Run the gameplay smoke test:

```sh
godot --headless --path . --script res://game/smoke_test.gd
```

In a cloud sandbox with a read-only home directory, set `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, and `XDG_CACHE_HOME` to writable directories before running Godot. Tests write a local highscore; use an isolated data directory to avoid changing your personal record.
