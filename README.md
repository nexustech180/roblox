# SCP Foundation: Chronicles

A fully automated, server-authoritative Roblox game set in the SCP universe.
Players are assigned to classes (Class-D, Scientist, Guard, MTF, Chaos
Insurgency, and four playable SCPs), grouped into squads, and sent on
procedurally-assigned missions — all without any admin ever touching a
button. Built as a [Rojo](https://rojo.space/) project: every gameplay system
is plain Luau source under `src/`, ready to sync into Roblox Studio.

## Getting it running

1. Install [Rojo](https://rojo.space/docs/v7/getting-started/installation/)
   (VS Code extension + `rojo` CLI, or the Studio plugin).
2. From this folder: `rojo serve` (or open `default.project.json` with the
   Rojo Studio plugin and click Connect).
3. Press Play. `MapScaffold` auto-generates a placeholder facility (spawn
   pads, mission zones, doors, a warhead panel) on server start, so the game
   is immediately playable — no manual map setup required. Round flow, class
   assignment, and missions all happen automatically once
   `GameConfig.MinPlayersToStart` players are present (4 by default; lower
   it in `src/ReplicatedStorage/Shared/Config/GameConfig.lua` for solo
   testing, or use Studio's multi-client test with several players).

Replace `MapScaffold`'s generated geometry with a real map whenever you're
ready: every service only ever looks at `CollectionService` tags and part
attributes, never at the generated parts directly, so tagging your own
Studio-built geometry with the same tags (see **Map tags reference** below)
is a drop-in replacement. Delete the `MapScaffold.Build()` call in
`Main.server.lua` once you do.

## How the round loop works

`RoundService` runs a small state machine with no manual triggers:

```
Lobby  ──(enough players)──▶  Intermission  ──(timer ends)──▶  Active
  ▲                                │ (players leave)               │
  └────────────────────────────────┘                                │
                                                                     │
Lobby  ◀──(RoundEndDisplaySeconds)── Ending  ◀──(win condition / time limit)
```

- **Lobby**: waiting for `GameConfig.MinPlayersToStart` players.
- **Intermission**: countdown (`GameConfig.IntermissionSeconds`); drops back
  to Lobby if the player count falls below the minimum.
- **Active**: `ClassService.BuildInitialRoster` assigns every player a class
  weighted by `ClassConfig.RosterWeight`, spawns them at tagged spawn points,
  and `MissionService` forms squads and hands out missions. Chaos Insurgency
  and MTF don't exist at t=0 — they arrive as reinforcement waves pulled from
  the spectator queue (`GameConfig.ChaosSpawnDelaySeconds` /
  `MTFReinforceDelaySeconds`, then every `ReinforcementWaveIntervalSeconds`).
  Win conditions are polled continuously: Foundation wins when every SCP is
  dead, SCP wins when every human faction is wiped, Chaos wins if Foundation
  is wiped after Chaos has spawned. A round also ends on time limit or if
  someone detonates the Alpha Warhead.
- **Ending**: result banner shown client-side for `RoundEndDisplaySeconds`,
  then back to Lobby.

Dying doesn't end your session — you become a spectator and queue for the
next reinforcement wave or the next round.

## Classes

Defined in one table, `ReplicatedStorage/Shared/Config/ClassConfig.lua`:

| Class | Faction | Notes |
|---|---|---|
| Class-D Personnel | DClass | No weapon, no keycard. Mission: reach the surface. |
| Scientist | Foundation | Keycard 2, unarmed, mission-support. |
| Facility Guard | Foundation | Keycard 3, P90. |
| MTF Nu-7 | Foundation | Reinforcement wave, keycard 4, AK + medkit. |
| Chaos Insurgency | ChaosInsurgency | Reinforcement wave, AK, frees Class-D. |
| SCP-173 | SCP | Freezes when observed (server-tracked line-of-sight + view cone); instant-kill lunge when not observed. |
| SCP-049 | SCP | `E` Touch of Death (instakill), `R` Reanimate (raises a nearby corpse into a hostile zombie with its own chase AI). |
| SCP-096 | SCP | Passive view-detection; enrages and single-mindedly chases whoever saw its face. |
| SCP-106 | SCP | `E` Phase (noclip through walls), `R` Pocket Dimension (banishes a victim to an isolated room and damages them over time); passive corrode-on-touch. |

Adding a class is a config-only change — spawn a new entry in
`ClassConfig`, tag a spawn point with its `SpawnTag`, and (for SCPs) add
ability logic to `SCPAbilityService` if it needs one.

## Missions

`ReplicatedStorage/Shared/Config/MissionConfig.lua` defines a mission pool
per faction (Foundation / ChaosInsurgency / DClass). `MissionService` groups
players into squads of `GameConfig.SquadSize`, assigns each squad a random
mission from its faction's pool, and tracks objective types:

- `ReachZone` — touch a part tagged with a given zone tag.
- `InteractPart` — use the `ProximityPrompt` on a part tagged with a given
  terminal tag.
- `EliminateCount` — squad kills N members of a target faction.
- `SurviveTime` — at least one squad member alive when the timer runs out.

Completing a mission pays credits/XP (persisted via `DataService`) and hands
the squad a fresh mission a few seconds later, so there's always something
to do for the whole round.

## Map tags reference

Tag your own geometry with these `CollectionService` tags and everything
above works with zero code changes:

| Tag | On | Attributes |
|---|---|---|
| `Spawn_<ClassId>` (e.g. `Spawn_DClass`) | BasePart | — |
| `FoundationDoor` | BasePart | `RequiredLevel` (0-5, see `KeycardConfig`), optional `Group` (for `DoorService.UnlockGroup`), optional `StartsUnlocked` |
| `Zone_Surface`, `Zone_DClassCells`, `Zone_Armory`, `Zone_SCPContainment` | BasePart (`CanTouch` on) | — |
| `Terminal_Containment`, `Terminal_Intel`, `Terminal_CellRelease` | BasePart | optional `TerminalName` |
| `WarheadPanel` | BasePart | — |

## Architecture

- **Server** (`src/ServerScriptService/Server`): one module per concern
  (`RoundService`, `ClassService`, `MissionService`, `SCPAbilityService`,
  `CombatService`, `InventoryService`, `KeycardService`, `DoorService`,
  `DataService`, `AntiExploitService`, `NotifyService`, `LoggingService`).
  Services never `require` each other — `Main.server.lua` requires them all
  once and wires them together via a shared `Deps` locator table passed to
  each `Init(deps)`, so there's no ModuleScript require-cycle risk and no
  hidden load-order coupling.
- **Shared** (`src/ReplicatedStorage/Shared`): `Config/` (every tunable —
  classes, SCP abilities, missions, tools, keycards — is data, not code),
  `Modules/` (tiny `Signal`/`Trove`/`Enums` utilities), `Remotes/` (a single
  registry so client and server always agree on remote names/shapes).
- **Client** (`src/StarterPlayer/StarterPlayerScripts/Client`): every UI
  surface is built at runtime with `Instance.new` (no binary `.rbxlx` UI
  assets to go stale) via small `Theme`/`UIUtil` helpers, one controller per
  concern (HUD, round banner, class card, mission tracker, combat/crosshair,
  SCP ability hotbar, warhead banner, toast notifications).
- **Security model**: every gameplay-affecting remote is handled and
  re-validated server-side (fire rate, range, class/cooldown checks via
  `AntiExploitService.CheckRate`/`Flag`); the client only ever *asks*.
  Damage always flows through `CombatService.ApplyDamage` so kill
  attribution is consistent whether the source was a gun, an SCP ability, or
  the warhead.

## Known simplifications (by design, given scope)

- No real pathfinding for zombie/SCP-096 chase AI — `Humanoid:MoveTo` toward
  the nearest hostile position. Works fine in open layouts; add
  `PathfindingService` waypoints if your map has tight corridors.
- A player who reconnects mid-round only sees their spectator status via the
  next `ClassAssigned` broadcast (there's a `GetInitialState` RemoteFunction
  stubbed in for a full late-join resync if you want to extend it).
- `AdminCommands` is a minimal chat-command panel (`/forcestart`,
  `/endround`, `/setclass`, `/credits`) gated to the place owner by default —
  add trusted `UserId`s to `ADMIN_USER_IDS` before shipping to a team.
