# Marine Outpost

A sci-fi incremental tower-defense prototype for Windows, built with Godot 4.6.

Open `project.godot` in Godot and press **F5**. Waves start automatically after 12 seconds, then 8 seconds after each cleared wave. Choose Marine ($60), Mortar ($110), or Cryo ($85), then click a pad to build. Select a turret to upgrade it or sell it for 70% of its invested cost. Pause freezes the countdown and combat; Tempo toggles 1×/2× speed. Defend your 30 lives against growing zombie waves. Best completed wave saves locally.

See [the roadmap](docs/ROADMAP.md) for controls, multiplayer plans, and development milestones. Current gameplay is single-player with original vector sprites, an industrial colony map, animated zombies, turret aiming, and hit effects. Multiplayer and Steam support are planned. The in-game interface is German.

Run the gameplay smoke test:

```sh
godot --headless --path . --script res://game/smoke_test.gd
```

In a cloud sandbox with a read-only home directory, set `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, and `XDG_CACHE_HOME` to writable directories before running Godot. Tests write a local highscore; use an isolated data directory to avoid changing your personal record.

New enemy types: sprinters from wave 2, armored zombies from wave 3, and a Titan every fifth wave. Mortars deal splash damage and bypass armor; cryo halves enemy movement for 2.5 seconds. Titans cost five lives when they escape. All others cost one. You can trigger the next wave early during the build countdown.
