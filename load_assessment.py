#!/usr/bin/env python3

import argparse
parser = argparse.ArgumentParser()
parser.add_argument("--input-file", required=True, help="The XLSX file with the human assessment")
parser.add_argument("--language", required=True, help="ISO-639-3 code for the language that is being assessed")
parser.add_argument("--database-config",
                    help="Config file with details of the database connection to use",
                    default="db.conf")
parser.add_argument("--verbose",
                    action="store_true",
                    help="a few debugging messages")
args = parser.parse_args()

import logging
import pandas
import psycopg2
import configparser
import sys

if args.verbose:
    logging.basicConfig(
        format='%(asctime)s.%(msecs)03d %(levelname)-8s %(message)s',
        level=logging.INFO,
        datefmt='%Y-%m-%d %H:%M:%S')
    logging.info("Starting")

    
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

excel = pandas.read_excel(args.input_file)

# I could sanity check by looking for version_NNNN_translation, and confirming that the language
# is right.

original_columns = ['lemma', 'gender', 'noun_case', 'noun_number', 'most_common_translation']
for colname in original_columns:
    if colname not in excel.columns:
        sys.exit(f"Missing {colname} from columns in {args.input_file}. This suggests that the vocab file has been mangled to the point of uselessness.")

yes_responses = ['yes', 'correct', 'right', 'yez', 'yed', 'tes', 'yes , spirit', 'yes, spirit']
no_responses = ['no', 'incorrect', 'wrong', 'not']
close_responses = ['close', 'clos']
valid_responses = {'': None}
for y in yes_responses:
    valid_responses[y] = 'correct'
for n in no_responses:
    valid_responses[n] = 'incorrect'
for c in close_responses:
    valid_responses[c] = 'close'
    

found_the_response_column = False
response_column = None
for colname in excel.columns:
    if colname in original_columns:
        continue
    focus = excel[excel[colname].notnull()][colname]
    if focus.dtype in ['int64', 'float64']:
        continue
    focus = focus.str.lower().str.strip()
    if focus.isin(valid_responses).all() and 10 * focus.shape[0] > excel.shape[0]:
        found_the_response_column = True
        response_column = colname
        break
    elif focus.isin(valid_responses).mean() > 0.8:
        print(colname, focus[~focus.isin(valid_responses)].value_counts())
        

if not(found_the_response_column):
    sys.exit("Sorry, can't find the answers")

for row_idx in excel[excel.most_common_translation.notnull()].index:
    lemma = excel.loc[row_idx].lemma
    gender = excel.loc[row_idx].gender
    noun_case = excel.loc[row_idx].noun_case
    noun_number = excel.loc[row_idx].noun_number
    target_language_assessed_word = excel.loc[row_idx].most_common_translation
    if target_language_assessed_word.strip() == '':
        continue
    assessment = valid_responses[excel.loc[row_idx][response_column].lower().strip()]
    if assessment is None:
        sys.exit(f"Shouldn't be possible to have an empty assessment (happened at row {row_idx}")
    write_cursor.execute("""
insert into human_scoring_of_vocab_lists (language, lemma, gender, noun_case, noun_number,
 target_language_assessed_word, assessment) values (%s,%s,%s,%s,%s,%s,%s)
""", [args.language, lemma, gender, noun_case, noun_number, target_language_assessed_word, assessment])

conn.commit()
