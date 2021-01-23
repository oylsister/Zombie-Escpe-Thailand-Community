#include <sourcemod>
#include <clientprefs>
#include <multicolors>

bool g_autozspawn[MAXPLAYERS+1];
Handle AutoZspawn_Cookie = INVALID_HANDLE;

ConVar g_CvarSpawnTimer;

public Plugin myinfo =
{
	name = "AutoZspawn with Toggle Option",
	author = "Mapeadores, Oylsister",
	description = "Allow player to autozspawn when joining late to the server",
	version = "1.2",
	url = ""
};

public void OnPluginStart()
{	
	g_CvarSpawnTimer = CreateConVar("zr_autospawntimer", "5.0", "Timer to autospawn player after choose team.", 0, true, 0.1, false);
	HookEvent("player_team", Event_OnPlayerTeam, EventHookMode_Pre);	
	RegConsoleCmd("sm_autozspawn", ToggleAutoZspawn);

	AutoZspawn_Cookie = RegClientCookie("autozspawn_cookie", "Toggle AutoZSpawn", CookieAccess_Protected);
    
    	for(int client = 1; client <= MaxClients; client++) 
	{
        	if(AreClientCookiesCached(client))
            		OnClientCookiesCached(client);
    	}
	
	LoadTranslations("AutoZspawn.phrases")
	AutoExecConfig();
}

public void OnClientDisconnect(int client)
{
	g_autozspawn[client] = false;
}

public void OnClientCookiesCached(int client)
{
    	char sBuffer[4];
    	GetClientCookie(client, AutoZspawn_Cookie, sBuffer, sizeof(sBuffer));

	if(sBuffer[0] != '\0') 
	{
		char sTemp[2];
        	FormatEx(sTemp, sizeof(sTemp), "%c", sBuffer[0]);
        	g_autozspawn[client] = StrEqual(sTemp, "1");
	}
	else
		g_autozspawn[client] = true;
}

public Action ToggleAutoZspawn(int client, int args)
{
	g_autozspawn[client] = !g_autozspawn[client];
	//CPrintToChat(client, "{green}[ZR] {default}AutoZspawn is now %s {default}for you.", g_autozspawn[client] ? "{lightgreen}Enabled" : "{red}Disabled");
	CPrintToChat(client, "{green}[ZR]{default} %T %T {defualt}%T", "ToggleAutoZspawn", g_autozspawn[client] ? "Enabled" : "Disabled", "for you");

	char sCookie[4];
    	FormatEx(sCookie, sizeof(sCookie), "%b", g_autozspawn[client]);
    	SetClientCookie(client, AutoZspawn_Cookie, sCookie);
}

public Action Event_OnPlayerTeam(Handle event, const char[] name, bool dontBroadcast)
{
    	int client = GetClientOfUserId(GetEventInt(event, "userid"));
    	if(!client || !IsClientInGame(client))
        	return Plugin_Continue;

	float g_fSpawnTimer = GetConVarFloat(g_CvarSpawnTimer);
	int iTeam = GetClientTeam(client);
    	if(!IsPlayerAlive(client) && iTeam >= 2)
	{
		if (g_autozspawn[client] == true)
			CreateTimer(g_fSpawnTimer, Timer_ZSpawn, GetClientUserId(client));
		else
			return Plugin_Continue;

		//CPrintToChat(client, "{green}[ZR] {default}You are currently %s {default}AutoZspawn. Type {lightgreen}!autozspawn {default}again to toggle the option.", g_autozspawn[client] ? "{lightgreen}Enabled" : "{red}Disabled");
		CPrintToChat(client, "{green}[ZR]{default} %T %T {default}%T, "JoinTeam", g_autozspawn[client] ? "Enabled" : "Disabled", "TypeAgain");
        }
    	return Plugin_Continue;
}

public Action Timer_ZSpawn(Handle timer, any userid)
{
    	int client = GetClientOfUserId(userid);
    	if(!client)
        	return Plugin_Handled;

    	ClientCommand(client, "zspawn");
    	return Plugin_Handled;
}