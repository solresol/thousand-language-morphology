#!/usr/bin/env python3

# This program is a memory hog when it doesn't need to be.
# Sensibly, it should work through each lemma on its own, and then
# store that in the database.
# Less sensibly, it should look at words in context (and do some sort
# of linear logic to eliminate words that can't be right)


import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--database-config",
                    help="Config file with details of the database connection to use",
                    default="db.conf")
parser.add_argument("--bible-version-name",
                    help="name of the bible version to export")
parser.add_argument("--bible-version-id",
                    help="id of the bible version to export")

parser.add_argument("--progress",
                    action="store_true",
                    help="show progress bar")
parser.add_argument("--verbose",
                    action="store_true",
                    help="a few debugging messages")
parser.add_argument("--dry-run",
                    action="store_true",
                    help="don't store the data back into the database")

# These next two should become irrelevant
parser.add_argument("--word-pairs-output",
                    help="CSV file to send singular and plural pairs to")
parser.add_argument("--translation-output",
                    help="CSV file to send lemma and target language pairs to")
parser.add_argument("--ngram-min-tokens",
                    type=int,
                    default=1,
                    help="Low-end for range of n-gram lengths")

parser.add_argument("--ngram-max-tokens",
                    type=int,
                    default=1,
                    help="High-end for range of n-gram lengths")
parser.add_argument("--tokengrams",
                    action='store_true',
                    help="Don't split at the word-level, split at n-tokens")

parser.add_argument("--singplur-only",
                    action='store_true',
                    help="Only extract vocabulary where we have both a singular and plural form of the noun")

args = parser.parse_args()

import logging
import psycopg2
import configparser
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

tokenisation_methods = {
    (False, 1) : 'unigram',
    (False, 2) : 'bigram',
    (False, 3) : 'trigram',
    (True, 1) : 'uni_token',
    (True, 2) : 'bi_token',
    (True, 3) : 'tri_token',
    (True, 4) : 'quad_token'
}
if not args.dry_run:
    if (args.tokengrams, args.ngram_max_tokens) not in tokenisation_methods:
        sys.exit(f"{args.tokengrams=} and {args.ngram_max_tokens=} is not a named tokenisation_method")
    if args.ngram_min_tokens != 1:
        sys.exit(f"The database isn't set up to handle {args.ngram_min_tokens=}; 1 is the only supported value at the moment")
    tokenisation_method_id = tokenisation_methods[ (args.tokengrams, args.ngram_max_tokens)]


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

logging.info("Use sqlalchemy's create engine method to connect to the database")
engine = sqlalchemy.create_engine(
    f"postgresql+psycopg2://{user}:{password}@{host}:5432/{dbname}")


def everygram_generator(sequence, min_tokens=1, max_tokens=None):
    sequence = list(sequence)
    sequence_length = len(sequence)+1
    if max_tokens is None:
        max_tokens = len(sequence)
    for i in range(len(sequence)):
        for j in range(min_tokens, max_tokens+1):
            if i+j < sequence_length:
                yield sequence[i:i+j]

def canonical_everygrams(sequence):
    if args.tokengrams:
        sequence = sequence
    else:
        sequence = nltk.word_tokenize(sequence)
    return [" ".join(x)
            for x in everygram_generator(sequence,
                                         min_tokens=args.ngram_min_tokens,
                                         max_tokens=args.ngram_max_tokens)
            ]

if args.bible_version_id is None:
    bible_version_name = args.bible_version_name
    logging.info(f"Finding {bible_version_name}")
    read_cursor.execute(
        "select version_id from bible_versions where lower(version_name) = lower(%s)",
        [bible_version_name]
    )
    row = read_cursor.fetchone()
    if row is None:
        sys.exit(f"{bible_version_name} not found")
    version = row[0]
    logging.info(f"{bible_version_name} is version id = {version}")
elif args.bible_version_name is None:
    version = args.bible_version_id
    logging.info(f"Finding the name of {version}")
    read_cursor.execute(
        "select version_name from bible_versions where version_id = %s and version_worth_fetching",
        [version])
    row = read_cursor.fetchone()
    if row is None:
        sys.exit(f"{version} not found, or it was not a version worth fetching")
    bible_version_name = row[0]
else:
    sys.exit("Must supply either a version name or a version id")

logging.info("Reading lemmas")

if not(args.singplur_only):
    sys.exit("--singplur-only is required; the alternative isn't implemented yet")

