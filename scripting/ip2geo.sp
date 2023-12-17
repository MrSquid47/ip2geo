#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "MrSquid"
#define PLUGIN_VERSION "0.0.1"

#include <sourcemod>
#include <sdktools>

#include <ip2geo>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "IP2Geo", 
	author = PLUGIN_AUTHOR, 
	description = "IP address to geolocation lookups", 
	version = PLUGIN_VERSION, 
	url = "https://github.com/MrSquid47/ip2geo"
};

Database g_hDatabase;

enum struct IP2GeoCallbackData {
	bool bActive;
	PrivateForward hFunc;
	int iData;
}
IP2GeoCallbackData g_eIP2GeoCallbackData[128];

enum struct ClientGeo {
	bool bLoaded;
	char sCountry[3];
	char sCountryName[64];
	char sState[64];
	char sCity[64];
}
ClientGeo g_eClientGeo[MAXPLAYERS + 1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	if (!FileExists("addons/sourcemod/data/sqlite/ip2geo.sq3")) {
		Format(error, err_max, "Could not find ip2geo.sq3");
		return APLRes_Failure;
	}
	
	char sError[128];
	KeyValues kv = CreateKeyValues("ip2geo", "driver", "sqlite");
	KvSetString(kv, "database", "ip2geo");
	g_hDatabase = SQL_ConnectCustom(kv, sError, sizeof(sError), true);
	if (!StrEqual(sError, "") || g_hDatabase == INVALID_HANDLE) {
		Format(error, err_max, "Failed to open ip2geo.sq3: %s", sError);
		return APLRes_Failure;
	}
	
	CreateNative("IP2Geo", Native_IP2Geo);
	CreateNative("GetClientGeoCountry", Native_GetClientGeoCountry);
	CreateNative("GetClientGeoCountryName", Native_GetClientGeoCountryName);
	CreateNative("GetClientGeoState", Native_GetClientGeoState);
	CreateNative("GetClientGeoCity", Native_GetClientGeoCity);
	
	RegPluginLibrary("ip2geo");
	return APLRes_Success;
}

public void OnPluginStart() {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i)) {
			DB_ClientGeo(i);
		}
	}
}

public void OnClientConnected(int iClient) {
	if (!IsFakeClient(iClient))
		DB_ClientGeo(iClient);
}

public void OnClientDisconnect(int iClient) {
	g_eClientGeo[iClient].bLoaded = false;
	strcopy(g_eClientGeo[iClient].sCountry, 3, "");
	strcopy(g_eClientGeo[iClient].sCountryName, 64, "");
	strcopy(g_eClientGeo[iClient].sState, 64, "");
	strcopy(g_eClientGeo[iClient].sCity, 64, "");
}

// Database helpers

public void DB_ClientGeo(int iClient) {
	if (!g_hDatabase) {
		return;
	}
	
	char sIP[32];
	GetClientIP(iClient, sIP, sizeof(sIP));
	char sQuery[512];
	IPToQuery(sIP, sQuery, sizeof(sQuery));
	g_hDatabase.Query(CB_SQLQueryCallback_ClientGeo, sQuery, GetClientSerial(iClient));
}

public void DB_IP2Geo(const char[] sIP, int iCBIndex) {
	if (!g_hDatabase) {
		return;
	}
	
	char sQuery[512];
	IPToQuery(sIP, sQuery, sizeof(sQuery));
	g_hDatabase.Query(CB_SQLQueryCallback_IP2Geo, sQuery, iCBIndex);
}

// Database callbacks

public void CB_SQLQueryCallback_ClientGeo(Database hDatabase, DBResultSet hResults, const char[] sError, any aData) {
	int iClient = GetClientFromSerial(aData);
	
	if (!hResults) {
		LogError(sError);
		return;
	}
	
	if (iClient && hResults.FetchRow()) {
		hResults.FetchString(0, g_eClientGeo[iClient].sCountry, 3);
		hResults.FetchString(1, g_eClientGeo[iClient].sCountryName, 64);
		hResults.FetchString(2, g_eClientGeo[iClient].sState, 64);
		hResults.FetchString(3, g_eClientGeo[iClient].sCity, 64);
		g_eClientGeo[iClient].bLoaded = true;
	}
}

public void CB_SQLQueryCallback_IP2Geo(Database hDatabase, DBResultSet hResults, const char[] sError, any aData) {
	int iCBIndex = aData;
	
	char sCountry[3], sCountryName[64], sState[64], sCity[64];
	if (hResults) {
		if (hResults.FetchRow()) {
			hResults.FetchString(0, sCountry, 3);
			hResults.FetchString(1, sCountryName, 64);
			hResults.FetchString(2, sState, 64);
			hResults.FetchString(3, sCity, 64);
		}
	}
	
	g_eIP2GeoCallbackData[iCBIndex].bActive = false;
	
	Call_StartForward(g_eIP2GeoCallbackData[iCBIndex].hFunc);
	Call_PushString(sCountry);
	Call_PushString(sCountryName);
	Call_PushString(sState);
	Call_PushString(sCity);
	Call_PushCell(g_eIP2GeoCallbackData[iCBIndex].iData);
	Call_Finish();
	CloseHandle(g_eIP2GeoCallbackData[iCBIndex].hFunc);
}

