#!/usr/bin/env python3

# Populate vocabulary_pairing_tests

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
parser.add_argument("--tokenisation-method",
                    choices=['unigram', 'bigram', 'trigram',
                             'uni_token', 'bi_token', 'tri_token', 'quad_token'],
                    default='unigram'
                    )
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
import scipy.stats
import math
import collections
import os
import sys
import tqdm

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

read_cursor.execute("select version_id from bible_versions where version_worth_fetching")
bible_versions = [ x[0] for x in read_cursor ]

iterator = bible_versions
if args.progress:
    iterator = tqdm.tqdm(bible_versions)

for v1 in iterator:
    logging.info(f"Working on bible version_id = {v1}")
    read_cursor.execute("select confidence from vocabulary_extractions where bible_version_id = %s and tokenisation_method_id = %s and confidence is not null",
                        [v1, args.tokenisation_method])
    confidences = [x[0] for x in read_cursor if not math.isnan(x[0]) ]
    if len(confidences) < 5:
        logging.error(f"Cannot work with bible version {v1}; insufficient vocabulary extracted")
        continue
    read_cursor.execute("select bible_version_id2 from vocabulary_pairing_tests where bible_version_id1 = %s and tokenisation_method_id = %s",
                        [v1, args.tokenisation_method])
    existing_pairings = set([x[0] for x in read_cursor])
    for v2 in bible_versions:
        if v2 in existing_pairings:
            continue
        read_cursor.execute("select confidence from vocabulary_extractions where bible_version_id = %s and tokenisation_method_id = %s and confidence is not null",
                            [v2, args.tokenisation_method])
        v2_confidences = [x[0] for x in read_cursor if not math.isnan(x[0])]
        if len(v2_confidences) < 5:
            continue
        u, p = scipy.stats.mannwhitneyu(confidences, v2_confidences)
        logging.info(f"Statistic for {v1} vs {v2} is {u}, pvalue={p}")

        read_cursor.execute("""select
         corr(v1.log_confidence, v2.log_confidence) as log_confidence_correlation,
  	 corr(v1.confidence, v2.confidence) as confidence_correlation,
 	 corr(v1.confidence_rank, v2.confidence_rank) as confidence_spearman_correlation
         from vocabulary_extraction_ranks as v1 join vocabulary_extraction_ranks as v2
             using (lemma, gender, noun_case, noun_number, tokenisation_method_id)
         where v1.bible_version_id = %s and v2.bible_version_id = %s 
           and tokenisation_method_id = %s""",
                            [v1, v2, args.tokenisation_method])
        row = read_cursor.fetchone()
        log_confidence_correlation = row[0]
        confidence_correlation = row[1]
        confidence_spearman = row[2]
        
        write_cursor.execute("insert into vocabulary_pairing_tests (tokenisation_method_id, bible_version_id1, bible_version_id2, mann_whitney_statistic, mann_whitney_pvalue, confidence_correlation, log_confidence_correlation, confidence_spearman_correlation) values (%s, %s, %s, %s, %s, %s, %s, %s)", [
            args.tokenisation_method,
            v1,
            v2,
            u,
            p,
            confidence_correlation,
            log_confidence_correlation,
            confidence_spearman
        ])
    conn.commit()


logging.info("Save completed")
