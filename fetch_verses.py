#!/usr/bin/env python3

# This program looks in the database for verses that have not been
# fetched, and inserts them into the database

import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--database-config", default="db.conf")
parser.add_argument("--verbose", action="store_true")
parser.add_argument("--one-language-only", action="store_true")
parser.add_argument("--progress", action="store_true")
parser.add_argument("--firefox-path")
parser.add_argument("--show-browser", action="store_true")
args = parser.parse_args()

import pandas
import xml.etree.ElementTree as ET
import os
import logging
import configparser
import psycopg2
import functools
import time
from bs4 import BeautifulSoup
import selenium.webdriver

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

logging.info("Querying to find incomplete versions")
query = "select version_id from incomplete_versions"
if args.one_language_only:
    query += " limit 1"
version_cursor.execute(query)

options = selenium.webdriver.firefox.options.Options()
if args.show_browser:
    pass
else:
    options.headless = True

logging.info("Launching firefox")
if args.firefox_path is not None:
    driver = selenium.webdriver.Firefox(options=options,
                                        firefox_binary=args.firefox_path)
else:
    driver = selenium.webdriver.Firefox(options=options)

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
    logging.info(f"Calculated {url}")
    return url

def bible_dot_com_usfm(book, chapter, verse):
    book_url = book_translation[book]    
    answer = f'{book_url}.{chapter}.{verse}'
    logging.info(f"bible_dot_com_usfm({book}, {chapter}, {verse}) = {answer}")
    return answer

@functools.lru_cache(2**18)
def get_url_content(url):
    logging.info(f"Fetching {url}")
    driver.get(url)
    logging.info("Waiting for the page to load")
    time.sleep(10)
    logging.info("Reading page content")
    soup = BeautifulSoup(driver.page_source)
    return soup


def get_verse_content(language_code, short_code, book, chapter, verse):
    logging.info(f"Getting {language_code} {short_code} {book} {chapter} {verse}")
    soup = get_url_content(bible_dot_com_url(language_code, short_code, book, chapter))
    spans = soup.find_all('span', class_='verse')
    usfm_to_look_for = bible_dot_com_usfm(book, chapter, verse)
    answer = ''
    for span in spans:
        content = span.find_all('span', class_='content')
        if span['data-usfm'] == usfm_to_look_for:
            for c in content:
                logging.info(" + {c.text}")
                answer += c.text
    return answer.strip()


for version_cursor_row in version_cursor:
    version_id = version_cursor_row[0]
    logging.info(f"Working with bible_version = {version_id}")
    version_details_cursor.execute("select grouping_code, short_code, version_name from bible_versions where version_id = %s", [version_id])
    vs = version_details_cursor.fetchone()
    grouping_code = vs[0]
    short_code = vs[1]
    version_name = vs[2]
    logging.info(f"Grouping code = {grouping_code}, short_code = {short_code}, version name = {version_name}")

    verse_details_cursor.execute("select book, chapter, verse from unfetched_verses where version_id = %s", [version_id])
    iterator = verse_details_cursor
    if args.progress:
        import tqdm
        iterator = tqdm.tqdm(iterator,
                             desc=version_name,
                             total=iterator.rowcount)
    for verse_detail_row in iterator:
        b,c,v = verse_detail_row
        logging.info(f"Processing {b} {c} {v}")
        content = get_verse_content(grouping_code, short_code, b, c, v)
        logging.info(f"Storing {version_id} {b} {c} {v} = {content}")
        write_cursor.execute("insert into verses (version_id, book, chapter, verse, passage) values (%s, %s, %s, %s, %s)",
                             [version_id, b, c, v, content])
        db.commit()

driver.quit()
