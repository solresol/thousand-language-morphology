#!/usr/bin/env python3

import argparse
import configparser
import psycopg2
import psycopg2.extras
import json
import requests

parser = argparse.ArgumentParser()
parser.add_argument("--pgconf", default="db.conf",
                    help="Database configuration file: .ini format, with a section called database and fields dbname, user, password, host")

args = parser.parse_args()

config = configparser.ConfigParser()
config.read(args.pgconf)
dbname = config['database']['dbname']
user = config['database']['user']
password = config['database']['password']
host = config['database']['host']
port = config['database']['port']
conn = psycopg2.connect(f'dbname={dbname} user={user} password={password} host={host} port={port}')
read_cursor = conn.cursor()
write_cursor = conn.cursor()

while True:
    fetched_something = False
    read_cursor.execute("select entity from wikidata_iso639_codes where entity not in (select entity from wikidata_content) union select entity from wikidata_containment where entity not in (select entity from wikidata_content)")
    for row in read_cursor:
        entity = row[0]
        print(entity)
        r = requests.get("https://wikidata.org/entity/" + entity + '.json')
        if r.status_code == 200:
            write_cursor.execute("insert into wikidata_content (entity, wikidata_content) values (%s, %s)", [entity, psycopg2.extras.Json(r.json())])
            conn.commit()
            fetched_something = True
    if not fetched_something:
        break
                                 
