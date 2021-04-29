#!/usr/bin/env python3

# This program parses the content of git@github.com:OpenText-org/GNT_annotation_v1.0
# and extracts out words that appear in pairs (same lemma, different forms)
#
# It then stores the results into a postgresql database

import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--opentext-location", default="GNT_annotation_v1.0")
parser.add_argument("--database-config", default="db.conf")
parser.add_argument("--verbose", action="store_true")
args = parser.parse_args()

import pandas
import xml.etree.ElementTree as ET
import os
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
conn = psycopg2.connect(f'dbname={dbname} user={user} password={password} host={host} port={port}')
read_cursor = conn.cursor()
write_cursor = conn.cursor()


# Actually, this isn't all of them, but they were the only ones I encountered
greek_capitals = ['Α', 'Β', 'Γ', 'Δ', 'Ζ', 'Θ', 'Κ', 'Λ', 'Μ', 'Ν', 'Π', 'Σ', 'Τ',
       'Φ', 'Χ', 'Ἀ', 'Ἁ',  'Ἐ', 'Ἑ',  'Ἠ', 'Ἡ',  'Ἰ', 'Ἱ',  'Ὀ', 'Ῥ']

def find_words(x):
    for child in x:
        if child.tag == 'w':
            yield child
        else:
            for word in find_words(child):
                yield word

nouns = []
finite_verbs = []
infinite_verbs = []
for book_file in ['01_matthew_full', '02_mark_full', '03_luke_full', '04_john_full']:
    logging.info(f"Reading {book_file}")
    path = os.path.join(args.opentext_location, book_file + ".xml")
    book = ET.parse(path)
    book_root = book.getroot()
    for word in find_words(book_root):
        pos = word.attrib['pos']
        wordref = word.attrib['{http://www.w3.org/XML/1998/namespace}id']
        lemma = word.attrib['lemma']
        logging.info(f"{wordref} = {lemma}")
        if pos == 'noun':
            if word.attrib['lemma'][0] in greek_capitals:
                continue
            read_cursor.execute("select count(*) from common_nouns where wordref = %s", [wordref])
            if read_cursor.fetchone()[0] != 0:
                continue
            
            write_cursor.execute("""insert into common_nouns
               (wordref, lemma, gender, noun_case, noun_number) values (%s, %s, %s, %s, %s)""",
                                 [ wordref,
                                   word.attrib['lemma'], 
                                   word.attrib['gender'],
                                   word.attrib['case'],
                                   word.attrib['number']])
            for d in word.attrib['domains'].split():
                read_cursor.execute("select count(*) from louw_nida_domains where wordref = %s and louw_nida_domain = %s", [wordref, d])
                if read_cursor.fetchone()[0] > 0:
                    continue
                write_cursor.execute("insert into louw_nida_domains (wordref, lemma, louw_nida_domain) values (%s, %s, %s)", [wordref, lemma, d])


            for sd in word.attrib.get('subdomains', '').split():
                read_cursor.execute("select count(*) from louw_nida_subdomains where wordref = %s and louw_nida_subdomain = %s", [wordref, sd])
                if read_cursor.fetchone()[0] > 0:
                    continue
                write_cursor.execute("insert into louw_nida_subdomains (wordref, lemma, louw_nida_subdomain) values (%s, %s, %s)", [wordref, lemma, sd])
            conn.commit()
        # elif pos == 'finite':
        #     finite_verbs.append(
        #         {'id': word.attrib['{http://www.w3.org/XML/1998/namespace}id'], 
        #          'lemma': word.attrib['lemma'], 
        #          'voice': word.attrib['voice'],
        #          'mood': word.attrib['mood'],
        #          'number': word.attrib['number'],
        #          'tense': word.attrib['tense'],
        #          'person': word.attrib['person'],
        #          'domains': word.attrib.get('domains', '').split(),
        #          'subdomains': word.attrib.get('subdomains', '').split()})
        # elif pos == 'infinitive':
        #     infinite_verbs.append(
        #         {'id': word.attrib['{http://www.w3.org/XML/1998/namespace}id'], 
        #          'lemma': word.attrib['lemma'], 
        #          'voice': word.attrib['voice'],
        #          'tense': word.attrib['tense'],
        #          'domains': word.attrib.get('domains', '').split(),
        #          'subdomains': word.attrib.get('subdomains', '').split()})
        # # TO-DO: verbs
conn.commit()
write_cursor.close()
read_cursor.close()
