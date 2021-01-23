#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <multicolors>

//#pragma newdecls required

#define PLUGIN_NAME     "Toggle Weapon Sounds clientprefs"
#define PLUGIN_VERSION  "1.1.0"

int g_iStopSound[MAXPLAYERS+1];
bool g_bHooked;
bool g_bReplaceSilence[MAXPLAYERS+1];

Handle g_hClientCookie = INVALID_HANDLE;

char ReplaceSoundPath[PLATFORM_MAX_PATH];

ConVar gCvar_ReplaceSound;

public Plugin myinfo =
{
        name = PLUGIN_NAME,
        author = "GoD-Tony",
        description = "Allows clients to stop hearing weapon sounds",
        version = PLUGIN_VERSION,
        url = "http://www.sourcemod.net/"
};

public void OnPluginStart()
{
        g_hClientCookie = RegClientCookie("togglestopsound", "Toggle hearing weapon sounds", CookieAccess_Private);
        SetCookieMenuItem(StopSoundCookieHandler, g_hClientCookie, "Stop Weapon Sounds");

        gCvar_ReplaceSound = CreateConVar("sm_stopsound_replacesound_path", "weapons/usp/usp1.wav", "Path To the sound that you want to replace.");

        AddTempEntHook("Shotgun Shot", CSS_Hook_ShotgunShot);
        AddNormalSoundHook(Hook_NormalSound);
      
        CreateConVar("sm_stopsound_version", PLUGIN_VERSION, "Toggle Weapon Sounds", FCVAR_NOTIFY|FCVAR_DONTRECORD);
        RegConsoleCmd("sm_stopsound", Command_StopSound, "Toggle hearing weapon sounds");
        RegConsoleCmd("sm_gunsound", Command_StopSound, "Toggle hearing weapon sounds");

        for (int i = 1; i <= MaxClients; ++i)
        {
                if (!AreClientCookiesCached(i))
                {
                        continue;
                }
              
                OnClientCookiesCached(i);
        }

	LoadTranslations("togglestopsound.phrases");
}

public void OnMapStart()
{
	GetConVarString(gCvar_ReplaceSound, ReplaceSoundPath, sizeof(ReplaceSoundPath));

        if(ReplaceSoundPath[0])
                PrecacheSound(ReplaceSoundPath, true);
}

public void StopSoundCookieHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
        switch (action)
        {
                case CookieMenuAction_DisplayOption:
                {
                }
              
                case CookieMenuAction_SelectOption:
                {
                        if(CheckCommandAccess(client, "sm_stopsound", 0))
                        {
                                PrepareMenu(client);
                        }
                        else
                        {
                                ReplyToCommand(client, "[SM] You have no access!");
                        }
                }
        }
}

void PrepareMenu(int client)
{
        Handle menu = CreateMenu(YesNoMenu, MENU_ACTIONS_DEFAULT|MenuAction_DrawItem|MenuAction_DisplayItem|MenuAction_Display);

        SetMenuTitle(menu, "%t\n ", "StopSound_Title");
        AddMenuItem(menu, "0", "Disable");
        AddMenuItem(menu, "1", "Stop Sound");
        AddMenuItem(menu, "2", "Replace to Silenced Sound");
        SetMenuExitBackButton(menu, true);
        DisplayMenu(menu, client, 20);
}

public int YesNoMenu(Handle menu, MenuAction action, int param1, int param2)
{
	switch(action)
        {
		case MenuAction_Select:
                {
                        char info[50];
			if(GetMenuItem(menu, param2, info, sizeof(info)))
			{
				SetClientCookie(param1, g_hClientCookie, info);
				g_iStopSound[param1] = StringToInt(info);
				if(StringToInt(info) == 2) 
				{
					g_bReplaceSilence[param1] = true;
					CReplyToCommand(param1, "%T %T {lightgreen}%T{default}.", "prefix", "stop weapon sounds", "Replace to Silenced Sound");
				}
				else if (StringToInt(info) == 1) 
				{
					g_bReplaceSilence[param1] = false;
					CReplyToCommand(param1, "%T %T {lightgreen}%T{default}.", "prefix", "stop weapon sounds", "Enabled");
				}
				else
				{
					g_bReplaceSilence[param1] = false;
					CReplyToCommand(param1, "%T %T {lightgreen}%T{default}.", "prefix", "stop weapon sounds", "Disabled");
				}
				CheckHooks();
				PrepareMenu(param1);
			}
		}
		case MenuAction_Cancel:
		{
			if( param2 == MenuCancel_ExitBack )
			{
				ShowCookieMenu(param1);
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}
        return 0;
}

public void OnClientCookiesCached(int client)
{
	char sValue[8];
	GetClientCookie(client, g_hClientCookie, sValue, sizeof(sValue));
	if (sValue[0] == '\0') 
	{
		SetClientCookie(client, g_hClientCookie, "2");
		strcopy(sValue, sizeof(sValue), "2");
        }
	g_iStopSound[client] = (StringToInt(sValue));
	g_bReplaceSilence[client] = StringToInt(sValue) > 1;
        CheckHooks();
}

public Action Command_StopSound(int client, int args)
{	
	if(AreClientCookiesCached(client))
		PrepareMenu(client);

	else
        {
                //ReplyToCommand(client, "[SM] Your Cookies are not yet cached. Please try again later...");
		CReplyToCommand(client, "%T %T", "prefix", "Loading_Cookies");
	}
	return Plugin_Handled;
}

public void OnClientDisconnect_Post(int client)
{
	g_iStopSound[client] = 0;
	g_bReplaceSilence[client] = false;
	CheckHooks();
}

void CheckHooks()
{
	bool bShouldHook = false;
      
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_iStopSound[i] > 0)
		{
			bShouldHook = true;
			break;
		}
	}
      
        // Fake (un)hook because toggling actual hooks will cause server instability.
        g_bHooked = bShouldHook;
}

