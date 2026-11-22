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

    Other optional switches:
        STAC_NO_UPDATER=1    never register with the Updater plugin (the update URL points at the
                             upstream TF2 build, which must not replace a build for another game)

    Feature switches derived from the game (do not define these by hand):
        STAC_GAME_FOLDER        expected game folder; StAC refuses to run in any other game
        STAC_ENGINE_SDK2013     game runs on the Source SDK 2013 engine branch, not the TF2 branch
        STAC_SOFT_EXTENSIONS    SteamWorks / Connect / SourceTV Manager / Conplex become optional:
                                StAC loads without them and only the features that need them turn off
        STAC_NO_MEMHACKS        compile out the DHooks detours + SDKCalls in stac_memory.sp
        STAC_STRICT_MEMHACKS    fail to load if the memory hacks can't be set up (upstream behaviour);
                                otherwise StAC logs the problem and runs without them
        STAC_NO_HALLOWEEN_CONDS the game's TFCond numbering differs from TF2's past the base conds,
                                so TF2's Halloween cond ids must not be trusted
        STAC_NO_ENTITY_OUTPUTS  SDKTools has no entity output hooking in this game ("Entity Outputs are
                                disabled"), so the backtrack patch watches trigger_teleport with SDKHooks
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

#else

    #if !defined STAC_GAME_TF2
        #define STAC_GAME_TF2
    #endif
    #define STAC_GAME_FOLDER        "tf"
    #define STAC_GAME_DESC          "Team Fortress 2"
    // upstream behaviour: every extension is required and the memory hacks must work
    #define STAC_STRICT_MEMHACKS

#endif
