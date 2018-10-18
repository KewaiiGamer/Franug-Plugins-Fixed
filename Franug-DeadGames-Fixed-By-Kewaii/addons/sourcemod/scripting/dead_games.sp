/*  SM Franug DeathMach and Bhop Minigame
 *
 *  Copyright (C) 2017 Francisco 'Franc1sco' García
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */

#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <basecomm>

#define PLUGIN_VERSION "v5.1"

bool g_bDM[MAXPLAYERS+1] = {false, ...};
bool g_bBhop[MAXPLAYERS+1] = {false, ...};
bool g_bNoWeapons[MAXPLAYERS+1] = {false, ...};
bool g_bEnded = false;
int g_offsCollisionGroup;

int g_iOffset_PlayerResource_Alive = -1;

public Plugin myinfo =
{
	name = "SM Franug DeathMach and Bhop Minigame",
	author = "Fixed by Kewaii. broken from Franug",
	description = "",
	version = PLUGIN_VERSION,
	url = "https://steamcommunity.com/id/KewaiiGamer"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	
	CreateNative("deadgames_isdm", Native_IsDM);
	CreateNative("deadgames_isbhop", Native_IsBhop);
	
	return APLRes_Success;
}

public void BaseComm_OnClientMute(int client, bool muteState)
{
	if(!muteState && g_bDM[client] && !GetAdminFlag(GetUserAdmin(client), Admin_Chat)) SetClientListeningFlags(client, VOICE_MUTED);
}

public Action Warden_OnWardenCreate(int client)
{
	if (g_bDM[client])return Plugin_Handled;
	return Plugin_Continue;
}

public int Native_IsDM(Handle plugin, int argc)
{  
	return g_bDM[GetNativeCell(1)];
}

public int Native_IsBhop(Handle plugin, int argc)
{  
	return g_bBhop[GetNativeCell(1)];
}

public void OnPluginStart()
{
	CreateConVar("sm_franugdmminigame_version", PLUGIN_VERSION, "", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	g_offsCollisionGroup = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");
	RegConsoleCmd("sm_godm", Command_DM);
	RegConsoleCmd("sm_nodm", Command_NoDM);
	RegConsoleCmd("sm_gobhop", Command_Bhop);
	RegConsoleCmd("sm_nobhop", Command_NoBhop);
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_team", Event_Team);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_death", Event_PlayerDeath2,EventHookMode_Pre);
	g_iOffset_PlayerResource_Alive = FindSendPropInfo("CCSPlayerResource", "m_bAlive");
	
	AddTempEntHook("Shotgun Shot", Hook_ShotgunShot);
	
	HookEvent("player_jump", Event_OnPlayerJump);
	AddNormalSoundHook(SoundHook);
	
	for (int i = 1; i < GetMaxClients(); i++)
		if (IsClientInGame(i)) OnClientPutInServer(i);
	
}

public void OnPluginEnd()
{
 		for (int i = 1; i < GetMaxClients(); i++)
  		{
			if (IsClientInGame(i))
			{
				if(g_bDM[i])
				{
					if(IsPlayerAlive(i))
					{
						ForcePlayerSuicide(i);
						if(IsPlayerAlive(i))
						{
							int team = GetClientTeam(i);
							ChangeClientTeam(i, 1);
							ChangeClientTeam(i, team);
						}
						SetEntProp(i, Prop_Data, "m_iFrags", GetClientFrags(i)+1);
						int olddeaths = GetEntProp(i, Prop_Data, "m_iDeaths");
						SetEntProp(i, Prop_Data, "m_iDeaths", olddeaths-1);
					}

					g_bDM[i] = false;
					g_bBhop[i] = false;
					g_bNoWeapons[i] = false;
					if(!BaseComm_IsClientMuted(i))SetClientListeningFlags(i, VOICE_NORMAL);

				}
			}
  		}
}


public Action Event_Team(Handle event, const char[] name, bool dontBroadcast) 
{
	CheckDead();
}

public Action Event_OnPlayerJump(Handle event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (g_bBhop[client]) SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
}

public void OnMapStart(){
	int entity = FindEntityByClassname(0, "cs_player_manager");
	SDKHook(entity, SDKHook_ThinkPost, OnPlayerManager_ThinkPost);
}

public void OnPlayerManager_ThinkPost(int entity) {

	for (int i = 1; i < GetMaxClients(); i++) {
		if(g_bDM[i])
		{
			SetEntData(entity, (g_iOffset_PlayerResource_Alive+i*4), 0, 1, true);
		}
	}
}

public void OnClientDisconnect(int client)
{
	g_bDM[client] = false;
	g_bBhop[client] = false;
	g_bNoWeapons[client] = false;
}

public void OnClientDisconnect_Post(int client)
{
	CheckDead();
}