singplur = pandas.read_sql(
    """select * from lemmas_with_repeated_singular_and_plural join common_nouns using (lemma, gender, noun_case)
     where noun_case in ('nominative', 'accusative')
    """, engine)
singplur['book'] = singplur.wordref.str.split('.').map(lambda x: x[1])
singplur['chapter'] = singplur.wordref.str.split('.').map(lambda x: int(x[2]))
singplur['verse'] = singplur.wordref.str.split('.').map(lambda x: int(x[3]))
singplur['verseref'] = singplur.book + " " + singplur.chapter.map(str) + ':' + singplur.verse.map(str)


logging.info(f"Reading verses from version_id = {version}")
this_version_verses = pandas.read_sql(
    f"""select book, chapter, verse, passage from verses where version_id = {version}""", engine)
this_version_verses['verseref'] = this_version_verses.book + " " + this_version_verses.chapter.map(str) + ':' + this_version_verses.verse.map(str)
logging.info(f"{bible_version_name} [version_id={version}] has {this_version_verses.shape[0]} verses")

# I can't remember what I was doing here
logging.info("Taking each word and seeing what verses it is in")
reverse_records = []
total_verses_in_translation = 0
for (b,c,v,p) in zip(this_version_verses.book, this_version_verses.chapter, this_version_verses.verse,
       this_version_verses.passage):
    total_verses_in_translation += 1
    words = canonical_everygrams(p)
    for w in words:
        reverse_records.append({'word': w, 'book': b, 'chapter': c, 'verse': v})

logging.info("Creating reverse record dataframe")
reverse_records_df = pandas.DataFrame.from_records(reverse_records).drop_duplicates()
logging.info(f"Shape of reverse record dataframe = {reverse_records_df.shape}")
reverse_records_df['verseref'] = reverse_records_df.book + " " + reverse_records_df.chapter.map(str) + ':' + reverse_records_df.verse.map(str)

logging.info("Finding each lemma (regardless of form) and finding what verses it appears in")
raw_lemma_lookup = pandas.read_sql(
    """select lemma, wordref from common_nouns""", engine)
raw_lemma_lookup['book'] = raw_lemma_lookup.wordref.str.split('.').map(lambda x: x[1])
raw_lemma_lookup['chapter'] = raw_lemma_lookup.wordref.str.split('.').map(lambda x: int(x[2]))
raw_lemma_lookup['verse'] = raw_lemma_lookup.wordref.str.split('.').map(lambda x: int(x[3]))
raw_lemma_lookup['verseref'] = raw_lemma_lookup.book + " " + raw_lemma_lookup.chapter.map(str) + ':' + raw_lemma_lookup.verse.map(str)


logging.info("Merging singular and plural lemma information with the verses that are available")
df = singplur.merge(this_version_verses,
              left_on=['book', 'chapter', 'verse'],
              right_on=['book', 'chapter', 'verse'])
df.drop('wordref', axis=1, inplace=True)
df.drop_duplicates(inplace=True)
df.set_index(
    ['lemma', 'gender', 'noun_case', 'noun_number'],
    inplace=True
)
df.sort_index(inplace=True)
df.rename(columns={'verseref_x': 'verseref'}, inplace=True)
df.drop(['verseref_y'], axis=1, inplace=True)


logging.info("Creating translation records")
translation_records = []
iterator = df.index.unique()
if args.progress:
    import tqdm
    iterator = tqdm.tqdm(iterator)

