#pragma semicolon 1

#include <sourcemod>
#include <cstrike>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "Fixing Buy Menu",
	author = "Oylsister",
	description = "Fix the ct weapon are not purchase with Zmarket price in game menu",
	version = "1.2",
	url = ""
};

public Action CS_OnBuyCommand(int client, const char[] weapon)
{
	if (StrEqual(weapon, "usp_silencer"))
	{
		ClientCommand(client, "sm_usp");
		return Plugin_Handled;
	}
	else if (StrEqual(weapon, "hkp2000"))
	{
		ClientCommand(client, "sm_p2000");
		return Plugin_Handled;
	}
	else if (StrEqual(weapon, "p250"))
	{
		ClientCommand(client, "sm_p250");
		return Plugin_Handled;
	}
	else if (StrEqual(weapon, "elite"))
	{
		ClientCommand(client, "sm_elite");
		return Plugin_Handled;
	}
	else if (StrEqual(weapon, "fiveseven"))
	{
		ClientCommand(client, "sm_fiveseven");
		return Plugin_Handled;
	}
	else if (StrEqual(weapon, "cz75a"))
	{
		ClientCommand(client, "sm_cz");
		return Plugin_Handled;
	}
	else if (StrEqual(weapon, "revolver"))
	{
		ClientCommand(client, "sm_r8");
		return Plugin_Handled;
	}
	else if (StrEqual(weapon, "deagle"))
	{
		ClientCommand(client, "sm_deagle");
		return Plugin_Handled;
	}
	else if (StrEqual(weapon, "nova"))
	{
		ClientCommand(client, "sm_nova");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "xm1014"))
	{
		ClientCommand(client, "sm_xm1014");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "mag7"))
	{
		ClientCommand(client, "sm_mag7");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "m249"))
	{
		ClientCommand(client, "sm_m249");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "negev"))
	{
		ClientCommand(client, "sm_negev");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "mp9"))
	{
		ClientCommand(client, "sm_mp9");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "mp7"))
	{
		ClientCommand(client, "sm_mp7");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "mp5navy"))
	{
		ClientCommand(client, "sm_mp5");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "mp5sd"))
	{
		ClientCommand(client, "sm_mp5");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "ump45"))
	{
		ClientCommand(client, "sm_ump");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "p90"))
	{
		ClientCommand(client, "sm_p90");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "bizon"))
	{
		ClientCommand(client, "sm_bizon");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "famas"))
	{
		ClientCommand(client, "sm_famas");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "ssg08"))
	{
		ClientCommand(client, "sm_ssg08");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "m4a1_silencer"))
	{
		ClientCommand(client, "sm_m4s");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "m4a1"))
	{
		ClientCommand(client, "sm_m4a4");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "aug"))
	{
		ClientCommand(client, "sm_aug");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "awp"))
	{
		ClientCommand(client, "sm_awp");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "scar20"))
	{
		ClientCommand(client, "sm_scar");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "hegrenade"))
	{
		ClientCommand(client, "sm_he");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "smokegrenade"))
	{
		ClientCommand(client, "sm_smoke");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "flashbang"))
	{
		ClientCommand(client, "sm_flash");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "decoy"))
	{
		ClientCommand(client, "sm_decoy");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "incgrenade"))
	{
		ClientCommand(client, "sm_inc");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "taser"))
	{
		ClientCommand(client, "sm_taser");
		return Plugin_Handled; 
	}
	else if (StrEqual(weapon, "kevlar"))
	{
		ClientCommand(client, "sm_kevlar");
		return Plugin_Handled; 
	}
	return Plugin_Continue;
}