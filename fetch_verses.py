#!/usr/bin/env python3

# This program looks in the database for verses that have not been
# fetched, and inserts them into the database

import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--database-config", default="db.conf")
parser.add_argument("--verbose", action="store_true")
parser.add_argument("--one-language-only", action="store_true")
parser.add_argument("--progress", action="store_true")
parser.add_argument("--firefox-path", default="/usr/local/bin/firefox")
args = parser.parse_args()

import pandas
import xml.etree.ElementTree as ET
import os
import logging
import configparser
import psycopg2
import functools
import time



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
version_cursor = conn.cursor()
version_details_cursor = conn.cursor()
verse_details_cursor = conn.cursor()
write_cursor = conn.cursor()

query = "select version_id from incomplete_versions"
if args.one_language_only:
    query += " limit 1"
version_cursor.execute(query)

import selenium.webdriver
options = selenium.webdriver.firefox.options.Options()
options.headless = True
driver = selenium.webdriver.Firefox(options=options,
                                    firefox_binary=args.firefox_path)

book_translation = {'Matt': 'MAT', 
                    'Mark': 'MRK',
                    'Luke': 'LUK',
                    'John': 'JHN'
                   }
def bible_dot_com_url(language_code, short_code, book, chapter, verse=None):
    book_url = book_translation[book]
    # The next line makes me queasy -- many languages don't have upper case
    short_code = short_code.upper()
    url = f'https://www.bible.com/bible/{language_code}/{book_url}.{chapter}.{short_code}'
    return url

def bible_dot_com_usfm(book, chapter, verse):
    return f'{book_url}.{chapter}.{verse}'

@functools.lru_cache(2**18)
def get_url_content(url):
    driver.get(url)
    time.sleep(3)
    soup = BeautifulSoup(driver.page_source)
    return soup


def get_verse_content(language_code, short_code, book, chapter, verse):
    soup = get_url_content(bible_dot_com_url(language_code, short_code, book, chapter))
    spans = soup.find_all('span', class_='verse')
    usfm_to_look_for = bible_dot_com_usfm(verseref)
    answer = ''
    for span in spans:
        content = span.find_all('span', class_='content')
        if span['data-usfm'] == usfm_to_look_for:
            for c in content:
                answer += c.text
    return answer.strip()


for version_id in version_cursor:
    version_details_cursor.execute("select grouping_code, short_code, version_name from bible_versions where version_id = %s", [version_id])
    vs = version_details_cursor.fetchone()
    grouping_code = vs[0]
    short_code = vs[1]
    version_name = vs[2]

    verse_details_cursor.execute("select book, chapter, verse from unfetched_verses where version_id = %s", [version_id])
    iterator = verse_details_cursor
    if args.verbose:
        import tqdm
        iterator = tqdm.tqdm(iterator,
                             desc=version_name,
                             total=iterator.rowcount)
    for verse_details in iterator:
        (b,c,v) = verse_details
        
    for verse in iterator:
        content = get_verse_content(grouping_code, short_code, verse)
        b,c,v = book_chapter_verse(verse)
        write_cursor.execute("insert into verses (version_id, book, chapter, verse, passage) values (%s, %s, %s, %s, %s)",
                             [version_id, b, c, v, content])
        db.commit()
