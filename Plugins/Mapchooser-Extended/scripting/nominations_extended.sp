/**
 * vim: set ts=4 :
 * =============================================================================
 * Nominations Extended
 * Allows players to nominate maps for Mapchooser
 *
 * Nominations Extended (C)2012-2013 Powerlord (Ross Bemrose)
 * SourceMod (C)2004-2007 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <mapchooser>
#include <mapchooser_extended>
#include <multicolors>
#include <basecomm>

#define MCE_VERSION "1.14.0"

public Plugin myinfo =
{
	name = "Map Nominations Extended with Admin and VIP Map",
	author = "Powerlord, Oylsister and AlliedModders LLC",
	description = "Provides Map Nominations",
	version = MCE_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=156974"
};

Handle g_Cvar_ExcludeOld = INVALID_HANDLE;
Handle g_Cvar_ExcludeCurrent = INVALID_HANDLE;

Handle g_MapList = INVALID_HANDLE;
Handle g_AdminMapList = INVALID_HANDLE;
Menu g_MapMenu;
Menu g_AdminMapMenu;
int g_mapFileSerial = -1;
int g_AdminMapFileSerial = -1;

#define LoopAllPlayers(%1) for(int %1=1;%1<=MaxClients;++%1)\
if(IsClientInGame(%1) && !IsFakeClient(%1))

#define MAPSTATUS_ENABLED (1<<0)
#define MAPSTATUS_DISABLED (1<<1)
#define MAPSTATUS_EXCLUDE_CURRENT (1<<2)
#define MAPSTATUS_EXCLUDE_PREVIOUS (1<<3)
#define MAPSTATUS_EXCLUDE_NOMINATED (1<<4)

Handle g_mapTrie;

// Nominations Extended Convars
Handle g_Cvar_MarkCustomMaps = INVALID_HANDLE;
Handle g_Cvar_NominateDelay = INVALID_HANDLE;
Handle g_Cvar_InitialDelay = INVALID_HANDLE;

int g_Player_NominationDelay[MAXPLAYERS+1];
int g_NominationDelay;

Handle g_Cvar_SteamGroupID = INVALID_HANDLE;

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("nominations.phrases");
	LoadTranslations("basetriggers.phrases"); // for Next Map phrase
	LoadTranslations("mapchooser_extended.phrases");

	int arraySize = ByteCountToCells(PLATFORM_MAX_PATH);
	g_MapList = CreateArray(arraySize);
	g_AdminMapList = CreateArray(arraySize);

	g_Cvar_ExcludeOld = CreateConVar("sm_nominate_excludeold", "1", "Specifies if the current map should be excluded from the Nominations list", 0, true, 0.00, true, 1.0);
	g_Cvar_ExcludeCurrent = CreateConVar("sm_nominate_excludecurrent", "1", "Specifies if the MapChooser excluded maps should also be excluded from Nominations", 0, true, 0.00, true, 1.0);
	g_Cvar_InitialDelay = CreateConVar("sm_nominate_initialdelay", "60.0", "Time in seconds before first Nomination can be made", 0, true, 0.00);
	g_Cvar_NominateDelay = CreateConVar("sm_nominate_delay", "3.0", "Delay between nominations", 0, true, 0.00, true, 60.00);
	g_Cvar_SteamGroupID = CreateConVar("sm_nominte_steamid", "103582791465893760", "Steam Group ID 64");

	RegConsoleCmd("say", Command_Say);
	RegConsoleCmd("say_team", Command_Say);

	RegConsoleCmd("sm_nominate", Command_Nominate);
	RegConsoleCmd("sm_nomlist", Command_NominateList);

	RegAdminCmd("sm_nominate_addmap", Command_Addmap, ADMFLAG_CHANGEMAP, "sm_nominate_addmap <mapname> - Forces a map to be on the next mapvote.");
	RegAdminCmd("sm_nominate_removemap", Command_Removemap, ADMFLAG_CHANGEMAP, "sm_nominate_removemap <mapname> - Removes a map from Nominations.");

	RegAdminCmd("sm_nominate_exclude", Command_AddExclude, ADMFLAG_CHANGEMAP, "sm_nominate_exclude <mapname> [cooldown] - Forces a map to be inserted into the recently played maps. Effectively blocking the map from being nominated.");

	// Nominations Extended cvars
	CreateConVar("ne_version", MCE_VERSION, "Nominations Extended Version", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_mapTrie = CreateTrie();
	AutoExecConfig();
}

public APLRes AskPluginLoad2(Handle hThis, bool bLate, char[] err, int iErrLen)
{
	RegPluginLibrary("nominations");

	CreateNative("GetNominationPool", Native_GetNominationPool);
	CreateNative("PushMapIntoNominationPool", Native_PushMapIntoNominationPool);
	CreateNative("PushMapsIntoNominationPool", Native_PushMapsIntoNominationPool);
	CreateNative("RemoveMapFromNominationPool", Native_RemoveMapFromNominationPool);
	CreateNative("RemoveMapsFromNominationPool", Native_RemoveMapsFromNominationPool);

	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	// This is an MCE cvar... this plugin requires MCE to be loaded.  Granted, this plugin SHOULD have an MCE dependency.
	g_Cvar_MarkCustomMaps = FindConVar("mce_markcustommaps");
}

public void OnConfigsExecuted()
{
	if(ReadMapList(g_MapList,
					g_mapFileSerial,
					"nominations",
					MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_MAPSFOLDER)
		== INVALID_HANDLE)
	{
		if(g_mapFileSerial == -1)
		{
			SetFailState("Unable to create a valid map list.");
		}
	}

	if(ReadMapList(g_AdminMapList,
					g_AdminMapFileSerial,
					"sm_nominate_addmap menu",
					MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_NO_DEFAULT|MAPLIST_FLAG_MAPSFOLDER)
		== INVALID_HANDLE)
	{
		if(g_AdminMapFileSerial == -1)
		{
			SetFailState("Unable to create a valid admin map list.");
		}
	}
	else
	{
		for(int i = 0; i < GetArraySize(g_MapList); i++)
		{
			static char map[PLATFORM_MAX_PATH];
			GetArrayString(g_MapList, i, map, sizeof(map));

			int Index = FindStringInArray(g_AdminMapList, map);
			if(Index != -1)
				RemoveFromArray(g_AdminMapList, Index);
		}
	}

	g_NominationDelay = GetTime() + GetConVarInt(g_Cvar_InitialDelay);

	UpdateMapTrie();
	UpdateMapMenus();
}

void UpdateMapMenus()
{
	if(g_MapMenu != INVALID_HANDLE)
		delete g_MapMenu;

	g_MapMenu = BuildMapMenu("");

	if(g_AdminMapMenu != INVALID_HANDLE)
		delete g_AdminMapMenu;

	g_AdminMapMenu = BuildAdminMapMenu("");
}

void UpdateMapTrie()
{
	static char map[PLATFORM_MAX_PATH];
	static char currentMap[PLATFORM_MAX_PATH];
	ArrayList excludeMaps;

	if(GetConVarBool(g_Cvar_ExcludeOld))
	{
		excludeMaps = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
		GetExcludeMapList(excludeMaps);
	}

	if(GetConVarBool(g_Cvar_ExcludeCurrent))
		GetCurrentMap(currentMap, sizeof(currentMap));

	ClearTrie(g_mapTrie);

	for(int i = 0; i < GetArraySize(g_MapList); i++)
	{
		int status = MAPSTATUS_ENABLED;

		GetArrayString(g_MapList, i, map, sizeof(map));

		if(GetConVarBool(g_Cvar_ExcludeCurrent))
		{
			if(StrEqual(map, currentMap))
				status = MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_CURRENT;
		}

		/* Dont bother with this check if the current map check passed */
		if(GetConVarBool(g_Cvar_ExcludeOld) && status == MAPSTATUS_ENABLED)
		{
			if(FindStringInArray(excludeMaps, map) != -1)
				status = MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_PREVIOUS;
		}

		SetTrieValue(g_mapTrie, map, status);
	}

	if(excludeMaps)
		delete excludeMaps;
}

