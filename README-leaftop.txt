LEAFTOP
======

*Language Extracted Automatically from Thousands of Passages*

A dataset prepared by Gregory Baker (gregory.baker2@hdr.mq.edu.au)

This is an automatically-generated dataset, derived from translations
of the four gospels of the New Testament. The software used for this
extraction is available on github at
https://github.com/solresol/thousand-language-morphology

The scraping code used to fetch the translations is included in the
git repository, but it takes several weeks to complete. Likewise, the
code used to identify the most probably vocabulary took over a month
to run on a large multi-CPU machine. It should run on any Linux or
Unix-like machine (it seems to run successfully on OSX); it might work
on Windows but has never been tried.

It is scraped from https://www.bible.com/versions ; many of the works
there are copyright Wycliffe and (very reasonably) anti-piracy
mechanisms are in place. For this reason scraping is done with a
Selenium-based scraper which renders the JavaScript of the page
to fetch the content, and pauses for long periods of time between
page fetches.

Many bible versions on the site do not contain the whole of the four
gospels: usually this is because the translation is incomplete. These
have been scraped in as much as possible, but not included for extraction.

A small number of passages do not contribute to determining whether
a gospel is complete or not.

John 7:53-8:11 is not present in all bible versions: if it is present,
it is scraped and used for vocabulary extraction; if not, the bible
version is still used but these verses are (obviously) not included as
part of the extraction. This slightly adjusts the confidence of the
translations of lemmas that would otherwise be found in these verses.

This applies also to Matthew 21:44, Mark 4:41, Luke 22:43-44 and John
5:5. For a very small number of versions (e.g. the Armenian Catholic
bible) the bible.com website has an off-by-one error in display the
verses numbers.  These corrections are hard-coded in lines 150-160 of
fetch_verses.py in the git repository listed above.

----------------------------------------------------------------------

There are 416 nouns in the gospels that appear twice or more in the
same case, number and gender.

The assumption is made that each of these nouns is translated
consistently into a single word, single token or character
sequence. (This of course is not universally true, but it works
remarkably often.)

For each each single word (or token, or ...) in the translated
language, the probability that it is the translation of the Greek
lemma is calculated using the binomial test based on their appearance
in the corresponding verses. If no word (or token) is clearly
identified as being the most probably translation, then the Greek
lemma is ignored for that language; if one word (or token) is the most
probable, it is recorded in this dataset.

Since there is some ambiguity, this process produces around 300 nouns,
together with a confidence score.

If the process produces less than 100 candidate translations of
unigrams, it is assumed that the language doesn't use spaces to
separate words. If the number of distinct uni_tokens is less than half
of the number of lemmas translated, it is assumed to be a
non-alphabetic language (e.g. Chinese). Failing this, the fallback is
quad_token (sequences of 1-4 characters). Quad_token is almost always
wrong.

For languages that have multiple translations of the bible, a "most
common translation choice" (the consensus answer of the extract process
on each bible version) is included as well.

This dataset contains the output of doing this process across 1505
languages. Some metadata about each language (to disambiguate
languages from different regions with the same) is also included,
mostly derived from wikidata. Cross references to which translation of
the bible it is derived from is included as well.

This is useful to researchers looking at grammar morphology across a
large number of languages and to researchers looking for comparative
wordlists between related languages.

----------------------------------------------------------------------

There are various limitations to be aware of:

- Languages (such as Khmer) that have an alphabet but do not have word
  breaks are not handled very well. Their translations will only be
  correct for words that are 4 letters or shorter; for a word in Khmer
  longer than this this process will generate some subsequence

- There are concepts in Koine Greek that do not always translate into
  a single word or single character. "Chief priest" is one; this will
  often be translated incorrectly.

- Koine Greek does not distinguish between the hair on the head of a
  human and the hair found on an animal. This will often be translated
  incorrectly.

- There will be mistakes in general. A low confidence score (a score
  of 2.0 or lower) has a very high chance of being an incorrect
  translation. The author has begun the process of evaluating how accurate
  this data is in general across a variety of languages. These are to
  be found in the evaluations folder.

