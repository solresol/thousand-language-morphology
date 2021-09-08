#!/usr/bin/env python3

import argparse
parser = argparse.ArgumentParser()
parser.add_argument("--database-config",
                    help="Config file with details of the database connection to use",
                    default="db.conf")
parser.add_argument("--languages", help="Comma separated list of iso language codes to process; default is all")
parser.add_argument("--minimum-independent-translations", default=1, type=int,
                    help="Only extract languages where there is at least this count of bibles in that language")
parser.add_argument("--verbose", action="store_true",
                    help="a few debugging messages")
parser.add_argument("--progress", action="store_true")

args = parser.parse_args()

import logging
import configparser
import psycopg2

if args.verbose:
    logging.basicConfig(
        format='%(asctime)s.%(msecs)03d %(levelname)-8s %(message)s',
        level=logging.INFO,
        datefmt='%Y-%m-%d %H:%M:%S')
    logging.info("Starting")
    args.progress = False


config = configparser.ConfigParser()
config.read(args.database_config)
dbname = config['database']['dbname']
user = config['database']['user']
password = config['database']['password']
host = config['database']['host']
port = config['database']['port']
logging.info("Connecting to database")
conn = psycopg2.connect(f'dbname={dbname} user={user} password={password} host={host} port={port}')
read_cursor = conn.cursor()
write_cursor = conn.cursor()

if args.languages is not None:
    langs = [x.strip() for x in args.languages.split(',')]
    placeholders = ",".join(["?" for x in langs])
    placeholder_text = 'and language in (' + placeholders + ')'
else:
    langs = []
    placeholder_text = ''

if args.minimum_independent_translations > 1:
    min_constraint = f' having count(*) >= {args.minimum_independent_translations}'
else:
    min_constraint = ''
    
sql = f"select language from bible_versions where version_worth_fetching {placeholder_text} group by language {min_constraint}"
read_cursor.execute(sql, langs)

languages = [x[0] for x in read_cursor]

for language in languages:
    sql = f"""select 
               sing.most_common_translation as singular,
               plur.most_common_translation as plural
          from vocab_lists.{language}_noun_extracts as sing 
          join vocab_lists.{language}_noun_extracts as plur 
         using (lemma, gender,noun_case)
         where sing.noun_number = 'singular'
           and plur.noun_number = 'plural'"""
    read_cursor.execute(sql)
    for row in read_cursor:
        print(row[0], row[1])
