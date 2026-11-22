# StAC multigame fork

This is a fork of [Steph's AntiCheat (StAC)](https://github.com/sapphonie/StAC-tf2) by sapphonie.
It builds StAC for **every TF2-family game that runs SourceMod**, plus Fortress Forever,
Half-Life 2: Deathmatch and Counter-Strike: Source, from one source tree:

| Game | Game folder | Engine | SourceMod tested | Release zip |
|---|---|---|---|---|
| Team Fortress 2 | `tf` | TF2 | 1.12, x86 | `stac-tf2.zip` |
| TF2 Classified | `tf2classified` | TF2 branch, x64 | 1.13, x64 | `stac-tf2classified.zip` |
| TF2: Gold Rush | `tf_goldrush` | TF2 branch, x64 | 1.13, x64 | `stac-tf2goldrush.zip` |
| Open Fortress | `open_fortress` | Source SDK 2013 | 1.11, x86 | `stac-open_fortress.zip` |
| Pre-Fortress 2 | `pf2` | Source SDK 2013 | 1.12, x86 | `stac-pf2.zip` |
| Fortress Forever | `fortressforever` | Source SDK 2013 | 1.11, x86 | `stac-fortressforever.zip` |
| Half-Life 2: Deathmatch | `hl2mp` | HL2DM (TF2's Steam branch) | 1.13, x86 | `stac-hl2mp.zip` |
| Counter-Strike: Source | `cstrike` | CS:S (TF2's Steam branch) | 1.13, x86 | `stac-cstrike.zip` |

Download the zip for your game from [Releases](../../releases). Every StAC check that the game can
support still runs. The full list of changes, and what was and wasn't verified, is in
[CHANGES-multigame.md](CHANGES-multigame.md).

## What's different from upstream

- **The bunnyhop check is off by default** (`stac_max_bhop_detections -1`) in every build.
- **Each game gets its own build.** Pick it at compile time (`STAC_GAME_TF2C=1`, `STAC_GAME_GOLDRUSH=1`,
  `STAC_GAME_OF=1`, `STAC_GAME_PF2=1`, `STAC_GAME_FF=1`, `STAC_GAME_HL2MP=1`, `STAC_GAME_CSS=1`; plain
  TF2 is the default). A build refuses to run in the wrong game.
- **Fortress Forever, HL2DM and CS:S builds have no TF2 code.** TF2's conds, taunts, teleporters, damage
  types, MvM check and team enum are compiled out. Every game-neutral check still runs. Cvars a game's
  client doesn't have (such as `fov_desired`) aren't queried.
- **Extensions are per game.** Outside TF2, SteamWorks, Connect and SourceTV Manager are optional:
  each zip ships only the ones that load on that game, and StAC logs which features are off for the
  rest. TF2 still requires them, as upstream does.
- **Conplex is optional everywhere and not bundled.** StAC calls none of its natives, and its source
  publishes no license, so the releases don't redistribute it. TF2 servers already running upstream
  StAC keep their copy.
- **Memory hooks only where they're safe.** On TF2 they behave exactly as upstream. On TF2 Classified
  they are compiled out (DHooks detours and raw-address SDKCalls crash its x64 server). Gold Rush,
  Open Fortress, PF2, Fortress Forever, HL2DM and CS:S try them, then run without them, logging why,
  because no gamedata covers those engines yet.
- **Missing cvars, events and props are skipped** instead of erroring. Games without entity-output
  hooking get a `trigger_teleport` fallback for the backtrack patch.
- **The Updater is compiled out of release builds**, because upstream's update URL serves the TF2
  build and would replace a build for another game.
- **Checks that only hold on TF2 are TF2-only.** The bogus-achievement, `cl_thirdperson` and
  `windows_speaker_config` checks, and the 90 cap on `fov_desired` (130 elsewhere), encode facts about
  TF2's client. On other games they banned legit players, so only the TF2 build runs them.
- **Fortress Forever's grenade buttons aren't "invalid input".** FF uses button bits 26 and 27
  (`IN_TOGGLEGRENADE2`, `IN_ATTACK3`), so the FF build only flags bits from 28 up. Before multigame.6,
  every two-tap grenade throw on FF counted toward an invalid-usercmd ban.
- **Taunts are read off the player too.** On TF2-based games other than TF2, StAC also reads the
  taunting condition from `m_nPlayerCond`, so the aim checks skip taunts even when the game's tools
  plugin isn't loaded.

## Install

1. Stop the server.
2. Unzip your game's zip into the game folder, for example `tf2classified/`, so that
   `addons/sourcemod/...` merges with yours.
3. Start the server. On first run StAC writes `cfg/sourcemod/stac.cfg`.

**Fortress Forever:** the zip also adds two SourceMod gamedata overrides
(`gamedata/sdkhooks.games/custom/stac-ff2013.txt`, `gamedata/sdktools.games/custom/stac-ff2013.txt`).
SourceMod's own FF gamedata is for FF 2.4. On FF 2013, an `OnTakeDamage` hook crashes the server, and
`OnPlayerRunCmd` never fires. The overrides fix that **for every plugin on the server**, so other plugins'
`OnPlayerRunCmd` and `OnTakeDamage` hooks start working too. Without them, StAC still runs, but its
usercmd checks don't. See [CHANGES-multigame.md](CHANGES-multigame.md).

In the other TF2-based games, also install the game's TF2-tools replacement plugin (Fortress Forever,
HL2DM and CS:S don't need one). StAC needs it for the
`TF2_OnConditionAdded`/`Removed` forwards that tell it when a player is taunting:
[SM-TF2Classified-Tools](https://github.com/AgitationSkeleton/SM-TF2Classified-Tools),
[SM-TF2GoldRush-Tools](https://github.com/AgitationSkeleton/SM-TF2GoldRush-Tools),
SM-Open-Fortress-Tools or PF2-Tools. Without it, StAC still loads and reads the taunting condition off
the player itself (multigame.6), but Halloween conditions aren't tracked.

An existing `stac.cfg` keeps its old values: SourceMod never overwrites a value that is already in
the file. To turn the bunnyhop check off on a server that already has one, set
`stac_max_bhop_detections "-1"` there.

## Start in log-only mode

Outside TF2, nobody has run these checks against real players for long. Start a new server in
log-only mode, play on it normally, read the logs, and only then turn bans on:

```
stac_max_aimsnap_detections "0"          // 0 = detect and log, never ban (-1 = don't check at all)
stac_max_psilent_detections "0"
stac_max_cmdnum_detections "0"
stac_max_fakeang_detections "0"
stac_max_invalid_usercmd_detections "0"
stac_ban_for_misccheats "0"
stac_debug "1"                           // also logs every join and every cvar check result
```

`stac_debug 1` writes each player's join and each cvar check to `addons/sourcemod/logs/stac/`, so a
quiet log shows that StAC really checked the player rather than that it never ran. Also make sure the
server writes game logs (`log on` in the server config), so you can see who played and when.
StAC skips the aim checks on servers with more than 33 slots, so test those on a smaller server.

## Building

```
SPCOMP_1_11=... SPCOMP_1_12=... SPCOMP_1_13=... python tools/build_release.py [game ...]
```

This writes one zip per game to `release/`. Open Fortress and Fortress Forever are compiled with
SourceMod 1.11's compiler, because their servers run 1.11 and code compiled with 1.12 is "too new" for it.

## Status

Every build has been loaded on a LAN test copy of its game's server, with bots only:
- it loads cleanly and its cvars register;
- the admin commands run;
- map changes run cleanly.

The Fortress Forever gamedata overrides have only been run on a Windows server.

On live servers (TF2 Classified, Gold Rush, Open Fortress, PF2, Fortress Forever, HL2DM and CS:S),
normal play in log-only mode with `stac_debug 1` produced no detections: each session got 27 to 54 cvar
checks. The aim checks still need more real-player data outside TF2, and Connect's early-connect hook
outside TF2 hasn't been tested with a human client yet. Reports are welcome in this fork's issues. Please don't report fork-specific
problems upstream.

## Credits

StAC is by [sapphonie](https://github.com/sapphonie) and its contributors (GPL-3.0). All
anticheat logic is theirs; this fork only adds the per-game build layer. Bundled extensions:
[SteamWorks](https://github.com/KyleSanderson/SteamWorks) (GPL-3.0),
[Connect](https://github.com/asherkin/connect) (GPL-3.0),
[SourceTV Manager](https://github.com/peace-maker/sourcetvmanager) (GPL-3.0).
They are unmodified, byte-identical to the files upstream StAC ships. Each zip lists the ones it
bundles, with links and licenses, in `addons/sourcemod/data/stac-third-party.txt`.

---

*Upstream's README follows, unchanged.*

---

<h1>  Steph's AntiCheat </h1>




[![Version](https://img.shields.io/github/v/release/sapphonie/StAC-TF2?color=98FB98&style=for-the-badge)](https://github.com/sapphonie/StAC-tf2/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/sapphonie/Stac-TF2/total?color=%239370D8&label=Downloads%20since%20v5&style=for-the-badge)](https://github.com/sapphonie/StAC-tf2/releases/latest)
[![Dev discord](https://img.shields.io/badge/Dev%20discord-%23StAC-7289DA?style=for-the-badge&logo=discord)](https://discord.gg/tUGgCByZVJ)
[![Donations](https://img.shields.io/badge/Support%20me-here!%20:\)-1F1F2A?style=for-the-badge)](https://sappho.io/donate)

<div align="center">
<img src="https://i.imgur.com/RKRaLPl.png" alt="StAC" width="256" style="float: center;"/>
</div>

#### Support me on [Patreon](https://www.patreon.com/sapphonie)!


### This plugin - "StAC" - and the ones bundled with it, can detect, log, patch, and punish for a majority of the cheats, macros, and unfair scripts available for Team Fortress 2, including:
- pSilentAim / NoRecoil / Angle Repeat cheats
- Plain aimsnap / Aimbot cheats
- Auto bhop cheats
- Fake eye angle cheats
- NoLerp cheats
- Some FoV cheats
### It also prevents and/or detects:
- Newlines/invalid characters in chat messages
- Cmdnum manipulation (clientside nospread)
- Tickcount manipulation (backtracking) - [Thank you to J_Tanzanite, author of LilAC](https://github.com/J-Tanzanite/Backtrack-Patch)!
- Interp/lerp abuse
- Clients using +right/+left inputs
- "Ping reducing" cheats (and patches "pingmasking" by legit clients as well)
- Clients purposefully not authorizing with Steam
- Cheat to cheat communication
- Several server crashing and server lagging exploits
- Admin spoofing
- Unkickable players

##
I hate cheaters. Everyone does. But you know what I hate more? Taking the sweet time out of my day to catch them. A lot of TF2 cheats do a lot of the same things, and if you know what to look for, you can detect their patterns and ban them ***automatically***!

But wait. Don't server-side anticheats suck?

***They don't have to.***

Of course, there's limitations to what this plugin can do. It can't scan the memory or programs on your computer, it can't see exactly what keys you're pressing on your keyboard, and players don't live inside the server room, so there's always the factor of lag and loss. 

But StAC is written so that it has as few false detections as possible, because **no one wants to get banned when they weren't cheating**. I've reverse engineered cheats, installed them myself (on an alt, don't worry!) and I've tested and refined this plugin over the course of years and thousands of hours of work so that it ignores legit clients, and only goes after naughty cheaters.

Even better, this plugin is set up to be as easy to use and install as possible, so you don't have to be a sourcemod guru to get rid of cheaters on your nfoserver.

### Jeers
- ["a fork of SMAC with a few added features"](https://canary.discord.com/channels/875964612233801748/880689027089584198/927463760547938325)
- ["broken high school computer science level code"](https://www.teamfortress.tv/post/1066189/savetf2)
- ["it's broken"](https://github.com/sapphonie/StAC-tf2/issues/95)
- ["very easy to bypass"](https://canary.discord.com/channels/335290997317697536/335291251937116167/976374661602476052)
- ["Is it really anti-cheat or just a joke?"](https://canary.discord.com/channels/335290997317697536/335291251937116167/976375279276666880)

### Cheers
- [~500 cheaters banned on my servers alone](https://sappho.io/bans/index.php?p=banlist&searchText=StAC&Submit=Search)
- In use in countless other server networks, including [Uncletopia](https://uncletopia.com), the now dead [Creators.TF](https://creators.tf), and more

### Installation & Configuration

0) Install and configure [Discord API](https://forums.alliedmods.net/showthread.php?t=292663) for Discord Webhook logging, if you'd like
1) download the latest release (called `stac.zip`) from [here](https://github.com/sapphonie/StAC-tf2/releases/latest). StAC automatically includes the latest versions of SourceTVManager, SteamWorks, Connect, and Conplex, and will not run without them. If you have issues with installation, feel free to join the discord and I'd be happy to help you out.
2) extract the downloaded zip, and copy all the folders inside of it into `/tf/addons/sourcemod/` on your tf2 server. Overwrite any files if prompted.
3) restart your server

The current list of cvars and admin commands is listed [here](cvars.md). The defaults should be good for most people, if you want to the plugin to autoban. If not, you can set any "detection" cvar to 0 to never ban, and to -1 to never even log or check in the first place. If you want to edit cvars,

4) wait 30 seconds after doing the above
5) edit `/tf/cfg/sourcemod/stac.cfg` to your liking
6) restart your server again

You should be good to go!

### Sourcebans
This plugin is compatible with [SourceBans](https://sbpp.dev/), [gbans](https://github.com/leighmacdonald/gbans), and the default TF2 ban handler, and auto detects which it should use. The plugin, by default, logs the currently recording demo (if one is recording) to the sourcebans ban message. To disable this, set `stac_include_demoname_in_sb` to `0`.

### Chat logging, file logging and Discord logging
This plugin prints detections to any clients on the server with the `sm_ban` permission, and the running SourceTV bot, if one exists. It saves more verbose logs to `/tf/addons/sourcemod/logs/stac/stac_month_day_year.log` by default, as well. To disable this verbose logging to file, set `stac_log_to_file` to `0`. This plugin can also log to a Discord channel via a webhook, in combination with zipcore's [Discord API](https://forums.alliedmods.net/showthread.php?t=292663) plugin. Edit `/tf/addons/sourcemod/configs/discord.cfg`, to look like the following code snippet, and StAC will print all detections to that channel as well.

```
"Discord"
{
    "stac"
    {
        "url"   "discord webhook url"
    }
}
```

### Disclaimers
Though I wrote StAC to throw as few false positives as possible, I can't guarantee perfection. I also can't guarantee that everything will always work how it's supposed to. Please submit a bug report if you can reproduce a way to trigger false positives, or for any bug or feature request. If you're more comfortable talking to me personally about it, join the development discord for StAC here: https://discord.gg/tUGgCByZVJ

### Philosophy
StAC isn't perfect. It can't be, no anticheat can, but especially not a serverside one. It does what it can, with the information available to it. This means, in simple terms, it's not gonna ban every single cheater. I essentially take the philosophy of a popular [php malware scanner](https://github.com/nbs-system/php-malware-finder/#what-does-it-detect):

"Of course it's trivial to bypass [[StAC]], but its goal is to catch skiddies and idiots, not people with a working brain. If you report a stupid tailored bypass for [[StAC]], you likely belong to one (or both) category, and should re-read the previous statement."

***TL:DR***; If you want actually good anticheat, pester Valve to hire more anticheat engineers, or play [Open Fortress](https://openfortress.fun) and/or [Team Fortress 2 Classic](https://tf2classic.com), which are source mods of TF2 that I head both the anticheat department of, of which I have access to client code to much more easily prevent people from cheating.

### Special Thanks etc.

LilAC: https://forums.alliedmods.net/showthread.php?t=321480 - J_Tanz rocks!

SMAC: https://github.com/Silenci0/SMAC

SSaC: Private - [AS] Nacho Replay, dog, and Miggy - RIP

Backwards - coding

Asherkin - coding

Addie - coding

JoinedSenses - coding

Everyone else in the sourcemod discord who had to put up with my asinine questions

Aad

dog - beta testing

elektro - beta testing

Creators.TF Community - beta testing

Cheddzy - for the COOL ass icon

Nanochip - rare code audits

Miggy - this one's for you, bud.
