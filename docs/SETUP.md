# Neon Sky Maze — Studio setup

## What you create manually

Almost nothing. Use a **blank Baseplate** place (default Terrain Grass is fine).

Optional manual steps:

| Item | Required? | Notes |
|------|-----------|--------|
| Rojo plugin connected | **Yes** | Session name can be anything (e.g. `RobolexStealEggTest`) |
| Blank place / Baseplate | **Yes** | Explorer can start empty of game content |
| Lobby SpawnLocation | No | `WorldSetup` builds `Workspace.Lobby.LobbySpawn` |
| Remotes folder | No | Created at runtime under `ReplicatedStorage.Remotes` |
| Lighting / Atmosphere | No | Applied by `WorldSetup` |
| Collision groups | No | Registered in `WorldSetup` for Ghost Mode |
| ScreenGui | No | Client builds `NeonSkyMazeUI` |

You do **not** need to pre-create `ServerScriptService` scripts, folders, or UI — Rojo syncs them.

## What scripts handle

- Neon lobby pad + spawn + sign lights
- Fog, Atmosphere, Bloom, ColorCorrection
- `ReplicatedStorage.Remotes` (all RemoteEvents)
- Maze under `Workspace.CurrentMaze` (cleared each round)
- Powerup balls + CollectionService tags
- Round loop: Intermission → Generate → Countdown → Race → Results
- Mid-join → lobby until next race; leave cleans state
- Client HUD, toasts, results, spectate (Q/E/R)

## Play with Rojo 7.7.1

1. Clone / open this repo locally.
2. Terminal:

   ```bash
   rojo serve default.project.json
   ```

3. Studio → Rojo plugin → **Connect** to the serve address (usually `localhost:34872`).
4. Confirm the tree appears under `ServerScriptService.Server`, `ReplicatedStorage.Shared`, `StarterPlayer.StarterPlayerScripts.Client`.
5. Press **Play**. Output should show:

   - `[NeonSkyMaze] WorldSetup ready…`
   - `[NeonSkyMaze] RoundManager online`
   - `[NeonSkyMaze] Client ready`

6. Stand on the magenta lobby spawn; wait for intermission countdown; you teleport into the maze.

### Multiplayer test

Use **Local Server** with 2+ players (Studio Test tab) to verify race placements, powerups, and mid-join lobby behavior.

## Project map (Rojo)

| Path | Becomes |
|------|---------|
| `src/shared/*` | `ReplicatedStorage.Shared` |
| `src/server/*.server.lua` | Scripts in `ServerScriptService.Server` |
| `src/server/*.lua` | ModuleScripts in `ServerScriptService.Server` |
| `src/client/*.client.lua` | LocalScripts in `StarterPlayerScripts.Client` |
| `src/client/*.lua` | ModuleScripts next to the client entry |

`MazeGenerator` and `PowerupManager` are **ModuleScripts** required by `RoundManager.server.lua` (cleaner than three independent Scripts).

## Config knobs

`ReplicatedStorage.Shared.Config` (source: `src/shared/Config.lua`):

- `MAZE_WIDTH` / `MAZE_HEIGHT` — 21 or 25 recommended
- `CELL_SIZE`, `WALL_HEIGHT`, `WALL_THICKNESS`
- `INTERMISSION_DURATION`, `COUNTDOWN_DURATION`, `RESULTS_DURATION`, `POST_WIN_CONTINUE`
- `POWERUP_COUNT_MIN` / `MAX`
- `MIN_PLAYERS_TO_START` — keep `1` for Solo testing; raise for live lobbies

## Tips

- If Ghost Mode does not phase through walls, check Output for PhysicsService errors and that `WorldSetup` ran.
- Sound asset IDs in `Effects.lua` are placeholders — swap for your own uploaded audio if a sound fails to load.
- Publishing: sync with Rojo, then File → Publish to Roblox as usual.
