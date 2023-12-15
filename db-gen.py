import csv, sqlite3, pycountry, os

if os.path.exists("ip2geo.sq3"):
    os.remove("ip2geo.sq3")

con = sqlite3.connect("ip2geo.sq3")
cur = con.cursor()
cur.execute("CREATE TABLE geolite2 (ip_start_0 INT, ip_start_1 INT, ip_start_2 INT, ip_start_3 INT, ip_end_0 INT, ip_end_1 INT, ip_end_2 INT, ip_end_3 INT, country_code TEXT, country_name TEXT, state TEXT, region TEXT, city TEXT, post_code TEXT, latitude NUMERIC, longitude NUMERIC, timezone TEXT);")

with open('geolite2-city-ipv4.csv','r') as fin:
    dr = csv.DictReader(fin, fieldnames=["ip_start", "ip_end", "country_code", "state", "region", "city", "post_code", "latitude", "longitude", "timezone"])
    to_db = [(i['ip_start'].split(".")[0], i['ip_start'].split(".")[1], i['ip_start'].split(".")[2], i['ip_start'].split(".")[3], i['ip_end'].split(".")[0], i['ip_end'].split(".")[1], i['ip_end'].split(".")[2], i['ip_end'].split(".")[3], i['country_code'], pycountry.countries.get(alpha_2=i['country_code']).name if pycountry.countries.get(alpha_2=i['country_code']) != None else '', i['state'], i['region'], i['city'], i['post_code'], i['latitude'], i['longitude'], i['timezone']) for i in dr]

cur.executemany("INSERT INTO geolite2 (ip_start_0, ip_start_1, ip_start_2, ip_start_3, ip_end_0, ip_end_1, ip_end_2, ip_end_3, country_code, country_name, state, region, city, post_code, latitude, longitude, timezone) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);", to_db)
# country name overrides
cur.execute("UPDATE geolite2 SET country_name = 'Kosovo' WHERE country_code = 'XK';")
cur.execute("UPDATE geolite2 SET country_name = 'South Korea' WHERE country_code = 'KR';")

con.commit()
con.close()