for row in iterator:
    temp_df = df.loc[row]
    lemma = row[0]
    if args.progress:
        iterator.set_description(lemma)
    ngram_appearances_in_verses = collections.defaultdict(int)
    verses_for_this_row = 0
    for passage in temp_df.passage:
        verses_for_this_row += 1
        words = canonical_everygrams(passage)
        for word in set(words):
            ngram_appearances_in_verses[word] += 1
    verses_with_the_lemma = raw_lemma_lookup[raw_lemma_lookup.lemma == lemma].verseref.unique()
    verses_with_the_lemma_in_the_right_form = temp_df.verseref.unique()
    verses_without_the_lemma = this_version_verses[~this_version_verses.verseref.isin(verses_with_the_lemma)].verseref.unique()
    places_we_want_to_check = set(verses_without_the_lemma).union(set(verses_with_the_lemma_in_the_right_form))
    search_subset = reverse_records_df[reverse_records_df.verseref.isin(places_we_want_to_check)]
    for word in ngram_appearances_in_verses:
        # I want to skip verses where the lemma appears in some other form
        appearances_anywhere = search_subset[search_subset.word == word]
        probability_of_seeing_this_word = appearances_anywhere.shape[0] / len(places_we_want_to_check)
        count_we_saw = ngram_appearances_in_verses[word]
        number_of_places_it_might_have_been = verses_for_this_row
        probability = scipy.stats.binom_test(count_we_saw,
                                            number_of_places_it_might_have_been,
                                            probability_of_seeing_this_word,
                                            alternative='greater')
        translation_records.append({
            'lemma': row[0],
            'gender': row[1],
            'noun_case': row[2],
            'noun_number': row[3],
            'translation': word,
            'binomial_test_p_score': probability,
            'neg_log_binomial_test_p_score': - math.log(probability),
            'appearances': appearances_anywhere.shape[0],
            'total_verses_in_translation': total_verses_in_translation,
            'probability_of_seeing_this_word': probability_of_seeing_this_word,
            'count_we_saw': count_we_saw,
            'number_of_places_we_saw_the_lemma': temp_df.shape[0]
        })
translation_df = pandas.DataFrame.from_records(translation_records)


best_translations = translation_df.groupby(
    ['lemma', 'gender', 'noun_case', 'noun_number']
).binomial_test_p_score.idxmin().reset_index()
best_translations.rename(
    columns={'binomial_test_p_score': 'best_p_score_index'},
    inplace=True)
noun_vocab = best_translations[['best_p_score_index']
                               ].merge(translation_df,
                                       left_on=['best_p_score_index'],
                                       right_index=True
                                       )

logging.info("Calculating confidence measures")
confidences = []
for row_idx in noun_vocab.index:
    lemma = noun_vocab.loc[row_idx].lemma
    gender = noun_vocab.loc[row_idx].gender
    noun_case = noun_vocab.loc[row_idx].noun_case
    noun_number = noun_vocab.loc[row_idx].noun_number
    translation = noun_vocab.loc[row_idx].translation
    neg_log_binomial_test_p_score  = noun_vocab.loc[row_idx].neg_log_binomial_test_p_score
    alternatives = translation_df[
            (translation_df.lemma == lemma) &
            (translation_df.gender == gender) &
            (translation_df.noun_case == noun_case) &
            (translation_df.noun_number == noun_number) &
            (translation_df.translation != translation)
    ]
    next_best = alternatives.neg_log_binomial_test_p_score.max()
    #print(lemma, gender, noun_case, noun_number, neg_log_binomial_test_p_score, next_best)
    confidences.append(neg_log_binomial_test_p_score / next_best)
noun_vocab['confidence'] = confidences
noun_vocab.sort_values('confidence')


if args.translation_output is not None:
    logging.info(f"Writing {args.translation_output}")
    output = noun_vocab.sort_values('confidence')
    output['is_correct'] = ''
    output_directory = os.path.dirname(args.translation_output)
    os.makedirs(output_directory, exist_ok = True)
    output.to_csv(args.translation_output, sep='\t')


logging.info("Finding nouns that appear in multiple numbers")
multi_number_nouns = noun_vocab[noun_vocab.confidence > 1].groupby(['lemma', 'gender', 'noun_case']).noun_number.nunique()
multi_number_nouns = multi_number_nouns[multi_number_nouns > 1]
word_number_pairs = []
for (lemma, gender, noun_case) in multi_number_nouns.index:
    singular = noun_vocab[(noun_vocab.lemma == lemma) &
                              (noun_vocab.gender == gender) &
                              (noun_vocab.noun_case == noun_case) &
                              (noun_vocab.noun_number == 'singular')
                             ].translation.iloc[0]
    plural = noun_vocab[(noun_vocab.lemma == lemma) &
                              (noun_vocab.gender == gender) &
                              (noun_vocab.noun_case == noun_case) &
                              (noun_vocab.noun_number == 'plural')
                             ].translation.iloc[0]
    word_number_pairs.append({'lemma': lemma, 'noun_case': noun_case, 'gender': gender,
                              'singular': singular, 'plural': plural})
word_number_pairs = pandas.DataFrame.from_records(word_number_pairs)

