#!/usr/bin/env python3

import argparse
parser = argparse.ArgumentParser()
parser.add_argument("--release-version", default="0.003",
                    help="Version number included in the Makefile header")
parser.add_argument("--makefile", default="Makefile",
                    help="Filename to create")
parser.add_argument("--database-config",
                    help="Config file with details of the database connection to use",
                    default="db.conf")
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

outfile = open(args.makefile, 'w')

logging.info(f"Finding downloaded bible versions")
read_cursor.execute(
    "select version_id, version_name, language from bible_versions where version_worth_fetching and version_id not in (select version_id from incomplete_versions)"
)
iterator = read_cursor
if args.verbose:
    import tqdm
    iterator = tqdm.tqdm(read_cursor, total=read_cursor.rowcount)

logging.info("Pre-processing version information")
dependencies = []
extractors = []

segmentations =  {
    'unigram': "",
    'bigram': "--ngram-max-tokens 2",
    'trigram': "--ngram-max-tokens 3",
    'uni_token': "--tokengrams",
    'bi_token': "--ngram-max-tokens 2 --tokengrams",
    'tri_token': "--ngram-max-tokens 3 --tokengrams",
    'quad_token': "--ngram-max-tokens 4 --tokengrams"
}

for version_id, version_name, language in iterator:
    if version_name.strip() == '':
        continue
    underscore_name = version_name.replace(' ','_')
    for segmentation in segmentations:
        pathname = f"extracts/by-language/{language}/{segmentation}/{underscore_name}.csv"
        translation_record_pathname = f"translations/by-language/{language}/{segmentation}/{underscore_name}.csv"
        dependencies.append(pathname)
        extractors.append(f"""
{pathname}: extract_vocab.py db.conf
	python3 extract_vocab.py --word-pairs-output $@ --translation {translation_record_pathname} --bible '{version_name}' --verbose {segmentations[segmentation]} 
""")

logging.info(f"Writing {args.makefile}")
outfile.write(f"""RELEASE_VERSION={args.release_version}

release/thousand-language-by-language-$(RELEASE_VERSION).zip: {' '.join(dependencies)}
	zip -9 $@ $^
""")

for extractor in extractors:
    outfile.write(extractor)
    outfile.write('\n')

outfile.write("""
enrichment/language-codes.csv:
	curl -H "Accept: text/csv" -o $@ 'https://query.wikidata.org/sparql?query=SELECT%20%3Fitem%20%3FitemLabel%20%3FISO_639_3_code%20%0AWHERE%20%7B%20%0A%20%20SERVICE%20wikibase%3Alabel%20%7B%20bd%3AserviceParam%20wikibase%3Alanguage%20%22%5BAUTO_LANGUAGE%5D%2Cen%22.%20%7D%0A%20%20%7B%20%3Fitem%20wdt%3AP220%20%3FISO_639_3_code.%20%7D%0A%7D%0A'

db.conf:
	echo "You need to configure a database connection to do this step"
""")

outfile.close()
logging.info("Program complete")
