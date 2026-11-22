# StAC multigame fork: changes

This fork builds StAC for every TF2-family game that runs SourceMod, plus Fortress Forever,
Half-Life 2: Deathmatch and Counter-Strike: Source, from one source tree.
Pick the game at compile time (`STAC_GAME_TF2`, `STAC_GAME_TF2C`, `STAC_GAME_GOLDRUSH`,
`STAC_GAME_OF`, `STAC_GAME_PF2`, `STAC_GAME_FF`, `STAC_GAME_HL2MP`, `STAC_GAME_CSS`);
`scripting/stac/stac_game.sp` maps each game to its feature switches. `tools/build_release.py` builds one zip per game.

## Changes for every game

- **Bunnyhop check is off by default.** `stac_max_bhop_detections` now defaults to `-1`, both as the
  cvar default and in the `cfg/sourcemod/stac.cfg` that StAC generates on first run.
  AutoExecConfig never overwrites a value that is already in an existing `stac.cfg`, so servers
  that already have one keep their old value until you change it there.
- **Updater is left out of the release builds.** Upstream's update URL serves the TF2-only build, and
  the Updater plugin would install it over a build for another game. A plain `spcomp stac.sp`
  build still has the Updater, as upstream does.
- **The build refuses to run in the wrong game.** It checks the game folder (only the last path
  component, so `-game <absolute path>` works too) and the engine. A wrong install stops with a
  message saying which build it needs.
- **Missing cvars, events and gamerules props are skipped instead of erroring.**
  `sv_allow_wait_command`, `sv_maxusrcmdprocessticks_holdaim`, `net_chan_limit_msec`,
  `sv_client_cmdrate_difference`, `sv_voicecodec` and the rate cvars are only touched if they exist.
  `teamplay_round_start`, `achievement_earned` and `player_teleported` are hooked only if the game
  has them. `m_bPlayingMannVsMachine` is read only when the gamerules proxy has it.
- **Conplex is optional in every build, and the release zips don't include it.** StAC calls none of
  Conplex's natives; the extension hardens rcon by itself once it is loaded. Its source
  (asherkin/webcon) publishes no license, so this fork doesn't redistribute its binary, gamedata or
  include in release zips. TF2 servers that already run upstream StAC keep their Conplex. Without it,
  StAC logs "Optional extension conplex.ext isn't running - disabled: rcon hardening" once.
- **A missing `gamedata/stac.txt` is checked before it is loaded.** On SourceMod 1.11,
  `LoadGameConfigFile` throws instead of returning null for a missing file, which stopped StAC from
  starting on Open Fortress (fixed in multigame.2; found during the first live rollout).
- **SourceTV Manager and SteamWorks calls are guarded.** If the extension isn't loaded, the demo
  name in ban reasons is skipped, and the server IP comes from the `hostip` cvar.

## Per game

