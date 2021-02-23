/**
 * vim: set ts=4 :
 * =============================================================================
 * Rock The Vote Extended
 * Creates a map vote when the required number of players have requested one.
 *
 * Rock The Vote Extended (C)2012-2013 Powerlord (Ross Bemrose)
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
#include <sdktools_functions>
#include <mapchooser>
#include <nextmap>
#include <multicolors>

#define MCE_VERSION "1.13.0"

public Plugin myinfo =
{
	name = "Rock The Vote Extended",
	author = "Powerlord and AlliedModders LLC",
	description = "Provides RTV Map Voting",
	version = MCE_VERSION,
	url = "https://forums.alliedmods.net/showthread.php?t=156974"
};

ConVar g_Cvar_Needed;
ConVar g_Cvar_MinPlayers;
ConVar g_Cvar_InitialDelay;
ConVar g_Cvar_Interval;
ConVar g_Cvar_ChangeTime;
ConVar g_Cvar_RTVPostVoteAction;
ConVar g_Cvar_RTVAutoDisable;

bool g_CanRTV = false;			// True if RTV loaded maps and is active.
bool g_RTVAllowed = false;		// True if RTV is available to players. Used to delay rtv votes.
int g_Voters = 0;				// Total voters connected. Doesn't include fake clients.
int g_Votes = 0;				// Total number of "say rtv" votes
int g_VotesNeeded = 0;			// Necessary votes before map vote begins. (voters * percent_needed)
bool g_Voted[MAXPLAYERS+1] = {false, ...};
Handle g_TimeOverTimer = INVALID_HANDLE;

bool g_InChange = false;

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("rockthevote.phrases");
	LoadTranslations("basevotes.phrases");

	g_Cvar_Needed = CreateConVar("sm_rtv_needed", "0.60", "Percentage of players needed to rockthevote (Def 60%)", 0, true, 0.05, true, 1.0);
	g_Cvar_MinPlayers = CreateConVar("sm_rtv_minplayers", "0", "Number of players required before RTV will be enabled.", 0, true, 0.0, true, float(MAXPLAYERS));
	g_Cvar_InitialDelay = CreateConVar("sm_rtv_initialdelay", "30.0", "Time (in seconds) before first RTV can be held", 0, true, 0.00);
	g_Cvar_Interval = CreateConVar("sm_rtv_interval", "240.0", "Time (in seconds) after a failed RTV before another can be held", 0, true, 0.00);
	g_Cvar_ChangeTime = CreateConVar("sm_rtv_changetime", "0", "When to change the map after a succesful RTV: 0 - Instant, 1 - RoundEnd, 2 - MapEnd", _, true, 0.0, true, 2.0);
	g_Cvar_RTVPostVoteAction = CreateConVar("sm_rtv_postvoteaction", "0", "What to do with RTV's after a mapvote has completed. 0 - Allow, success = instant change, 1 - Deny", _, true, 0.0, true, 1.0);
	g_Cvar_RTVAutoDisable = CreateConVar("sm_rtv_autodisable", "0", "Automatically disable RTV when map time is over.", _, true, 0.0, true, 1.0);

	RegConsoleCmd("sm_rtv", Command_RTV);

	RegAdminCmd("sm_forcertv", Command_ForceRTV, ADMFLAG_CHANGEMAP, "Force an RTV vote");
	RegAdminCmd("sm_disablertv", Command_DisableRTV, ADMFLAG_CHANGEMAP, "Disable the RTV command");
	RegAdminCmd("sm_enablertv", Command_EnableRTV, ADMFLAG_CHANGEMAP, "Enable the RTV command");

	HookEvent("player_team", OnPlayerChangedTeam, EventHookMode_PostNoCopy);

	AutoExecConfig(true, "rtv");
}

public void OnMapStart()
{
	g_Voters = 0;
	g_Votes = 0;
	g_VotesNeeded = 0;
	g_InChange = false;

	/* Handle late load */
	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}
}

public void OnMapEnd()
{
	g_CanRTV = false;
	g_RTVAllowed = false;
	g_TimeOverTimer = INVALID_HANDLE;
}

public void OnConfigsExecuted()
{
	g_CanRTV = true;
	g_RTVAllowed = false;
	CreateTimer(g_Cvar_InitialDelay.FloatValue, Timer_DelayRTV, _, TIMER_FLAG_NO_MAPCHANGE);
	SetupTimeOverTimer();
}

public void OnMapTimeLeftChanged()
{
	SetupTimeOverTimer();
}

public void OnClientPutInServer(int client)
{
	UpdateRTV();
}

public void OnClientDisconnect(int client)
{
	if (g_Voted[client])
	{
		g_Voted[client] = false;
		g_Votes--;
	}

	UpdateRTV();
}

public void OnPlayerChangedTeam(Handle event, const char[] name, bool dontBroadcast)
{
	UpdateRTV();
}

void UpdateRTV()
{
	g_Voters = 0;

	for (int i=1; i<=MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			if (GetClientTeam(i) == 2 || GetClientTeam(i) == 3)
			{
				g_Voters++;
			}
		}
	}

