/*
*
*	Block Damage by RedSMURF/Drekes
*	
*
*	Description:
*		Enables / disables damage done by a player.
*
*	Cvars:
*		None
*	
*	Commands:
*       amx_blockdamage                                     "Opens a menu for selecting a player with preset durations."
*		amx_blockdamage <name/steamid/userid> 	            "Block/Unblock damage done by a player." 
*       amx_blockdamage <name/steamid/userid> <duration>    "Blocks damage with a specific duration."
*		amx_blockdamage_list	                            "List all the currently connected no-damage players."
* 
*
*	Changelog:
*		v1.0 : Solved the unblock damage issue
*		v1.1 : Added a time option instead of manually unblocking
*
*/
#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <nvault>
		
#define VERSION "1.1"
#define isPlayer(%1) (1 <= %1 <= g_iMaxPlayers)
#define MAX_PLAYERS 32
#define MAX_TIME 9999

enum _:PLAYER_DATA
{
    PDATA_NAME[ 32 ],
    PDATA_AUTHID[ 64 ],
    PDATA_USERID[ 4 ],
    PDATA_NO_DAMAGE_STR[ 4 ],
    bool:PDATA_NO_DAMAGE,
    PDATA_NO_DAMAGE_COOLDOWN,
    bool:PDATA_NO_DAMAGE_COOLDOWN_FLAG,
    PDATA_MENU_TARGET
}

enum _:MENUS
{
    MENU_SHOW_PLAYERS,
    MENU_SHOW_DURATIONS
}

new g_ePlayerData[ MAX_PLAYERS + 1 ][ PLAYER_DATA ],
    g_iVault,
	g_iMaxPlayers,
    g_iitemHandlerPlayers,
    g_szDurations[][] = { "10", "20", "30", "45", "60", "90", "120", "240", "480", "PERMANENT" }

public plugin_init()
{
	register_plugin( "Block Damage", VERSION, "RedSMURF/Drekes" )
	register_cvar( "amx_blockdamage_version", VERSION, FCVAR_SERVER | FCVAR_SPONLY )
	
	register_concmd( "amx_blockdamage", "cmdBlockDamage", ADMIN_RCON, "<name/steamid/userid> ^"Block/Unblock a player from doing damage^"" )
	register_concmd( "amx_blockdamage_list", "cmdBlockDamageList", ADMIN_RCON, "Displays a list with all current connected no-damage players" )
    RegisterHam( Ham_TraceAttack, "player", "fwdPlayerTraceAttack" )
	
	g_iMaxPlayers = get_maxplayers()
    g_iitemHandlerPlayers = menu_makecallback( "itemHandlerPlayers" )
	g_iVault = nvault_open( "amx_blockdamage" )
	
	if( g_iVault == INVALID_HANDLE )
		set_fail_state( "Couldn't open nvault" )

    set_task( 1.0, "updateTimer", .flags = "b" )
}

public plugin_end()
{
	nvault_close( g_iVault )
}

public client_authorized( id )
{
    get_user_name( id, g_ePlayerData[ id ][ PDATA_NAME ], charsmax( g_ePlayerData[][ PDATA_NAME ] ) )
    get_user_authid( id, g_ePlayerData[ id ][ PDATA_AUTHID ], charsmax( g_ePlayerData[][ PDATA_AUTHID ] ) )
    formatex( g_ePlayerData[ id ][ PDATA_USERID ], charsmax( g_ePlayerData[][ PDATA_USERID ] ), "%d", get_user_userid( id ) )

	nvault_get( g_iVault, g_ePlayerData[ id ][ PDATA_AUTHID ], g_ePlayerData[ id ][ PDATA_NO_DAMAGE_STR ], charsmax( g_ePlayerData[][ PDATA_NO_DAMAGE_STR ] ) )
    g_ePlayerData[ id ][ PDATA_NO_DAMAGE ] = bool:str_to_num( g_ePlayerData[ id ][ PDATA_NO_DAMAGE_STR ] )
}