public void OnNominationRemoved(const char[] map, int owner)
{
	int status;

	/* Is the map in our list? */
	if(!GetTrieValue(g_mapTrie, map, status))
		return;

	/* Was the map disabled due to being nominated */
	if((status & MAPSTATUS_EXCLUDE_NOMINATED) != MAPSTATUS_EXCLUDE_NOMINATED)
		return;

	SetTrieValue(g_mapTrie, map, MAPSTATUS_ENABLED);
}

public Action Command_Addmap(int client, int args)
{
	if(args == 0)
	{
		AttemptAdminNominate(client);
		return Plugin_Handled;
	}

	if(args != 1)
	{
		CReplyToCommand(client, "\x04[NE]\x01 Usage: sm_nominate_addmap <mapname>");
		return Plugin_Handled;
	}

	static char mapname[PLATFORM_MAX_PATH];
	GetCmdArg(1, mapname, sizeof(mapname));

	if(!IsMapValid(mapname))
	{
		CReplyToCommand(client, "%t", "Map was not found", mapname);
		AttemptAdminNominate(client, mapname);
		return Plugin_Handled;
	}

	if(!CheckCommandAccess(client, "sm_nominate_ignore", ADMFLAG_CHEATS, true))
	{
		int status;
		if(GetTrieValue(g_mapTrie, mapname, status))
		{
			if((status & MAPSTATUS_DISABLED) == MAPSTATUS_DISABLED)
			{
				if((status & MAPSTATUS_EXCLUDE_CURRENT) == MAPSTATUS_EXCLUDE_CURRENT)
					CPrintToChat(client, "\x04[NE]\x01 %t", "Can't Nominate Current Map");

				if((status & MAPSTATUS_EXCLUDE_PREVIOUS) == MAPSTATUS_EXCLUDE_PREVIOUS)
				{
					int Cooldown = GetMapCooldown(mapname);
					CPrintToChat(client, "\x04[NE]\x01 %t (%d)", "Map in Exclude List", Cooldown);
				}

				if((status & MAPSTATUS_EXCLUDE_NOMINATED) == MAPSTATUS_EXCLUDE_NOMINATED)
					CPrintToChat(client, "\x04[NE]\x01 %t", "Map Already Nominated");

				return Plugin_Handled;
			}
		}

		int TimeRestriction = GetMapTimeRestriction(mapname);
		if(TimeRestriction)
		{
			CPrintToChat(client, "\x04[NE]\x01 %t", "Map Nominate Time Error", RoundToFloor(float(TimeRestriction / 60)), TimeRestriction % 60);

			return Plugin_Handled;
		}

		int PlayerRestriction = GetMapPlayerRestriction(mapname);
		if(PlayerRestriction)
		{
			if(PlayerRestriction < 0)
				CPrintToChat(client, "\x04[NE]\x01 %t", "Map Nominate MinPlayers Error", PlayerRestriction * -1);
			else
				CPrintToChat(client, "\x04[NE]\x01 %t", "Map Nominate MaxPlayers Error", PlayerRestriction);

			return Plugin_Handled;
		}

		int GroupRestriction = GetMapGroupRestriction(mapname);
		if(GroupRestriction >= 0)
		{
			CPrintToChat(client, "\x04[NE]\x01 %t", "Map Nominate Group Error", GroupRestriction);
			return Plugin_Handled;
		}
	}

	NominateResult result = NominateMap(mapname, true, 0);

	if(result > Nominate_Replaced)
	{
		/* We assume already in vote is the casue because the maplist does a Map Validity check and we forced, so it can't be full */
		CReplyToCommand(client, "%t", "Map Already In Vote", mapname);

		return Plugin_Handled;
	}

	SetTrieValue(g_mapTrie, mapname, MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_NOMINATED);

	CReplyToCommand(client, "%t", "Map Inserted", mapname);
	LogAction(client, -1, "\"%L\" inserted map \"%s\".", client, mapname);

	CPrintToChatAll("\x04[NE]\x01 %N has inserted %s into nominations", client, mapname);

	return Plugin_Handled;
}

