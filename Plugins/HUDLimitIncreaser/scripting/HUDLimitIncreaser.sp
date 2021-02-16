#pragma semicolon 1

#include <sourcemod>

#pragma newdecls required

public Plugin myinfo =
{
	name = "HUDLimitIncreaser",
	author = "gubka",
	description = "Increase limitation of showing HP and Ammo HUD",
	version = "1.0",
	url = "https://forums.alliedmods.net/showthread.php?t=314962"
};

public void OnPluginStart() 
{
	FindConVar("sv_sendtables").SetInt(1);

	// Loads a gamedata configs file
	Handle hConfig = LoadGameConfigFile("HUDLimitIncreaser.games");

	// Load other offsets
	int iBits                            = GameConfGetOffset(hConfig,  "CSendProp::m_nBits");
	Address g_SendTableCRC                = GameConfGetAddress(hConfig, "g_SendTableCRC");
	Address m_ArmorValue                = GameConfGetAddress(hConfig, "m_ArmorValue");
	Address m_iAccount                    = GameConfGetAddress(hConfig, "m_iAccount");
	Address m_iHealth                    = GameConfGetAddress(hConfig, "m_iHealth");
	Address m_iClip1                    = GameConfGetAddress(hConfig, "m_iClip1");
	Address m_iPrimaryReserveAmmoCount    = GameConfGetAddress(hConfig, "m_iPrimaryReserveAmmoCount");
	Address m_iSecondaryReserveAmmoCount = GameConfGetAddress(hConfig, "m_iSecondaryReserveAmmoCount");

	// Memory patching
	StoreToAddress(m_ArmorValue + view_as<Address>(iBits), 32, NumberType_Int32);
	StoreToAddress(m_iAccount + view_as<Address>(iBits), 32, NumberType_Int32);
	StoreToAddress(m_iHealth + view_as<Address>(iBits), 32, NumberType_Int32);
	StoreToAddress(m_iClip1 + view_as<Address>(iBits), 32, NumberType_Int32);
	StoreToAddress(m_iPrimaryReserveAmmoCount + view_as<Address>(iBits), 32, NumberType_Int32);
	StoreToAddress(m_iSecondaryReserveAmmoCount + view_as<Address>(iBits), 32, NumberType_Int32);

	/// 1337 -> it just a random and an invalid CRC32 byte
	StoreToAddress(g_SendTableCRC, 1337, NumberType_Int32);
} 