public client_disconnected( id )
{
    formatex( g_ePlayerData[ id ][ PDATA_NO_DAMAGE_STR ],
    charsmax( g_ePlayerData[][ PDATA_NO_DAMAGE_STR ] ), "%d", g_ePlayerData[ id ][ PDATA_NO_DAMAGE ] )

	nvault_set( g_iVault, g_ePlayerData[ id ][ PDATA_AUTHID ], g_ePlayerData[ id ][ PDATA_NO_DAMAGE_STR ] )
}

public updateTimer()
{
    new iPlayers[ MAX_PLAYERS ], iNum, iPlayer
    get_players( iPlayers, iNum, "h" )

    for ( new i = 0; i < iNum; i ++ )
    {
        iPlayer = iPlayers[ i ]

        if ( !g_ePlayerData[ iPlayer ][ PDATA_NO_DAMAGE ] || !g_ePlayerData[ iPlayer ][ PDATA_NO_DAMAGE_COOLDOWN_FLAG ] )
            continue

        if ( !g_ePlayerData[ iPlayer ][ PDATA_NO_DAMAGE_COOLDOWN ] )
        {
            g_ePlayerData[ iPlayer ][ PDATA_NO_DAMAGE ] = false
            g_ePlayerData[ iPlayer ][ PDATA_NO_DAMAGE_COOLDOWN_FLAG ] = false

            client_print( 0, print_chat, "%s is no longer blocked from doing damage", g_ePlayerData[ iPlayer ][ PDATA_NAME ] )
        }
        else
            g_ePlayerData[ iPlayer ][ PDATA_NO_DAMAGE_COOLDOWN ] -= 1 
    }
}

public cmdBlockDamage( id, iLevel, iCid )
{
    if ( !cmd_access( id, iLevel, iCid, 1 ) )
        return PLUGIN_HANDLED

    switch( read_argc() )
    {
        case 1:
        {
            showMenu( id, MENU_SHOW_PLAYERS )
        }

        case 2:
        {
            new szTarget[ 32 ], iTarget
            read_argv( 1, szTarget, charsmax( szTarget ) )

            iTarget = cmd_target( id, szTarget, CMDTARGET_ALLOW_SELF | CMDTARGET_OBEY_IMMUNITY )
            if ( iTarget )
            {
                g_ePlayerData[ iTarget ][ PDATA_NO_DAMAGE ] = !g_ePlayerData[ iTarget ][ PDATA_NO_DAMAGE ]
                logCommand( id, iTarget )
            }
        }

        case 3: 
        {
            new szTarget[ 32 ], szNum[ 16 ], iTarget

            read_argv( 1, szTarget, charsmax( szTarget ) )
            read_argv( 2, szNum, charsmax( szNum ) )

            iTarget = cmd_target( id, szTarget, CMDTARGET_ALLOW_SELF | CMDTARGET_OBEY_IMMUNITY )
            if ( iTarget )
            {
                g_ePlayerData[ iTarget ][ PDATA_NO_DAMAGE_COOLDOWN ] = str_to_num( szNum )
                g_ePlayerData[ iTarget ][ PDATA_NO_DAMAGE_COOLDOWN ] = clamp( g_ePlayerData[ iTarget ][ PDATA_NO_DAMAGE_COOLDOWN ], 0, MAX_TIME )

                g_ePlayerData[ iTarget ][ PDATA_NO_DAMAGE ] = true
                g_ePlayerData[ iTarget ][ PDATA_NO_DAMAGE_COOLDOWN_FLAG ] = true
                logCommand( id, iTarget, true )
            }
        }

        default: 
        {
            console_print( id, "Usage: ^namx_blockdamage ^namx_blockdamage <name/steamid/userid> ^namx_blockdamage <name/steamid/userid> <duration>" )
        }
    }

    return PLUGIN_HANDLED
}

