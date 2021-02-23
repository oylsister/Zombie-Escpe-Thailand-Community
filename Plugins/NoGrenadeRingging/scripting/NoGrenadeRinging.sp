#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <dhooks>

// int CCSPlayer::OnDamagedByExplosion(CTakeDamageInfo const&)
Handle g_hDamagedByExplosion;

public Plugin myinfo =
{
	name			= "NoGrenadeRinging",
	author			= "BotoX",
	description		= "Block the annoying ringing noise when a grenade explodes next to you",
	version			= "1.0.1",
	url				= ""
};

public void OnPluginStart()
{
	Handle hTemp = LoadGameConfigFile("NoGrenadeRinging.games");
	if(hTemp == INVALID_HANDLE)
		SetFailState("Why you no has gamedata?");

	int Offset = GameConfGetOffset(hTemp, "OnDamagedByExplosion");
	g_hDamagedByExplosion = DHookCreate(Offset, HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity, OnDamagedByExplosion);
	DHookAddParam(g_hDamagedByExplosion, HookParamType_ObjectPtr);
	CloseHandle(hTemp);

	/* Late load */
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
			OnClientPutInServer(client);
	}
}

public void OnClientPutInServer(int client)
{
	// Don't add removal callback for this one
	DHookEntity(g_hDamagedByExplosion, false, client);
}

// int CCSPlayer::OnDamagedByExplosion(CTakeDamageInfo const&)
public MRESReturn OnDamagedByExplosion(int pThis, Handle hReturn, Handle hParams)
{
	// Block call
	DHookSetReturn(hReturn, 0);
	return MRES_Supercede;
}