public Action Command_Removemap(int client, int args)
{
	if(args != 1)
	{
		CReplyToCommand(client, "\x04[NE]\x01 Usage: sm_nominate_removemap <mapname>");
		return Plugin_Handled;
	}

	static char mapname[PLATFORM_MAX_PATH];
	GetCmdArg(1, mapname, sizeof(mapname));

	// int status;
	if(/*!GetTrieValue(g_mapTrie, mapname, status)*/!IsMapValid(mapname))
	{
		CReplyToCommand(client, "%t", "Map was not found", mapname);
		return Plugin_Handled;
	}

	if(!RemoveNominationByMap(mapname))
	{
		CReplyToCommand(client, "This map isn't nominated.", mapname);

		return Plugin_Handled;
	}

	CReplyToCommand(client, "Map '%s' removed from the nominations list.", mapname);
	LogAction(client, -1, "\"%L\" removed map \"%s\" from nominations.", client, mapname);

	CPrintToChatAll("\x04[NE]\x01 %N has removed %s from nominations", client, mapname);

	return Plugin_Handled;
}

public Action Command_AddExclude(int client, int args)
{
	if(args < 1)
	{
		CReplyToCommand(client, "\x04[NE]\x01 Usage: sm_nominate_exclude <mapname>");
		return Plugin_Handled;
	}

	static char mapname[PLATFORM_MAX_PATH];
	GetCmdArg(1, mapname, sizeof(mapname));

	int cooldown = 0;
	int mode = 0;
	if(args >= 2)
	{
		static char buffer[8];
		GetCmdArg(2, buffer, sizeof(buffer));
		cooldown = StringToInt(buffer);
	}
	if(args >= 3)
	{
		static char buffer[8];
		GetCmdArg(3, buffer, sizeof(buffer));
		mode = StringToInt(buffer);
	}

	int status;
	if(!GetTrieValue(g_mapTrie, mapname, status))
	{
		CReplyToCommand(client, "\x04[NE]\x01 %t", "Map was not found", mapname);
		return Plugin_Handled;
	}

	ShowActivity(client, "Excluded map \"%s\" from nomination", mapname);
	LogAction(client, -1, "\"%L\" excluded map \"%s\" from nomination", client, mapname);

	SetTrieValue(g_mapTrie, mapname, MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_PREVIOUS);

	// native call to mapchooser_extended
	ExcludeMap(mapname, cooldown, mode);

	return Plugin_Handled;
}