public showMenu( id, iType )
{
    new iMenu, szItem[ 64 ], iPlayers[ 32 ], iNum, iPlayer

    switch( iType )
    {
        case MENU_SHOW_PLAYERS:
        {
            iMenu = menu_create( "Choose your option", "menuHandlerPlayers" )
            get_players( iPlayers, iNum, "h" )

            for ( new i = 0; i < iNum; i ++ )
            {
                iPlayer = iPlayers[ i ]
                menu_additem( iMenu, g_ePlayerData[ iPlayer ][ PDATA_NAME ], g_ePlayerData[ iPlayer ][ PDATA_USERID ], .callback = g_iitemHandlerPlayers )
            }
        }

        case MENU_SHOW_DURATIONS:
        {
            iMenu = menu_create( "Choose your option", "menuHandlerDurations" )

            for ( new i = 0; i < sizeof( g_szDurations ); i ++ )
            {
                formatex( szItem, charsmax( szItem ), "%s %s",
                g_szDurations[ i ], equal( g_szDurations[ i ], "PERMANENT" ) ? "" : "seconds" )

                menu_additem( iMenu, szItem, g_szDurations[ i ] )
            }
        }
    }

    menu_setprop( iMenu, MPROP_EXIT, MEXIT_FORCE )
    menu_setprop( iMenu, MPROP_NUMBER_COLOR, "\y" )

    menu_display( id, iMenu )
}

public menuHandlerPlayers( id, menu, item )
{
    if ( item == MENU_EXIT )
    {
        menu_destroy( menu )
        return PLUGIN_HANDLED
    }
    new iAccess, szName[ 32 ], szInfo[ 32 ], iTarget

    menu_item_getinfo( menu, item, iAccess, szInfo, charsmax( szInfo ), szName, charsmax( szName ) )
    iTarget = find_player( "k", str_to_num( szInfo ) )

    g_ePlayerData[ id ][ PDATA_MENU_TARGET ] = iTarget 
    showMenu( id, MENU_SHOW_DURATIONS )

    menu_destroy( menu )
    return PLUGIN_HANDLED
}

public itemHandlerPlayers( id, menu, item )
{
    new iAccess, szName[ 32 ], szInfo[ 32 ], iTarget

    menu_item_getinfo( menu, item, iAccess, szInfo, charsmax( szInfo ), szName, charsmax( szName ) )
    iTarget = find_player( "k", str_to_num( szInfo ) )

    return !iTarget || g_ePlayerData[ iTarget ][ PDATA_NO_DAMAGE ] ? ITEM_DISABLED : ITEM_IGNORE
}

public menuHandlerDurations( id, menu, item )
{
    if ( item == MENU_EXIT )
    {
        menu_destroy( menu )
        return PLUGIN_HANDLED
    }
    new iAccess, szName[ 32 ], szInfo[ 32 ], iTarget, iDuration

    menu_item_getinfo( menu, item, iAccess, szInfo, charsmax( szInfo ), szName, charsmax( szName ) )
    iTarget = g_ePlayerData[ id ][ PDATA_MENU_TARGET ]

    if ( szInfo[ 0 ] == 'P' )
    {
        g_ePlayerData[ iTarget ][ PDATA_NO_DAMAGE ] = true
        logCommand( id, iTarget )
    }
    else 
    {
        iDuration = str_to_num( szInfo )
        iDuration = clamp( iDuration, 0, MAX_TIME )

        g_ePlayerData[ iTarget ][ PDATA_NO_DAMAGE ] = true
        g_ePlayerData[ iTarget ][ PDATA_NO_DAMAGE_COOLDOWN ] = iDuration
        g_ePlayerData[ iTarget ][ PDATA_NO_DAMAGE_COOLDOWN_FLAG ] = true

        logCommand( id, iTarget, true )
    }

    menu_destroy( menu )
    return PLUGIN_HANDLED
}

