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


#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <devzones>
#include <basecomm>
//#include <smlib>

#define PLUGIN_VERSION "v5.0.3"

bool g_dm[MAXPLAYERS+1] = {false, ...};
bool g_bhop[MAXPLAYERS+1] = {false, ...};
bool noarmas[MAXPLAYERS+1] = {false, ...};
bool cerrado = false;
int g_offsCollisionGroup;

char map[128];

int g_iOffset_PlayerResource_Alive = -1;

public Plugin myinfo =
{
	name = "SM Franug DeathMach and Bhop Minigame",
	author = "Franc1sco Steam: franug",
	description = "",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/franug"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	
	CreateNative("DM_isdm", Native_isdm);
	CreateNative("DM_isbhop", Native_isbhop);
	
	return APLRes_Success;
}

public void BaseComm_OnClientMute(int client, bool muteState)
{
	if(!muteState && g_dm[client] && !GetAdminFlag(GetUserAdmin(client), Admin_Chat)) SetClientListeningFlags(client, VOICE_MUTED);
}
public Action warden_OnWardenCreate(int client)
{
	if (g_dm[client])return Plugin_Handled;
	return Plugin_Continue;
}

public int Native_isdm(Handle plugin, int argc)
{  
	return g_dm[GetNativeCell(1)];
}

public int Native_isbhop(Handle plugin, int argc)
{  
	return g_bhop[GetNativeCell(1)];
}

