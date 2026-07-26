# SCP Foundation: Chronicles

A server-authoritative Roblox game set in the SCP universe. You start as
Class-D Personnel and grind repeatable missions to level up, ranking through
personnel clearance at the same level milestones Blox Fruits uses for its
Seas (700 / 1500 / 2450) - reskinned as a Foundation career path instead of
sailing to a new ocean. Built as a [Rojo](https://rojo.space/) project: every
gameplay system is plain Luau source under `src/`, ready to sync into Roblox
Studio.

This is Phase A of a larger Blox-Fruits-style rework: clearance tiers and
the two-currency economy (Glint / Aetheric Ducats) are in; a Helper SCP
ownership system (Devil Fruit equivalent), a Lab Shop, PvP SCP-stealing,
Cybernetics upgrades, quest-giver NPCs, and 45 sites/85 bosses of content
are planned next.

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

`SessionService` spawns you the instant your profile loads, as whatever
class you were last using (Class-D on a fresh profile). From there:

1. `MissionService` hands you a mission for your current class, drawn from a
   shuffled "bag" of that class's small mission pool - every mission in the
   pool comes up once before any repeat, so you're never stuck grinding the
   exact same objective back-to-back, but you will keep cycling through the
   same handful of missions to level (that's the point - it's a grind).
2. Objectives are one of: reach a zone, use a terminal, eliminate a quota of
   spawned hostile NPCs, or survive a timer. Completing all of a mission's
   objectives pays Glint/XP and a new mission starts a few seconds later.
3. Both the objective counts/durations and the Glint/XP payout scale up
   with your level (`GameConfig.DifficultyLevelStep` /
   `DifficultyScalePerStep`), so returning to an earlier class's missions
   later doesn't trivialize them.
4. XP required per level increases with `XPCurveBase * level ^
   XPCurveExponent` - each level costs more than the last, so the grind gets
   steeper the higher you climb, especially toward the level-700 milestone.
5. Press **C** any time to open the class menu and switch to any class
   you've unlocked. Dying costs a respawn delay and a small Glint penalty,
   but never resets mission or level progress.

## Classes and level gates

Defined in one table, `ReplicatedStorage/Shared/Config/ClassConfig.lua`,
ordered by `UnlockLevel`, using the exact level breakpoints Blox Fruits uses
for its three Seas:

| Level | Class | Notes |
|---|---|---|
| 1 | Class-D Personnel | Starting class. No weapon, no keycard. |
| **700** | **Class-C Personnel** | Keycard 3, first weapon (P90). Helper SCPs become usable from here (Phase B). |
| **1500** | **Class-B Personnel** | Keycard 4, AK + Medkit. |
| **2450** | **Class-A Personnel (O5 Command)** | Keycard 5, best conventional loadout - the top of the ladder. |
| 2600 / 3200 | SCP-049 / SCP-106 | Temporary placeholders - moving to a separate, price-gated Helper SCP system (own many, equip one) rather than a level-locked class. |

SCP-173 and SCP-096 from the original SCP:SL cast aren't playable yet:
both of their signature mechanics (freezing when observed, enraging when its
face is seen) need a second real player to do the observing. They're
planned to come back once the Helper SCP system (multiplayer) lands.

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
- `AdminCommands` is a minimal chat-command panel (`/setclass`, `/glint`,
  `/ducats`, `/addxp`) gated to the place owner by default, meant for
  jumping straight to a level/class while testing rather than grinding for
  real - add trusted `UserId`s to `ADMIN_USER_IDS` before sharing with
  anyone else. A proper redeem-code system (Phase F of the roadmap) will
  supersede this for one-click "give me everything" testing.
- The XP curve, difficulty scaling, and mission pools are all single tables
  in `GameConfig.lua`/`MissionConfig.lua` - tune the numbers there rather
  than touching service code.
