import csv, sqlite3, pycountry, os, time, traceback, sys

if os.path.exists("ip2geo.sq3"):
    os.remove("ip2geo.sq3")

con = sqlite3.connect("ip2geo.sq3")
cur = con.cursor()
cur.execute("PRAGMA foreign_keys = ON;")
cur.execute("CREATE TABLE strings (id INTEGER, string TEXT UNIQUE, PRIMARY KEY(id AUTOINCREMENT));")
cur.execute("CREATE TABLE geolite2 (ip_start_0 INT, ip_start_1 INT, ip_start_2 INT, ip_start_3 INT, ip_end_0 INT, ip_end_1 INT, ip_end_2 INT, ip_end_3 INT, country_code INT, country_name INT, state INT, city INT, CONSTRAINT 'cns1' FOREIGN KEY('country_code') REFERENCES strings(id) ON DELETE CASCADE ON UPDATE CASCADE, CONSTRAINT 'cns2' FOREIGN KEY('country_name') REFERENCES strings(id) ON DELETE CASCADE ON UPDATE CASCADE, CONSTRAINT 'cns3' FOREIGN KEY('state') REFERENCES strings(id) ON DELETE CASCADE ON UPDATE CASCADE, CONSTRAINT 'cns5' FOREIGN KEY('city') REFERENCES strings(id) ON DELETE CASCADE ON UPDATE CASCADE);")
cur.execute("CREATE VIEW geolite2_view AS SELECT a.ip_start_0,a.ip_start_1,a.ip_start_2,a.ip_start_3,a.ip_end_0,a.ip_end_1,a.ip_end_2,a.ip_end_3,b.string AS country_code,c.string AS country_name,d.string AS state,f.string AS city from geolite2 a join strings b on a.country_code = b.id join strings c on a.country_name = c.id join strings d on a.state = d.id join strings f on a.city = f.id;")
#con.set_trace_callback(print)

num_lines = 0
try:
    with open("geolite2-city-ipv4.csv", "rb") as f:
        num_lines = sum(1 for _ in f)
except Exception as e:
    print("Could not open geolite2-city-ipv4.csv")
    os.exit(1)
print("Found " + str(num_lines) + " total records")

ins_count = 0
with open('geolite2-city-ipv4.csv','r') as fin:
    dr = csv.DictReader(fin, fieldnames=["ip_start", "ip_end", "country_code", "state", "region", "city", "post_code", "latitude", "longitude", "timezone"])
    cur.execute("INSERT INTO strings (string) VALUES('{str}');".format(str = ''))
    con.commit()
    for i in dr:
        country_code, country_name, state, city= 1, 1, 1, 1
        cname = ''
        if pycountry.countries.get(alpha_2=i['country_code']) != None:
            cname = pycountry.countries.get(alpha_2=i['country_code']).name
        if i['country_code'] == 'XK':
            cname = 'Kosovo'
        if i['country_code'] == 'KR':
            cname = 'South Korea'
        try:
            cur.execute("INSERT INTO strings (string) VALUES (?);", (i['country_code'],))
            country_code = cur.lastrowid
        except sqlite3.Error as er:
            cur.execute("SELECT id FROM strings WHERE string = ?;", (i['country_code'],))
            country_code = cur.fetchone()[0]
            pass
        try:
            cur.execute("INSERT INTO strings (string) VALUES (?);", (cname,))
            country_name = cur.lastrowid
        except sqlite3.Error as er:
            cur.execute("SELECT id FROM strings WHERE string = ?;", (cname,))
            country_name = cur.fetchone()[0]
            pass
        try:
            cur.execute("INSERT INTO strings (string) VALUES (?);", (i['state'],))
            state = cur.lastrowid
        except sqlite3.Error as er:
            cur.execute("SELECT id FROM strings WHERE string = ?;", (i['state'],))
            state = cur.fetchone()[0]
            pass
        try:
            cur.execute("INSERT INTO strings (string) VALUES (?);", (i['city'],))
            city = cur.lastrowid
        except sqlite3.Error as er:
            cur.execute("SELECT id FROM strings WHERE string = ?;", (i['city'],))
            city = cur.fetchone()[0]
            pass

        cur.execute("INSERT INTO geolite2 (ip_start_0, ip_start_1, ip_start_2, ip_start_3, ip_end_0, ip_end_1, ip_end_2, ip_end_3, country_code, country_name, state, city) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);", (i['ip_start'].split(".")[0], i['ip_start'].split(".")[1], i['ip_start'].split(".")[2], i['ip_start'].split(".")[3], i['ip_end'].split(".")[0], i['ip_end'].split(".")[1], i['ip_end'].split(".")[2], i['ip_end'].split(".")[3], country_code, country_name, state, city))
        ins_count = ins_count + 1
        if ins_count % 100 == 0:
            prog = (100.0 / num_lines) * ins_count
            print('Building database... [%d%%]\r'%prog, end="")
    print('Building database... [%d%%]\r'%100, end="")

con.commit()
con.close()

print("\n\nDone")