public void OnPluginStart()
{
	CreateConVar("sm_franugdmminigame_version", PLUGIN_VERSION, "", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	
	g_offsCollisionGroup = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");
	RegConsoleCmd("sm_godm", Command_dm);
	RegConsoleCmd("sm_nodm", Command_nodm);
	RegConsoleCmd("sm_gobhop", Command_bhop);
	RegConsoleCmd("sm_nobhop", Command_nobhop);
	//RegConsoleCmd("drop", drop13);
	
	HookEvent("round_start", roundStart);
	HookEvent("round_end", Event_Round_End);
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

public OnPluginEnd()
{
 		for (int i = 1; i < GetMaxClients(); i++)
  		{
			if (IsClientInGame(i))
			{
				if(g_dm[i])
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

					g_dm[i] = false;
					g_bhop[i] = false;
					noarmas[i] = false;
					if(!BaseComm_IsClientMuted(i))SetClientListeningFlags(i, VOICE_NORMAL);

				}
              		}
  		}
}


public Action:Event_Team(Handle:event, const String:name[], bool:dontBroadcast) 
{
	ComprobarMuertos();
}

public Action:Event_OnPlayerJump(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (g_bhop[client]) SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
	//else JumpBoostOnClientJumpPost(client);
}

/* #if _USEPROXY
public OnMapStart()
{
	g_iPlayerManager = FindEntityByClassname(0, "cs_player_manager");
}
#endif */

bool mapazo;
public OnMapStart(){
	
	mapazo = false;
	GetCurrentMap(map, 128);
	if (StrContains(map, "jb_improved_cola") != -1 || StrEqual(map, "jb_spy_vs_spy_beta7b2_dm"))mapazo = true;
	new entity = FindEntityByClassname(0, "cs_player_manager");
	SDKHook(entity, SDKHook_ThinkPost, OnPlayerManager_ThinkPost);
}

public OnPlayerManager_ThinkPost(entity) {

	for (new i = 1; i < GetMaxClients(); i++) {
		if(g_dm[i])
		{
			SetEntData(entity, (g_iOffset_PlayerResource_Alive+i*4), 0, 1, true);
		}
	}
}

public OnClientDisconnect(client)
{
	g_dm[client] = false;
	g_bhop[client] = false;
	noarmas[client] = false;
}

public OnClientDisconnect_Post(client)
{
	ComprobarMuertos();
}
/*
public Action:drop13(client, args)
{
	if(g_dm[client]) return Plugin_Handled;
	
	return Plugin_Continue;
}*/

public Action:Command_nodm(client, args)
{
	if(g_dm[client])
	{
		if (IsPlayerAlive(client))ForcePlayerSuicide(client);
		g_dm[client] = false;
		g_bhop[client] = false;
		noarmas[client] = false;
		if(!BaseComm_IsClientMuted(client))SetClientListeningFlags(client, VOICE_NORMAL);
	}
		
	return Plugin_Handled;
}

public Action:Command_dm(client, args)
{
		
	decl Float:Position[3];
	if(!Zone_GetZonePosition("dmzone", false, Position)) return Plugin_Handled;
		
	if (!cerrado && !IsPlayerAlive(client) && !g_dm[client])
	{
				g_dm[client] = true;
				//SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit); 
				if(!BaseComm_IsClientMuted(client) && !GetAdminFlag(GetUserAdmin(client), Admin_Chat))SetClientListeningFlags(client, VOICE_MUTED);
				CreateTimer(0.5, Resucitar, GetClientUserId(client));
				PrintToChat(client," \x04Now you go to DM");
	}
	else PrintToChat(client," \x04You cant go to DM now.");
		
	return Plugin_Handled;
}

public Action Command_nobhop(int client, int args)
{
	if(g_dm[client])
	{
		if (IsPlayerAlive(client))ForcePlayerSuicide(client);
		g_dm[client] = false;
		g_bhop[client] = false;
		noarmas[client] = false;
		if(!BaseComm_IsClientMuted(client))SetClientListeningFlags(client, VOICE_NORMAL);
	}
		
	return Plugin_Handled;
}

public Action Command_bhop(int client, int args)
{
	float Position[3];
	if(!Zone_GetZonePosition("bhopzone", false, Position)) return Plugin_Handled;
		
	if (!cerrado && !IsPlayerAlive(client) && !g_dm[client])
	{
				g_dm[client] = true;
				g_bhop[client] = true;
				SDKHook(client, SDKHook_PostThink, Hook_Think);
				//SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit); 
				if(!BaseComm_IsClientMuted(client) && !GetAdminFlag(GetUserAdmin(client), Admin_Chat))SetClientListeningFlags(client, VOICE_MUTED);
				CreateTimer(0.5, Resucitar, GetClientUserId(client));
				PrintToChat(client," \x04Now you go to BHOP");
	}
	else PrintToChat(client," \x04You cant go to BHOP now.");
		
	return Plugin_Handled;
}

public Action:Event_PlayerDeath2(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(g_dm[victim])
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
	
}

ComprobarMuertos()
{
	new cts = 0;
	new terros2 = 0;
	for (new i = 1; i < MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{

			if(GetClientTeam(i) == 2 && !g_dm[i])
				terros2++;
			else if(GetClientTeam(i) == 3 && !g_dm[i])
			cts++;
		}
	}
	
	if(terros2 == 0 || cts == 0)
	{
		cerrado = true;
		for (new i = 1; i < MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				if(g_dm[i])
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
						new olddeaths = GetEntProp(i, Prop_Data, "m_iDeaths");
						SetEntProp(i, Prop_Data, "m_iDeaths", olddeaths-1);
					}

					g_dm[i] = false;
					g_bhop[i] = false;
					noarmas[i] = false;
					if(!BaseComm_IsClientMuted(i))SetClientListeningFlags(i, VOICE_NORMAL);

				}
			}
		}
	}
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	
/*
	if(jugadores == 1 && IsValidClient(ultimo))
	{
		PrintToChatAll("SOLO QUEDA UN CT, AHORA ESTE PUEDE ESCRIBIR !ceo para empezar ronda especial");
		ceo = true;
	}
*/
	decl Float:Position[3];
	if(!Zone_GetZonePosition("dmzone", false, Position) && !Zone_GetZonePosition("bhopzone", false, Position)) return Plugin_Continue;
	

	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if(g_dm[victim])
	{
		CreateTimer(2.0, Resucitar,GetClientUserId(victim));
		return Plugin_Continue;
	}
	
	ComprobarMuertos();
	
	return Plugin_Continue;
}

public Action:Event_Round_End(Handle:event, const String:name[], bool:dontBroadcast)
{
		cerrado = true;
 		for (new i = 1; i < GetMaxClients(); i++)
  		{
			if (IsClientInGame(i))
			{
				if(IsPlayerAlive(i) && g_dm[i])
				{
					ForcePlayerSuicide(i);
					g_dm[i] = false;
					g_bhop[i] = false;
					if(!BaseComm_IsClientMuted(i))SetClientListeningFlags(i, VOICE_NORMAL);
					noarmas[i] = false;
					
				}
              		}
  		}
}

