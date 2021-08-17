#!/usr/bin/env python3

import argparse
parser = argparse.ArgumentParser()
parser.add_argument("--database-config",
                    help="Config file with details of the database connection to use",
                    default="db.conf")
parser.add_argument("--languages", help="Comma separated list of iso language codes to process; default is all")
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

logging.info(f"Counting versions in different languages")
language_version_lookup = {}

if args.languages:
    language_list = args.languages.lower().split(',')
    for language in language_list:
        logging.info(f"Counting {language} versions")
        read_cursor.execute("select count(*) from bible_versions where language = %s", [language])
        row = read_cursor.fetchone()
        if row is None or row[0] == 0:
            sys.exit(f"Language {language} doesn't exist")
        language_version_lookup[language] = row[0]
else:
    read_cursor.execute("select language, count(*) from bible_versions group by language")
    for row in read_cursor:
        language = row[0]
        number_of_versions = row[1]
        language_version_lookup[language] = number_of_versions
    logging.info(f"{len(language_version_lookup)} languages found")

languages_to_process = language_version_lookup.keys()
if args.progress:
    import tqdm
    languages_to_process = tqdm.tqdm(languages_to_process)


read_cursor.execute("select distinct lemma, gender, noun_case, noun_number from common_nouns")
all_noun_lemmae = [{'lemma': row[0], 'gender': row[1], 'noun_case': row[2], 'noun_number': row[3]} for row in read_cursor]

for language in languages_to_process:
    if args.progress:
        languages_to_process.set_description(language)
    logging.info(f"Processing {language}")
    read_cursor.execute("select distinct version_id from bible_versions where language = %s", [language])
    bible_version_ids = [row[0] for row in read_cursor]
    read_cursor.execute("""
     select distinct tokenisation_method_id
       from bible_versions join vocabulary_extractions on (version_id = bible_version_id)
      where language = %s""",
                        [language])
    tokenisation_methods = [row[0] for row in read_cursor]
    logging.info(f"Available tokenisation methods: {tokenisation_methods}")
    sql = f"""create table if not exists vocab_lists.{language}_noun_extracts (
extract_reference_id serial primary key,
lemma varchar,
tokenisation_method_id varchar,
gender varchar,
noun_case varchar,
noun_number varchar,
most_common_translation varchar,
cumulative_confidence float,
"""
    sql += ",\n".join([f"version_{version_id}_translation varchar" for version_id in bible_version_ids])
    sql += ");"
    logging.info(f"Creating table vocab_lists.{language}_noun_extracts")
    write_cursor.execute(sql)
    sql = f"create unique index if not exists {language}_noun_extracts_aux_idx on vocab_lists.{language}_noun_extracts(lemma, tokenisation_method_id, gender, noun_case, noun_number)";
    write_cursor.execute(sql)
    conn.commit()
    
    for tokenisation in tokenisation_methods:
        logging.info(f"Working on {tokenisation=} for {language=}")
        for lemma_group in all_noun_lemmae:
            #logging.info(f"Looking at translations of {lemma_group['lemma']} ({lemma_group['gender']},{lemma_group['noun_case']},{lemma_group['noun_number']}) as {tokenisation}")
            lemma_is_not_translated = True
            translation_alternatives = {}
            translation_confidences = {}
            update_fragment_cols = []
            update_fragment_vals = []            
            for version_id in bible_version_ids:
                read_cursor.execute("""select translation_in_target_language, confidence from vocabulary_extractions
where confidence > 1 
  and bible_version_id = %s 
  and tokenisation_method_id = %s
  and lemma = %s
  and gender = %s
  and noun_case = %s
  and noun_number = %s""", [version_id, tokenisation, lemma_group['lemma'],
                                    lemma_group['gender'], lemma_group['noun_case'],
                                    lemma_group['noun_number']])
                # should only be one row of output, but we really like our for loops
                for row in read_cursor:
                    lemma_is_not_translated = False
                    trans, confidence = row
                    if trans not in translation_alternatives:
                        translation_alternatives[trans] = 0
                        translation_confidences[trans] = 1
                    translation_alternatives[trans] += 1
                    if confidence is None:
                        logging.critical(f"{confidence=} for {lemma_group['lemma']=} in bible {version_id=}")
                    translation_confidences[trans] *= confidence
                    update_fragment_cols.append(f"version_{version_id}_translation")
                    update_fragment_vals.append(trans)
            # OK, we've seen all versions. Let's see if we have some winners.
            if lemma_is_not_translated:
                continue
            most_popular_translation = None
            most_popular_translation_count = 0
            tie_for_first = False
            for trans, trans_count in translation_alternatives.items():
                if trans_count == most_popular_translation_count:
                    tie_for_first = True
                if trans_count > most_popular_translation_count:
                    most_popular_translation = trans
                    most_popular_translation_count = trans_count
                    tie_for_first = False
            # Let's upsert the row
            read_cursor.execute(f"""
select extract_reference_id from vocab_lists.{language}_noun_extracts
where tokenisation_method_id = %s
  and lemma = %s
  and gender = %s
  and noun_case = %s
  and noun_number = %s""", [tokenisation, lemma_group['lemma'],
                                    lemma_group['gender'], lemma_group['noun_case'],
                                    lemma_group['noun_number']])
            row = read_cursor.fetchone()
            if row is None:
                repeat_count = 5 + len(update_fragment_cols)
                sql = f"insert into vocab_lists.{language}_noun_extracts (tokenisation_method_id, lemma, gender, noun_case, noun_number, "
                if not(tie_for_first):
                    sql += "most_common_translation, cumulative_confidence, "
                    repeat_count += 2
                sql += ", ".join(update_fragment_cols)
                sql += ') values ('
                sql += ', '.join(['%s'] * repeat_count)
                sql += ')'
                sql_values = [tokenisation, lemma_group['lemma'],
                                    lemma_group['gender'], lemma_group['noun_case'],
                                    lemma_group['noun_number']]
                if not(tie_for_first):
                    sql_values += [most_popular_translation, translation_confidences[most_popular_translation]]
                sql_values += update_fragment_vals
                write_cursor.execute(sql, sql_values)
            else:
                if not tie_for_first:
                    write_cursor.execute(f"update vocab_lists.{language}_noun_extracts set most_common_translation = %s, cumulative_confidence = %s where extract_reference_id = %s",
                                         [most_popular_translation, translation_confidences[most_popular_translation], row[0]])
                sql = f"update vocab_lists.{language}_noun_extracts set "
                sql += ", ".join([f"{x} = %s" for x in update_fragment_cols])
                sql += " where extract_reference_id = %s"
                sql_values = update_fragment_vals + [row[0]]
                write_cursor.execute(sql, sql_values)
    
    conn.commit()
    
