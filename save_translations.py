#!/usr/bin/env python3

# This program might be irrelevant now; extract_vocab.py stores things back into the
# database. This seems a better long-term solution.

import argparse

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
parser.add_argument("--extracts-directory",
                    help="where to find by-language/isocode/method",
                    default="translations")


args = parser.parse_args()

import logging
import psycopg2
import configparser
import glob
import sqlalchemy
import pandas
import nltk
import sklearn.feature_extraction
import scipy.stats
import math
import collections
import os
import sys

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

logging.info("Use sqlalchemy's create engine method to connect to the database")
engine = sqlalchemy.create_engine(
    f"postgresql+psycopg2://{user}:{password}@{host}:5432/{dbname}")

filenames = glob.glob(os.path.join(args.extracts_directory, 'by-language/*/*/*.csv'))

iterator = filenames
if args.progress:
    iterator = tqdm.tqdm(filenames)
                      
for filename in filenames:
    logging.info(f"Processing {filename}")
    directory_components = filename.split('/')
    bible_version_name, ext = os.path.splitext(directory_components[-1])
    bible_version_name = bible_version_name.replace('_', ' ')
    tokenisation_method = directory_components[-2]
    language_code = directory_components[-3]
    logging.info(f"Finding the version id for {language_code}/{bible_version_name}")
    read_cursor.execute(
        "select version_id from bible_versions where version_name = %s and language = %s",
        [bible_version_name, language_code]
    )
    row = read_cursor.fetchone()
    if row is None:
        sys.exit(f"Cannot find {language_code}/{bible_version_name}")
    version_id = row[0]
    logging.info(f"{language_code}/{bible_version_name} is version id = {version_id}")
    logging.info("Reading vocabulary")
    vocab = pandas.read_csv(filename, sep='\t')
    vocab['bible_version_id'] = version_id
    vocab['tokenisation_method_id'] = tokenisation_method
    vocab.rename(columns={'translation': 'translation_in_target_language'}, inplace=True)
    logging.info("Writing to database")
    vocab[['bible_version_id', 'tokenisation_method_id', 'lemma',
           'gender', 'noun_case', 'noun_number',
           'translation_in_target_language', 'binomial_test_p_score',
           'neg_log_binomial_test_p_score', 'appearances',
           'total_verses_in_translation',
           'probability_of_seeing_this_word', 'count_we_saw',
           'number_of_places_we_saw_the_lemma', 'confidence' ]
          ].to_sql('vocabulary_extractions', engine, if_exists='append', index=False)
    
        
logging.info("Save completed")
