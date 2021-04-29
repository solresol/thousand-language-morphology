create table common_nouns (
  wordref varchar primary key,
  lemma varchar,
  gender varchar,
  noun_case varchar,
  noun_number varchar
);

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


create table louw_nida_domains (
  lemma varchar,
  louw_nida_domain varchar
);
create unique index on louw_nida_domains(lemma, louw_nida_domain);

create table louw_nida_subdomains (
  lemma varchar,
  louw_nida_subdomain varchar
);
create unique index on louw_nida_subdomains(lemma, louw_nida_subdomain);
  
  



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


