/*
    Gamedata
*/

/*
    The memory hacks below (3 DHooks detours + 3 virtual SDKCalls) give StAC:
      - each client's signon state, so usercmds and client commands sent before signon get eaten
      - CNetChan::GetTimeSinceLastReceived, used to spot lagging clients
      - newline / rtl / ltr char stripping in player names
    Everything else in StAC works without them.

    STAC_STRICT_MEMHACKS (TF2):  any failure here is fatal, like upstream.
    otherwise:                   any failure turns all of them off, logs why, and StAC keeps running.
    STAC_NO_MEMHACKS:            compiled out entirely (games where DHooks/SDKCalls crash the server).
*/

void DoStACGamedata()
{
    memhacksActive = false;

#if defined STAC_NO_MEMHACKS
    StacLog("Memory hacks are compiled out of this build (%s). Signon-state, netchan and name sanitizing hooks are off.", STAC_GAME_DESC);
#else
    if (SetUpMemHacks())
    {
        memhacksActive = true;
    }
#endif

    // ENTPROP OFFSETS

    /* ent flags */
    Offset_m_fFlags = FindSendPropInfo("CTFPlayer", "m_fFlags");

    if ( Offset_m_fFlags == -1 )
    {
#if defined STAC_GAME_TF2
        SetFailState( "Failed to get CTFPlayer::m_fFlags offset." );
#else
        // bhop check falls back to GetEntityFlags
        StacLog("No CTFPlayer::m_fFlags sendprop in this game, using GetEntityFlags instead.");
#endif
    }
}

#if !defined STAC_NO_MEMHACKS

// Fails the plugin in strict builds, otherwise just logs. Always returns false.
bool MemHackFail(const char[] fmt, any ...)
{
    char msg[256];
    VFormat(msg, sizeof(msg), fmt, 2);
#if defined STAC_STRICT_MEMHACKS
    SetFailState("%s", msg);
#else
    StacLog("%s\nRunning without memory hacks: signon-state, netchan and name sanitizing hooks are off.", msg);
#endif
    return false;
}

Handle PrepVirtualCall(const char[] name, SDKType returnType)
{
    StartPrepSDKCall( SDKCall_Raw );
    if ( !PrepSDKCall_SetFromConf( stac_gamedata, SDKConf_Virtual, name ) )
    {
        // EndPrepSDKCall would still hand back a handle for a call with no address
        EndPrepSDKCall();
        return null;
    }
    PrepSDKCall_SetReturnInfo( returnType, SDKPass_Plain );
    return EndPrepSDKCall();
}

