#if defined _ip2geo_included
#endinput
#endif
#define _ip2geo_included

public SharedPlugin __pl_ip2geo =
{
	name = "ip2geo",
	file = "ip2geo.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_ip2geo_SetNTVOptional()
{
	MarkNativeAsOptional("IP2Geo");
	MarkNativeAsOptional("GetClientGeoCountry");
	MarkNativeAsOptional("GetClientGeoCountryName");
	MarkNativeAsOptional("GetClientGeoState");
	MarkNativeAsOptional("GetClientGeoCity");
}
#endif

typedef IP2GeoCallback = function void (const char[] sCountry, const char[] sCountryName, const char[] sState, const char[] sCity, int iData);

/**
* Lookup an IP address in the database.
*
* @param hFunc			An IP2GeoCallback function.
* @param sIP			An IP adress to lookup.
* @param iData			Optional tracking value.
* @return        		Returns true if a lookup was succesfully started.
*/
native bool IP2Geo(IP2GeoCallback hFunc, const char[] sIP, int iData = 0);

/**
* Get geolocation country for a client.
*
* @param iClient		A client index.
* @param sCountry		Buffer to store country code.
* @param iLen			Buffer length.
* @return        		Returns true if a record was found in memory.
*/
native bool GetClientGeoCountry(int iClient, char[] sCountry, int iLen);

/**
* Get geolocation country name for a client.
*
* @param iClient		A client index.
* @param sCountryName	Buffer to store country name.
* @param iLen			Buffer length.
* @return        		Returns true if a record was found in memory.
*/
native bool GetClientGeoCountryName(int iClient, char[] sCountryName, int iLen);

/**
* Get geolocation state/region for a client.
*
* @param iClient		A client index.
* @param sState		Buffer to store state.
* @param iLen			Buffer length.
* @return        		Returns true if a record was found in memory.
*/
native bool GetClientGeoState(int iClient, char[] sState, int iLen);

/**
* Get geolocation city for a client.
*
* @param iClient		A client index.
* @param sCity			Buffer to store city.
* @param iLen			Buffer length.
* @return        		Returns true if a record was found in memory.
*/
native bool GetClientGeoCity(int iClient, char[] sCity, int iLen);