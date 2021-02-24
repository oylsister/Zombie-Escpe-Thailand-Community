#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <multicolors>

#pragma newdecls required

enum struct ShowingHP
{
	char sEntityName[64];
	int iEntityIndex;
}

ShowingHP g_ShowHPClient[MAXPLAYERS+1];

Handle BossHud_Cookie = INVALID_HANDLE;

bool g_bEnableBHud[MAXPLAYERS+1];
bool g_bHitmarker[MAXPLAYERS+1];

float g_fLastClienthit[MAXPLAYERS+1];
float g_fLastShowBHud;
//float g_fLastShowBHud;

float CurrentTime;

public Plugin myinfo = 
{
	name = "Demo Simplified BossHUD",
	author = "Oylsister",
	description = "Showing an entity health with hitmarker",
	version = "1.0",
	url = "https://github.com/oylsister/Zombie-Escpe-Thailand-Community"
};

public void OnPluginStart()
{
	BossHud_Cookie = RegClientCookie("bosshp_cookie", "[BossHUD] Toggle Showing Boss Health", CookieAccess_Protected);
	SetCookieMenuItem(BossHudMenu_Cookie, 0, "[BossHUD] Showing Entity HP");
	for(int client = 1; client <= MaxClients; client++) 
	{
        	if(AreClientCookiesCached(client)) 
            		OnClientCookiesCached(client);
    	}

	HookEntityOutput("func_physbox", "OnHealthChanged", OnDamage);
	HookEntityOutput("func_physbox_multiplayer", "OnHealthChanged", OnDamage);
	HookEntityOutput("func_breakable", "OnHealthChanged", OnDamage);
	HookEntityOutput("prop_dynamic", "OnHealthChanged", OnDamageHook);
	HookEntityOutput("math_counter", "OutValue", OnDamageCounter);

	RegConsoleCmd("sm_bhud", BossHudMenu);
	RegConsoleCmd("sm_bosshp", BossHudMenu);

	LoadTranslations("BossHud.phrases");
}

public void OnClientCookiesCached(int client)
{
	char sBuffer[4];
    	GetClientCookie(client, BossHud_Cookie, sBuffer, sizeof(sBuffer));

	if(sBuffer[0] != '\0') 
	{
        	char sTemp[2];
        	FormatEx(sTemp, sizeof(sTemp), "%c", sBuffer[1]);
        	g_bEnableBHud[client] = StrEqual(sTemp, "1");
		
		FormatEx(sTemp, sizeof(sTemp), "%c", sBuffer[2]);
        	g_bHitmarker[client] = StrEqual(sTemp, "1");
	}
	
	else 
	{
		g_bEnableBHud[client] = true;	
		g_bHitmarker[client] = true;
        	
		char sCookie[4];
    		FormatEx(sCookie, sizeof(sCookie), "%b%b", g_bEnableBHud[client], g_bHitmarker[client]);
    		SetClientCookie(client, BossHud_Cookie, sCookie);
	}
}
public void BossHudMenu_Cookie(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
    	if(action == CookieMenuAction_SelectOption)
        	BossHudMenu(client, 1);
}

public int BossHudMenu_Handler(Menu menu, MenuAction action, int client, int param)
{
    	if(action == MenuAction_Select) 
	{
		switch (param)
		{
			case 0:
			{
            			g_bEnableBHud[client] = !g_bEnableBHud[client];
            			CPrintToChat(client, "%t %t {lightgreen}%t{default}.", "prefix", "Toggle_BHud", g_bEnableBHud[client] ? "Enabled" : "Disabled");
        		}
			case 1:
			{
            			g_bHitmarker[client] = !g_bHitmarker[client];
            			CPrintToChat(client, "%t %t {lightgreen}%t{default}.", "prefix", "Toggle_Hitmarker", g_bHitmarker[client] ? "Enabled" : "Disabled");
        		}
		}
        	char sCookie[4];
    		FormatEx(sCookie, sizeof(sCookie), "%b%b", g_bEnableBHud[client], g_bHitmarker[client]);
    		SetClientCookie(client, BossHud_Cookie, sCookie);

        	BossHudMenu(client, 1);
	} 
	else if(action == MenuAction_Cancel)
        	ShowCookieMenu(client);

    	else if(action == MenuAction_End)
        	delete menu;
}

