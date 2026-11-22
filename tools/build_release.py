#!/usr/bin/env python3
"""Build one StAC release zip per supported game from this one source tree.

    python tools/build_release.py [--out DIR] [--games tf2,tf2classified,...]

Compilers: each game is compiled with the oldest SourceMod compiler line the build supports,
so the plugin also loads on newer SourceMod versions. Point the script at spcomp with
environment variables (one per SourceMod line, or SPCOMP for all of them):

    SPCOMP_1_11=/path/to/sm-1.11/addons/sourcemod/scripting/spcomp(.exe)
    SPCOMP_1_12=...
    SPCOMP_1_13=...
    SPCOMP=...                      fallback for any line not set above

Each zip unpacks straight into the game folder (tf/, tf2classified/, tf_goldrush/,
open_fortress/, pf2/, fortressforever/, hl2mp/, cstrike/) and carries only the extensions and gamedata
that game can use.
See CHANGES-multigame.md for what is in each zip and why.
"""
import argparse
import hashlib
import os
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# extension binaries (relative to extensions/) and gamedata files (relative to gamedata/)
TF2_EXTS = [
    "SteamWorks.ext.dll", "SteamWorks.ext.so",
    "connect.ext.2.tf2.dll", "connect.ext.2.tf2.so",
    "x64/connect.ext.2.tf2.dll", "x64/connect.ext.2.tf2.so",
    "sourcetvmanager.ext.2.tf2.dll", "sourcetvmanager.ext.2.tf2.so",
    # Conplex (conplex.ext + conplex.games.txt) is not bundled: asherkin/webcon publishes no license, so
    # its binaries can't be redistributed in this fork's releases. It is optional in every build; TF2
    # servers that want rcon hardening keep the copy upstream StAC installs.
    # webcon.ext (also in extensions/) is a web console built on Conplex; StAC doesn't use it, so it isn't shipped
]

GAMES = {
    # zip name: settings
    "tf2": {
        "define": "STAC_GAME_TF2",
        "sm": "1_12",
        "folder": "tf",
        "exts": TF2_EXTS,
        "gamedata": ["stac.txt", "connect.games.txt", "sourcetvmanager.games.txt"],
    },
    "tf2classified": {
        "define": "STAC_GAME_TF2C",
        "sm": "1_13",
        "folder": "tf2classified",
        # x64-only game. Connect has x64 builds; SteamWorks, Conplex and SourceTV Manager don't
        # (or aren't safe there), and the memory hacks are compiled out, so no stac.txt.
        "exts": ["x64/connect.ext.2.tf2.dll", "x64/connect.ext.2.tf2.so"],
        "gamedata": ["connect.games.txt"],
    },
    "tf2goldrush": {
        "define": "STAC_GAME_GOLDRUSH",
        "sm": "1_13",
        "folder": "tf_goldrush",
        # x64-only game. Upstream's Connect gamedata already matches Gold Rush's engine; no x64
        # SteamWorks / Conplex / SourceTV Manager. No stac.txt: StAC's memory hacks have no verified
        # Gold Rush gamedata yet, so this build runs without them (it logs that at load).
        "exts": ["x64/connect.ext.2.tf2.dll", "x64/connect.ext.2.tf2.so"],
        "gamedata": ["connect.games.txt"],
    },
    "open_fortress": {
        "define": "STAC_GAME_OF",
        "sm": "1_11",
        "folder": "open_fortress",
        # SDK 2013 engine: SteamWorks is engine independent; Connect, SourceTV Manager and Conplex
        # have no sdk2013 builds (Conplex's signatures don't match the sdk2013 engine either).
        # No stac.txt: StAC's gamedata only covers TF2's engine, so the memory hacks stay off here.
        "exts": ["SteamWorks.ext.dll", "SteamWorks.ext.so"],
        "gamedata": [],
    },
    "pf2": {
        "define": "STAC_GAME_PF2",
        "sm": "1_12",
        "folder": "pf2",
        "exts": ["SteamWorks.ext.dll", "SteamWorks.ext.so"],
        "gamedata": [],
    },
    "fortressforever": {
        "define": "STAC_GAME_FF",
        "sm": "1_11",
        "folder": "fortressforever",
        # SDK 2013 engine, like Open Fortress: only SteamWorks. FF servers run SourceMod 1.11.
        # SourceMod's own FF gamedata is for FF 2.4: its OnTakeDamage offset is FF 2013's TraceAttack
        # (hooking it crashes the server) and its PlayerRunCmd offset is wrong, so OnPlayerRunCmd never
        # fires. These "custom" overrides fix both offsets for every plugin on the server, not only StAC.
        "exts": ["SteamWorks.ext.dll", "SteamWorks.ext.so"],
        "gamedata": ["sdkhooks.games/custom/stac-ff2013.txt", "sdktools.games/custom/stac-ff2013.txt"],
    },
    "hl2mp": {
        "define": "STAC_GAME_HL2MP",
        "sm": "1_12",
        "folder": "hl2mp",
        # HL2DM and CS:S run on the same Steam branch as TF2, but the TF2 builds of Connect and SourceTV
        # Manager don't fit: loaded under the game's name, Connect can't find
        # CBaseServer::CheckMasterServerRequestRestart, SourceTV Manager has no ExecuteStringCommand
        # offset, and Conplex can't set up its ProcessAccept detour. Only SteamWorks is shipped.
        # No stac.txt: StAC's gamedata only covers TF2, so the memory hacks stay off.
        "exts": ["SteamWorks.ext.dll", "SteamWorks.ext.so"],
        "gamedata": [],
    },
    "cstrike": {
        "define": "STAC_GAME_CSS",
        "sm": "1_12",
        "folder": "cstrike",
        "exts": ["SteamWorks.ext.dll", "SteamWorks.ext.so"],
        "gamedata": [],
    },
}

