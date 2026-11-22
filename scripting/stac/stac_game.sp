#pragma semicolon 1

/********** PER-GAME BUILD CONFIGURATION **********/

/*
    One source tree builds StAC for every supported SourceMod game.
    Pick the game at compile time by defining ONE of these on the spcomp command line:

        spcomp stac.sp STAC_GAME_TF2=1            (default when nothing is defined)
        spcomp stac.sp STAC_GAME_TF2C=1           TF2 Classified        (game folder "tf2classified", x64)
        spcomp stac.sp STAC_GAME_GOLDRUSH=1       TF2: Gold Rush        (game folder "tf_goldrush",   x64)
        spcomp stac.sp STAC_GAME_OF=1             Open Fortress         (game folder "open_fortress", SDK 2013)
        spcomp stac.sp STAC_GAME_PF2=1            Pre-Fortress 2        (game folder "pf2",           SDK 2013)
        spcomp stac.sp STAC_GAME_FF=1             Fortress Forever      (game folder "fortressforever", SDK 2013)
        spcomp stac.sp STAC_GAME_HL2MP=1          Half-Life 2: Deathmatch (game folder "hl2mp")
        spcomp stac.sp STAC_GAME_CSS=1            Counter-Strike: Source  (game folder "cstrike")

    Other optional switches:
        STAC_NO_UPDATER=1    never register with the Updater plugin (the update URL points at the
                             upstream TF2 build, which must not replace a build for another game)

    Feature switches derived from the game (do not define these by hand):
        STAC_GAME_FOLDER        expected game folder; StAC refuses to run in any other game
        STAC_ENGINE_SDK2013     game runs on the Source SDK 2013 engine branch, not the TF2 branch
        STAC_ENGINE_HL2DM       SourceMod runs the game as Engine_HL2DM (instead of Engine_TF2)
        STAC_ENGINE_CSS         SourceMod runs the game as Engine_CSS (instead of Engine_TF2)
        STAC_SOFT_EXTENSIONS    SteamWorks / Connect / SourceTV Manager / Conplex become optional:
                                StAC loads without them and only the features that need them turn off
        STAC_NO_MEMHACKS        compile out the DHooks detours + SDKCalls in stac_memory.sp
        STAC_STRICT_MEMHACKS    fail to load if the memory hacks can't be set up (upstream behaviour);
                                otherwise StAC logs the problem and runs without them
        STAC_NO_HALLOWEEN_CONDS the game's TFCond numbering differs from TF2's past the base conds,
                                so TF2's Halloween cond ids must not be trusted
        STAC_NO_ENTITY_OUTPUTS  SDKTools has no entity output hooking in this game ("Entity Outputs are
                                disabled"), so the backtrack patch watches trigger_teleport with SDKHooks
        STAC_NO_TF2_API         not a TF2-family game: no tf2_stocks include, no TF2 forwards (taunts,
                                Halloween conds, teleporters), no TF2 damage types, no MvM check
        STAC_PLAYER_CLASS       server class of the player entity, for the m_fFlags sendprop lookup
        STAC_FIRE_BULLETS_TE    name of the temp entity the game sends for hitscan shots
        STAC_NO_FOV_DESIRED     the game's client has no fov_desired cvar, so it isn't queried
        STAC_NO_SPEAKER_CONFIG_CHECK  the game's own client engine registers windows_speaker_config,
                                so that cvar can't be used to spot cathook
        STAC_VERIFY_SDKHOOK_OFFSETS  SourceMod's own gamedata for this game is for an older game build:
                                only SDKHook OnTakeDamage / EndTouch when its offset is the verified one
*/

#if defined STAC_GAME_TF2C

    #define STAC_GAME_FOLDER        "tf2classified"
    #define STAC_GAME_DESC          "TF2 Classified"
    #define STAC_SOFT_EXTENSIONS
    // DHooks detours and raw-address SDKCalls crash TF2 Classified's x64 server on SM 1.13
    #define STAC_NO_MEMHACKS
    #define STAC_NO_HALLOWEEN_CONDS
    #if !defined STAC_NO_UPDATER
        #define STAC_NO_UPDATER
    #endif

#elseif defined STAC_GAME_GOLDRUSH

    #define STAC_GAME_FOLDER        "tf_goldrush"
    #define STAC_GAME_DESC          "TF2: Gold Rush"
    #define STAC_SOFT_EXTENSIONS
    #define STAC_NO_HALLOWEEN_CONDS
    // SourceMod ships no entity output gamedata for Gold Rush
    #define STAC_NO_ENTITY_OUTPUTS
    #if !defined STAC_NO_UPDATER
        #define STAC_NO_UPDATER
    #endif

#elseif defined STAC_GAME_OF

    #define STAC_GAME_FOLDER        "open_fortress"
    #define STAC_GAME_DESC          "Open Fortress"
    #define STAC_ENGINE_SDK2013
    #define STAC_SOFT_EXTENSIONS
    #define STAC_NO_HALLOWEEN_CONDS
    // SourceMod's entity output gamedata doesn't match Open Fortress
    #define STAC_NO_ENTITY_OUTPUTS
    #if !defined STAC_NO_UPDATER
        #define STAC_NO_UPDATER
    #endif