// Everything is looked up and validated first, and only then are the detours turned on,
// so a half-working setup never runs (a ProcessUsercmds detour without signon states would eat every usercmd).
bool SetUpMemHacks()
{
    // Our base gamedata file. SourceMod 1.11 throws (instead of returning null) when the file is
    // missing, which would abort OnPluginStart before the no-memhacks fallback - check first.
    char gdpath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, gdpath, sizeof(gdpath), "gamedata/stac.txt");
    if (!FileExists(gdpath))
    {
        return MemHackFail("No StAC gamedata (gamedata/stac.txt) for this game.");
    }
    stac_gamedata = LoadGameConfigFile("stac");
    if (!stac_gamedata)
    {
        return MemHackFail("Failed to load StAC gamedata.");
    }

    // MEMORY OFFSETS

    /*
        Memory offsets
    */
    {
        int signon  = GameConfGetOffset(stac_gamedata, "Offset_SignonState");
        int iclhack = GameConfGetOffset(stac_gamedata, "Offset_IClient_HACK");
        if (signon == -1 || iclhack == -1)
        {
            return MemHackFail("StAC gamedata has no Offset_SignonState / Offset_IClient_HACK for this game.");
        }
        // offset from client's signon state, offset from CBaseClient::this (?)
        Offset_SignonState  = view_as<Address>( signon );
        // Hack, see gamedata
        Offset_IClient_HACK = view_as<Address>( iclhack );
    }

    // VTABLE OFFSETS

    /*
        CBaseClient::GetPlayerSlot - for converting IClient* to ent idx
    */
    SDKCall_GetPlayerSlot = PrepVirtualCall( "CBaseClient::GetPlayerSlot", SDKType_PlainOldData );
    if ( !SDKCall_GetPlayerSlot )
    {
        return MemHackFail( "Failed to get CBaseClient::GetPlayerSlot offset." );
    }
    PrintToServer( "CBaseClient::GetPlayerSlot set up!" );

    /*
        CNetChan::GetMsgHandler - for converting CNetChan::this* to a IClient*
    */
    SDKCall_GetMsgHandler = PrepVirtualCall( "CNetChan::GetMsgHandler", SDKType_PlainOldData );
    if ( !SDKCall_GetMsgHandler )
    {
        return MemHackFail( "Failed to get CNetChan::GetMsgHandler offset." );
    }
    PrintToServer( "CNetChan::GetMsgHandler set up!" );

    /*
        CNetChan::GetTimeSinceLastReceived
    */
    SDKCall_GetTimeSinceLastReceived = PrepVirtualCall( "CNetChan::GetTimeSinceLastReceived", SDKType_Float );
    if ( !SDKCall_GetTimeSinceLastReceived )
    {
        return MemHackFail( "Failed to get CNetChan::GetTimeSinceLastReceived offset." );
    }
    PrintToServer( "CNetChan::GetTimeSinceLastReceived set up!" );

    // SIGNATURES

    /*
        CNetChan::ProcessPacket - for getting client's signonstate
    */
    DynamicDetour hProcessPacket = DynamicDetour.FromConf(stac_gamedata, "CNetChan::ProcessPacket");
    if (!hProcessPacket)
    {
        return MemHackFail("Failed to setup detour for CNetChan::ProcessPacket");
    }

    /*
        CBasePlayer::ProcessUsercmds - for eating usercmds from players who aren't signed on
    */
    DynamicDetour hProcessUsercmds = DynamicDetour.FromConf( stac_gamedata, "CBasePlayer::ProcessUsercmds" );
    if ( !hProcessUsercmds )
    {
        delete hProcessPacket;
        return MemHackFail( "Failed to setup detour for CBasePlayer::ProcessUsercmds" );
    }

    /*
        CVEngineServer::GetClientConVarValue - for sanitizing client names
    */
    DynamicDetour hGetClientConVarValue = DynamicDetour.FromConf( stac_gamedata, "CVEngineServer::GetClientConVarValue" );
    if ( !hGetClientConVarValue )
    {
        delete hProcessPacket;
        delete hProcessUsercmds;
        return MemHackFail( "Failed to setup detour for CVEngineServer::GetClientConVarValue" );
    }

    // detours
    if ( !hProcessPacket.Enable(Hook_Pre, Detour_CNetChan__ProcessPacket) )
    {
        return MemHackFail("Failed to detour CNetChan::ProcessPacket.");
    }
    PrintToServer("CNetChan::ProcessPacket detoured!");

    if ( !hProcessUsercmds.Enable(Hook_Pre, Detour_CBasePlayer__ProcessUsercmds) )
    {
        hProcessPacket.Disable(Hook_Pre, Detour_CNetChan__ProcessPacket);
        return MemHackFail( "Failed to detour CBasePlayer::ProcessUsercmds." );
    }
    PrintToServer( "CBasePlayer::ProcessUsercmds detoured!" );

    if ( !hGetClientConVarValue.Enable(Hook_Post, Detour_CVEngineServer__GetClientConVarValue) )
    {
        hProcessPacket.Disable(Hook_Pre, Detour_CNetChan__ProcessPacket);
        hProcessUsercmds.Disable(Hook_Pre, Detour_CBasePlayer__ProcessUsercmds);
        return MemHackFail( "Failed to detour CVEngineServer::GetClientConVarValue." );
    }
    PrintToServer( "CVEngineServer::GetClientConVarValue detoured!" );

    return true;
}

public MRESReturn Detour_CBasePlayer__ProcessUsercmds(int entity, DHookParam hParams)
{
    if (!memhacksActive)
    {
        return MRES_Ignored;
    }
    // Could this ever throw? We may one day find out...
    if (IsFakeClient(entity))
    {
        return MRES_Ignored;
    }

    if (signonStateFor[entity] <= SIGNONSTATE_SPAWN)
    {
        return MRES_Supercede;
    }
    return MRES_Ignored;
}


