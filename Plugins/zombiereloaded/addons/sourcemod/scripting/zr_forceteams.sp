#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <zombiereloaded>
#include <cstrike>

bool started;
int ctscore;
int trscore;

public Plugin myinfo =
{
	name = "[ZR] Force Teams",
	author = "Franc1sco franug, simpson0141, Modified by. Someone",
	description = "",
	version = "2.3",
	url = "http://steamcommunity.com/id/franug"
};

public void OnPluginStart() 
{
	HookEvent("player_spawn", OnSpawn, EventHookMode_Post);
	HookEvent("round_start", EventRoundStart, EventHookMode_Pre);
	HookEvent("round_end", EventRoundEnd, EventHookMode_Pre);
	
	AutoExecConfig();
}

public Action OnSpawn(Handle event, const char[] name, bool dontBroadcast) 
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(!started)
		if(GetClientTeam(client) == CS_TEAM_T) CS_SwitchTeam(client, CS_TEAM_CT);
}

public Action EventRoundStart(Handle event, const char[] name, bool dontBroadcast) 
{
	ctscore = GetTeamScore(3);
	trscore = GetTeamScore(2);
	
	started = false;
}

public Action EventRoundEnd(Handle event, const char[] name, bool dontBroadcast) 
{
	CreateTimer(1.0, Check);
}

public Action Check(Handle timer)
{
	started = false;
}

public void ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
	if(!started) started = true;
}

public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
	if(reason == CSRoundEnd_GameStart)
		CreateTimer(1.0, Check);
	
	if (GameRules_GetProp("m_bWarmupPeriod") == 1)
		return Plugin_Continue;
	else
		CreateTimer(1.0, Check);
	
	if(!started)
	{
		int count;
	
		for (int i = 1; i <= MaxClients; i++) 
			if (IsClientInGame(i) && IsPlayerAlive(i))
				count++;
	
		if(count > 0)
		{
			SetTeamScore(3, ctscore);
			SetTeamScore(2, trscore);
			return Plugin_Handled;
		}
	}
	else return Plugin_Continue;
	
	return Plugin_Continue;
}