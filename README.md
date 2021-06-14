Thousand Language Morphology Database
=====================================

This project is part of Greg Baker's postgrad studies.

Greg's claim is that p-adic metrics are ideally suited to various natural
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

5. Run `parse_verses.py` . If necessary add `--verbose` or `--opentext-location` or `--database-config`

6. Run `make enrichment/language-codes.csv`

6. (More to come)