public MRESReturn Detour_CNetChan__ProcessPacket(Address pThis, DHookParam hParams)
{
    // Get our client idx and iclient ptr
    Address icl_ptr;
    int cl;
    if (!GetClientFromNetChan(pThis, icl_ptr, cl) || !icl_ptr || cl <= 0)
    {
        StacLog
        (
            "\
            \njunk in CNetChan::ProcessPacket detour:\
            \npThis 0x%lx\
            \nicl_ptr 0x%lx\
            \ncl %i\
            ",
            pThis,
            icl_ptr,
            cl
        );

        return MRES_Ignored;
    }

    // TODO: do this in a SetSignonState detour?
    // ^ no, would break on lateload
    int signonState     = GetSignonState(icl_ptr);
    signonStateFor[cl]  = signonState;

    timeSinceLastRecvFor[cl] = SDKCall(SDKCall_GetTimeSinceLastReceived, pThis);

    return MRES_Ignored;
}

bool GetClientFromNetChan(Address pThis, Address& IClient, int& client)
{
    IClient = Address_Null;
    client  = -1;
    // sanity check
    if (!pThis)
    {
        StacLog("null pThis??");
        return false;
    }

    IClient = SDKCall( SDKCall_GetMsgHandler, pThis );
    // Clients will be null when connecting and disconnecting
    if (!IClient)
    {
        StacLog("null iclient??");
        return false;
    }

    client = SDKCall(SDKCall_GetPlayerSlot, IClient) + 1;

    return true;
}


int GetSignonState(Address IClient)
{
    if (!IClient)
    {
        return -1;
    }

    // m_nSignonState is a 4 byte int regardless of arch, its fine to use LoadFromAddress
    int signonState = LoadFromAddress( (IClient - Offset_IClient_HACK) + Offset_SignonState, NumberType_Int32 )
    return signonState;
}

// const char* GetClientConVarValue( int clientIndex, const char *name );
public MRESReturn Detour_CVEngineServer__GetClientConVarValue(Address pThis, DHookReturn hReturn, DHookParam hParams)
{
    int cl = DHookGetParam(hParams, 1);
    char nameOfCvar[256];
    hParams.GetString(2, nameOfCvar, sizeof(nameOfCvar));

    // Not their name, don't care
    if (!StrEqual(nameOfCvar, "name", .caseSensitive=true))
    {
        return MRES_Ignored;
    }

    // Invalid client, do not care
    if (!IsValidClient(cl))
    {
        return MRES_Ignored;
    }

    // lol
    static char name[(MAX_NAME_LENGTH*2)+1];
    name[0] = 0x0;

    // i really hope this just works
    hReturn.GetString(name, sizeof(name));

    int newlines;
    int returns;
    int rtl;
    int ltr;

    // todo: implement C style iscntrl
    newlines    = ReplaceString(name, sizeof(name), "\n",           "");
    returns     = ReplaceString(name, sizeof(name), "\r",           "");
    rtl         = ReplaceString(name, sizeof(name), "\xE2\x80\x8F", "");
    ltr         = ReplaceString(name, sizeof(name), "\xE2\x80\x8E", "");

    // We didn't replace anything. We don't care.
    if ( newlines == 0 && returns == 0 && rtl == 0 && ltr == 0 )
    {
        return MRES_Ignored;
    }

    hReturn.SetString(name);

    char namemsg[512];
    Format
    (
        namemsg,
        sizeof(namemsg),
        "Client had %i newline chars, %i return chars, %i right2left chars, and %i left2right chars in their name",
        newlines,
        returns,
        rtl,
        ltr
    );

    int userid = GetClientUserId(cl);
    DataPack pack = new DataPack();
    pack.Reset(.clear=true);
    pack.WriteCell(userid);
    pack.WriteString(namemsg);
    pack.WriteString(name);
    pack.Reset(.clear=false);
    CreateTimer(1.0, Timer_SendStacNameNotif, pack);
    CreateTimer(2.0, BanName, userid);
    return MRES_Override;
}

Action Timer_SendStacNameNotif(Handle timer, DataPack pack)
{
    // already at the beginning of the pack...
    // pack.Reset(.clear=false);
    int userid = pack.ReadCell();
    char namemsg[512];
    char name[(MAX_NAME_LENGTH*2)+1];
    pack.ReadString(namemsg, sizeof(namemsg));
    pack.ReadString(name, sizeof(name));
    pack.Reset(.clear=true);
    delete pack;

    int cl = GetClientOfUserId(userid);

    if (!IsValidClient(cl))
    {
        return Plugin_Continue;
    }
    // Sanitize their name outside of our detour lol
    SetClientName(cl, name);

    StacLog(namemsg);
    StacNotify(userid, namemsg, 1);

    return Plugin_Continue;
}

#endif // !STAC_NO_MEMHACKS
