
/*	Copyright (C) 2018 IT-KiLLER
	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.
	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.
	
	You should have received a copy of the GNU General Public License
	along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

#include <sdktools>
#include <zombiereloaded>
#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "[ZR] Bhop Velocity Limiter",
	author = "IT-KILLER",
	description = "The velocity it adjusted only for players who actually jumps on the ground.",
	version = "1.0",
	url = "https://github.com/IT-KiLLER"
};

ConVar g_cvarVelocityZombies, g_cvarVelocityHumans;
float g_fBhopVelocityZombie, g_fBhopVelocityZombieSquare, g_fBhopVelocityHumans, g_fBhopVelocityHumansSquare;

public void OnPluginStart()
{
	g_cvarVelocityZombies = CreateConVar("zr_bhopvelocity_zombies", "300.0", "Max velocity for zombies.", _, true, 0.0, true, 2000.0);
	g_cvarVelocityHumans = CreateConVar("zr_bhopvelocity_humans", "300.0", "Max velocity for humans.", _, true, 0.0, true, 2000.0);
	
	g_cvarVelocityZombies.AddChangeHook(OnCvarChanged);
	g_cvarVelocityHumans.AddChangeHook(OnCvarChanged);
	
	AutoExecConfig(true, "ZR_BhopVelocityLimiter", "sourcemod/zombiereloaded");
}

public void OnConfigsExecuted()
{
	g_fBhopVelocityZombie  = g_cvarVelocityZombies.FloatValue;
	g_fBhopVelocityZombieSquare = Pow(g_cvarVelocityZombies.FloatValue, 2.0);
	g_fBhopVelocityHumans  = g_cvarVelocityHumans.FloatValue;
	g_fBhopVelocityHumansSquare = Pow(g_cvarVelocityHumans.FloatValue, 2.0);
}

public void OnCvarChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	if(StrEqual(oldValue, newValue)) return;

	if(convar == g_cvarVelocityZombies)
	{
		g_fBhopVelocityZombie  = g_cvarVelocityZombies.FloatValue;
		g_fBhopVelocityZombieSquare = Pow(g_cvarVelocityZombies.FloatValue, 2.0);
	}
	else if(convar == g_cvarVelocityHumans)
	{
		g_fBhopVelocityHumans  = g_cvarVelocityHumans.FloatValue;
		g_fBhopVelocityHumansSquare = Pow(g_cvarVelocityHumans.FloatValue, 2.0);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(buttons & IN_JUMP && IsPlayerAlive(client) && GetEntityFlags(client) & FL_ONGROUND & ~FL_ATCONTROLS && GetEntityMoveType(client) == MOVETYPE_WALK)
	{
		float flAbsVelocity[3];
		float flVelocity;
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", flAbsVelocity);
		flVelocity = flAbsVelocity[0]*flAbsVelocity[0] + flAbsVelocity[1]*flAbsVelocity[1];
		
		if(ZR_IsClientHuman(client)) 
		{
			if(flVelocity > g_fBhopVelocityHumansSquare)
			{
				NormalizeVector(flAbsVelocity, flAbsVelocity);
				ScaleVector(flAbsVelocity, g_fBhopVelocityHumans);
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, flAbsVelocity);
			}
		} 
		else if(ZR_IsClientZombie(client)) 
		{
			if(flVelocity > g_fBhopVelocityZombieSquare)
			{
				NormalizeVector(flAbsVelocity, flAbsVelocity);
				ScaleVector(flAbsVelocity, g_fBhopVelocityZombie);
				TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, flAbsVelocity);
			}
		}
	}

	return Plugin_Continue;
}