public Action Command_Say(int client, int args)
{
	if(!client)
		return Plugin_Continue;

	static char text[192];
	if(!GetCmdArgString(text, sizeof(text)))
		return Plugin_Continue;

	int startidx = 0;
	if(text[strlen(text)-1] == '"')
	{
		text[strlen(text)-1] = '\0';
		startidx = 1;
	}

	ReplySource old = SetCmdReplySource(SM_REPLY_TO_CHAT);

	if(strcmp(text[startidx], "nominate", false) == 0)
	{
		if(IsNominateAllowed(client))
		{
			if(g_NominationDelay > GetTime())
				CReplyToCommand(client, "\x04[NE]\x01 Nominations will be unlocked in %d seconds", g_NominationDelay - GetTime());
			else
				AttemptNominate(client);
		}
	}

	SetCmdReplySource(old);

	return Plugin_Continue;
}

public Action Command_Nominate(int client, int args)
{
	if(!client || !IsNominateAllowed(client))
		return Plugin_Handled;

	if(g_NominationDelay > GetTime())
	{
		CPrintToChat(client, "\x04[NE]\x01 Nominations will be unlocked in %d seconds", g_NominationDelay - GetTime());
		return Plugin_Handled;
	}

	if(args == 0)
	{
		AttemptNominate(client);
		return Plugin_Handled;
	}

	if(g_Player_NominationDelay[client] > GetTime())
	{
		CPrintToChat(client, "\x04[NE]\x01 Please wait %d seconds before you can nominate again", g_Player_NominationDelay[client] - GetTime());
		return Plugin_Handled;
	}

	static char mapname[PLATFORM_MAX_PATH];
	GetCmdArg(1, mapname, sizeof(mapname));

	int status;
	if(!GetTrieValue(g_mapTrie, mapname, status))
	{
		CPrintToChat(client, "%t", "Map was not found", mapname);
		AttemptNominate(client, mapname);
		return Plugin_Handled;
	}

	if((status & MAPSTATUS_DISABLED) == MAPSTATUS_DISABLED)
	{
		if((status & MAPSTATUS_EXCLUDE_CURRENT) == MAPSTATUS_EXCLUDE_CURRENT)
			CPrintToChat(client, "\x04[NE]\x01 %t", "Can't Nominate Current Map");

		if((status & MAPSTATUS_EXCLUDE_PREVIOUS) == MAPSTATUS_EXCLUDE_PREVIOUS)
		{
			int Cooldown = GetMapCooldown(mapname);
			CPrintToChat(client, "\x04[NE]\x01 %t (%d)", "Map in Exclude List", Cooldown);
		}

		if((status & MAPSTATUS_EXCLUDE_NOMINATED) == MAPSTATUS_EXCLUDE_NOMINATED)
			CPrintToChat(client, "\x04[NE]\x01 %t", "Map Already Nominated");

		return Plugin_Handled;
	}

	int TimeRestriction = GetMapTimeRestriction(mapname);
	if(TimeRestriction)
	{
		CPrintToChat(client, "\x04[NE]\x01 %t", "Map Nominate Time Error", RoundToFloor(float(TimeRestriction / 60)), TimeRestriction % 60);

		return Plugin_Handled;
	}

	int PlayerRestriction = GetMapPlayerRestriction(mapname);
	if(PlayerRestriction)
	{
		if(PlayerRestriction < 0)
			CPrintToChat(client, "\x04[NE]\x01 %t", "Map Nominate MinPlayers Error", PlayerRestriction * -1);
		else
			CPrintToChat(client, "\x04[NE]\x01 %t", "Map Nominate MaxPlayers Error", PlayerRestriction);

		return Plugin_Handled;
	}

	int GroupRestriction = GetMapGroupRestriction(mapname, client);
	if(GroupRestriction >= 0)
	{
		CPrintToChat(client, "\x04[NE]\x01 %t", "Map Nominate Group Error", GroupRestriction);
		return Plugin_Handled;
	}

	NominateResult result = NominateMap(mapname, false, client);

	if(result > Nominate_Replaced)
	{
		if(result == Nominate_AlreadyInVote)
			CPrintToChat(client, "\x04[NE]\x01 %t", "Map Already In Vote", mapname);
		else if(result == Nominate_VoteFull)
			CPrintToChat(client, "\x04[NE]\x01 %t", "Max Nominations");

		return Plugin_Handled;
	}

	/* Map was nominated! - Disable the menu item and update the trie */

	SetTrieValue(g_mapTrie, mapname, MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_NOMINATED);

	static char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));

	if(result == Nominate_Added)
		CPrintToChatAll("\x04[NE]\x01 %t", "Map Nominated", name, mapname);
	else if(result == Nominate_Replaced)
		CPrintToChatAll("\x04[NE]\x01 %t", "Map Nomination Changed", name, mapname);

	LogMessage("%s nominated %s", name, mapname);

	g_Player_NominationDelay[client] = GetTime() + GetConVarInt(g_Cvar_NominateDelay);

	return Plugin_Continue;
}

