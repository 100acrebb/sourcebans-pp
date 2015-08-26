// *************************************************************************
//  This file is part of SourceBans: Reloaded.
//
//  Copyright (C) 2014-2015 Sarabveer Singh <sarabveer@sarabveer.me>
//  
//  SourceBans: Reloaded is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Affero General Public License as published by
//  the Free Software Foundation, per version 3 of the License.
//  
//  SourceBans: Reloaded is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//  
//  You should have received a copy of the GNU Affero General Public License
//  along with SourceBans: Reloaded. If not, see <http://www.gnu.org/licenses/>.
//
//  This file incorporates work covered by the following copyright(s): 
//
//   SourceBans: Family Sharing Bans
//   Copyright (C) 2014 SourceBans Team - Part of GameConnect
//   Licensed under GNU GPL version 3, or later.
//   Page: <https://forums.alliedmods.net/showpost.php?p=2139880&postcount=7>  
//
// *************************************************************************

#pragma semicolon 1
#include <sourcemod>
#include <SteamWorks>
#include <sourcebans>

#define PLUGIN_VERSION "1.6.0"

public Plugin:myinfo =
{
	name        = "SourceBans: Family Sharing Bans",
	author      = "Peace-Maker, Sarabveer(VEER™)",
	description = "Enforce bans over shared accounts",
	version     = PLUGIN_VERSION,
	url         = "http://www.sourcebans.net"
};

public SW_OnValidateClient(OwnerId, ClientID)
{
	if(OwnerId != ClientID)
	{
		new client = GetClientIndexFromAccountID(ClientID);
		if(client <= 0)
			return;
		
		new String:sIdentity[40];
		SteamNumberToAuthID(OwnerId, sIdentity, sizeof(sIdentity));
		
		if(!SB_Connect())
			return;
	
		decl String:sQuery[1024];
		Format(sQuery, sizeof(sQuery), "SELECT 1 \
										FROM   {{bans}} \
										WHERE  type = 0 AND authid REGEXP '^STEAM_[0-9]:%s$' \
										  AND  (length = 0 OR created + length > UNIX_TIMESTAMP()) \
										  AND  RemovedBy IS NULL", sIdentity[8]);
										  
		new Handle:hPack = CreateDataPack();
		WritePackString(hPack, sIdentity);
		WritePackCell(hPack, GetClientSerial(client));
		ResetPack(hPack);
		
		SB_Query(Query_CheckBanCallback, sQuery, hPack, DBPrio_High);
	}
}

public Query_CheckBanCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	new String:sIdentity[40];
	ReadPackString(data, sIdentity, sizeof(sIdentity));
	new serial = ReadPackCell(data);
	CloseHandle(data);
	
	new client = GetClientFromSerial(serial);
	if(!client)
		return;
	
	if(hndl == INVALID_HANDLE)
	{
		LogError("Failed to check the ban for %s: %s", sIdentity, error);
		return;
	}
	
	if(!SQL_FetchRow(hndl))
		return;
	
	LogMessage("%L is using banned family sharing account %s and was kicked.", client, sIdentity);
	KickClient(client, "Player is using banned family sharing account %s.", sIdentity);
}

stock GetClientIndexFromAccountID(accID)
{
	for(new i=1;i<=MaxClients;i++)
	{
		if(IsClientConnected(i) && !IsFakeClient(i) && GetSteamAccountID(i) == accID)
			return i;
	}
	return -1;
}

// Thanks KyleS
stock AuthIDToSteamNumber(const String:sAuth[])
{
	return ((StringToInt(sAuth[10]) << 1) | StringToInt(sAuth[8]));
}

stock SteamNumberToAuthID(AuthID, String:sAuth[], len, universe = 0)
{
	return FormatEx(sAuth, len, "STEAM_%u:%u:%u", universe, (AuthID & 1), (AuthID >> 1));
}

stock NormalizeSteamID(String:sAuth[], len)
{
	return SteamNumberToAuthID(AuthIDToSteamNumber(sAuth), sAuth, len);
}