if args.word_pairs_output is not None:
    logging.info(f"Writing {args.word_pairs_output}")
    output_file = args.word_pairs_output
    output_directory = os.path.dirname(output_file)
    os.makedirs(output_directory, exist_ok = True)
    word_number_pairs.to_csv(args.word_pairs_output, index=False, sep='\t')

if args.dry_run:
    logging.info("Skipping the database update. Terminating cleanly now.")
    sys.exit(0)

for row_idx in noun_vocab.index:
    confidence = noun_vocab.loc[row_idx].confidence
    if confidence == 1.0:
        continue
    lemma = noun_vocab.loc[row_idx].lemma
    gender = noun_vocab.loc[row_idx].gender
    noun_case = noun_vocab.loc[row_idx].noun_case
    noun_number = noun_vocab.loc[row_idx].noun_number
    translation = noun_vocab.loc[row_idx].translation
    binomial_test_p_score = noun_vocab.loc[row_idx].binomial_test_p_score
    neg_log_binomial_test_p_score  = noun_vocab.loc[row_idx].neg_log_binomial_test_p_score
    appearances = noun_vocab.loc[row_idx].appearances
    total_verses_in_translation = noun_vocab.loc[row_idx].total_verses_in_translation
    probability_of_seeing_this_word = noun_vocab.loc[row_idx].probability_of_seeing_this_word
    count_we_saw = noun_vocab.loc[row_idx].count_we_saw
    number_of_places_we_saw_the_lemma = noun_vocab.loc[row_idx].number_of_places_we_saw_the_lemma
    read_cursor.execute("""select translation_in_target_language,
               neg_log_binomial_test_p_score,
               confidence
          from vocabulary_extractions
         where bible_version_id = %s
           and tokenisation_method_id = %s
           and lemma = %s
           and gender = %s
           and noun_case = %s
           and noun_number = %s""", [version, tokenisation_method_id, lemma, gender,
                                     noun_case, noun_number])
    dbrow = read_cursor.fetchone()
    if dbrow is None:
        logging.info(f"Inserting {lemma} {gender} {noun_case} {noun_number} -> {translation} confidence = {confidence}")
        write_cursor.execute("""insert into vocabulary_extractions (
 bible_version_id,
 tokenisation_method_id,
 lemma,
 gender,
 noun_case,
 noun_number,
 translation_in_target_language,
 binomial_test_p_score,
 neg_log_binomial_test_p_score,
 appearances,
 total_verses_in_translation,
 probability_of_seeing_this_word,
 count_we_saw,
 number_of_places_we_saw_the_lemma,
 confidence) values (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)""",
                             [version, tokenisation_method_id, lemma, gender, noun_case,
                              noun_number, translation,
                              float(binomial_test_p_score),
                              float(neg_log_binomial_test_p_score),
                              int(appearances),
                              int(total_verses_in_translation),
                              float(probability_of_seeing_this_word),
                              int(count_we_saw),
                              int(number_of_places_we_saw_the_lemma),
                              float(confidence)])
        continue
    previous_translation = dbrow[0]
    previous_neg_log = dbrow[1]
    previous_confidence = dbrow[2]
    if previous_translation != translation or previous_neg_log != neg_log_binomial_test_p_score or previous_confidence != confidence:
        logging.info(f"Updating {lemma} {gender} {noun_case} {noun_number} -> {translation} instead of {previous_translation},  confidence = {confidence} instead of {previous_confidence}, neg_log_binomial_test_p_score = {neg_log_binomial_test_p_score} instead of {previous_neg_log}")
        write_cursor.execute("""update vocabulary_extractions
        set  translation_in_target_language = %s,
             binomial_test_p_score =  %s,
             neg_log_binomial_test_p_score = %s,
             appearances = %s,
             total_verses_in_translation = %s,
             probability_of_seeing_this_word = %s,
             count_we_saw = %s,
             number_of_places_we_saw_the_lemma = %s,
             confidence = %s,
             is_replacement = true
       where bible_version_id = %s
        and tokenisation_method_id = %s
        and lemma = %s
        and gender = %s
        and noun_case = %s
        and noun_number = %s""",

                             [translation,
                              float(binomial_test_p_score),
                              float(neg_log_binomial_test_p_score),
                              int(appearances),
                              int(total_verses_in_translation),
                              float(probability_of_seeing_this_word),
                              int(count_we_saw),
                              int(number_of_places_we_saw_the_lemma),
                              float(confidence),
                              version,
                              tokenisation_method_id, lemma, gender, noun_case, noun_number ])

conn.commit()