public Action:Resucitar(Handle:timer,any:userid)
{
	new client = GetClientOfUserId(userid);
	
	if(IsValidClient(client) && (GetClientTeam(client) == 2 || GetClientTeam(client) == 3) && g_dm[client] && !cerrado && !IsPlayerAlive(client))
	{
		//PrintToChat(client, "has ido");
		
		if(!g_bhop[client]) PrintToChat(client," \x04Type !nodm for exit dm zone and !godm for join again.");
		else PrintToChat(client," \x04Type !nobhop for exit dm zone and !gobhop for join again.");
		
		noarmas[client] = false;
		CS_RespawnPlayer(client);
		SetEntData(client, g_offsCollisionGroup, 2, 4, true);
		//SetEntProp(client, Prop_Send, "m_lifeState", 0);
		
		StripAllWeapons(client);
		
		if (g_bhop[client])
		{		
			SetEntityRenderMode(client, RENDER_TRANSADD);
			SetEntityRenderColor(client, 0, 255, 0, 120);
		}
		
		decl Float:Position[3];
		if(GetClientTeam(client) == 2)
		{
			if(!g_bhop[client])
			{
				GivePlayerItem(client, "weapon_ak47");
				GivePlayerItem(client, "weapon_glock");
				GivePlayerItem(client, "weapon_knife");
			}
			
			if(g_bhop[client] && Zone_GetZonePosition("bhop1", false, Position)) TeleportEntity(client, Position, NULL_VECTOR, NULL_VECTOR);
			else if(Zone_GetZonePosition("dm1", false, Position)) TeleportEntity(client, Position, NULL_VECTOR, NULL_VECTOR);
			
			noarmas[client] = true;
		}
		else if(GetClientTeam(client) == 3)
		{
			if(!g_bhop[client])
			{
				GivePlayerItem(client, "weapon_ak47");
				GivePlayerItem(client, "weapon_glock");
				GivePlayerItem(client, "weapon_knife");
			}
			SetEntityHealth(client, 200);
			
			if(g_bhop[client] && Zone_GetZonePosition("bhop2", false, Position)) TeleportEntity(client, Position, NULL_VECTOR, NULL_VECTOR);
			else if(Zone_GetZonePosition("dm2", false, Position)) TeleportEntity(client, Position, NULL_VECTOR, NULL_VECTOR);
			
			noarmas[client] = true;
		}
		
	}
}

stock StripAllWeapons(client)
{
	new wepIdx;
	for (new i; i < 5; i++)
	{
		while ((wepIdx = GetPlayerWeaponSlot(client, i)) != -1)
		{
			RemovePlayerItem(client, wepIdx);
			AcceptEntityInput(wepIdx, "Kill");
		}
	}
}

public Action:roundStart(Handle:event, const String:name[], bool:dontBroadcast) 
{
	cerrado = false;

	for (new i = 1; i < GetMaxClients(); i++)
	{
		if (IsClientInGame(i))
		{
			if(g_dm[i])
			{
				g_dm[i] = false;
				g_bhop[i] = false;
				if(!BaseComm_IsClientMuted(i))SetClientListeningFlags(i, VOICE_NORMAL);
				
			}
			noarmas[i] = false;
		}
	}
}
public IsValidClient( client ) 
{ 
    if ( !( 1 <= client <= MaxClients ) || !IsClientInGame(client) ) 
        return false; 
     
    return true; 
}