public cmdBlockDamageList( id, iLevel, iCid )
{
	if( !cmd_access( id, iLevel, iCid, 1 ) )
		return PLUGIN_HANDLED
		
	new szText[ 512 ], iLen
	iLen = formatex( szText, charsmax( szText ), "Currently connected no-damage players:^n" )
	
	new iPlayers[ 32 ], iNum, iPlayer, iBlockedPlayers
	get_players( iPlayers, iNum, "h" )
	
	for( new i = 0; i < iNum; i++ )
	{
		iPlayer = iPlayers[ i ]
		
		if( !g_ePlayerData[ iPlayer ][ PDATA_NO_DAMAGE ] )
			continue
			
		iBlockedPlayers++ 
		iLen += format( szText[ iLen ], charsmax( szText ) - iLen, "- %s^n", g_ePlayerData[ iPlayer ][ PDATA_NAME ] )
	}
	
	if( !iBlockedPlayers )
		formatex( szText, charsmax(szText), "No no-damage players connected." )
		
	console_print( id, szText )
	
	return PLUGIN_HANDLED
}

public fwdPlayerTraceAttack( iVictim, iAttacker, Float:Damage, Float:fDirection[ 3 ], iDamageBits )
{
	return ( isPlayer( iAttacker ) && g_ePlayerData[ iAttacker ][ PDATA_NO_DAMAGE ] ) ? HAM_SUPERCEDE : HAM_IGNORED
}

stock logCommand( id, iTarget, bool:bCoolDown = false )
{
    if ( !bCoolDown )
    {
        console_print( id, "[AMXX] %slocked damage for player %s", 
        g_ePlayerData[ iTarget ][ PDATA_NO_DAMAGE ] ? "B" : "Unb", g_ePlayerData[ iTarget ][ PDATA_NAME ] )

	    show_activity( id, g_ePlayerData[ id ][ PDATA_NAME ], "%slocked damage for %s",
        g_ePlayerData[ iTarget ][ PDATA_NO_DAMAGE ] ? "B" : "Unb", g_ePlayerData[ iTarget ][ PDATA_NAME ] )

	    log_amx( "[AMXX] ADMIN ^"%s^" <%s> %slocked damage for ^"%s^" <%s>", 
        g_ePlayerData[ id ][ PDATA_NAME ], g_ePlayerData[ id ][ PDATA_AUTHID ], 
	    g_ePlayerData[ iTarget ][ PDATA_NO_DAMAGE ] ? "B" : "Unb", 
        g_ePlayerData[ iTarget ][ PDATA_NAME ], g_ePlayerData[ iTarget ][ PDATA_AUTHID ] )
    }
    else 
    {
        console_print( id, "[AMXX] Blocked damage for player %s for %d second%s", 
        g_ePlayerData[ iTarget ][ PDATA_NAME ], g_ePlayerData[ iTarget ][ PDATA_NO_DAMAGE_COOLDOWN ], 
        g_ePlayerData[ iTarget ][ PDATA_NO_DAMAGE_COOLDOWN ] == 1 ? "" : "s" )

	    show_activity( id, g_ePlayerData[ id ][ PDATA_NAME ], "Blocked damage for %s for %d second%s",
        g_ePlayerData[ iTarget ][ PDATA_NAME ], g_ePlayerData[ iTarget ][ PDATA_NO_DAMAGE_COOLDOWN ], 
        g_ePlayerData[ iTarget ][ PDATA_NO_DAMAGE_COOLDOWN ] == 1 ? "" : "s" )

	    log_amx( "[AMXX] ADMIN ^"%s^" <%s> Blocked damage for ^"%s^" <%s> for %d second%s", 
        g_ePlayerData[ id ][ PDATA_NAME ], g_ePlayerData[ id ][ PDATA_AUTHID ], 
        g_ePlayerData[ iTarget ][ PDATA_NAME ], g_ePlayerData[ iTarget ][ PDATA_AUTHID ],
        g_ePlayerData[ iTarget ][ PDATA_NO_DAMAGE_COOLDOWN ], g_ePlayerData[ iTarget ][ PDATA_NO_DAMAGE_COOLDOWN ] == 1 ? "" : "s" )
    }
}