public Action Command_NominateList(int client, int args)
{
	int arraySize = ByteCountToCells(PLATFORM_MAX_PATH);
	ArrayList MapList = CreateArray(arraySize);

	GetNominatedMapList(MapList);
	if(!GetArraySize(MapList))
	{
		CReplyToCommand(client, "\x04[NE]\x01 No maps have been nominated.");
		delete MapList;
		return Plugin_Handled;
	}

	static char map[PLATFORM_MAX_PATH];

	if (client == 0)
	{
		char aBuf[2048];
		StrCat(aBuf, sizeof(aBuf), "\x04[NE]\x01 Nominated Maps:");
		for(int i = 0; i < GetArraySize(MapList); i++)
		{
			StrCat(aBuf, sizeof(aBuf), "\n");
			GetArrayString(MapList, i, map, sizeof(map));
			StrCat(aBuf, sizeof(aBuf), map);
		}
		CReplyToCommand(client, aBuf);
		delete MapList;
		return Plugin_Handled;
	}

	Handle NominateListMenu = CreateMenu(Handler_NominateListMenu, MENU_ACTIONS_DEFAULT|MenuAction_DisplayItem);

	for(int i = 0; i < GetArraySize(MapList); i++)
	{
		GetArrayString(MapList, i, map, sizeof(map));
		AddMenuItem(NominateListMenu, map, map);
	}

	SetMenuTitle(NominateListMenu, "Nominated Maps", client);
	DisplayMenu(NominateListMenu, client, MENU_TIME_FOREVER);

	delete MapList;
	return Plugin_Handled;
}

public int Handler_NominateListMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

void AttemptNominate(int client, const char[] filter = "")
{
	Menu menu = g_MapMenu;
	if(filter[0])
		menu = BuildMapMenu(filter);

	SetMenuTitle(menu, "%T", "Nominate Title", client);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);

	return;
}

void AttemptAdminNominate(int client, const char[] filter = "")
{
	Menu menu = g_AdminMapMenu;
	if(filter[0])
		menu = BuildAdminMapMenu(filter);

	SetMenuTitle(menu, "%T", "Nominate Title", client);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);

	return;
}

Menu BuildMapMenu(const char[] filter)
{
	Menu menu = CreateMenu(Handler_MapSelectMenu, MENU_ACTIONS_DEFAULT|MenuAction_DrawItem|MenuAction_DisplayItem);

	static char map[PLATFORM_MAX_PATH];

	for(int i = 0; i < GetArraySize(g_MapList); i++)
	{
		GetArrayString(g_MapList, i, map, sizeof(map));

		if(!filter[0] || StrContains(map, filter, false) != -1)
		{
			AddMenuItem(menu, map, map);
		}
	}

	SetMenuExitButton(menu, true);

	return menu;
}

Menu BuildAdminMapMenu(const char[] filter)
{
	Menu menu = CreateMenu(Handler_AdminMapSelectMenu, MENU_ACTIONS_DEFAULT|MenuAction_DrawItem|MenuAction_DisplayItem);

	static char map[PLATFORM_MAX_PATH];

	for(int i = 0; i < GetArraySize(g_AdminMapList); i++)
	{
		GetArrayString(g_AdminMapList, i, map, sizeof(map));

		if(!filter[0] || StrContains(map, filter, false) != -1)
			AddMenuItem(menu, map, map);
	}

	if(filter[0])
	{
		// Search normal maps aswell if filter is specified
		for(int i = 0; i < GetArraySize(g_MapList); i++)
		{
			GetArrayString(g_MapList, i, map, sizeof(map));

			if(!filter[0] || StrContains(map, filter, false) != -1)
				AddMenuItem(menu, map, map);
		}
	}

	SetMenuExitButton(menu, true);

	return menu;
}

