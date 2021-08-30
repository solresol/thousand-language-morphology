create table koine_greek_genders (gender varchar primary key);
insert into koine_greek_genders (gender) values ('masculine');
insert into koine_greek_genders (gender) values ('feminine');
insert into koine_greek_genders (gender) values ('neuter');
create table koine_greek_cases (noun_case varchar primary key);
insert into koine_greek_cases (noun_case) values ('accusative');
insert into koine_greek_cases (noun_case) values ('dative');
insert into koine_greek_cases (noun_case) values ('genitive');
insert into koine_greek_cases (noun_case) values ('nominative');
insert into koine_greek_cases (noun_case) values ('vocative');
create table koine_greek_noun_numbers (noun_number varchar primary key);
insert into koine_greek_noun_numbers (noun_number) values ('plural');
insert into koine_greek_noun_numbers (noun_number) values ('singular');
-- it would be good to add a complete list of lemmas. At the moment I see
-- 818 distinct nouns that are not here:
create table common_noun_baker_translations (
  -- Less official even than Bill Mounce
  lemma varchar primary key,
  english_translation varchar not null
);
create table bill_mounce_glosses (
  lemma varchar primary key,
    -- At the moment this doesn't have translations for all lemmas we encounter.
    -- It would be a good idea to fix this.
  gloss varchar not null
);

-- These do have every possible lemma
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



----------------------------------------------------------------------