| Game (folder) | Engine / tested SM | Extensions | Memory hacks | Other changes |
|---|---|---|---|---|
| TF2 (`tf`) | TF2, SM 1.12 x86 | SteamWorks, Connect and SourceTV Manager required, as upstream; Conplex optional (not bundled) | On; any failure is fatal, as upstream | none |
| TF2 Classified (`tf2classified`) | TF2 branch, x64, SM 1.13 | Optional. Ships Connect x64 only | Compiled out (`STAC_NO_MEMHACKS`): DHooks detours and raw-address SDKCalls crash TF2C's x64 server | TF2 Tools ext not required; TF2's Halloween cond ids are ignored |
| TF2: Gold Rush (`tf_goldrush`) | TF2 branch, x64, SM 1.13 | Optional. Ships Connect x64 + upstream's current `connect.games.txt` | Tried at load; turned off with a log line because there is no Gold Rush gamedata | SDKTools has no entity-output hooking here, so the backtrack patch watches `trigger_teleport` with SDKHooks (`STAC_NO_ENTITY_OUTPUTS`); TF2 Tools ext not required |
| Open Fortress (`open_fortress`) | SDK 2013, SM 1.11 x86 | Optional. Ships SteamWorks (engine independent) | Tried at load; off because there is no SDK 2013 gamedata | Same entity-output fallback as Gold Rush; built with the SM 1.11 compiler, because 1.12 output fails on SM 1.11 with "code is too new" |
| Pre-Fortress 2 (`pf2`) | SDK 2013, SM 1.12 x86 | Optional. Ships SteamWorks | Tried at load; off because there is no SDK 2013 gamedata | TF2 Tools ext not required |
| Fortress Forever (`fortressforever`) | SDK 2013, SM 1.11 x86 | Optional. Ships SteamWorks | Tried at load; off because there is no SDK 2013 gamedata | Not a TF2 game (see below). Same entity-output fallback as Gold Rush. Ships SourceMod gamedata overrides for FF 2013 (see below). Built with the SM 1.11 compiler |
| Half-Life 2: Deathmatch (`hl2mp`) | HL2DM (TF2's Steam branch), SM 1.13 x86 | Optional. Ships SteamWorks | Tried at load; off because StAC's gamedata only covers TF2 | Not a TF2 game (see below). Built with the SM 1.12 compiler |
| Counter-Strike: Source (`cstrike`) | CS:S (TF2's Steam branch), SM 1.13 x86 | Optional. Ships SteamWorks | Tried at load; off because StAC's gamedata only covers TF2 | Not a TF2 game (see below). Built with the SM 1.12 compiler |

When the memory hacks are off, StAC has no signon state, no `GetTimeSinceLastReceived` lag signal
and no stripping of control characters from names. With the memory hacks off, the before-signon
command filter stays out of the way instead of blocking every client command. All other checks
run as usual: aim, cvar, netprop, userinfo, cmdnum/tickcount, backtrack patch and bhop (if enabled).

Taunt and Halloween-cond tracking uses the `TF2_OnConditionAdded`/`Removed` forwards. Outside TF2,
StAC only gets these forwards if the game's tools plugin is installed: SM-TF2Classified-Tools,
SM-TF2GoldRush-Tools, SM-Open-Fortress-Tools or PF2-Tools. Since multigame.6 the TF2-based builds
other than TF2 also read the taunting condition (`m_nPlayerCond` bit 7) off the player every tick
(`STAC_POLL_TAUNT_COND`), so the aim checks skip taunts without that plugin too; Halloween conditions
still need it.

**Fortress Forever buttons (multigame.6).** FF's `in_buttons.h` defines `IN_TOGGLEGRENADE2` as `1 << 26`
and `IN_ATTACK3` as `1 << 27`. The invalid-usercmd check flagged every button bit from 26 up, so each
two-tap grenade throw on FF counted toward a ban (5 by default). The FF build now flags bits from 28
up (`STAC_FIRST_INVALID_BUTTON`); every other build keeps 26.

### Fortress Forever, HL2DM and CS:S (`STAC_NO_TF2_API`)

These games aren't TF2-based, so their builds don't include `tf2_stocks` and compile out everything
that only exists in TF2: the `TF2_OnConditionAdded`/`Removed` and `TF2_OnPlayerTeleport` forwards
(taunts, Halloween conds, teleporters), TF2's burning damage types, the MvM check, and `TFTeam`
(team 0/1 are unassigned/spectator in every Source game). They need no tools plugin. Like every
non-TF2 build, they skip the achievement, `cl_thirdperson` and `windows_speaker_config` checks.
Every game-neutral check still runs: aim/snap, eye angles, cmdnum/tickcount, backtrack patch, interp,
cvar queries, userinfo, chat newlines, names and bhop (if enabled).

- **Player class and bullet temp entity per game.** The `m_fFlags` lookup uses `CFFPlayer`,
  `CHL2MP_Player` or `CCSPlayer`, and the shot hook uses the `"Shotgun Shot"` temp entity (TF2's is
  `"Fire Bullets"`). Both names were checked with `sm_dump_teprops` on each game's server.
- **Client cvar queries.** Every queried cvar was checked against each game's `client.dll` and
  `engine.dll`. `fov_desired` isn't a client cvar in any of the three (the engine only lists it as a
  userinfo name), so it isn't queried (`STAC_NO_FOV_DESIRED`). An unknown cvar would be reported as
  "could not query". The other values StAC checks behave as on TF2: `cl_interpolate` is dev-only,
  `cl_cmdrate` is clamped to 10..100 by the engine, and the cheat-only list is all `FCVAR_CHEAT`.
- **Commands with client index -1.** HL2DM's engine sends some commands to command listeners with
  client -1, which made StAC's command filter throw "Client index -1 is invalid". Non-TF2 builds treat it like
  the server console.
- **Fortress Forever: SourceMod's gamedata is for FF 2.4.** On FF 2013 its `OnTakeDamage` offset
  (65) is `TraceAttack`, so an `OnTakeDamage` SDKHook crashes the server within seconds of bots fighting.
  Its `PlayerRunCmd` offset (355) is also wrong, so `OnPlayerRunCmd` never fires, for any plugin.
  The FF zip ships two override files, `gamedata/sdkhooks.games/custom/stac-ff2013.txt`
  (`OnTakeDamage` 67) and `gamedata/sdktools.games/custom/stac-ff2013.txt` (`PlayerRunCmd` 428).
  The offsets were read from FF's `server.so` vtables and checked with bots on Windows. **They change
  these hooks for every plugin on the server, not only StAC**: other plugins' `OnPlayerRunCmd` (for
  example LilAC's) start running on FF too. The StAC build also checks the offsets itself
  (`STAC_VERIFY_SDKHOOK_OFFSETS`). Without the override, it logs that and doesn't hook `OnTakeDamage`, so it
  can't crash the server, but its usercmd checks don't run. The backtrack patch's `trigger_teleport`
  `EndTouch` hook stays off on FF: the computed offset (107) was never seen to fire in testing, so the zip
  doesn't override it.
- **Extensions.** HL2DM and CS:S run on TF2's Steam branch, but the TF2 builds of the other extensions
  don't work there. Loaded under the game's file name on a test server, Connect fails ("Failed to find
  CBaseServer__CheckMasterServerRequestRestart"), SourceTV Manager loads without its
  `CBaseClient::ExecuteStringCommand` offset, and Conplex can't set up its `ProcessAccept` detour. So the
  three zips ship SteamWorks only, and StAC runs without the others, as on Open Fortress.

## Verified vs not verified

Verified on LAN test copies of each game's server, with bots and no human players:
- StAC loads with no errors and its cvars register; `stac_max_bhop_detections` defaults to `-1` and the generated `stac.cfg` has `-1`.
- `sm_stac_checkall` and `sm_stac_detections` run.
- A map change (OnMapEnd/OnMapStart/config execution) runs clean.
- Each optional extension is reported as loaded or missing.
- TF2 only: all 3 detours and 3 SDKCalls set up.
- Making Conplex optional (after the test runs above) is a compile-time change only: every build
  compiles, but that last change was not load-tested again.

Fortress Forever, HL2DM and CS:S (added after multigame.3) were tested the same way, with FF 2013 (ffnextbot
bots), HL2DM (hrcbot bots) and CS:S (CS bots) on copies of the live servers' SourceMod setups, with
LilAC loaded alongside. On FF this was done both with and without the gamedata overrides.

Not verified (each needs a real human client, which the test setup didn't have):
- Detections that fire on a real player's usercmds.
- Connect's `OnClientPreConnectEx` on TF2C and Gold Rush. The extension loads, but bots skip that path.
- On TF2, the signon-state and netchan hooks running against a live netchan.
- The `hostip` fallback for the notification IP. The code path is simple, but the test servers only had bots.
- On FF, HL2DM and CS:S: cvar query answers from a real client, and StAC's usercmd checks on a real
  player (StAC skips bots). On FF, `OnPlayerRunCmd` was confirmed to fire for bots with the override.
- The FF gamedata overrides on a Linux server (the Linux offsets are Windows + 1, from `server.so`, not run).
- HL2DM's "Shotgun Shot" temp entity firing for every weapon (registered and hooked; not counted per weapon).

## Third-party binaries in the zips

| File | Zips | Source | License |
|---|---|---|---|
| `SteamWorks.ext.dll` / `.so` (1.2.3) | tf2, open_fortress, pf2, fortressforever, hl2mp, cstrike | github.com/KyleSanderson/SteamWorks (same binary upstream StAC ships) | GPL-3.0 |
| `connect.ext.2.tf2.dll` / `.so` (x86), `x64/connect.ext.2.tf2.dll` / `.so` (1.4.0) | tf2 (x86+x64), tf2classified (x64), tf2goldrush (x64) | asherkin/connect (limetech builds), as shipped by upstream StAC | GPL-3.0 (stated in the extension's source headers) |
| `sourcetvmanager.ext.2.tf2.dll` / `.so` | tf2 | github.com/peace-maker/sourcetvmanager, as shipped by upstream StAC | GPL-3.0 |
| `conplex.ext.dll` / `.so` | none (not bundled) | asherkin/webcon (Conplex); upstream StAC ships it | no license published, so this fork's releases leave it out |

Every zip also includes the plugin source (`addons/sourcemod/scripting/`) and `data/stac-build-info.txt`,
which lists the sha256 of every shipped file.