public int Handler_MapSelectMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End:
		{
			if(menu != g_MapMenu)
				delete menu;
		}
		case MenuAction_Select:
		{
			if(g_Player_NominationDelay[param1] > GetTime())
			{
				CPrintToChat(param1, "\x04[NE]\x01 Please wait %d seconds before you can nominate again", g_Player_NominationDelay[param1] - GetTime());
				DisplayMenuAtItem(menu, param1, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
				return 0;
			}

			static char map[PLATFORM_MAX_PATH];
			char name[MAX_NAME_LENGTH];
			GetMenuItem(menu, param2, map, sizeof(map));

			GetClientName(param1, name, MAX_NAME_LENGTH);

			NominateResult result = NominateMap(map, false, param1);

			/* Don't need to check for InvalidMap because the menu did that already */
			if(result == Nominate_AlreadyInVote)
			{
				CPrintToChat(param1, "\x04[NE]\x01 %t", "Map Already Nominated");
				return 0;
			}
			else if(result == Nominate_VoteFull)
			{
				CPrintToChat(param1, "\x04[NE]\x01 %t", "Max Nominations");
				return 0;
			}

			SetTrieValue(g_mapTrie, map, MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_NOMINATED);

			if(result == Nominate_Added)
				CPrintToChatAll("\x04[NE]\x01 %t", "Map Nominated", name, map);
			else if(result == Nominate_Replaced)
				CPrintToChatAll("\x04[NE]\x01 %t", "Map Nomination Changed", name, map);

			LogMessage("%s nominated %s", name, map);
			g_Player_NominationDelay[param1] = GetTime() + GetConVarInt(g_Cvar_NominateDelay);
		}

		case MenuAction_DrawItem:
		{
			static char map[PLATFORM_MAX_PATH];
			GetMenuItem(menu, param2, map, sizeof(map));

			int status;

			if(!GetTrieValue(g_mapTrie, map, status))
			{
				LogError("Menu selection of item not in trie. Major logic problem somewhere.");
				return ITEMDRAW_DEFAULT;
			}

			if((status & MAPSTATUS_DISABLED) == MAPSTATUS_DISABLED)
				return ITEMDRAW_DISABLED;

			if(GetMapTimeRestriction(map) || GetMapPlayerRestriction(map) || GetMapGroupRestriction(map, param1) >= 0)
				return ITEMDRAW_DISABLED;

			if(GetMapVIPOnly(map) && !IsClientVIP(param1))
				return ITEMDRAW_DISABLED;

			if(GetMapAdminOnly(map) && !IsClientAdmin(param1))
				return ITEMDRAW_DISABLED;

			return ITEMDRAW_DEFAULT;
		}

		case MenuAction_DisplayItem:
		{
			static char map[PLATFORM_MAX_PATH];
			GetMenuItem(menu, param2, map, sizeof(map));

			int mark = GetConVarInt(g_Cvar_MarkCustomMaps);
			bool official;

			int status;

			if(!GetTrieValue(g_mapTrie, map, status))
			{
				LogError("Menu selection of item not in trie. Major logic problem somewhere.");
				return 0;
			}

			static char buffer[100];
			static char display[150];

			if(mark)
				official = IsMapOfficial(map);

			if(mark && !official)
			{
				switch(mark)
				{
					case 1:
					{
						Format(buffer, sizeof(buffer), "%T", "Custom Marked", param1, map);
					}

					case 2:
					{
						Format(buffer, sizeof(buffer), "%T", "Custom", param1, map);
					}
				}
			}
			else
				strcopy(buffer, sizeof(buffer), map);

			if((status & MAPSTATUS_DISABLED) == MAPSTATUS_DISABLED)
			{
				if((status & MAPSTATUS_EXCLUDE_CURRENT) == MAPSTATUS_EXCLUDE_CURRENT)
				{
					Format(display, sizeof(display), "%s (%T)", buffer, "Current Map", param1);
					return RedrawMenuItem(display);
				}

				if((status & MAPSTATUS_EXCLUDE_PREVIOUS) == MAPSTATUS_EXCLUDE_PREVIOUS)
				{
					int Cooldown = GetMapCooldown(map);
					Format(display, sizeof(display), "%s (%T %d)", buffer, "Recently Played", param1, Cooldown);
					return RedrawMenuItem(display);
				}

				if((status & MAPSTATUS_EXCLUDE_NOMINATED) == MAPSTATUS_EXCLUDE_NOMINATED)
				{
					Format(display, sizeof(display), "%s (%T)", buffer, "Nominated", param1);
					return RedrawMenuItem(display);
				}
			}
			
			if(GetMapVIPOnly(map) && IsClientVIP(param1))
			{
				Format(display, sizeof(display), "%s (★VIP★)", buffer);
				return RedrawMenuItem(display);
			}

			if(GetMapVIPOnly(map) && !IsClientVIP(param1))
			{
				Format(display, sizeof(display), "%s (VIP Only)", buffer);
				return RedrawMenuItem(display);
			}

			if(GetMapAdminOnly(map) && IsClientAdmin(param1))				
			{
				Format(display, sizeof(display), "%s (★Admin★)", buffer);
				return RedrawMenuItem(display);
			}

			if(GetMapAdminOnly(map) && !IsClientAdmin(param1))
			{
				Format(display, sizeof(display), "%s (Admin Only)", buffer);
				return RedrawMenuItem(display);
			}

			int TimeRestriction = GetMapTimeRestriction(map);
			if(TimeRestriction)
			{
				Format(display, sizeof(display), "%s (%T)", buffer, "Map Time Restriction", param1, "+", RoundToFloor(float(TimeRestriction / 60)), TimeRestriction % 60);

				return RedrawMenuItem(display);
			}

			int PlayerRestriction = GetMapPlayerRestriction(map);
			if(PlayerRestriction)
			{
				if(PlayerRestriction < 0)
					Format(display, sizeof(display), "%s (%T)", buffer, "Map Player Restriction", param1, "+", PlayerRestriction * -1);
				else
					Format(display, sizeof(display), "%s (%T)", buffer, "Map Player Restriction", param1, "-", PlayerRestriction);

				return RedrawMenuItem(display);
			}

			int GroupRestriction = GetMapGroupRestriction(map, param1);
			if(GroupRestriction >= 0)
			{
				Format(display, sizeof(display), "%s (%T)", buffer, "Map Group Restriction", param1, GroupRestriction);
				return RedrawMenuItem(display);
			}

			if(mark && !official)
				return RedrawMenuItem(buffer);

			return 0;
		}
	}

	return 0;
}