create table common_nouns (
  wordref varchar primary key,
  lemma varchar not null,
  gender varchar not null references koine_greek_genders(gender),
  noun_case varchar not null references koine_greek_cases(noun_case),
  noun_number varchar not null references koine_greek_noun_numbers(noun_number)
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

create view repeated_nouns as
  select distinct lemma , gender, noun_case, noun_number
    from common_nouns as c1 join common_nouns as c2 using (lemma, gender, noun_case, noun_number)
   where c1.wordref != c2.wordref;

-- These next few views can probably be layered on top of repeated_nouns
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


-- And in fact, it would make more sense for verses_worth_fetching to be calculated
-- based on repeated_nouns rather than the mess that is here...

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

create view number_of_verses_worth_fetching as
   select count(*) as verse_count from verses_worth_fetching;

create view verses_worth_fetching_simplified as
  select distinct
    split_part(wordref,'.',2) as book,
    cast(split_part(wordref,'.',3) as int) as chapter,
    cast(split_part(wordref,'.',4) as int) as verse
   from repeated_nouns join common_nouns
     using (lemma, gender, noun_case, noun_number);

create view number_of_verses_worth_fetching_simplified as
  select count(*) as verse_count from verses_worth_fetching_simplified;




----------------------------------------------------------------------

create table bible_versions (
 version_id serial primary key,
 language varchar,
 grouping_code varchar,
 short_code varchar,
 version_name varchar,
 version_worth_fetching bool default true
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


create view number_of_verses_fetched as
  select version_id, count(verse_version_id) as verses_fetched
    from bible_versions left join verses using (version_id)
   where version_worth_fetching
   group by version_id;

create view incomplete_versions as
   select version_id from number_of_verses_fetched
     where verses_fetched < (select verse_count from number_of_verses_worth_fetching);

create view all_verse_version_combinations as
  select version_id, book, chapter, verse
    from bible_versions, verses_worth_fetching;

create view unfetched_verses as
 select version_id, book, chapter, verse
   from  all_verse_version_combinations left join verses using (version_id, book, chapter, verse)
  where verses.verse_version_id is null;


create table raw_wikidata_iso639_codes (
  wikidata_entity varchar,
  entity varchar generated always as (replace(wikidata_entity, 'http://www.wikidata.org/entity/', '')) stored,
  language_name varchar,
  iso_639_3_code varchar
);
-- load this from enrichment/language-codes.csv
create table raw_wikidata_iso639_code_deprecations (
  entity varchar,
  iso_639_3_code varchar
);

create table iso639_aliases (
   language_alias varchar primary key,
   normally_known_as varchar
);

create materialized view wikidata_iso639_codes as
 select r.entity, r.language_name, r.iso_639_3_code
   from raw_wikidata_iso639_codes as r left join raw_wikidata_iso639_code_deprecations d
    using (entity, iso_639_3_code)
 where d.entity is null
   and r.iso_639_3_code in (select language from bible_versions);
create unique index on wikidata_iso639_codes(entity);
create unique index on wikidata_iso639_codes(iso_639_3_code);

create view bible_version_language_wikidata as
  select version_id, normally_known_as as iso_639_3_code, language_name, entity
    from bible_versions join iso639_aliases on (language = language_alias)
			join wikidata_iso639_codes on (normally_known_as = iso_639_3_code)
 union
  select version_id, iso_639_3_code, language_name, entity
    from bible_versions join wikidata_iso639_codes on (language = iso_639_3_code);


create table wikidata_geo (
  entity varchar -- should be "references wikidata_iso639_codes(entity)" except that it's not unique there,
  country varchar,
  indigenous_to_name varchar,
  indigenous_to_entity varchar,
  latitude float,
  longitude float,
  location_entity varchar,
  location_name varchar
);

create table tokenisation_methods (
  tokenisation_method_id varchar primary key
);
insert into tokenisation_methods (tokenisation_method_id) values ('unigram');
insert into tokenisation_methods (tokenisation_method_id) values ('bigram');
insert into tokenisation_methods (tokenisation_method_id) values ('trigram');
insert into tokenisation_methods (tokenisation_method_id) values ('uni_token');
insert into tokenisation_methods (tokenisation_method_id) values ('bi_token');
insert into tokenisation_methods (tokenisation_method_id) values ('tri_token');
insert into tokenisation_methods (tokenisation_method_id) values ('quad_token');

create table vocabulary_extractions (
  bible_version_id int references bible_versions,
  tokenisation_method_id varchar references tokenisation_methods,
  lemma varchar not null,
  gender varchar not null references koine_greek_genders(gender), --have to add these constraints
  noun_case varchar not null references koine_greek_cases(noun_case), --have to add these constraints
  noun_number varchar not null references koine_greek_noun_numbers(noun_number), --have to add these constraints
  translation_in_target_language varchar,
  binomial_test_p_score float,
  neg_log_binomial_test_p_score float,
  appearances int,
  total_verses_in_translation int,
  probability_of_seeing_this_word float,
  count_we_saw int,
  number_of_places_we_saw_the_lemma int,
  confidence float,
  is_correct boolean,
  extraction_timestamp timestamp default current_timestamp,
  is_replacement boolean default false -- recording whether extract_vocab replaced a pre-existing value
);
alter table vocabulary_extractions add primary key (bible_version_id, tokenisation_method_id, lemma, gender, noun_case, noun_number);
create index on vocabulary_extractions(lemma, gender, noun_case, noun_number, tokenisation_method_id);
create index on vocabulary_extractions(bible_version_id, tokenisation_method_id);
create index on vocabulary_extractions(bible_version_id) where is_replacement;


create materialized view vocabulary_sizes as
SELECT vocabulary_extractions.bible_version_id,
    vocabulary_extractions.tokenisation_method_id,
    bible_versions.language,
    bible_versions.version_name,
    count(*) AS number_of_translated_lemmas,
    min(confidence) as min_confidence,
    max(confidence) as max_confidence,
    avg(confidence) as mean_confidence,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY confidence) as median_confidence,

    min(neg_log_binomial_test_p_score) as min_neg_log_binominal_test_p_score,
    max(neg_log_binomial_test_p_score) as max_neg_log_binominal_test_p_score,
    avg(neg_log_binomial_test_p_score) as mean_neg_log_binominal_test_p_score,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY neg_log_binomial_test_p_score) as median_neg_log_binomial_test_p_score

   FROM vocabulary_extractions
     JOIN bible_versions ON vocabulary_extractions.bible_version_id = bible_versions.version_id
  WHERE vocabulary_extractions.confidence > 1::double precision
  GROUP BY vocabulary_extractions.bible_version_id, vocabulary_extractions.tokenisation_method_id,
  bible_versions.language, bible_versions.version_name;

create index on vocabulary_sizes(bible_version_id, language, version_name);
create unique index on vocabulary_sizes(bible_version_id, language, version_name, tokenisation_method_id);
create index on vocabulary_sizes(tokenisation_method_id);

-- remember to refresh it later


