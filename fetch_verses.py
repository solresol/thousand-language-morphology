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
parser.add_argument("--use-chrome", action="store_true")
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

if args.use_chrome:
    options = selenium.webdriver.chrome.options.Options()
    if args.show_browser:
        pass
    else:
        options.headless = True
    logging.info("Launching chrome")
    driver = selenium.webdriver.Chrome(options=options)
else:
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
    if driver.current_url != url:
        logging.critical(f"I tried to load {url} but ended up at {driver.current_url}")
        raise Unretrievable
    return soup

class Unretrievable(Exception):
    pass


def get_verse_content(language_code, short_code, book, chapter, verse):
    logging.info(f"Getting {language_code} {short_code} {book} {chapter} {verse}")
    target_url = bible_dot_com_url(language_code, short_code, book, chapter)
    soup = get_url_content(target_url)
    spans = soup.find_all('span', class_='verse')
    usfm_to_look_for = bible_dot_com_usfm(book, chapter, verse)
    logging.info(f"Looking for a span with data-usfm = {usfm_to_look_for}")
    answer = ''
    for span in spans:
        content = span.find_all('span', class_='content')
        if (span['data-usfm'] == usfm_to_look_for
            or ('+' + usfm_to_look_for) in span['data-usfm']
            or (usfm_to_look_for + '+') in span['data-usfm']):
            for c in content:
                logging.info(f" + {c.text}")
                answer += c.text
    if answer == '':
        for span in spans:
            content = span.find_all('span', class_='content')
            try:
                parent = content.parent
            except AttributeError:
                continue
            if (parent['data-usfm'] == usfm_to_look_for
                or ('+' + usfm_to_look_for) in parent['data-usfm']
                or (usfm_to_look_for + '+') in parent['data-usfm']):
                for c in content:
                    logging.info(f" + {c.text}")
                    answer += c.text
    if answer == '':
        if usfm_to_look_for in [ 'MAT.21.44',
                                 'MRK.4.41',
                                 'LUK.22.43', 'LUK.22.44',
                                 'JHN.5.5', 'JHN.7.53', 'JHN.8.1', 'JHN.8.3', 'JHN.8.4',
                                'JHN.8.7', 'JHN.8.9', 'JHN.8.10'
                                ]:
            return ''
        if short_code == 'da1871' and usfm_to_look_for == 'MRK.9.1':
            return ''
        if short_code == 'vulg' and usfm_to_look_for == 'MAT.17.27':
            return ''
        if short_code == 'vulg' and usfm_to_look_for == 'JHN.11.57':
            return get_verse_content(language_code, short_code, book, chapter, verse - 1)
        if short_code in ['湛約翰韶瑪亭譯本', '%E6%B9%9B%E7%B4%84%E7%BF%B0%E9%9F%B6%E7%91%AA%E4%BA%AD%E8%AD%AF%E6%9C%AC'] and usfm_to_look_for == 'MAT.18.14':
            return ''
        if short_code == 'wantacoc':
            if usfm_to_look_for in ['MAT.15.8', 'MAT.2.9', 'MAT.24.9', 'MAT.15.39']:
                # Do you ever get the feeling that Armenian Catholics
                # aren't good at proofreading?
                return get_verse_content(language_code, short_code, book, chapter, verse - 1)
        logging.warning(f"Could not load {short_code} {book} {chapter} {verse}")
    return answer.strip()


bad_versions = []
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
        if version_id in bad_versions:
            logging.info(f"Skipping version {version_id} because of past failures")
            break
        b,c,v = verse_detail_row
        logging.info(f"Processing {b} {c} {v}")
        try:
            content = get_verse_content(grouping_code, short_code, b, c, v)
        except Unretrievable:
            logging.critical(f"Version {version_id} appears to be unretrievable as it is missing the relevant chapter.")
            write_cursor.execute("update bible_versions set version_worth_fetching = false where version_id = %s", [version_id])
            conn.commit()
            if version_id not in bad_versions:
                bad_versions.append(version_id)
                logging.warning(f"The bad versions list is now {bad_versions}")
            break
            
        logging.info(f"Storing {version_id} {b} {c} {v} = {content}")
        write_cursor.execute("insert into verses (version_id, book, chapter, verse, passage) values (%s, %s, %s, %s, %s)",
                             [version_id, b, c, v, content])
        conn.commit()

driver.quit()