// Helpers

void IPToQuery(const char[] sIP, char[] sQuery, int maxlen) {
	char sTemp[32], sSearch[16];
	strcopy(sTemp, sizeof(sTemp), sIP);
	int iOc1, iOc2, iOc3, iOc4;
	
	if (SplitString(sTemp, ".", sSearch, sizeof(sSearch)) == -1)
		return;
	iOc1 = StringToInt(sSearch);
	Format(sSearch, sizeof(sSearch), "%s.", sSearch);
	ReplaceStringEx(sTemp, sizeof(sTemp), sSearch, "");
	
	if (SplitString(sTemp, ".", sSearch, sizeof(sSearch)) == -1)
		return;
	iOc2 = StringToInt(sSearch);
	Format(sSearch, sizeof(sSearch), "%s.", sSearch);
	ReplaceStringEx(sTemp, sizeof(sTemp), sSearch, "");
	
	if (SplitString(sTemp, ".", sSearch, sizeof(sSearch)) == -1)
		return;
	iOc3 = StringToInt(sSearch);
	Format(sSearch, sizeof(sSearch), "%s.", sSearch);
	ReplaceStringEx(sTemp, sizeof(sTemp), sSearch, "");
	
	if (strlen(sTemp) <= 0)
		return;
	iOc4 = StringToInt(sTemp);
	
	Format(sQuery, maxlen, "SELECT b.string AS country_code,c.string AS country_name,d.string AS state,f.string AS city from geolite2 a join strings b on a.country_code = b.id join strings c on a.country_name = c.id join strings d on a.state = d.id join strings f on a.city = f.id WHERE ip_start_0 <= %i AND ip_start_1 <= %i AND ip_start_2 <= %i AND ip_start_3 <= %i AND ip_end_0 >= %i AND ip_end_1 >= %i AND ip_end_2 >= %i AND ip_end_3 >= %i;", iOc1, iOc2, iOc3, iOc4, iOc1, iOc2, iOc3, iOc4);
}

// Natives

any Native_IP2Geo(Handle plugin, int numParams) {
	int iCBIndex = -1;
	for (int i = 0; i < 128; i++) {
		if (g_eIP2GeoCallbackData[i].bActive == false) {
			iCBIndex = i;
			break;
		}
	}
	if (iCBIndex == -1) {
		return false;
	}
	
	g_eIP2GeoCallbackData[iCBIndex].bActive = true;
	g_eIP2GeoCallbackData[iCBIndex].hFunc = new PrivateForward(ET_Ignore, Param_String, Param_String, Param_String, Param_String, Param_Cell);
	g_eIP2GeoCallbackData[iCBIndex].hFunc.AddFunction(plugin, GetNativeFunction(1));
	g_eIP2GeoCallbackData[iCBIndex].iData = GetNativeCell(3);
	char sIP[32];
	GetNativeString(2, sIP, sizeof(sIP));
	
	DB_IP2Geo(sIP, iCBIndex);
	
	return true;
}

any Native_GetClientGeoCountry(Handle plugin, int numParams) {
	int iClient = GetNativeCell(1);
	
	if (!g_eClientGeo[iClient].bLoaded)
		return false;
	
	int iLen = GetNativeCell(3);
	if (iLen > 0)
	{
		char[] sCountry = new char[iLen];
		GetNativeString(2, sCountry, iLen);
		strcopy(sCountry, iLen, g_eClientGeo[iClient].sCountry);
		SetNativeString(2, sCountry, iLen);
	}
	
	return true;
}

any Native_GetClientGeoCountryName(Handle plugin, int numParams) {
	int iClient = GetNativeCell(1);
	
	if (!g_eClientGeo[iClient].bLoaded)
		return false;
	
	int iLen = GetNativeCell(3);
	if (iLen > 0)
	{
		char[] sCountryName = new char[iLen];
		GetNativeString(2, sCountryName, iLen);
		strcopy(sCountryName, iLen, g_eClientGeo[iClient].sCountryName);
		SetNativeString(2, sCountryName, iLen);
	}
	
	return true;
}

any Native_GetClientGeoState(Handle plugin, int numParams) {
	int iClient = GetNativeCell(1);
	
	if (!g_eClientGeo[iClient].bLoaded)
		return false;
	
	int iLen = GetNativeCell(3);
	if (iLen > 0)
	{
		char[] sState = new char[iLen + 1];
		GetNativeString(2, sState, iLen + 1);
		strcopy(sState, iLen + 1, g_eClientGeo[iClient].sState);
		SetNativeString(2, sState, iLen + 1);
	}
	
	return true;
}

any Native_GetClientGeoCity(Handle plugin, int numParams) {
	int iClient = GetNativeCell(1);
	
	if (!g_eClientGeo[iClient].bLoaded)
		return false;
	
	int iLen = GetNativeCell(3);
	if (iLen > 0)
	{
		char[] sCity = new char[iLen + 1];
		GetNativeString(2, sCity, iLen + 1);
		strcopy(sCity, iLen + 1, g_eClientGeo[iClient].sCity);
		SetNativeString(2, sCity, iLen + 1);
	}
	
	return true;
} 