public Zone_OnClientLeave(client, String:zone[])
{
	if(IsValidClient(client) && g_dm[client] && !cerrado)
	{
		//PrintToChat(client, "pasado1");
		if(!g_bhop[client] && StrContains(zone, "dmzone", false) == 0)
		{
			//PrintToChat(client, "pasadodm1");
			//PrintToChat(client, "\x03Dont go out of DeathMach!");
			decl Float:Position[3];
			if(GetClientTeam(client) == CS_TEAM_CT)
			{
				if(Zone_GetZonePosition("dm2", false, Position)) TeleportEntity(client, Position, NULL_VECTOR, NULL_VECTOR);
			}
			else if(GetClientTeam(client) == CS_TEAM_T)
			{
				if(Zone_GetZonePosition("dm1", false, Position)) TeleportEntity(client, Position, NULL_VECTOR, NULL_VECTOR);
			}
		}
		else if(StrContains(zone, "bhopzone", false) == 0)
		{
			//PrintToChat(client, "pasado2");
			//PrintToChat(client, "\x03Dont go out of DeathMach!");
			decl Float:Position[3];
			if(GetClientTeam(client) == CS_TEAM_CT)
			{
				if(Zone_GetZonePosition("bhop2", false, Position)) TeleportEntity(client, Position, NULL_VECTOR, NULL_VECTOR);
			}
			else if(GetClientTeam(client) == CS_TEAM_T)
			{
				//PrintToChat(client, "pasado3");
				if(Zone_GetZonePosition("bhop1", false, Position)) TeleportEntity(client, Position, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
}

public Zone_OnClientEntry(client, String:zone[])
{
	if(IsValidClient(client) && g_dm[client] && !cerrado)
	{
		if(!g_bhop[client] && StrContains(zone, "nodead", false) == 0)
		{
			decl Float:Position[3];
			if(GetClientTeam(client) == CS_TEAM_CT)
			{
				if(Zone_GetZonePosition("dm2", false, Position)) TeleportEntity(client, Position, NULL_VECTOR, NULL_VECTOR);
			}
			else if(GetClientTeam(client) == CS_TEAM_T)
			{
				if(Zone_GetZonePosition("dm1", false, Position)) TeleportEntity(client, Position, NULL_VECTOR, NULL_VECTOR);
			}
		}
		else if(StrContains(zone, "nodead", false) == 0)
		{
			//PrintToChat(client, "pasado2");
			//PrintToChat(client, "\x03Dont go out of DeathMach!");
			decl Float:Position[3];
			if(GetClientTeam(client) == CS_TEAM_CT)
			{
				if(Zone_GetZonePosition("bhop2", false, Position)) TeleportEntity(client, Position, NULL_VECTOR, NULL_VECTOR);
			}
			else if(GetClientTeam(client) == CS_TEAM_T)
			{
				//PrintToChat(client, "pasado3");
				if(Zone_GetZonePosition("bhop1", false, Position)) TeleportEntity(client, Position, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_WeaponDropPost, OnWeaponDrop);
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
	SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit); 
}

public Action:Hook_Think(client) 
{ 
    if (g_bhop[client]) 
    {
    	if(IsPlayerAlive(client) && GetEntityFlags(client) & FL_ONGROUND)
		{
			new flags = GetEntityFlags(client);
			SetEntityFlags(client, flags&~FL_ONGROUND);
		}
    }
	else SDKUnhook(client, SDKHook_PostThink, Hook_Think);
}   

public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if(g_bhop[victim]) return Plugin_Handled;
	
	if(!IsValidClient(attacker)) return Plugin_Continue;
	
	if(g_dm[victim] != g_dm[attacker])
	{
		//PrintToChat(attacker, "\x03No podeis atacaros si ambos no estais en DM!");
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public OnWeaponDrop(client, entity)
{
    if (!IsClientInGame(client) || !g_dm[client] || !IsValidEntity(entity) || !IsValidEdict(entity))
        return;

    AcceptEntityInput(entity, "kill");
}

public Action:OnWeaponCanUse(client, weapon)
{
	if (noarmas[client] && (!mapazo || g_bhop[client])) return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action:Hook_SetTransmit(entity, client) 
{ 
	if (entity == client) return Plugin_Continue;
	
	/*
	if(!g_dm[entity])
	{
		SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmit); 
		return Plugin_Continue; 
	}*/
	
	if (g_dm[client] != g_dm[entity]) 
		return Plugin_Handled;
     
	return Plugin_Continue; 
}   

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if(g_dm[client])
	{
		if(g_bhop[client] || !mapazo)
			buttons &= ~IN_USE;
		
		//buttons &= ~IN_ATTACK2;
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
    if (g_dm[shooter] != g_dm[client]) {
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




public Action SoundHook(int clients[64], &numClients, String:sound[PLATFORM_MAX_PATH], &Ent, &channel, &Float:volume, &level, &pitch, &flags)
{
	if(IsValidClient(Ent) && g_bhop[Ent]) return Plugin_Stop;
	 
	return Plugin_Continue;
}