public Action BossHudMenu(int client, int args)
{
    	Menu menu = new Menu(BossHudMenu_Handler, MENU_ACTIONS_DEFAULT);
    	menu.SetTitle("%t\n", "Cookies_MenuName");

    	char sTemp[256];
    	FormatEx(sTemp, sizeof(sTemp), "%t: %t", "Menu_BHud", g_bEnableBHud[client] ? "Enabled" : "Disabled");
    	menu.AddItem("bBhud", sTemp);
	FormatEx(sTemp, sizeof(sTemp), "%t: %t", "Menu_Hitmarker", g_bHitmarker[client] ? "Enabled" : "Disabled");
    	menu.AddItem("bHM", sTemp);
    
    	menu.ExitBackButton = true;
    	menu.Display(client, 30);
}

public void OnDamageHook(const char[] output, int entity, int activator, float delay)
{
	if (activator > 0 && activator < MAXPLAYERS)
		g_fLastClienthit[activator] = GetEngineTime();
}

public void OnDamage(const char[] output, int entity, int activator, float delay)
{
	if (activator < 1 || activator > MAXPLAYERS) 
		return;

	g_fLastClienthit[activator] = GetEngineTime();
	
	int value;
	value = GetEntProp(entity, Prop_Data, "m_iHealth");
	
	if (value > 500000) 
		return;

	if (g_fLastShowBHud + 3.0 < GetEngineTime() && g_fLastClienthit[activator] > GetEngineTime() - 0.2)
	{
		if (g_ShowHPClient[activator].iEntityIndex != entity)
		{
			GetEntPropString(entity, Prop_Data, "m_iName", g_ShowHPClient[activator].sEntityName, 64);

			if(strlen(g_ShowHPClient[activator].sEntityName) == 0)
				Format(g_ShowHPClient[activator].sEntityName, 64, "HP");

			g_ShowHPClient[activator].iEntityIndex = entity;
		}

		if (g_bHitmarker[activator])
			ShowHitMarker(activator);

		if (g_bEnableBHud[activator])
		{
			if (value <= 0) //to prevent displaying negative number
				UpdateBossHP(activator, entity, g_ShowHPClient[activator].sEntityName, 0);

			else
				UpdateBossHP(activator, entity, g_ShowHPClient[activator].sEntityName, value);
		}
	}
}

public void OnDamageCounter(const char[] output, int entity, int activator, float delay)
{
	if (g_fLastShowBHud + 3.0 < GetEngineTime() && (IsValidEntity(entity) || IsValidEdict(entity)) && activator > 0 && activator <= MAXPLAYERS)
	{
		if (g_fLastClienthit[activator] < GetEngineTime() - 0.1) 
			return;
		
		int value = RoundToNearest(GetEntDataFloat(entity, FindDataMapInfo(entity, "m_OutValue")));
		GetEntPropString(entity, Prop_Data, "m_iName", g_ShowHPClient[activator].sEntityName, 64);

		g_ShowHPClient[activator].iEntityIndex = 0;

		if (value > 0)
		{
			if (g_bHitmarker[activator])
				ShowHitMarker(activator);	
			
			if (g_bEnableBHud[activator])
				UpdateBossHP(activator, 0, g_ShowHPClient[activator].sEntityName, value);
		}
	}
}

public void UpdateBossHP(int client, int entity, const char[] entityname, int value)
{
	CurrentTime = GetEngineTime();
	if ((g_fLastClienthit[client] > CurrentTime - 3.0 && g_fLastShowBHud + 0.1 < CurrentTime)  ||  value == 0)
	{
		int iPlayer = 0;
		int iCTPlayer = 0;

		for(int i = 1; i <= MaxClients; ++i)
		{
			if(IsClientInGame(i))
			{
				if (GetClientTeam(i) == 3) 
				{
					iCTPlayer++;

					if (g_fLastClienthit[i] > CurrentTime - 7.0 && g_ShowHPClient[i].iEntityIndex == entity && StrEqual(g_ShowHPClient[i].sEntityName, entityname)) 
						iPlayer++;
				}
			}
		}
		
		if (iPlayer > iCTPlayer / 2) 
			PrintHintTextToAll("%s: %d HP", entityname, value);

		else 
		{
			for(int i = 1; i <= MaxClients; ++i)
			{
				if(IsClientInGame(i))
				{
					if (g_fLastClienthit[i] > CurrentTime - 7.0 && g_ShowHPClient[i].iEntityIndex == entity && StrEqual(g_ShowHPClient[i].sEntityName, entityname))
						PrintHintText(i, "%s: %d HP", entityname, value);
				}
			}
		}
		g_fLastShowBHud = CurrentTime;
	}
}

public void ShowHitMarker(int client)
{
	SetHudTextParams(-1.0, -1.0, 0.1, 255, 0, 0, 255, 1, 0.0, 0.1, 0.1);
	ShowHudText(client, 5, "◞  ◟\n◝  ◜");
}