#elseif defined STAC_GAME_PF2

    #define STAC_GAME_FOLDER        "pf2"
    #define STAC_GAME_DESC          "Pre-Fortress 2"
    #define STAC_ENGINE_SDK2013
    #define STAC_SOFT_EXTENSIONS
    #define STAC_NO_HALLOWEEN_CONDS
    #if !defined STAC_NO_UPDATER
        #define STAC_NO_UPDATER
    #endif

#elseif defined STAC_GAME_FF

    #define STAC_GAME_FOLDER        "fortressforever"
    #define STAC_GAME_DESC          "Fortress Forever"
    #define STAC_ENGINE_SDK2013
    #define STAC_SOFT_EXTENSIONS
    #define STAC_NO_TF2_API
    #define STAC_PLAYER_CLASS       "CFFPlayer"
    #define STAC_FIRE_BULLETS_TE    "Shotgun Shot"
    // FF's client has no fov_desired, and the engine FF ships still registers windows_speaker_config
    #define STAC_NO_FOV_DESIRED
    #define STAC_NO_SPEAKER_CONFIG_CHECK
    // SourceMod's FireOutput signature doesn't match FF's server ("Sigscan for FireOutput failed")
    #define STAC_NO_ENTITY_OUTPUTS
    // SourceMod's game.ff.txt offsets are for FF 2.4. These are FF 2013's, read from the CFFPlayer /
    // CBaseEntity vtables in FF's server.so (Windows = Linux index - 1). OnTakeDamage was confirmed on a
    // test server with bots; EndTouch wasn't seen to fire, so the zip doesn't override it.
    #define STAC_VERIFY_SDKHOOK_OFFSETS
    #define STAC_SDKHOOK_ONTAKEDAMAGE_WINDOWS   67
    #define STAC_SDKHOOK_ONTAKEDAMAGE_LINUX     68
    #define STAC_SDKHOOK_ENDTOUCH_WINDOWS       107
    #define STAC_SDKHOOK_ENDTOUCH_LINUX         108
    #if !defined STAC_NO_UPDATER
        #define STAC_NO_UPDATER
    #endif

#elseif defined STAC_GAME_HL2MP

    #define STAC_GAME_FOLDER        "hl2mp"
    #define STAC_GAME_DESC          "Half-Life 2: Deathmatch"
    #define STAC_ENGINE_HL2DM
    #define STAC_SOFT_EXTENSIONS
    #define STAC_NO_TF2_API
    #define STAC_PLAYER_CLASS       "CHL2MP_Player"
    #define STAC_FIRE_BULLETS_TE    "Shotgun Shot"
    #define STAC_NO_FOV_DESIRED
    #if !defined STAC_NO_UPDATER
        #define STAC_NO_UPDATER
    #endif

#elseif defined STAC_GAME_CSS

    #define STAC_GAME_FOLDER        "cstrike"
    #define STAC_GAME_DESC          "Counter-Strike: Source"
    #define STAC_ENGINE_CSS
    #define STAC_SOFT_EXTENSIONS
    #define STAC_NO_TF2_API
    #define STAC_PLAYER_CLASS       "CCSPlayer"
    #define STAC_FIRE_BULLETS_TE    "Shotgun Shot"
    #define STAC_NO_FOV_DESIRED
    #if !defined STAC_NO_UPDATER
        #define STAC_NO_UPDATER
    #endif

#else

    #if !defined STAC_GAME_TF2
        #define STAC_GAME_TF2
    #endif
    #define STAC_GAME_FOLDER        "tf"
    #define STAC_GAME_DESC          "Team Fortress 2"
    // upstream behaviour: every extension is required and the memory hacks must work
    #define STAC_STRICT_MEMHACKS

#endif

/********** CHECKS THAT ONLY HOLD ON TF2 **********/
// False positives found live 2026-11-21 (two legit TF2 Classified players banned). These checks
// encode facts about TF2's client that other games don't share, so only the TF2 build runs them:
//   - bogus achievement: TF2's achievement ids start at 127; TF2C numbers its own from 0, and
//     HL2DM/CS:S/etc. have their own lists, so every real achievement there looked "bogus".
//   - cl_thirdperson must be 0: devonly in TF2, but a normal archived option in TF2C and OF.
//   - windows_speaker_config as a cheat var: the SDK 2013 base engine (OF/PF2/FF) registers it.
//   - fov_desired: TF2 clamps to 90; TF2C, OF and PF2 allow up to 130 (MAX_FOV 130).
#if !defined STAC_GAME_TF2
    #define STAC_NO_ACHIEVEMENT_CHECK
    #define STAC_NO_THIRDPERSON_CHECK
    #if !defined STAC_NO_SPEAKER_CONFIG_CHECK
        #define STAC_NO_SPEAKER_CONFIG_CHECK
    #endif
    #define STAC_FOV_MAX            130
#else
    #define STAC_FOV_MAX            90
#endif

// TF2 and the TF2-based games all call the player class CTFPlayer and send hitscan shots as "Fire Bullets"
#if !defined STAC_PLAYER_CLASS
    #define STAC_PLAYER_CLASS       "CTFPlayer"
#endif
#if !defined STAC_FIRE_BULLETS_TE
    #define STAC_FIRE_BULLETS_TE    "Fire Bullets"
#endif