//	g_Voters = GetTeamClientCount(2) + GetTeamClientCount(3);
	g_VotesNeeded = RoundToFloor(float(g_Voters) * GetConVarFloat(g_Cvar_Needed));

	if (!g_CanRTV)
	{
		return;
	}

	if (g_Votes &&
		g_Voters &&
		g_Votes >= g_VotesNeeded &&
		g_RTVAllowed )
	{
		if (g_Cvar_RTVPostVoteAction.IntValue == 1 && HasEndOfMapVoteFinished())
		{
			return;
		}

		StartRTV();
	}
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	if (!g_CanRTV || !client)
	{
		return;
	}

	if (strcmp(sArgs, "rtv", false) == 0 || strcmp(sArgs, "rockthevote", false) == 0)
	{
		ReplySource old = SetCmdReplySource(SM_REPLY_TO_CHAT);

		AttemptRTV(client);

		SetCmdReplySource(old);
	}
}

public Action Command_RTV(int client, int args)
{
	if (!g_CanRTV || !client)
	{
		return Plugin_Handled;
	}

	AttemptRTV(client);

	return Plugin_Handled;
}

void AttemptRTV(int client)
{
	if (!g_RTVAllowed  || (g_Cvar_RTVPostVoteAction.IntValue == 1 && HasEndOfMapVoteFinished()))
	{
		CReplyToCommand(client, "\x04[RTV]\x01 %t", "RTV Not Allowed");
		return;
	}

	if (!CanMapChooserStartVote())
	{
		CReplyToCommand(client, "\x04[RTV]\x01 %t", "RTV Started");
		return;
	}

	if (GetClientCount(true) < g_Cvar_MinPlayers.IntValue)
	{
		CReplyToCommand(client, "\x04[RTV]\x01 %t", "Minimal Players Not Met");
		return;
	}

	if (g_Voted[client])
	{
		CReplyToCommand(client, "\x04[RTV]\x01 %t", "Already Voted", g_Votes, g_VotesNeeded);
		return;
	}

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));

	g_Votes++;
	g_Voted[client] = true;

	CPrintToChatAll("\x04[RTV]\x01 %t", "RTV Requested", name, g_Votes, g_VotesNeeded);

	if (g_Votes >= g_VotesNeeded)
	{
		StartRTV();
	}
}

public Action Timer_DelayRTV(Handle timer)
{
	g_RTVAllowed = true;
}

void StartRTV()
{
	if (g_InChange)
	{
		return;
	}

	if (EndOfMapVoteEnabled() && HasEndOfMapVoteFinished())
	{
		/* Change right now then */
		char map[PLATFORM_MAX_PATH];
		if (GetNextMap(map, sizeof(map)))
		{
			GetMapDisplayName(map, map, sizeof(map));

			CPrintToChatAll("\x04[RTV]\x01 %t", "Changing Maps", map);
			CreateTimer(5.0, Timer_ChangeMap, _, TIMER_FLAG_NO_MAPCHANGE);
			g_InChange = true;

			ResetRTV();

			g_RTVAllowed = false;
		}
		return;
	}

	if (CanMapChooserStartVote())
	{
		MapChange when = view_as<MapChange>(g_Cvar_ChangeTime.IntValue);
		InitiateMapChooserVote(when);

		ResetRTV();

		g_RTVAllowed = false;
		CreateTimer(g_Cvar_Interval.FloatValue, Timer_DelayRTV, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

void ResetRTV()
{
	g_Votes = 0;

	for (int i=1; i<=MAXPLAYERS; i++)
	{
		g_Voted[i] = false;
	}
}

public Action Timer_ChangeMap(Handle hTimer)
{
	g_InChange = false;

	LogMessage("RTV changing map manually");

	char map[PLATFORM_MAX_PATH];
	if (GetNextMap(map, sizeof(map)))
	{
		ForceChangeLevel(map, "RTV after mapvote");
	}

	return Plugin_Stop;
}

public Action Command_ForceRTV(int client, int args)
{
	if(!g_CanRTV)
		return Plugin_Handled;

	CShowActivity2(client, "\x04[RTV]\x01 ", "%t", "Initiated Vote Map");

	StartRTV();

	return Plugin_Handled;
}

public Action Command_DisableRTV(int client, int args)
{
	if(!g_RTVAllowed)
		return Plugin_Handled;

	ShowActivity2(client, "\x04[RTV]\x01 ", "disabled RockTheVote.");

	g_RTVAllowed = false;

	return Plugin_Handled;
}

public Action Command_EnableRTV(int client, int args)
{
	if(g_RTVAllowed)
		return Plugin_Handled;

	CShowActivity2(client, "\x04[RTV]\x01 ", "enabled RockTheVote");

	g_RTVAllowed = true;

	return Plugin_Handled;
}

void SetupTimeOverTimer()
{
	int time;
	if(GetMapTimeLeft(time) && time > 0)
	{
		if(g_TimeOverTimer != INVALID_HANDLE)
		{
			KillTimer(g_TimeOverTimer);
			g_TimeOverTimer = INVALID_HANDLE;
		}

		g_TimeOverTimer = CreateTimer(float(time), Timer_MapOver, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_MapOver(Handle timer)
{
	g_TimeOverTimer = INVALID_HANDLE;

	if(g_Cvar_RTVAutoDisable.BoolValue)
		g_RTVAllowed = false;
}