create materialized view vocabulary_sizes_crosstab as
  select v.bible_version_id,
	 v.language,
	 v.version_name,
	 unitoken.number_of_translated_lemmas as unitoken_number_of_translated_lemmas,
	 unitoken.min_confidence as unitoken_min_confidence,
	 unitoken.max_confidence as unitoken_max_confidence,
	 unitoken.mean_confidence        as unitoken_mean_confidence,
	 unitoken.median_confidence as unitoken_median_confidence,
	 unitoken.min_neg_log_binominal_test_p_score as unitoken_min_neg_log_binominal_test_p_score,
	 unitoken.max_neg_log_binominal_test_p_score as unitoken_max_neg_log_binominal_test_p_score,
	 unitoken.mean_neg_log_binominal_test_p_score as unitoken_mean_neg_log_binominal_test_p_score,
	 unitoken.median_neg_log_binomial_test_p_score as unitoken_median_neg_log_binomial_test_p_score,

	 bitoken.number_of_translated_lemmas as bitoken_number_of_translated_lemmas,
	 bitoken.min_confidence as bitoken_min_confidence,
	 bitoken.max_confidence as bitoken_max_confidence,
	 bitoken.mean_confidence        as bitoken_mean_confidence,
	 bitoken.median_confidence as bitoken_median_confidence,
	 bitoken.min_neg_log_binominal_test_p_score as bitoken_min_neg_log_binominal_test_p_score,
	 bitoken.max_neg_log_binominal_test_p_score as bitoken_max_neg_log_binominal_test_p_score,
	 bitoken.mean_neg_log_binominal_test_p_score as bitoken_mean_neg_log_binominal_test_p_score,
	 bitoken.median_neg_log_binomial_test_p_score as bitoken_median_neg_log_binomial_test_p_score,

	 tritoken.number_of_translated_lemmas as tritoken_number_of_translated_lemmas,
	 tritoken.min_confidence as tritoken_min_confidence,
	 tritoken.max_confidence as tritoken_max_confidence,
	 tritoken.mean_confidence        as tritoken_mean_confidence,
	 tritoken.median_confidence as tritoken_median_confidence,
	 tritoken.min_neg_log_binominal_test_p_score as tritoken_min_neg_log_binominal_test_p_score,
	 tritoken.max_neg_log_binominal_test_p_score as tritoken_max_neg_log_binominal_test_p_score,
	 tritoken.mean_neg_log_binominal_test_p_score as tritoken_mean_neg_log_binominal_test_p_score,
	 tritoken.median_neg_log_binomial_test_p_score as tritoken_median_neg_log_binomial_test_p_score,

	 quadtoken.number_of_translated_lemmas as quadtoken_number_of_translated_lemmas,
	 quadtoken.min_confidence as quadtoken_min_confidence,
	 quadtoken.max_confidence as quadtoken_max_confidence,
	 quadtoken.mean_confidence        as quadtoken_mean_confidence,
	 quadtoken.median_confidence as quadtoken_median_confidence,
	 quadtoken.min_neg_log_binominal_test_p_score as quadtoken_min_neg_log_binominal_test_p_score,
	 quadtoken.max_neg_log_binominal_test_p_score as quadtoken_max_neg_log_binominal_test_p_score,
	 quadtoken.mean_neg_log_binominal_test_p_score  as quadtoken_mean_neg_log_binominal_test_p_score,
	 quadtoken.median_neg_log_binomial_test_p_score as quadtoken_median_neg_log_binomial_test_p_score,

	 trigram.number_of_translated_lemmas as trigram_number_of_translated_lemmas,
	 trigram.min_confidence as trigram_min_confidence,
	 trigram.max_confidence as trigram_max_confidence,
	 trigram.mean_confidence        as trigram_mean_confidence,
	 trigram.median_confidence as trigram_median_confidence,
	 trigram.min_neg_log_binominal_test_p_score as trigram_min_neg_log_binominal_test_p_score,
	 trigram.max_neg_log_binominal_test_p_score as trigram_max_neg_log_binominal_test_p_score,
	 trigram.mean_neg_log_binominal_test_p_score as trigram_mean_neg_log_binominal_test_p_score,
	 trigram.median_neg_log_binomial_test_p_score as trigram_median_neg_log_binomial_test_p_score,

	 bigram.number_of_translated_lemmas as bigram_number_of_translated_lemmas,
	 bigram.min_confidence as bigram_min_confidence,
	 bigram.max_confidence as bigram_max_confidence,
	 bigram.mean_confidence        as bigram_mean_confidence,
	 bigram.median_confidence as bigram_median_confidence,
	 bigram.min_neg_log_binominal_test_p_score as bigram_min_neg_log_binominal_test_p_score,
	 bigram.max_neg_log_binominal_test_p_score as bigram_max_neg_log_binominal_test_p_score,
	 bigram.mean_neg_log_binominal_test_p_score as bigram_mean_neg_log_binominal_test_p_score,
	 bigram.median_neg_log_binomial_test_p_score as bigram_median_neg_log_binomial_test_p_score,

	 unigram.number_of_translated_lemmas as unigram_number_of_translated_lemmas,
	 unigram.min_confidence as unigram_min_confidence,
	 unigram.max_confidence as unigram_max_confidence,
	 unigram.mean_confidence        as unigram_mean_confidence,
	 unigram.median_confidence as unigram_median_confidence,
	 unigram.min_neg_log_binominal_test_p_score as unigram_min_neg_log_binominal_test_p_score,
	 unigram.max_neg_log_binominal_test_p_score as unigram_max_neg_log_binominal_test_p_score,
	 unigram.mean_neg_log_binominal_test_p_score as unigram_mean_neg_log_binominal_test_p_score,
	 unigram.median_neg_log_binomial_test_p_score as unigram_median_neg_log_binomial_test_p_score
  from vocabulary_sizes as v join
       vocabulary_sizes as unitoken using (bible_version_id, language, version_name) join
       vocabulary_sizes as bitoken using (bible_version_id, language, version_name) join
       vocabulary_sizes as tritoken using (bible_version_id, language, version_name) join
       vocabulary_sizes as quadtoken using (bible_version_id, language, version_name) join
       vocabulary_sizes as unigram using (bible_version_id, language, version_name) join
       vocabulary_sizes as bigram using (bible_version_id, language, version_name) join
       vocabulary_sizes as trigram using (bible_version_id, language, version_name)
 where unitoken.tokenisation_method_id = 'uni_token'
   and bitoken.tokenisation_method_id = 'bi_token'
   and tritoken.tokenisation_method_id = 'tri_token'
   and quadtoken.tokenisation_method_id = 'quad_token'
   and unigram.tokenisation_method_id = 'unigram'
   and bigram.tokenisation_method_id = 'bigram'
   and trigram.tokenisation_method_id = 'trigram'   ;