- The author believes that the use and distributions of these
  translations is legitimate fair dealing and fair use; but the
  underlying translations from which these translations were derived
  are usually works that are still under copyright, often by
  Wycliffe.

----------------------------------------------------------------------

Most languages will have three files:

- *-vocab.csv

- *-vocab.xlsx

- *-metadata.txt

22 languages have variant forms denoted with an underscore and then
a variant specifier. Examples include: shu_rom and zho_tw. These are
as recorded as-is based on their classification on bible.com.

Variants generally arise where a translator wanted to target a
translation to a particular target community who may not be fully
aligned with the greater community of language speakers. To take two
examples, there is a Romanised Chadian Arabic (shu_rom) or the bible
version written in full-form Chinese characters that is often used in
Taiwan.




[*-vocab.csv, *-vocab.xlsx]

The content of the *-vocab.csv and *-vocab.xlsx are the same. The
author found that many users of the leaftop dataset (including the
translators who worked on evaluations) encountered dubious behaviour
when opening a CSV file in Excel: Excel defaulted to an incorrect
character encoding which corrupted non-ascii characters. To work
around that, CSV and Excel format files are both provided.

The columns in these files are:

- lemma: the lemma form of the Koine Greek noun

- extract_reference_id: a primary key for the table. This is a unique
  but non-sequential integer. Its primary use is in tracking the responses
  for human translators checking the data

- tokenisation_method_id: unigram, uni_token or quad_token. The method
  that was used for tokenisation in this language

- gender: the gender of the noun in Koine Greek. This column is
  present in order to distinguish the uses of παῖς (child) which
  appears in both genders in the data set.

- noun_case: accusative, dative, genitive,  nominative or vocative

- noun_number: singular or plural

- most_common_translation: the "consensus answer" -- how do most
  bibles in this language translate this word?

- cumulative_confidence: how confident can we be about that answer?
  1.0 = complete ambiguity, 2.0 = likely to be correct; higher values are possible.
  This is the probability that this word is likely to be the correct translation,
  divided by the probability that the next-most-likely word is the correct translation

- version_*_translation: there will be one of these for each translation into the target
  language. The version number can be looked up in the language_index.csv file

- english_translation: a translation from Koine Greek into English of
  the word in question.  These were done by the author (Greg Baker)
  who is knowledgeable but not professionally fluent in Koine Greek


[*-metadata.txt]

The first sentence of this file will be a summary sentence:

e.g.  English appears to be alphabetic. It is written with spaces
between words. As a result, this extract was calculated using the
unigram method.

The remaining sentences are geographic information extracted from
Wikidata about these languages. Wikidata has generally proven
to be reliable but no efforts have been made to validate these statements.

esi and rmn_arl were not represented on Wikidata at the time of the extract,
so no statements were generated about these languages or their geography.
RMN is the code for Balkan Romani. ESI is the code for North Alaskan Iñupiatun.

----------------------------------------------------------------------

There is a language and Bible verison index file in docs/language_index.csv.
The columns in this file are:

- ISO_639_3_Code: the ISO code of the language, or of its variant

- Language Name: the name of the language in English

- Wikidata Entity: the wikidata entity that refers to this language

- Leaftop Bible Version Id: a unique, semi-stable key. Attempts will be made
  to keep this number consistent across later iterations of the
  leaftop dataset.

- bible.com/versions: http://bible.com/versions/{...} is the landing page
  of the Bible version this row refers to (and from which the content was scraped)

- Likely name of bible: bugs in the scraping process have mangled many non-ascii
  Bible names. This will be addressed in a future version of this database.

----------------------------------------------------------------------

A very small number of languages have been evaluated by human translators.
These are in the evaluations subdirectory. Formatting is not consistent,
but generally these match up to the equivalent *-vocab.xlsx file, but with
a column added by the translator to report whether the translation was
correct or not.
