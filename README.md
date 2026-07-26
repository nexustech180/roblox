# SCP Foundation: Chronicles

A solo, server-authoritative Roblox game set in the SCP universe. You start
as Class-D Personnel and grind repeatable missions to level up, unlocking
better classes at level milestones - the same shape as Blox Fruits' "reach
level 700 to sail to the next sea," just reskinned as a Foundation career
path. Built as a [Rojo](https://rojo.space/) project: every gameplay system
is plain Luau source under `src/`, ready to sync into Roblox Studio.

## Getting it running

1. Install [Rojo](https://rojo.space/docs/v7/getting-started/installation/)
   (VS Code extension + `rojo` CLI, or the Studio plugin).
2. From this folder: `rojo serve` (or open `default.project.json` with the
   Rojo Studio plugin and click Connect). Alternatively, open
   `SCPFoundationChronicles.rbxlx` directly in Studio - it's the same
   project pre-built into a place file, no Rojo required.
3. Press Play. `MapScaffold` auto-generates a placeholder facility (spawn
   pads, mission zones, doors) on server start, and you spawn immediately as
   Class-D - no waiting for other players, no lobby.

Replace `MapScaffold`'s generated geometry with a real map whenever you're
ready: every service only ever looks at `CollectionService` tags and part
attributes, never at the generated parts directly, so tagging your own
Studio-built geometry with the same tags (see **Map tags reference** below)
is a drop-in replacement. Delete the `MapScaffold.Build()` call in
`Main.server.lua` once you do.

## The core loop

There is no round, no lobby, no other players required. `SessionService`
spawns you the instant your profile loads, as whatever class you were last
using (Class-D on a fresh profile). From there:

1. `MissionService` hands you a mission for your current class, drawn from a
   shuffled "bag" of that class's small mission pool - every mission in the
   pool comes up once before any repeat, so you're never stuck grinding the
   exact same objective back-to-back, but you will keep cycling through the
   same handful of missions to level (that's the point - it's a grind).
2. Objectives are one of: reach a zone, use a terminal, eliminate a quota of
   spawned hostile NPCs, or survive a timer. Completing all of a mission's
   objectives pays credits/XP and a new mission starts a few seconds later.
3. Both the objective counts/durations and the credits/XP payout scale up
   with your level (`GameConfig.DifficultyLevelStep` /
   `DifficultyScalePerStep`), so returning to an earlier class's missions
   later doesn't trivialize them.
4. XP required per level increases with `XPCurveBase * level ^
   XPCurveExponent` - each level costs more than the last, so the grind gets
   steeper the higher you climb, especially toward the level-700 milestone.
5. Press **C** any time to open the class menu and switch to any class
   you've unlocked. Dying costs a respawn delay and a small credit penalty,
   but never resets mission or level progress.

## Classes and level gates

Defined in one table, `ReplicatedStorage/Shared/Config/ClassConfig.lua`,
ordered by `UnlockLevel`:

| Level | Class | Notes |
|---|---|---|
| 1 | Class-D Personnel | Starting class. No weapon, no keycard. |
| 50 | Scientist | Keycard 2, still unarmed. |
| 150 | Facility Guard | Keycard 3, first weapon (P90). |
| 400 | Chaos Renegade | No keycard, faster, harder-hitting AK. |
| 550 | MTF Nu-7 | Keycard 4, AK + Medkit. |
| **700** | **Site Director (O5 Command)** | Keycard 5, the big milestone unlock. |
| 1200 | SCP-049 | Prestige. Touch of Death + Reanimate (raises corpses into hostile zombies). |
| 1800 | SCP-106 | Prestige, endgame. Phase through walls, Pocket Dimension, passive corrode. |

SCP-173 and SCP-096 from the original SCP:SL cast aren't here on purpose:
both of their signature mechanics (freezing when observed, enraging when its
face is seen) only make sense with a second human in the room to do the
observing, which doesn't exist in a solo game. SCP-049 and SCP-106 both work
solo since their kit is "hunt hostiles with unique abilities," same shape as
every other class - they just fight the NPCs `NPCService` spawns for mission
objectives instead of other players.

Adding a class is a config-only change - add an entry to `ClassConfig` with
an `UnlockLevel`, tag a spawn point with its `SpawnTag`, add a few entries to
`MissionConfig._PoolByClass`, and (for anything with unique abilities) add
the ability logic to `SCPAbilityService`.

## Missions

`ReplicatedStorage/Shared/Config/MissionConfig.lua` defines a small mission
pool per class. `MissionService` tracks each player's progress through
whichever mission is currently drawn, and its objective types:

- `ReachZone` — touch a part tagged with a given zone tag.
- `InteractPart` — use the `ProximityPrompt` on a part tagged with a given
  terminal tag.
- `EliminateNPCCount` — kill a quota of hostile NPCs spawned near you for
  this attempt (`NPCService` gives them simple chase-and-melee AI; kills
  route through the same `CombatService.ApplyDamage` choke point as
  everything else, so a gun, a melee weapon, or an SCP ability all credit
  progress identically).
- `SurviveTime` — stay alive until a timer runs out.

## Map tags reference

Tag your own geometry with these `CollectionService` tags and everything
above works with zero code changes:

| Tag | On | Attributes |
|---|---|---|
| `Spawn_<ClassId>` (e.g. `Spawn_DClass`) | BasePart | — |
| `FoundationDoor` | BasePart | `RequiredLevel` (0-5, see `KeycardConfig`), optional `Group` (for `DoorService.UnlockGroup`), optional `StartsUnlocked` |
| `Zone_Surface`, `Zone_DClassCells`, `Zone_Armory`, `Zone_SCPContainment` | BasePart (`CanTouch` on) | — |
| `Terminal_Containment`, `Terminal_Intel`, `Terminal_CellRelease` | BasePart | optional `TerminalName` |

## Architecture

- **Server** (`src/ServerScriptService/Server`): one module per concern
  (`SessionService`, `ClassService`, `MissionService`, `NPCService`,
  `SCPAbilityService`, `CombatService`, `InventoryService`,
  `KeycardService`, `DoorService`, `DataService`, `AntiExploitService`,
  `NotifyService`, `LoggingService`). Services never `require` each other -
  `Main.server.lua` requires them all once and wires them together via a
  shared `Deps` locator table passed to each `Init(deps)`, so there's no
  ModuleScript require-cycle risk and no hidden load-order coupling.
- **Shared** (`src/ReplicatedStorage/Shared`): `Config/` (every tunable -
  classes, SCP abilities, missions, tools, keycards, the XP curve - is data,
  not code), `Modules/` (a tiny `Signal` utility), `Remotes/` (a single
  registry so client and server always agree on remote names/shapes).
- **Client** (`src/StarterPlayer/StarterPlayerScripts/Client`): every UI
  surface is built at runtime with `Instance.new` (no binary `.rbxlx` UI
  assets to go stale) via small `Theme`/`UIUtil` helpers - HUD, class card,
  class-change menu (press C), mission tracker, combat/crosshair, and SCP
  ability hotbar.
- **Security model**: every gameplay-affecting remote is handled and
  re-validated server-side (fire rate, range, class/cooldown/level checks
  via `AntiExploitService.CheckRate`/`Flag`); the client only ever *asks*.

## Known simplifications (by design, given scope)

- Hostile NPCs are deliberately minimal rigs (a torso-sized part + a head,
  no limbs) with `Humanoid:MoveTo`-based chase AI rather than
  `PathfindingService` navigation - fine in open layouts, worth upgrading if
  your map has tight corridors. Swap the rig in `NPCService.buildRig`.
- `AdminCommands` is a minimal chat-command panel (`/setclass`, `/credits`,
  `/addxp`) gated to the place owner by default, meant for jumping straight
  to a level/class while testing rather than grinding for real - add trusted
  `UserId`s to `ADMIN_USER_IDS` before sharing with anyone else.
- The XP curve, difficulty scaling, and mission pools are all single tables
  in `GameConfig.lua`/`MissionConfig.lua` - tune the numbers there rather
  than touching service code.
