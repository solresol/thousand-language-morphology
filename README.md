Thousand Language Morphology Database
=====================================

(All author information redacted until the end of 2022, where I'll put it back
again. I just had a paper desk-rejected because of an anonymity fail because
of this README.)

My claim is that p-adic metrics are ideally suited to various natural
language processing machine learning tasks -- better than Euclidean metrics.

One of the tasks where p-adics are likely to be helpful is in grammar morphology:
deducing from a very small number of examples how the language changes the forms
of words to represent their roles in a sentence.


This repo will contain word-form pairs from 1000 languages.


Building from scratch
---------------------

This not complete yet.

1. `git clone git@github.com:OpenText-org/GNT_annotation_v1.0.git` in some directory.

2. Create a postgresql database with utf8 encoding -- `createdb --encoding=utf8 --template=template8 thousand_language`

3. Create a user with write permissions to all the tables in the database.

4. Create a file `db.conf`

```
[database]
dbname=thousand_language
user=gntwriter
password=whateverpasswordyouused
host=localhost
port=5432
```

5. `pip3 install --user -r requirements.txt`

6. Run `parse_verses.py` . If necessary add `--verbose` or `--opentext-location` or `--database-config`

7. Run the `datacleaning.sql` file using `psql`

8. Run `fetch_verses.py` -- this takes a few weeks to complete

9. Run `extract_vocab.py` -- this takes a few weeks to complete

10. Load wikidata codes (`\copy f'wikidata_iso639_codes' from 'enrichment/language-codes.csv')
and run `refresh materialized view wikidata_iso639_codes`

11. Run `wikidata/cache-wikidata.py`

12. Run `refresh materialized view wikidata_parental_tree;`

13. Load `canonical-english.sql`

14. Load the translation data into the database with `save_translations.py` and then run
`refresh materialized view vocabulary_sizes`
`refresh materialized view vocabulary_sizes_crosstab` and
`refresh materialized view lemma_translation_counts` and 
`refresh materialized view vocabulary_extraction_correlations`

15. Run `./make_vocab_lists.py`

16. Run `./make_leaftop.py`

17. Hire some translators to check the content in `leaftop/`

18. Load their results with `load_assessment.py`

19. Run `./make_leaftop.py` again, but send the `--output` to the directory
which has the clone of `github.com:solresol/leaftop.gif`

20. Run `./make_explorer.py` (again, use `--output` to put the output
into a suitable subdirectory (e.g. `leaftop-explorer`) of the
leaftop repo.

21. Run `pairings.py` (maybe run it several times with `pairings --tokenisation-method bigram/trigram/uni_token`  etc.) It took about 48 hours to run.

22. `refresh materialized view translation_exploration`
`refresh materialized view likely_valid_vocabulary_extractions`
`refresh materialized view summary_of_vocabulary_extractions`
`refresh materialized view confidence_vs_reality`

23. Make a release of LEAFTOP. zip the data, docs, evaluations and leaftop-explorer files from the leaftop repo.

24. `refresh materialized view singular_plural_similarity_and_signals`
