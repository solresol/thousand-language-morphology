create table common_nouns (
  wordref varchar primary key,
  lemma varchar,
  gender varchar,
  noun_case varchar,
  noun_number varchar
);
create index on common_nouns(lemma,gender,noun_number,noun_case);
create index on common_nouns(lemma,gender,noun_number);
create index on common_nouns(lemma,gender,noun_case);
create index on common_nouns (noun_number);
create index on common_nouns (noun_case);

create table finite_verbs (
   wordref varchar primary key,
   lemma varchar,
   voice varchar,
   mood varchar,
   verb_number varchar,
   tense varchar,
   person varchar
);

create table infinite_verbs (
   wordref varchar primary key,
   lemma varchar,
   voice varchar,
   tense varchar
);

create view repeated_nominatives as
  select distinct lemma , gender, noun_number
    from common_nouns as c1 join common_nouns as c2 using (lemma, gender, noun_number)
   where c1.wordref != c2.wordref
     and c1.noun_case = 'nominative';

create view repeated_accusatives as
  select distinct lemma , gender, noun_number
    from common_nouns as c1 join common_nouns as c2 using (lemma, gender, noun_number)
   where c1.wordref != c2.wordref
     and c1.noun_case = 'accusative';

create view lemmas_with_repeated_nominative_and_accusative as
  select distinct lemma, gender, noun_number
  from repeated_nominatives join repeated_accusatives using (lemma, gender, noun_number);


create view repeated_singulars as
  select distinct lemma , gender, noun_case
    from common_nouns as c1 join common_nouns as c2 using (lemma, gender, noun_case)
   where c1.wordref != c2.wordref
     and c1.noun_number = 'singular';

create view repeated_plurals as
  select distinct lemma , gender, noun_case
    from common_nouns as c1 join common_nouns as c2 using (lemma, gender, noun_case)
   where c1.wordref != c2.wordref
     and c1.noun_number = 'plural';

create view lemmas_with_repeated_singular_and_plural as
  select distinct lemma, gender, noun_case
  from repeated_singulars join repeated_plurals using (lemma, gender, noun_case);


create view verses_worth_fetching as
  select 
    split_part(wordref,'.',2) as book,
    cast(split_part(wordref,'.',3) as int) as chapter,
    cast(split_part(wordref,'.',4) as int) as verse
   from lemmas_with_repeated_singular_and_plural join common_nouns
     using (lemma, gender, noun_case)
    where noun_number in ('singular', 'plural')
  UNION
  select 
    split_part(wordref,'.',2) as book,
    cast(split_part(wordref,'.',3) as int) as chapter,
    cast(split_part(wordref,'.',4) as int) as verse
   from lemmas_with_repeated_nominative_and_accusative join common_nouns
     using (lemma, gender, noun_number)
    where noun_number in ('nominative', 'accusative');
 -- in time I will add other unions. 
 -- I might also have to figure out how to do the split_part function in sqlite







create table louw_nida_domains (
  wordref varchar,
  lemma varchar,
  louw_nida_domain varchar
);
create unique index on louw_nida_domains(wordref, louw_nida_domain);

create table louw_nida_subdomains (
  wordref varchar,
  lemma varchar,
  louw_nida_subdomain varchar
);
create unique index on louw_nida_subdomains(wordref, louw_nida_subdomain);
  
  



create table bible_versions (
 version_id serial primary key,
 language varchar,
 grouping_code varchar,
 short_code varchar,
 version_name varchar
);
create unique index on bible_versions(language, grouping_code, short_code);



create table verses (
  verse_version_id serial primary key,
  version_id integer references bible_versions,
  book varchar,
  chapter int,
  verse int,
  passage varchar
);
create unique index on verses(version_id, book, chapter, verse);
create index on verses(book, chapter, verse);

create view unfetched_verses as
  select version_id, book, chapter, verse 
    from bible_versions, verses_worth_fetching 
  EXCEPT
   select version_id, book, chapter, verse
    from verses;