public Action Command_NoDM(int client, int args)
{
	if(g_bDM[client])
	{
		if (IsPlayerAlive(client))ForcePlayerSuicide(client);
		g_bDM[client] = false;
		g_bBhop[client] = false;
		g_bNoWeapons[client] = false;
		if(!BaseComm_IsClientMuted(client))SetClientListeningFlags(client, VOICE_NORMAL);
	}
		
	return Plugin_Handled;
}

public Action Command_DM(int client, int args)
{
	if (!g_bEnded && !IsPlayerAlive(client) && !g_bDM[client])
	{
				g_bDM[client] = true;
				if(!BaseComm_IsClientMuted(client) && !GetAdminFlag(GetUserAdmin(client), Admin_Chat))SetClientListeningFlags(client, VOICE_MUTED);
				CreateTimer(0.5, Respawn, GetClientUserId(client));
				PrintToChat(client," \x04You just went into DM");
	}
	else PrintToChat(client," \x04You cannot go to DM.");
		
	return Plugin_Handled;
}

public Action Command_NoBhop(int client, int args)
{
	if(g_bDM[client])
	{
		if (IsPlayerAlive(client))ForcePlayerSuicide(client);
		g_bDM[client] = false;
		g_bBhop[client] = false;
		g_bNoWeapons[client] = false;
		if(!BaseComm_IsClientMuted(client))SetClientListeningFlags(client, VOICE_NORMAL);
	}
		
	return Plugin_Handled;
}

public Action Command_Bhop(int client, int args)
{
	if (!g_bEnded && !IsPlayerAlive(client) && !g_bDM[client])
	{
		g_bDM[client] = true;
		g_bBhop[client] = true;
		SDKHook(client, SDKHook_PostThink, Hook_Think);
		if(!BaseComm_IsClientMuted(client) && !GetAdminFlag(GetUserAdmin(client), Admin_Chat))SetClientListeningFlags(client, VOICE_MUTED);
		CreateTimer(0.5, Respawn, GetClientUserId(client));
		PrintToChat(client," \x04You just went into DM");
	}
	else PrintToChat(client," \x04You cannot go to DM.");
		
	return Plugin_Handled;
}

public Action Event_PlayerDeath2(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(g_bDM[victim])
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
	
}

void CheckDead()
{
	int cts = 0;
	int trs = 0;
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{

			if(GetClientTeam(i) == 2 && !g_bDM[i])
				trs++;
			else if(GetClientTeam(i) == 3 && !g_bDM[i])
			cts++;
		}
	}
	
	if(trs == 0 || cts == 0)
	{
		g_bEnded = true;
		for (int i = 1; i < MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				if(g_bDM[i])
				{
					if(IsPlayerAlive(i))
					{
						ForcePlayerSuicide(i);
						if(IsPlayerAlive(i))
						{
							int team = GetClientTeam(i);
							ChangeClientTeam(i, 1);
							ChangeClientTeam(i, team);
						}
						SetEntProp(i, Prop_Data, "m_iFrags", GetClientFrags(i)+1);
						int olddeaths = GetEntProp(i, Prop_Data, "m_iDeaths");
						SetEntProp(i, Prop_Data, "m_iDeaths", olddeaths-1);
					}

					g_bDM[i] = false;
					g_bBhop[i] = false;
					g_bNoWeapons[i] = false;
					if(!BaseComm_IsClientMuted(i))SetClientListeningFlags(i, VOICE_NORMAL);

				}
			}
		}
	}
}

public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if(g_bDM[victim])
	{
		CreateTimer(2.0, Respawn,GetClientUserId(victim));
		return Plugin_Continue;
	}
	
	CheckDead();
	
	return Plugin_Continue;
}

public Action Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
		g_bEnded = true;
 		for (int i = 1; i < GetMaxClients(); i++)
  		{
			if (IsClientInGame(i))
			{
				if(IsPlayerAlive(i) && g_bDM[i])
				{
					ForcePlayerSuicide(i);
					g_bDM[i] = false;
					g_bBhop[i] = false;
					if(!BaseComm_IsClientMuted(i))SetClientListeningFlags(i, VOICE_NORMAL);
					g_bNoWeapons[i] = false;
					
				}
              		}
  		}
}

public Action Respawn(Handle timer,any userid)
{
	int client = GetClientOfUserId(userid);
	
	if(IsValidClient(client) && (GetClientTeam(client) == 2 || GetClientTeam(client) == 3) && g_bDM[client] && !g_bEnded && !IsPlayerAlive(client))
	{
		
		if(!g_bBhop[client]) PrintToChat(client," \x04Type !nodm to exit deathmatch and !godm to join again.");
		else PrintToChat(client," \x04Type !nobhop to exit bhop and !gobhop to join again.");
		
		g_bNoWeapons[client] = false;
		CS_RespawnPlayer(client);
		SetEntData(client, g_offsCollisionGroup, 2, 4, true);
		
		StripAllWeapons(client);
		
		if (g_bBhop[client])
		{		
			SetEntityRenderMode(client, RENDER_TRANSADD);
			SetEntityRenderColor(client, 0, 255, 0, 120);
		}
		
		if(GetClientTeam(client) == 2)
		{
			if(!g_bBhop[client])
			{
				GivePlayerItem(client, "weapon_ak47");
				GivePlayerItem(client, "weapon_glock");
				GivePlayerItem(client, "weapon_knife");
			}
			
			g_bNoWeapons[client] = true;
		}
		else if(GetClientTeam(client) == 3)
		{
			if(!g_bBhop[client])
			{
				GivePlayerItem(client, "weapon_ak47");
				GivePlayerItem(client, "weapon_glock");
				GivePlayerItem(client, "weapon_knife");
			}
			SetEntityHealth(client, 200);
			
			g_bNoWeapons[client] = true;
		}
		
	}
}