stock bool IsNominateAllowed(int client)
{
	if(BaseComm_IsClientGagged(client))
		return false;

	CanNominateResult result = CanNominate();

	switch(result)
	{
		case CanNominate_No_VoteInProgress:
		{
			CReplyToCommand(client, "\x04[NE]\x01 %t", "Nextmap Voting Started");
			return false;
		}

		case CanNominate_No_VoteComplete:
		{
			char map[PLATFORM_MAX_PATH];
			GetNextMap(map, sizeof(map));
			CReplyToCommand(client, "\x04[NE]\x01 %t", "Next Map", map);
			return false;
		}

		case CanNominate_No_VoteFull:
		{
			CReplyToCommand(client, "\x04[NE]\x01 %t", "Max Nominations");
			return false;
		}

	}

	return true;
}

public int Handler_AdminMapSelectMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_End:
		{
			if(menu != g_AdminMapMenu)
				delete menu;
		}
		case MenuAction_Select:
		{
			static char map[PLATFORM_MAX_PATH];
			GetMenuItem(menu, param2, map, sizeof(map));

			NominateResult result = NominateMap(map, true, 0);

			if(result > Nominate_Replaced)
			{
				/* We assume already in vote is the casue because the maplist does a Map Validity check and we forced, so it can't be full */
				CPrintToChat(param1, "\x04[NE]\x01 %t", "Map Already In Vote", map);
				return 0;
			}

			SetTrieValue(g_mapTrie, map, MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_NOMINATED);

			CPrintToChat(param1, "\x04[NE]\x01 %t", "Map Inserted", map);
			LogAction(param1, -1, "\"%L\" inserted map \"%s\".", param1, map);

			CPrintToChatAll("\x04[NE]\x01 %N has inserted %s into nominations", param1, map);
		}

		case MenuAction_DrawItem:
		{
			if(!CheckCommandAccess(param1, "sm_nominate_ignore", ADMFLAG_CHEATS, true))
			{
				static char map[PLATFORM_MAX_PATH];
				GetMenuItem(menu, param2, map, sizeof(map));

				int status;
				if(GetTrieValue(g_mapTrie, map, status))
				{
					if((status & MAPSTATUS_DISABLED) == MAPSTATUS_DISABLED)
						return ITEMDRAW_DISABLED;
				}

				if(GetMapTimeRestriction(map) || GetMapPlayerRestriction(map) || GetMapGroupRestriction(map) >= 0)
					return ITEMDRAW_DISABLED;
			}

			return ITEMDRAW_DEFAULT;
		}

		case MenuAction_DisplayItem:
		{
			if(!CheckCommandAccess(param1, "sm_nominate_ignore", ADMFLAG_CHEATS, true))
			{
				static char map[PLATFORM_MAX_PATH];
				GetMenuItem(menu, param2, map, sizeof(map));

				static char buffer[100];
				static char display[150];

				strcopy(buffer, sizeof(buffer), map);

				int status;
				if(GetTrieValue(g_mapTrie, map, status))
				{
					if((status & MAPSTATUS_DISABLED) == MAPSTATUS_DISABLED)
					{
						if((status & MAPSTATUS_EXCLUDE_CURRENT) == MAPSTATUS_EXCLUDE_CURRENT)
						{
							Format(display, sizeof(display), "%s (%T)", buffer, "Current Map", param1);
							return RedrawMenuItem(display);
						}

						if((status & MAPSTATUS_EXCLUDE_PREVIOUS) == MAPSTATUS_EXCLUDE_PREVIOUS)
						{
							int Cooldown = GetMapCooldown(map);
							Format(display, sizeof(display), "%s (%T %d)", buffer, "Recently Played", param1, Cooldown);
							return RedrawMenuItem(display);
						}

						if((status & MAPSTATUS_EXCLUDE_NOMINATED) == MAPSTATUS_EXCLUDE_NOMINATED)
						{
							Format(display, sizeof(display), "%s (%T)", buffer, "Nominated", param1);
							return RedrawMenuItem(display);
						}
					}
				}

				int TimeRestriction = GetMapTimeRestriction(map);
				if(TimeRestriction)
				{
					Format(display, sizeof(display), "%s (%T)", buffer, "Map Time Restriction", param1, "+", RoundToFloor(float(TimeRestriction / 60)), TimeRestriction % 60);

					return RedrawMenuItem(display);
				}

				int PlayerRestriction = GetMapPlayerRestriction(map);
				if(PlayerRestriction)
				{
					if(PlayerRestriction < 0)
						Format(display, sizeof(display), "%s (%T)", buffer, "Map Player Restriction", param1, "+", PlayerRestriction * -1);
					else
						Format(display, sizeof(display), "%s (%T)", buffer, "Map Player Restriction", param1, "-", PlayerRestriction);

					return RedrawMenuItem(display);
				}

				int GroupRestriction = GetMapGroupRestriction(map);
				if(GroupRestriction >= 0)
				{
					Format(display, sizeof(display), "%s (%T)", buffer, "Map Group Restriction", param1, GroupRestriction);
					return RedrawMenuItem(display);
				}
			}

			return 0;
		}
	}

	return 0;
}

