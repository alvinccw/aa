# Neon Sky Maze

Server-authoritative multiplayer maze race for Roblox, synced with **Rojo**.

Players wait in a neon lobby, a fresh Recursive-Backtracking maze generates each round, a 5s countdown freezes racers, then first to the glowing goal wins. Powerups (speed, jump, ghost, traps, compass, double boost) spawn every race. Results show top times, then the loop repeats.

## Quick start (Studio + Rojo)

1. Install [Rojo 7.x](https://rojo.space/) (project tested against **7.7.1**).
2. Open a blank Baseplate place in Roblox Studio (Terrain Grass is fine).
3. Install the Rojo Studio plugin and connect.
4. From this repo:

```bash
rojo serve default.project.json
```

5. In Studio, connect the Rojo plugin to `localhost` (default port **34872**).
6. Press **Play** (or Play Solo). Scripts build the lobby, remotes, lighting, maze, and UI at runtime.

Full setup notes: see [`docs/SETUP.md`](docs/SETUP.md) in this repo, or the Project store copy `docs/neon-sky-maze-setup.md`.

## Layout

```
default.project.json
src/
  shared/     Config.lua, Remotes.lua
  server/     RoundManager, MazeGenerator, PowerupManager, WorldSetup
  client/     ClientMain, GameUI, Effects, Spectate
docs/         Studio setup guide
```

## Tuning

Edit `src/shared/Config.lua` for maze size, timings, powerup counts, and neon colors.

## License

MIT — use freely in your experiences.