void StripAllWeapons(int client)
{
	int wepIdx;
	for (int i; i < 5; i++)
	{
		while ((wepIdx = GetPlayerWeaponSlot(client, i)) != -1)
		{
			RemovePlayerItem(client, wepIdx);
			AcceptEntityInput(wepIdx, "Kill");
		}
	}
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast) 
{
	g_bEnded = false;

	for (int i = 1; i < GetMaxClients(); i++)
	{
		if (IsClientInGame(i))
		{
			if(g_bDM[i])
			{
				g_bDM[i] = false;
				g_bBhop[i] = false;
				if(!BaseComm_IsClientMuted(i))SetClientListeningFlags(i, VOICE_NORMAL);
				
			}
			g_bNoWeapons[i] = false;
		}
	}
}
public int IsValidClient(int client) 
{ 
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) 
        return false; 
     
    return true; 
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_WeaponDropPost, OnWeaponDrop);
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
	SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit); 
}

public Action Hook_Think(int client) 
{ 
    if (g_bBhop[client]) 
    {
    	if(IsPlayerAlive(client) && GetEntityFlags(client) & FL_ONGROUND)
		{
			int flags = GetEntityFlags(client);
			SetEntityFlags(client, flags&~FL_ONGROUND);
		}
    }
	else SDKUnhook(client, SDKHook_PostThink, Hook_Think);
}   

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(g_bBhop[victim]) return Plugin_Handled;
	
	if(!IsValidClient(attacker)) return Plugin_Continue;
	
	if(g_bDM[victim] != g_bDM[attacker])
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public int OnWeaponDrop(int client, int entity)
{
    if (!IsClientInGame(client) || !g_bDM[client] || !IsValidEntity(entity) || !IsValidEdict(entity))
        return;

    AcceptEntityInput(entity, "kill");
}

public Action OnWeaponCanUse(int client, int weapon)
{
	if (g_bNoWeapons[client] && g_bBhop[client]) return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action Hook_SetTransmit(int entity, int client) 
{ 
	if (entity == client) return Plugin_Continue;
	
	if (g_bDM[client] != g_bDM[entity]) 
		return Plugin_Handled;
     
	return Plugin_Continue; 
}   

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if(g_bDM[client])
	{
		if(g_bBhop[client])
			buttons &= ~IN_USE;
	}
	return Plugin_Continue;
}


public bool CanHear(int shooter, int client) {
    if (!IsValidClient(shooter) || !IsValidClient(client) || shooter == client) {
        return true;
    }

    float pos[3];
    GetClientAbsOrigin(client, pos);

    // Block the transmisson.
    if (g_bDM[shooter] != g_bDM[client]) {
        return false;
    }

    // Transmit by default.
    return true;
}

public Action Hook_ShotgunShot(const char[] te_name, const int[] players, int numClients, float delay) {

    int shooterIndex = TE_ReadNum("m_iPlayer") + 1;

    // Check which clients need to be excluded.
    int[] newClients = new int[MaxClients];
    int newTotal = 0;

    for (int i = 0; i < numClients; i++) {
        int client = players[i];

        bool rebroadcast = true;
        if (!IsValidClient(client)) {
            rebroadcast = true;
        } else {
            rebroadcast = CanHear(shooterIndex, client);
        }

        if (rebroadcast) {
            // This Client should be able to hear it.
            newClients[newTotal] = client;
            newTotal++;
        }
    }

    // No clients were excluded.
    if (newTotal == numClients) {
        return Plugin_Continue;
    }

    // All clients were excluded and there is no need to broadcast.
    if (newTotal == 0) {
        return Plugin_Stop;
    }

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
    TE_WriteNum("m_iPlayer", TE_ReadNum("m_iPlayer"));
    TE_WriteFloat("m_fInaccuracy", TE_ReadFloat("m_fInaccuracy"));
    TE_WriteFloat("m_fSpread", TE_ReadFloat("m_fSpread"));
    TE_Send(newClients, newTotal, delay);

    return Plugin_Stop;
}



public Action SoundHook(int clients[64], int &numClients, char sound[PLATFORM_MAX_PATH], int &Ent, int &channel, float &volume, int &level, int &pitch, int &flags)
{
	if(IsValidClient(Ent) && g_bBhop[Ent]) return Plugin_Stop;
	 
	return Plugin_Continue;
}