public Action:Hook_NormalSound(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
        // Ignore non-weapon or Re-broadcasted sounds.
        if (!g_bHooked || StrEqual(sample, ReplaceSoundPath, false) || !(strncmp(sample, "weapons", 7, false) == 0 || strncmp(sample[1], "weapons", 7, false) == 0 || strncmp(sample[2], "weapons", 7, false) == 0))
                return Plugin_Continue;
      
        int i, j;
      
        for (i = 0; i < numClients; i++)
        {
                if (g_iStopSound[clients[i]] > 0)
                {
                        // Remove the client from the array.
                        for (j = i; j < numClients-1; j++)
                        {
                                clients[j] = clients[j+1];
                        }
                      
                        numClients--;
                        i--;
                }
        }
      
        return (numClients > 0) ? Plugin_Changed : Plugin_Stop;
}

public Action CSS_Hook_ShotgunShot(const char[] te_name, const int[] Players, int numClients, float delay)
{
        if (!g_bHooked)
                return Plugin_Continue;
      
        // Check which clients need to be excluded.
	decl newClients[MaxClients];
	int client; 
	int i;
        int newTotal = 0;

        int clientlist[MAXPLAYERS+1];
        int clientcount = 0;

        for (i = 0; i < numClients; i++)
        {
                client = Players[i];
              
                if (g_iStopSound[client] <= 0)
                {
                        newClients[newTotal++] = client;
                }
                else if(ReplaceSoundPath[0])
                {
                        if(g_bReplaceSilence[client])
                        {
                                clientlist[clientcount++] = client;
                        }
                }
        }
      
        // No clients were excluded.
        if (newTotal == numClients)
                return Plugin_Continue;

        int player = TE_ReadNum("m_iPlayer");
        if(ReplaceSoundPath[0]) 
	{
                new entity = player + 1;
                for (new j = 0; j < clientcount; j++)
                {
                        if (entity == clientlist[j])
                        {
                                for (new k = j; k < clientcount-1; k++)
                                {
                                        clientlist[k] = clientlist[k+1];
                                }
                              
                                clientcount--;
                                j--;
                        }
                }
                EmitSound(clientlist, clientcount, ReplaceSoundPath, entity, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
        }
      
        // All clients were excluded and there is no need to broadcast.
        else if (newTotal == 0)
                return Plugin_Stop;
      
        // Re-broadcast to clients that still need it.
        float vTemp[3];
        TE_Start("Shotgun Shot");
        TE_ReadVector("m_vecOrigin", vTemp);
        TE_WriteVector("m_vecOrigin", vTemp);
        TE_WriteFloat("m_vecAngles[0]", TE_ReadFloat("m_vecAngles[0]"));
        TE_WriteFloat("m_vecAngles[1]", TE_ReadFloat("m_vecAngles[1]"));
        TE_WriteNum("m_weapon", TE_ReadNum("m_weapon"));
        TE_WriteNum("m_iMode", TE_ReadNum("m_iMode"));
        TE_WriteNum("m_iSeed", TE_ReadNum("m_iSeed"));
        TE_WriteNum("m_iPlayer", player);
        TE_WriteFloat("m_fInaccuracy", TE_ReadFloat("m_fInaccuracy"));
        TE_WriteFloat("m_fSpread", TE_ReadFloat("m_fSpread"));
        TE_Send(newClients, newTotal, delay);
      
        return Plugin_Stop;
}