public int Native_GetNominationPool(Handle plugin, int numArgs)
{
	SetNativeCellRef(1, g_MapList);

	return 0;
}

public int Native_PushMapIntoNominationPool(Handle plugin, int numArgs)
{
	char map[PLATFORM_MAX_PATH];

	GetNativeString(1, map, PLATFORM_MAX_PATH);

	ShiftArrayUp(g_MapList, 0);
	SetArrayString(g_MapList, 0, map);

	UpdateMapTrie();
	UpdateMapMenus();

	return 0;
}

public int Native_PushMapsIntoNominationPool(Handle plugin, int numArgs)
{
	ArrayList maps = GetNativeCell(1);

	for (int i = 0; i < maps.Length; i++)
	{
		char map[PLATFORM_MAX_PATH];
		maps.GetString(i, map, PLATFORM_MAX_PATH);

		if (FindStringInArray(g_MapList, map) == -1)
		{
			ShiftArrayUp(g_MapList, 0);
			SetArrayString(g_MapList, 0, map);
		}
	}

	delete maps;

	UpdateMapTrie();
	UpdateMapMenus();

	return 0;
}

public int Native_RemoveMapFromNominationPool(Handle plugin, int numArgs)
{
	char map[PLATFORM_MAX_PATH];

	GetNativeString(1, map, PLATFORM_MAX_PATH);

	int idx;

	if ((idx = FindStringInArray(g_MapList, map)) != -1)
		RemoveFromArray(g_MapList, idx);

	UpdateMapTrie();
	UpdateMapMenus();

	return 0;
}

public int Native_RemoveMapsFromNominationPool(Handle plugin, int numArgs)
{
	ArrayList maps = GetNativeCell(1);

	for (int i = 0; i < maps.Length; i++)
	{
		char map[PLATFORM_MAX_PATH];
		maps.GetString(i, map, PLATFORM_MAX_PATH);

		int idx = -1;

		if ((idx = FindStringInArray(g_MapList, map)) != -1)
			RemoveFromArray(g_MapList, idx);
	}

	delete maps;

	UpdateMapTrie();
	UpdateMapMenus();

	return 0;
}
