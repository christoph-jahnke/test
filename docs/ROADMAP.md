# Marine Outpost

Target: Windows, top-down 3D with an angled camera, eventually distributed on Steam.

## Playable prototype

Open project.godot in Godot 4.6 and press F5 to run the 3D project. The previous 2D version remains in game/main.tscn and can be run separately with F6. Use the mouse wheel to zoom in 3D. Click a circular build pad to buy a $60 marine turret. Select a turret and use Upgrade to improve damage and range. Waves launch automatically after an initial 12-second setup and 8-second build breaks; the launch button can shorten a break. Kills grant $4; completed waves grant a cash bonus. Normal enemies cost one life when reaching the outpost; Titans cost five. Pause freezes combat; New run resets the match. The local highscore records completed waves and survives restarts.

The default scene now uses original low-poly 3D models, directional lighting and shadows, an industrial colony, animated legs, rotating weapons, and combat effects. The existing 2D controller supplies the shared combat simulation and UI through a small adapter. The 2D scene and SVG assets are retained as a fallback. Next visual work: richer models, animation, sound, and Windows performance testing. This remains prototype artwork. There is no multiplayer, Steam integration, online ladder, or permanent research yet. Endless scaling is implemented; long-run balance still needs playtesting.

## Development milestones

1. Prove single-player combat: playtest this prototype; tune pacing and economy; add sound, enemy feedback, and clear wave previews.
2. Strategic variety: marine, splash mortar, and cryo towers are implemented, alongside sprinters, armored zombies, and a Titan every fifth wave. Selling refunds 70% of investment. Next: upgrade branches, targeting controls, and balance playtests.
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
