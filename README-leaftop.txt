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

For languages that have multiple translations of the bible, a "most
common translation choice" is included as well.

This dataset contains the output of doing this process across 1471
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

- There will be mistakes in general. A low confidence score (a score
  of 2.0 or lower) has a very high chance of being an incorrect
  translation. The author has begun the process of evaluating how accurate
  this data is in general across a variety of languages.

- The author believes that the use and distributions of these
  translations is legitimate fair dealing and fair use; but the
  underlying translations from which these translations were derived
  are usually works that are still under copyright, often by
  Wycliffe.