# every build of this fork leaves the Updater out: its URL serves the upstream TF2-only build
COMMON_DEFINES = ["STAC_NO_UPDATER=1"]


# Credit and source for every bundled third-party file (all unmodified: byte-identical to the
# files upstream StAC ships, see CHANGES-multigame.md for the sha256 table)
THIRD_PARTY = [
    ("SteamWorks", "SteamWorks.ext", "https://github.com/KyleSanderson/SteamWorks", "GPL-3.0", "KyleSanderson"),
    ("Connect", "connect.ext", "https://github.com/asherkin/connect", "GPL-3.0", "Asher Baker (asherkin)"),
    ("SourceTV Manager", "sourcetvmanager.ext", "https://github.com/peace-maker/sourcetvmanager", "GPL-3.0", "peace-maker"),
]


def third_party_notice(exts):
    lines = ["StAC (Steph's AntiCheat) by sapphonie and contributors - https://github.com/sapphonie/StAC-tf2 (GPL-3.0)",
             "This build is from the multigame fork; its source is in addons/sourcemod/scripting/ and in the fork's repository.",
             "", "Bundled third-party extensions (unmodified, as shipped by upstream StAC):"]
    shipped = False
    for name, prefix, url, lic, author in THIRD_PARTY:
        files = [e for e in exts if e.split("/")[-1].startswith(prefix)]
        if files:
            shipped = True
            lines.append("  %s by %s - %s (%s): %s" % (name, author, url, lic, ", ".join(files)))
    if not shipped:
        lines.append("  none")
    lines += ["", "Not bundled: Conplex (https://github.com/asherkin/webcon) publishes no license; StAC runs without it.",
              "Each extension's source and license are at the links above."]
    return chr(10).join(lines) + chr(10)


def spcomp_for(line):
    exe = os.environ.get("SPCOMP_" + line) or os.environ.get("SPCOMP")
    if not exe or not os.path.isfile(exe):
        sys.exit("no compiler for SourceMod %s: set SPCOMP_%s (or SPCOMP) to spcomp's path" % (line.replace("_", "."), line))
    return exe


def compile_plugin(game, cfg, outdir):
    exe = spcomp_for(cfg["sm"])
    out = os.path.join(outdir, "stac.smx")
    cmd = [exe, "stac.sp", "-i" + os.path.join("include"), cfg["define"] + "=1", "-o" + out] + COMMON_DEFINES
    res = subprocess.run(cmd, cwd=os.path.join(ROOT, "scripting"), capture_output=True, text=True)
    log = (res.stdout or "") + (res.stderr or "")
    if res.returncode != 0 or not os.path.isfile(out):
        sys.exit("compile failed for %s:\n%s" % (game, log))
    warnings = [l for l in log.splitlines() if "warning" in l and "inconsistent indentation" not in l]
    for w in warnings:
        print("  [%s] %s" % (game, w))
    return out


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def add(zf, src, arc, manifest):
    zf.write(src, arc)
    manifest.append("%s  %s" % (sha256(src), arc))


def build(game, cfg, outdir):
    sm = "addons/sourcemod/"
    zpath = os.path.join(outdir, "stac-%s.zip" % game)
    manifest = []
    with tempfile.TemporaryDirectory() as tmp:
        smx = compile_plugin(game, cfg, tmp)
        with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as zf:
            add(zf, smx, sm + "plugins/stac.smx", manifest)
            for e in cfg["exts"]:
                add(zf, os.path.join(ROOT, "extensions", *e.split("/")), sm + "extensions/" + e, manifest)
            for g in cfg["gamedata"]:
                add(zf, os.path.join(ROOT, "gamedata", g), sm + "gamedata/" + g, manifest)
            for t in sorted(os.listdir(os.path.join(ROOT, "translations"))):
                add(zf, os.path.join(ROOT, "translations", t), sm + "translations/" + t, manifest)
            # GPL: ship the source the plugin was built from
            for base, _dirs, files in os.walk(os.path.join(ROOT, "scripting")):
                for f in sorted(files):
                    if f.lower() == "conplex.inc":
                        continue   # Conplex publishes no license (see TF2_EXTS); the fork repo has it
                    full = os.path.join(base, f)
                    rel = os.path.relpath(full, ROOT).replace(os.sep, "/")
                    zf.write(full, sm + rel)
            zf.write(os.path.join(ROOT, "LICENSE"), sm + "scripting/stac-LICENSE.txt")
            info = (
                "StAC multigame build for %s (game folder \"%s\")\n"
                "Compiled with: %s=1 %s, SourceMod %s compiler\n"
                "Unzip into the game folder (%s/) so addons/ merges with the existing one.\n\n"
                "sha256 of shipped binaries/data:\n%s\n"
            ) % (game, cfg["folder"], cfg["define"], " ".join(COMMON_DEFINES), cfg["sm"].replace("_", "."),
                 cfg["folder"], "\n".join(manifest))
            zf.writestr(sm + "data/stac-build-info.txt", info)
            zf.writestr(sm + "data/stac-third-party.txt", third_party_notice(cfg["exts"]))
    print("built %s" % zpath)
    for m in manifest:
        print("    " + m)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "release"))
    ap.add_argument("--games", default=",".join(GAMES))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    for g in a.games.split(","):
        g = g.strip()
        if g not in GAMES:
            sys.exit("unknown game %r (have: %s)" % (g, ", ".join(GAMES)))
        build(g, GAMES[g], a.out)


if __name__ == "__main__":
    main()
