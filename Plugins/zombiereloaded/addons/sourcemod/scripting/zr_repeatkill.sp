#include <sourcemod>
#include <zombiereloaded>
#include <cstrike>
#include <zr_repeatkill>

#define PLUGIN_NAME "ZR Repeat Kill Detector"
#define PLUGIN_VERSION "1.2"

#pragma semicolon 1
#pragma newdecls required

Handle g_hRespawnDelay = INVALID_HANDLE;
float g_fDeathTime[MAXPLAYERS+1];
bool g_bBlockRespawn = false;

Handle g_hCvar_RepeatKillDetectThreshold = INVALID_HANDLE;
float g_fRepeatKillDetectThreshold;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "GoD-Tony, Vauff, Snowy",
	description = "Disables respawning on maps with repeat killers",
	version = PLUGIN_VERSION,
	url = "https://github.com/Vauff/ZR_RepeatKill"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_togglerepeatkill", ToggleRepeatKill, ADMFLAG_GENERIC, "Turns off the repeat killer detector if it is enabled");
	RegAdminCmd("sm_togglerk", ToggleRepeatKill, ADMFLAG_GENERIC, "Turns off the repeat killer detector if it is enabled");
	RegAdminCmd("sm_rk", ToggleRepeatKill, ADMFLAG_GENERIC, "Turns off the repeat killer detector if it is enabled");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("RepeatKillerEnabled", Native_RepeatKillerEnabled);
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	if ((g_hRespawnDelay = FindConVar("zr_respawn_delay")) == INVALID_HANDLE)
	{
		SetFailState("Failed to find zr_respawn_delay cvar.");
	}
	
	g_hCvar_RepeatKillDetectThreshold = CreateConVar("zr_repeatkill_threshold", "3.0", "Zombie Reloaded Repeat Kill Detector Threshold", 0, true, 0.0, true, 10.0);
	g_fRepeatKillDetectThreshold = GetConVarFloat(g_hCvar_RepeatKillDetectThreshold);
	HookConVarChange(g_hCvar_RepeatKillDetectThreshold, OnConVarChanged);

	CreateConVar("zr_repeatkill_version", PLUGIN_VERSION, PLUGIN_NAME, FCVAR_NOTIFY|FCVAR_DONTRECORD);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	
	AutoExecConfig(true, "plugin.RepeatKillDetector");
}

public void OnConVarChanged(Handle cvar, const char[] oldVal, const char[] newVal)
{
	if(cvar == g_hCvar_RepeatKillDetectThreshold)
	{
		g_fRepeatKillDetectThreshold = GetConVarFloat(g_hCvar_RepeatKillDetectThreshold);
	}
}

public Action ToggleRepeatKill(int client, int args)
{
	if (g_bBlockRespawn)
	{
		PrintToChatAll(" \x04[ZR]\x01 Repeat killer detector force toggled off. Re-enabling respawn for this round.");
		ServerCommand("zr_zspawn_force @all 1");
		g_bBlockRespawn = false;
	}
	else
	{
		PrintToChat(client, " \x04[ZR] \x01Repeat killer is already turned off!");
	}

	return Plugin_Handled;
}

public void OnClientDisconnect(int client)
{
	g_fDeathTime[client] = 0.0;
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	g_bBlockRespawn = false;
}

public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	if (g_bBlockRespawn)
	{
		return;
	}

	char weapon[32];
	GetEventString(event, "weapon", weapon, sizeof(weapon));

	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if (victim && !attacker && StrEqual(weapon, "trigger_hurt"))
	{
		float fGameTime = GetGameTime();

		if (fGameTime - g_fDeathTime[victim] - GetConVarFloat(g_hRespawnDelay) < g_fRepeatKillDetectThreshold)
		{
			PrintToChatAll(" \x04[ZR]\x01 Repeat killer detected. Disabling respawn for this round.");
			g_bBlockRespawn = true;
		}

		g_fDeathTime[victim] = fGameTime;
	}
}

public Action ZR_OnClientRespawn(int &client, ZR_RespawnCondition &condition)
{
	if (g_bBlockRespawn)
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public int Native_RepeatKillerEnabled(Handle plugin, int params)
{
	return g_bBlockRespawn;
}