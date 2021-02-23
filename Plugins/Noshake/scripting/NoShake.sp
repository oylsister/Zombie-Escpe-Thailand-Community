#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <clientprefs>
#include <multicolors>

#pragma newdecls required

Handle g_hNoShakeCookie;
ConVar g_Cvar_NoShakeGlobal;

bool g_bNoShake[MAXPLAYERS + 1] = {false, ...};
bool g_bNoShakeGlobal = false;

public Plugin myinfo =
{
	name 			= "NoShake with Translations Supported and Setting Menu",
	author 			= "BotoX",
	description 	= "Disable env_shake",
	version 		= "1.1.0",
	url 			= ""
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_shake", Command_Shake, "[NoShake] Disables or enables screen shakes.");
	RegConsoleCmd("sm_noshake", Command_Shake, "[NoShake] Disables or enables screen shakes.");

	g_hNoShakeCookie = RegClientCookie("noshake_cookie", "NoShake", CookieAccess_Protected);

	g_Cvar_NoShakeGlobal = CreateConVar("sm_noshake_global", "0", "Disable screenshake globally.", 0, true, 0.0, true, 1.0);
	g_bNoShakeGlobal = g_Cvar_NoShakeGlobal.BoolValue;
	g_Cvar_NoShakeGlobal.AddChangeHook(OnConVarChanged);
	
	LoadTranslations("NoShake.phrases");

	HookUserMessage(GetUserMessageId("Shake"), MsgHook, true);
}

public void OnClientCookiesCached(int client)
{
	static char sCookieValue[2];
	GetClientCookie(client, g_hNoShakeCookie, sCookieValue, sizeof(sCookieValue));
	g_bNoShake[client] = StringToInt(sCookieValue) != 0;
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if(StringToInt(newValue) > StringToInt(oldValue))
		//CPrintToChatAll("{green}[{lime}NoShake{green}] {default}Enabled no-shake for everyone!");
		CPrintToChatAll("%t %t", "prefix", "enable_forall");

	else if(StringToInt(newValue) < StringToInt(oldValue))
		//CPrintToChatAll("{green}[{lime}NoShake{green}] {default}Disabled no-shake for everyone!");
		CPrintToChatAll("%t %t", "prefix", "disable_forall");

	g_bNoShakeGlobal = StringToInt(newValue) != 0;
}

public Action MsgHook(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
	if(playersNum == 1 && (g_bNoShakeGlobal || g_bNoShake[players[0]]))
		return Plugin_Handled;
	else
		return Plugin_Continue;
}

public Action Command_Shake(int client, int args)
{
	if(g_bNoShakeGlobal)
		return Plugin_Handled;

	if(!AreClientCookiesCached(client))
	{
		//CPrintToChat(client, "{green}[{lime}NoShake{green}] {default}Please wait. Your settings are still loading.");
		CPrintToChat(client, "%t %t", "prefix", "setting_loading");
		return Plugin_Handled;
	}

	if(g_bNoShake[client])
	{
		g_bNoShake[client] = false;
		//CPrintToChat(client, "{green}[{lime}NoShake{green}] {default}has been {orange}disabled!", "prefix", "disabled");
		CPrintToChat(client, "%t %t", "prefix", "disabled");
	}
	else
	{
		g_bNoShake[client] = true;
		//CPrintToChat(client, "{green}[{lime}NoShake{green}] {default}has been {orange}enabled!", "prefix", "enabled");
		CPrintToChat(client, "%t %t", "prefix", "enabled");
	}

	static char sCookieValue[2];
	IntToString(g_bNoShake[client], sCookieValue, sizeof(sCookieValue));
	SetClientCookie(client, g_hNoShakeCookie, sCookieValue);

	return Plugin_Handled;
}

public void NoShakeMenu_Cookie(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	if(action == CookieMenuAction_SelectOption)
		NoShakeMenu(client, 1);
}

public int NoShakeMenu_Handler(Menu menu, MenuAction action, int client, int param)
{
    	if(action == MenuAction_Select) 
	{
        	if(param == 0) 
		{
            		g_bNoShake[client] = !g_bNoShake[client];
            
            		if(g_bNoShake[client] == true)
            			CPrintToChat(client, "%t %t", "prefix", "enabled");
            	
           		if(g_bNoShake[client] == false)
            			CPrintToChat(client, "%t %t", "prefix", "disabled");
        	}

		static char sCookieValue[2];
		IntToString(g_bNoShake[client], sCookieValue, sizeof(sCookieValue));
		SetClientCookie(client, g_hNoShakeCookie, sCookieValue);

       		NoShakeMenu(client, 1);
	} 
	else if(action == MenuAction_Cancel)
        	ShowCookieMenu(client);

    	else if(action == MenuAction_End)
        	delete menu;
}

public Action NoShakeMenu(int client, int args)
{
	Menu menu = new Menu(NoShakeMenu_Handler, MENU_ACTIONS_DEFAULT);
	//menu.SetTitle("[BossHP] Toggle Showing BossHP and BHud\n");
	menu.SetTitle("%t \n", "NoShake_Menu_Title");

	char sTemp[32];
	FormatEx(sTemp, sizeof(sTemp), "%t: %t", "Noshake", g_bNoShake[client] ? "Enable" : "Disable");
	menu.AddItem("bNoShake", sTemp);
    
	menu.ExitBackButton = true;
	menu.Display(client, 30);
}

