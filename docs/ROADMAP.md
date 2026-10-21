# Marine Outpost

Target: Windows, top-down 2D, eventually distributed on Steam.

## Playable prototype

Open project.godot in Godot 4.6 and press F6 with main.tscn open, or F5 to run the project. Click a circular build pad to buy a $60 marine turret. Select a turret and use Upgrade to improve damage and range. Launch each wave when ready. Kills grant $4; completed waves grant a cash bonus. Every zombie reaching the blue outpost costs one of 30 lives. Pause freezes combat; New run resets the match. The local highscore records completed waves and survives restarts.

The prototype now uses original SVG marine, zombie, and base sprites over a drawn industrial colony map. Zombies sway as they walk; turrets turn toward their targets and hits emit sparks. This remains prototype artwork, not a finished production art pass. There is no multiplayer, Steam integration, online ladder, or permanent research yet. Endless scaling is implemented; long-run balance still needs playtesting.

## Development milestones

1. Prove single-player combat: playtest this prototype; tune pacing and economy; add sound, enemy feedback, and clear wave previews.
2. Add strategic variety: rapid-fire marine, area-damage mortar, slowing tower; armored, fast, and boss zombies; tower targeting and upgrade branches.
3. Add incremental progression: single-player research earned between runs, unlocks, versioned saves, and progression balancing. Keep competitive power equal for all players.
4. Build multiplayer for two, then four players: one shared map with separate lanes and 30 lives per player. Authoritative simulation validates cash, builds, wave outcomes, and attacks. Define wave synchronization, opponent targeting, disconnect rules, and ties before implementation.
5. Add offensive spending: choose between towers/upgrades and sending zombies or strengthening an opponent's next wave. Tune attack pricing and prevent runaway income advantages. Start with last player alive wins.
6. Steam preparation: Windows export and hardware testing, licensed visual/audio assets, accessible settings, tutorial, Steam lobbies, achievements, trusted leaderboards, and store materials. Public ladders require validated match results and an operating budget for any servers.

## Decisions still open

- Multiplayer waves: synchronized rounds or individually launched waves?
- Sending enemies: select one opponent or use a fixed rotation?
- Match duration, expected run length, and research progression speed.
- Final art direction and title (Marine Outpost is a working title).

Use the existing isolated checkout for development; no extra Git worktree is necessary.