create materialized view lemma_translation_counts as
  select lemma,
	 gender, noun_case, noun_number,
	 tokenisation_method_id,
	 count(*) as number_of_translations
   from vocabulary_extractions
  group by lemma, gender, noun_case, noun_number, tokenisation_method_id;

create table machine_learning_methods (
    ml_method varchar primary key
);
insert into machine_learning_methods values ('GlobalPadicLinear');
insert into machine_learning_methods values ('GlobalSiegel');
insert into machine_learning_methods values ('LocalPadicLinear');
insert into machine_learning_methods values ('LocalEuclideanSiegel');
insert into machine_learning_methods values ('HybridSiegel');

create table machine_learning_morphology_scoring (
    mlm_score_id serial primary key,
    bible_version_id int            references bible_versions (version_id),
    tokenisation_method_id varchar  references tokenisation_methods(tokenisation_method_id),
    calculation_algorithm varchar   references machine_learning_methods(ml_method),
    algorithm_region_size_parameter int,
    result_version varchar,
    answers_correct int not null check (answers_correct >= 0),
    answers_wrong int not null check (answers_wrong >= 0),
    total_vocab_size_checked int not null check (total_vocab_size_checked >= 0) ,
    when_added date default current_date,
    CONSTRAINT algorithm_region_compat check (calculation_algorithm ilike 'Global%' or algorithm_region_size_parameter is not null),
    CONSTRAINT all_vocab_accounted_for check (answers_correct + answers_wrong = total_vocab_size_checked)
);
create index on machine_learning_morphology_scoring (bible_version_id, tokenisation_method_id,
							    calculation_algorithm, algorithm_region_size_parameter,
							    result_version);

create unique index on machine_learning_morphology_scoring (
       bible_version_id, tokenisation_method_id,
       calculation_algorithm, algorithm_region_size_parameter,
       result_version) where calculation_algorithm not like 'Global%';
create unique index on machine_learning_morphology_scoring (
       bible_version_id, tokenisation_method_id,
       calculation_algorithm, result_version) where calculation_algorithm like 'Global%';



create view broad_results_across_all_languages as
 select calculation_algorithm,
	avg(100.0 * answers_correct / nullif(total_vocab_size_checked, 0)) as percentage_correct_across_all_languages
   from machine_learning_morphology_scoring
   join bible_versions on (bible_version_id = version_id)
  group by calculation_algorithm;


create table language_orthography (
  iso_639_3_code varchar primary key, -- should be foreign key actually
  word_based boolean not null,
  alphabetic boolean not null,
  best_tokenisation_method not null varchar references tokenisation_methods(tokenisation_method_id)
);



create schema vocab_lists;

create table human_scoring_assessment_options (assessment varchar primary key);
insert into human_scoring_assessment_options (assessment) values ('correct');
insert into human_scoring_assessment_options (assessment) values ('incorrect');
insert into human_scoring_assessment_options (assessment) values ('close');

create table human_scoring_of_vocab_lists (
 language varchar, -- should reference iso_639_3 code
 lemma varchar not null,
 gender varchar not null references koine_greek_genders(gender),
 noun_case varchar not null references koine_greek_cases(noun_case),
 noun_number varchar not null references koine_greek_noun_numbers(noun_number),
 target_language_assessed_word varchar,
 assessment varchar references human_scoring_assessment_options (assessment)
);

alter table human_scoring_of_vocab_lists add primary key (language, lemma, gender, noun_case, noun_number);
