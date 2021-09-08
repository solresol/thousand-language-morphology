#!/usr/bin/env python3

# Create the LEAFTOP (language extracted automatically from thousands of passages) database

import argparse
import shutil

parser = argparse.ArgumentParser()
parser.add_argument("--database-config",
                    help="Config file with details of the database connection to use",
                    default="db.conf")
parser.add_argument("--progress",
                    action="store_true",
                    help="show progress bar")
parser.add_argument("--verbose",
                    action="store_true",
                    help="a few debugging messages")
parser.add_argument("--output-directory",
                    help="where to put the output",
                    default="leaftop")
parser.add_argument("--readme",
                    default="README-leaftop.txt",
                    help="README-leaftop.txt location (which is copied as README.txt into the docs/ direcotyr")
parser.add_argument("--evaluations",
                    help="Directory of evaluation files",
                    default="leaftop-evaluations")
parser.add_argument("--skip-duplicate-language-rows",
                    action="store_true",
                    help="When there are two translations into the same language, do we repeat the language information?")

args = parser.parse_args()

import logging
import psycopg2
import configparser
import glob
import math
import collections
import os
import sys
import urllib.parse
import pandas
import sqlalchemy

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
language_cursor = conn.cursor()
read_cursor = conn.cursor()
write_cursor = conn.cursor()

logging.info("Use sqlalchemy's create engine method to connect to the database")
engine = sqlalchemy.create_engine(
    f"postgresql+psycopg2://{user}:{password}@{host}:5432/{dbname}")

logging.info("Getting language information")

language_cursor.execute("""
select language, language_name, entity, version_id, grouping_code, version_name
   from bible_versions left join bible_version_language_wikidata using (version_id)
  where version_worth_fetching
order by language_name, version_id""")

iterator = language_cursor
if args.progress:
    import tqdm
    iterator = tqdm.tqdm(iterator, total=language_cursor.rowcount)

os.makedirs(args.output_directory, exist_ok=True)
os.makedirs(os.path.join(args.output_directory, 'data'), exist_ok=True)
os.makedirs(os.path.join(args.output_directory, 'docs'), exist_ok=True)

language_index_records = []
languages_we_cannot_use = set()
previous_language = None
for language_row in iterator:
    this_language, language_name, entity, version_id, grouping_code, version_name = language_row
    logging.info(f"Processing {language_name} ({this_language})")
    if args.progress:
        iterator.set_description(language_name)
    if this_language in languages_we_cannot_use:
        continue
    if version_name.startswith('%'):
        version_name = urllib.parse.unquote_plus(version_name)
    logging.info(f"Fetching vocab_lists.{this_language}_noun_extracts")
    translations = pandas.read_sql(f"select * from vocab_lists.{this_language}_noun_extracts left join common_noun_baker_translations using(lemma) order by tokenisation_method_id, english_translation, lemma, noun_case, noun_number, gender", engine)
    if translations.shape[0] == 0:
        languages_we_cannot_use.update([this_language])
        continue
    # A language can use. Let's get the index sorted out.
    if this_language == previous_language and args.skip_duplicate_language_rows:
        language_index_records.append({
            'Leaftop Bible version Id': version_id,
            'bible.com/versions': grouping_code,
            'Likely name of bible': version_name
        })
        continue
    previous_language = this_language
    language_index_records.append({
        'ISO_639_3_Code': this_language,
        'Language Name': language_name,
        'Wikidata Entity': entity,
        'Leaftop Bible version Id': version_id,
        'bible.com/versions': grouping_code,
        'Likely name of bible': version_name
    })
    word_based = True
    alphabetic = True
    if translations[translations.tokenisation_method_id == 'unigram'].shape[0] < 100:
        word_based = False
    distinct_tokens_seen = translations[translations.tokenisation_method_id == 'uni_token'].most_common_translation.nunique()
    translated_lemmas = translations[translations.tokenisation_method_id == 'uni_token'].shape[0]
    if distinct_tokens_seen > (translated_lemmas / 2):
        alphabetic = False

    if word_based:
        best_output = 'unigram'
    elif alphabetic:
        best_output = 'quad_token'
    else:
        best_output = 'uni_token'

    read_cursor.execute("select count(*) from language_orthography where iso_639_3_code = %s", [this_language])
    row = read_cursor.fetchone()
    if row[0] == 0:
        write_cursor.execute("insert into language_orthography (iso_639_3_code, word_based, alphabetic, best_tokenisation_method) values (%s, %s, %s, %s)",
                             [this_language, word_based, alphabetic, best_output])
    else:
        write_cursor.execute("update language_orthography set word_based = %s, alphabetic = %s, best_tokenisation_method = %s where iso_639_3_code = %s",
                             [word_based, alphabetic, best_output, this_language])


    output_df = translations[translations.tokenisation_method_id == best_output]
    output_df.to_csv(
        os.path.join(args.output_directory,'data', f"{this_language}-vocab.csv"),
                     index=False)
    output_df.to_excel(
        os.path.join(args.output_directory,'data', f"{this_language}-vocab.xlsx"),
                     freeze_panes=(1,0),
                     index=False)

    meta_data_sentences = set()
    if entity is not None:
        read_cursor.execute("select country, indigenous_to_name, latitude, longitude, location_name from wikidata_geo where entity = %s", [entity])
        for georow in read_cursor:
            country, indig, lat, longi, locname = georow
            if lat is not None and longi is not None:
                sentence = f"{language_name} is found at lat,long= ({lat},{longi})"
                meta_data_sentences.update([sentence])
            said_something = False
            if indig is not None:
                said_something = True
                if country is not None:
                    sentence = f"{language_name} is indigenous to {indig}, {country}"
                else:
                    sentence = f"{language_name} is indigenous to {indig}"
                meta_data_sentences.update([sentence])
            if locname is not None:
                said_something = True
                if country is not None:
                    sentence = f"{language_name} is used in {locname}, {country}"
                else:
                    sentence = f"{language_name} is used in {locname}"
                meta_data_sentences.update([sentence])
            if not said_something and country is not None:
                sentence = f"{language_name} is a language in {country}"
                meta_data_sentences.update([sentence])
        with open(os.path.join(args.output_directory, 'data',  f"{this_language}-metadata.txt"),'w') as meta:
            meta.write(f"{language_name} appears to be {'' if alphabetic else 'non-'}alphabetic. It is {'' if word_based else 'not '} written with spaces between words. As a result, this extract was calculated using the {best_output} method.\n")
            meta.write('\n'.join(sorted(list(meta_data_sentences))))


    conn.commit()


language_index = pandas.DataFrame.from_records(language_index_records)
language_index.to_csv(
    os.path.join(args.output_directory, 'docs', 'language_index.csv'),
    index=False
    )

shutil.copyfile(args.readme,os.path.join(args.output_directory, 'docs', 'README.txt'))
shutil.copytree(args.evaluations,os.path.join(args.output_directory, 'evaluations'), dirs_exist_ok=True)
