#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>
#include <sdkhooks>

Handle g_hRadiusDamage = INVALID_HANDLE;

public Plugin myinfo =
{
	name = "Napalm Lag Fix",
	author = "GoD-Tony + BotoX",
	description = "Prevents lag when napalm is used on players",
	version = "1.0.4",
	url = "https://forums.alliedmods.net/showthread.php?t=188093"
};

public void OnPluginStart()
{
	// Gamedata.
	Handle hConfig = LoadGameConfigFile("napalmlagfix.games");
	if(hConfig == INVALID_HANDLE)
		SetFailState("Could not find gamedata file: napalmlagfix.games.txt");

	int offset = GameConfGetOffset(hConfig, "RadiusDamage");
	if(offset == -1)
		SetFailState("Failed to find RadiusDamage offset");

	CloseHandle(hConfig);

	// DHooks
	g_hRadiusDamage = DHookCreate(offset, HookType_GameRules, ReturnType_Void, ThisPointer_Ignore, Hook_RadiusDamage);
	DHookAddParam(g_hRadiusDamage, HookParamType_ObjectPtr);	// 1 - CTakeDamageInfo &info
	DHookAddParam(g_hRadiusDamage, HookParamType_VectorPtr);	// 2 - Vector &vecSrc
	DHookAddParam(g_hRadiusDamage, HookParamType_Float);		// 3 - float flRadius
	DHookAddParam(g_hRadiusDamage, HookParamType_Int);			// 4 - int iClassIgnore
	DHookAddParam(g_hRadiusDamage, HookParamType_CBaseEntity);	// 5 - CBaseEntity *pEntityIgnore
}

public void OnMapStart()
{
	DHookGamerules(g_hRadiusDamage, false);
}

public MRESReturn Hook_RadiusDamage(Handle hParams)
{
	if(DHookIsNullParam(hParams, 5))
		return MRES_Ignored;

	int iDmgBits = DHookGetParamObjectPtrVar(hParams, 1, 60, ObjectValueType_Int);
	int iEntIgnore = DHookGetParam(hParams, 5);

	if(!(iDmgBits & DMG_BURN))
		return MRES_Ignored;

	// Block napalm damage if it's coming from another client.
	if(1 <= iEntIgnore <= MaxClients)
		return MRES_Supercede;

	// Block napalm that comes from grenades
	char sEntClassName[64];
	if(GetEntityClassname(iEntIgnore, sEntClassName, sizeof(sEntClassName)))
	{
		if(!strcmp(sEntClassName, "hegrenade_projectile"))
			return MRES_Supercede;
	}

	return MRES_Ignored;
}
