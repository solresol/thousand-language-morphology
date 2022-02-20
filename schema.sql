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


create table wikidata_content (
  entity varchar primary key,
  wikidata_content jsonb
);

create view wikidata_containment as
  select jsonb_array_elements(wikidata_content->'entities'->entity->'claims'->'P279')->'mainsnak'->'datavalue'->'value'->>'id' as entity from wikidata_content;

create view wikidata_labels as
  select entity, wikidata_content->'entities'->entity->'labels'->'en'->>'value' as entity_label from wikidata_content;


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
  is_replacement boolean default false, -- recording whether extract_vocab replaced a pre-existing value
  log_confidence float generated always as (log10 (confidence)) stored
);
alter table vocabulary_extractions add primary key (bible_version_id, tokenisation_method_id, lemma, gender, noun_case, noun_number);
create index on vocabulary_extractions(lemma, gender, noun_case, noun_number, tokenisation_method_id);
create index on vocabulary_extractions(bible_version_id, tokenisation_method_id);
create index on vocabulary_extractions(bible_version_id) where is_replacement;



create table language_orthography (
  iso_639_3_code varchar primary key, -- should be foreign key actually
  word_based boolean not null,
  alphabetic boolean not null,
  best_tokenisation_method varchar not null references tokenisation_methods(tokenisation_method_id)
);




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
insert into machine_learning_methods values ('Y_Equals_X');

create table machine_learning_morphology_scoring (
    mlm_score_id serial primary key,
    bible_version_id int        not null references bible_versions (version_id),
    tokenisation_method_id varchar not null  references tokenisation_methods(tokenisation_method_id),
    calculation_algorithm varchar not null  references machine_learning_methods(ml_method),
    algorithm_region_size_parameter int,
    result_version varchar not null,
    answers_correct int not null check (answers_correct >= 0),
    answers_wrong int not null check (answers_wrong >= 0),
    total_vocab_size_checked int not null check (total_vocab_size_checked >= 0) ,
    when_added date default current_date,
    computation_time float,
    computation_hostname varchar,
    proportion_correct float generated always as ((1.0*answers_correct)/(nullif(answers_correct+answers_wrong,0))) stored,
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

alter table human_scoring_of_vocab_lists add primary key (language, lemma, gender, noun_case, noun_number;

create view human_scoring_of_vocab_lists_summary as select language, language_name, avg(case when assessment = 'incorrect' then 0 else 1 end) as proportion_correct from human_scoring_of_vocab_lists left join wikidata_iso639_codes on (language = iso_639_3_code) group by language, language_name order by language;
);

create table vocabulary_pairing_tests (
 vocabulary_pairing_test_id serial primary key,
 tokenisation_method_id varchar not null references tokenisation_methods(tokenisation_method_id),
 bible_version_id1 int not null references bible_versions(version_id),
 bible_version_id2 int not null references bible_versions(version_id),
 mann_whitney_statistic float,
 mann_whitney_pvalue float,
 confidence_correlation float,
 log_confidence_correlation float,
 confidence_spearman_correlation float,
 calculation_timestamp timestamp default current_timestamp
);
create unique index on vocabulary_pairing_tests (
 tokenisation_method_id, bible_version_id1, bible_version_id2
);
create index on vocabulary_pairing_tests (bible_version_id1);
create index on vocabulary_pairing_tests (bible_version_id2);

create view language_pairing_links as
  select v1.language as language1,
	 v2.language as language2,
	 tokenisation_method_id,
	 max(confidence_correlation) as confidence_correlation,
	 max(log_confidence_correlation) as log_confidence_correlation,
	 max(confidence_spearman_correlation) as confidence_spearman_correlation
    from vocabulary_pairing_tests join bible_versions as v1
	    on (v1.version_id = bible_version_id1)
	    join bible_versions as v2 on (v2.version_id = bible_version_id2)
  group by tokenisation_method_id, v1.language, v2.language;





create view vocabulary_extraction_ranks as
 select bible_version_id,
	lemma,
	gender,
	noun_case,
	noun_number,
	tokenisation_method_id,
	confidence,
	log_confidence,
	rank() over (partition by bible_version_id, tokenisation_method_id order by confidence) as confidence_rank
   from vocabulary_extractions;




-- -- Note that this next line creates a materialized view that can only be refreshed on a very large system
-- create materialized view vocabulary_extraction_correlations_materialized_views as
--   select v1.bible_version_id as bible_version_id1,
--          v2.bible_version_id as bible_version_id2,
--	 tokenisation_method_id,
--	 corr(v1.log_confidence, v2.log_confidence) as log_confidence_correlation,
--	 corr(v1.confidence, v2.confidence) as confidence_correlation,
--	 corr(v1.confidence_rank, v2.confidence_rank) as confidence_spearman_correlation
--     from vocabulary_extraction_ranks as v1 join vocabulary_extraction_ranks as v2
--          using (lemma, gender, noun_case, noun_number, tokenisation_method_id)
-- group by bible_version_id1, bible_version_id2, tokenisation_method_id;

-- create table vocabulary_extraction_correlations as
--  select * from vocabulary_extraction_correlations_materialized_views;




----------------------------------------------------------------------

create view language_structure_identification_algorithm as (
with unitoken_results as (
select language, bible_version_id,
   count(*) as number_of_unitokens_extracted,
   count(distinct translation_in_target_language) as number_of_distinct_unitokens_extracted
FROM vocabulary_extractions
     JOIN bible_versions ON vocabulary_extractions.bible_version_id = bible_versions.version_id
where tokenisation_method_id = 'uni_token'
group by language, bible_version_id
),
unigram_results as (
select language, bible_version_id,
   count(*) as number_of_unigrams_extracted
   FROM vocabulary_extractions
     JOIN bible_versions ON vocabulary_extractions.bible_version_id = bible_versions.version_id
where tokenisation_method_id = 'unigram'
group by language, bible_version_id
),
unitoken_ranked_results as (
 select language, bible_version_id, number_of_unitokens_extracted,
  number_of_distinct_unitokens_extracted,
  row_number() over (partition by language order by
     number_of_distinct_unitokens_extracted,
     number_of_unitokens_extracted,
     bible_version_id
     ) as ranking
  from unitoken_results
),
unigram_ranked_results as (
 select language, bible_version_id, number_of_unigrams_extracted,
  row_number() over (partition by language order by
     number_of_unigrams_extracted,
     bible_version_id
     ) as ranking
  from unigram_results
)
select language,
  unigram_ranked_results.bible_version_id =
    unitoken_ranked_results.bible_version_id as used_different_versions,
    number_of_unitokens_extracted,
    number_of_distinct_unitokens_extracted,
    number_of_distinct_unitokens_extracted / (1.0 * number_of_unitokens_extracted) as unitoken_diversity_ratio,
    number_of_unigrams_extracted
 from unitoken_ranked_results
  join unigram_ranked_results using (language)
  where unigram_ranked_results.ranking = 1
   and unitoken_ranked_results.ranking = 1
   )
   ;

create view language_structure_identification_results as
  select language,
	 case
	   when number_of_unigrams_extracted > 150 then 'unigram'
	   when unitoken_diversity_ratio > 0.5 then 'uni_token'
	   else 'quad_token'
	 end as tokenisation_method_id,
	 case
	   when number_of_unigrams_extracted > 150 then 'alphabetic with word markers'
	   when unitoken_diversity_ratio > 0.5 then 'non-alphabetic'
	   else 'alphabetic without word markers'
	 end as language_structure
   from language_structure_identification_algorithm;


create materialized view translation_exploration as
select language, tokenisation_method_id, lemma,
bible_version_id, gender, noun_case, noun_number, confidence,
binomial_test_p_score,
neg_log_binomial_test_p_score,
translation_in_target_language
from vocabulary_extractions
join bible_versions on (bible_version_id = version_id)
join language_structure_identification_results using (language, tokenisation_method_id)
where confidence is not null
and confidence != 'NaN'
order by confidence desc;



----------------------------------------------------------------------

create materialized view likely_valid_vocabulary_extractions as
SELECT bible_versions.language,
    vocabulary_extractions.bible_version_id,
    vocabulary_extractions.lemma,
    vocabulary_extractions.gender,
    vocabulary_extractions.noun_case,
    vocabulary_extractions.noun_number,
    vocabulary_extractions.translation_in_target_language,
    vocabulary_extractions.confidence
   FROM vocabulary_extractions
     JOIN bible_versions ON vocabulary_extractions.bible_version_id = bible_versions.version_id
     JOIN language_structure_identification_results USING (language, tokenisation_method_id);

create materialized view summary_of_vocabulary_extractions as
   with foo as (select language, bible_version_id, count(*) from likely_valid_vocabulary_extractions  group by bible_version_id, language)
   select language, max("count") from foo group by language;



----------------------------------------------------------------------

create table language_families (
  language_code varchar primary key, -- I should make this reference some other table
  language_family varchar
);


insert into language_families (language_code, language_family) values ('aeb', 'Afro-Asiatic');
insert into language_families (language_code, language_family) values ('arb', 'Afro-Asiatic');
insert into language_families (language_code, language_family) values ('ary', 'Afro-Asiatic');
insert into language_families (language_code, language_family) values ('ben', 'Indo-European');
insert into language_families (language_code, language_family) values ('ceb', 'Austronesian');
insert into language_families (language_code, language_family) values ('deu', 'Indo-European');
insert into language_families (language_code, language_family) values ('dob', 'Austronesian');
insert into language_families (language_code, language_family) values ('epo', 'Artificial');
insert into language_families (language_code, language_family) values ('fon', 'Niger-Congo');
insert into language_families (language_code, language_family) values ('fra', 'Indo-European');
insert into language_families (language_code, language_family) values ('gkp', 'Niger-Congo');
insert into language_families (language_code, language_family) values ('gup', 'Arnhem');
insert into language_families (language_code, language_family) values ('hil', 'Austronesian');
insert into language_families (language_code, language_family) values ('hin', 'Indo-European');
insert into language_families (language_code, language_family) values ('hmo', 'Austronesian');
insert into language_families (language_code, language_family) values ('ibo', 'Niger-Congo');
insert into language_families (language_code, language_family) values ('kij', 'Austronesian');
insert into language_families (language_code, language_family) values ('kpr', 'Trans-New Guinea');
insert into language_families (language_code, language_family) values ('lid', 'Austronesian');
insert into language_families (language_code, language_family) values ('lsm', 'Niger-Congo');
insert into language_families (language_code, language_family) values ('lug', 'Niger-Congo');
insert into language_families (language_code, language_family) values ('mar', 'Indo-European');
insert into language_families (language_code, language_family) values ('med', 'Trans-New Guinea');
insert into language_families (language_code, language_family) values ('mev', 'Niger-Congo');
insert into language_families (language_code, language_family) values ('nyn', 'Niger-Congo');
insert into language_families (language_code, language_family) values ('shu', 'Afro-Asiatic');
insert into language_families (language_code, language_family) values ('shu_rom', 'Afro-Asiatic');
insert into language_families (language_code, language_family) values ('sin', 'Indo-European');
insert into language_families (language_code, language_family) values ('swh', 'Niger-Congo');
insert into language_families (language_code, language_family) values ('tbc', 'Austronesian');
insert into language_families (language_code, language_family) values ('tel', 'Dravidian');
insert into language_families (language_code, language_family) values ('teo', 'Nilo-Saharan');
insert into language_families (language_code, language_family) values ('tgl', 'Austronesian');
insert into language_families (language_code, language_family) values ('twi', 'Niger-Congo');
insert into language_families (language_code, language_family) values ('urd', 'Indo-European');
insert into language_families (language_code, language_family) values ('xog', 'Niger-Congo');
insert into language_families (language_code, language_family) values ('yor', 'Niger-Congo');

-- More needs to be done with that...

----------------------------------------------------------------------

create materialized view confidence_vs_reality as
select human_scoring_of_vocab_lists.language,
 human_scoring_of_vocab_lists.lemma,
 human_scoring_of_vocab_lists.gender,
 human_scoring_of_vocab_lists.noun_case,
 human_scoring_of_vocab_lists.noun_number, target_language_assessed_word,
 assessment,
 case when assessment = 'correct' then 1
      when assessment = 'close' then 1
      else 0
 end as assessment_as_number,
 10.0^sum(log10(confidence)) as leaftop_confidence
from
  human_scoring_of_vocab_lists
  join
  translation_exploration
  on ((translation_in_target_language = target_language_assessed_word)
   and
    (human_scoring_of_vocab_lists.language = translation_exploration.language))
group by human_scoring_of_vocab_lists.language,
human_scoring_of_vocab_lists.lemma,
human_scoring_of_vocab_lists.gender,
human_scoring_of_vocab_lists.noun_case,
human_scoring_of_vocab_lists.noun_number, target_language_assessed_word, assessment;


-- Mungu -- swahili. Marked as incorrect?
--  fra      | ἄρτος         | masculine | accusative | plural      | pains                         | incorrect
--  swh      | σημεῖον       | neuter    | nominative | singular    | ishara                        | incorrect  |                    0 |     115259970030.05214
 -- happens twice

--  fra      | γάμος         | masculine | accusative | singular    | noces                         | incorrect  |                    0 |     1162990.3303605858
--  fra      | γάμος         | masculine | accusative | plural      | noces                         | incorrect  |                    0 |
-- fra      | πνεῦμα        | neuter    | nominative | plural      | esprits                       | incorrect  |

--  swh      | ἀργύριον      | neuter    | accusative | singular    | fedha                         | incorrect  |                    0 |
--  swh      | ἄρτος         | masculine | nominative | plural      | mikate                        | incorrect

--  lug      | ἀδελφός       | masculine | accusative | singular    | muganda                       | incorrect  |

--  ben      | ὀφθαλμός      | masculine | accusative | plural      | চোখ                           | incorrect  |                    0 |     2442440.7445191215
--  ben      | ὀφθαλμός      | masculine | nominative | plural      | চোখ                           | incorrect  |                    0 |     2442440.7445191164
--  ben      | ὀφθαλμός      | masculine | nominative | singular    | চোখ                           | incorrect  |                    0 |



-- First real one...
--  ben      | τέκνον        | neuter    | accusative | singular    | ভাই                           | incorrect  |
--  tgl      | ὀψάριον       | neuter    | accusative | singular    | tinapay


create view confidence_vs_reality_roc as
select
 language_family, leaftop_confidence,
 avg(assessment_as_number) over (order by leaftop_confidence desc) as global_avg,
 count(assessment_as_number) over (order by leaftop_confidence desc) as global_number_of_terms,
 avg(assessment_as_number) over (partition by language_family order by leaftop_confidence desc) as family_avg,
 count(assessment_as_number) over (partition by language_family order by leaftop_confidence desc) as family_number_of_terms,
 count(*) over (partition by language_family) as family_best_possible
 from confidence_vs_reality join language_families on (language = language_code) order by leaftop_confidence desc;




create view hardness_to_translate as
select
 lemma, english_translation, avg(case when assessment = 'incorrect' then 0 else 1 end) as proportion_correct,
 percentile_cont(0.5) WITHIN GROUP (ORDER BY leaftop_confidence) as median_leaftop_confidence
 from confidence_vs_reality join common_noun_baker_translations using (lemma)
 group by lemma, english_translation;






create table swadesh (
       swadesh_number int primary key,
       swadesh_term varchar unique not null
);

create table swadesh_mapping(
       swadesh_number int references swadesh,
       lemma varchar references common_noun_baker_translations
);

insert into swadesh (swadesh_number, swadesh_term) values (    1, 'I');
insert into swadesh (swadesh_number, swadesh_term) values (    2, 'you (singular)');
insert into swadesh (swadesh_number, swadesh_term) values (    3, 'he');
insert into swadesh (swadesh_number, swadesh_term) values (    4, 'we');
insert into swadesh (swadesh_number, swadesh_term) values (    5, 'you (plural)');
insert into swadesh (swadesh_number, swadesh_term) values (    6, 'they');
insert into swadesh (swadesh_number, swadesh_term) values (    7, 'this');
insert into swadesh (swadesh_number, swadesh_term) values (    8, 'that');
insert into swadesh (swadesh_number, swadesh_term) values (    9, 'here');
insert into swadesh (swadesh_number, swadesh_term) values (   10, 'there');
insert into swadesh (swadesh_number, swadesh_term) values (   11, 'who');
insert into swadesh (swadesh_number, swadesh_term) values (   12, 'what');
insert into swadesh (swadesh_number, swadesh_term) values (   13, 'where');
insert into swadesh (swadesh_number, swadesh_term) values (   14, 'when');
insert into swadesh (swadesh_number, swadesh_term) values (   15, 'how');
insert into swadesh (swadesh_number, swadesh_term) values (   16, 'not');
insert into swadesh (swadesh_number, swadesh_term) values (   17, 'all');
insert into swadesh (swadesh_number, swadesh_term) values (   18, 'many');
insert into swadesh (swadesh_number, swadesh_term) values (   19, 'some');
insert into swadesh (swadesh_number, swadesh_term) values (   20, 'few');
insert into swadesh (swadesh_number, swadesh_term) values (   21, 'other');
insert into swadesh (swadesh_number, swadesh_term) values (   22, 'one');
insert into swadesh (swadesh_number, swadesh_term) values (   23, 'two');
insert into swadesh (swadesh_number, swadesh_term) values (   24, 'three');
insert into swadesh (swadesh_number, swadesh_term) values (   25, 'four');
insert into swadesh (swadesh_number, swadesh_term) values (   26, 'five');
insert into swadesh (swadesh_number, swadesh_term) values (   27, 'big');
insert into swadesh (swadesh_number, swadesh_term) values (   28, 'long');
insert into swadesh (swadesh_number, swadesh_term) values (   29, 'wide');
insert into swadesh (swadesh_number, swadesh_term) values (   30, 'thick');
insert into swadesh (swadesh_number, swadesh_term) values (   31, 'heavy');
insert into swadesh (swadesh_number, swadesh_term) values (   32, 'small');
insert into swadesh (swadesh_number, swadesh_term) values (   33, 'short');
insert into swadesh (swadesh_number, swadesh_term) values (   34, 'narrow');
insert into swadesh (swadesh_number, swadesh_term) values (   35, 'thin');
insert into swadesh (swadesh_number, swadesh_term) values (   36, 'woman',  null);
insert into swadesh_mapping(swadesh_number, lemma) values (36, 'γυνή');
insert into swadesh (swadesh_number, swadesh_term) values (   37, 'man (adult male)');
insert into swadesh_mapping(swadesh_number, lemma) values (37, 'ἀνήρ');
insert into swadesh_mapping(swadesh_number, lemma) values (37, 'ἄνθρωπος');
insert into swadesh (swadesh_number, swadesh_term) values (   38, 'man (human being)',null);
insert into swadesh_mapping(swadesh_number, lemma) values (38, 'ἀνήρ');
insert into swadesh_mapping(swadesh_number, lemma) values (38, 'ἄνθρωπος');
insert into swadesh (swadesh_number, swadesh_term) values (   39, 'child');
insert into swadesh_mapping(swadesh_number, lemma) values (39, 'παιδίον');
insert into swadesh_mapping(swadesh_number, lemma) values (39, 'παῖς');
insert into swadesh_mapping(swadesh_number, lemma) values (39, 'τέκνον');
insert into swadesh (swadesh_number, swadesh_term) values (   40, 'wife');
insert into swadesh_mapping(swadesh_number, lemma) values (40, 'γυνή');
insert into swadesh (swadesh_number, swadesh_term) values (   41, 'husband');
insert into swadesh_mapping(swadesh_number, lemma) values (41, 'ἀνήρ');
insert into swadesh (swadesh_number, swadesh_term) values (   42, 'mother');
insert into swadesh_mapping(swadesh_number, lemma) values (42, 'μήτηρ');
insert into swadesh (swadesh_number, swadesh_term) values (   43, 'father');
insert into swadesh_mapping(swadesh_number, lemma) values (43, 'πατήρ');
insert into swadesh (swadesh_number, swadesh_term) values (   44, 'animal');
insert into swadesh (swadesh_number, swadesh_term) values (   45, 'fish');
insert into swadesh_mapping(swadesh_number, lemma) values (45, 'ἰχθύς');
insert into swadesh_mapping(swadesh_number, lemma) values (45, 'ὀψάριον');
insert into swadesh (swadesh_number, swadesh_term) values (   46, 'bird');
insert into swadesh (swadesh_number, swadesh_term) values (   47, 'dog');
insert into swadesh (swadesh_number, swadesh_term) values (   48, 'louse');
insert into swadesh (swadesh_number, swadesh_term) values (   49, 'snake');
insert into swadesh (swadesh_number, swadesh_term) values (   50, 'worm');
insert into swadesh (swadesh_number, swadesh_term) values (   51, 'tree');
insert into swadesh_mapping(swadesh_number, lemma) values (51, 'δένδρον');
insert into swadesh (swadesh_number, swadesh_term) values (   52, 'forest');
insert into swadesh (swadesh_number, swadesh_term) values (   53, 'stick');
insert into swadesh (swadesh_number, swadesh_term) values (   54, 'fruit');
insert into swadesh_mapping(swadesh_number, lemma) values (54, 'καρπός');
insert into swadesh (swadesh_number, swadesh_term) values (   55, 'seed');
insert into swadesh (swadesh_number, swadesh_term) values (   56, 'leaf');
insert into swadesh (swadesh_number, swadesh_term) values (   57, 'root');
insert into swadesh (swadesh_number, swadesh_term) values (   58, 'bark (of a tree)');
insert into swadesh (swadesh_number, swadesh_term) values (   59, 'flower');
insert into swadesh (swadesh_number, swadesh_term) values (   60, 'grass');
insert into swadesh (swadesh_number, swadesh_term) values (   61, 'rope');
insert into swadesh (swadesh_number, swadesh_term) values (   62, 'skin');
insert into swadesh (swadesh_number, swadesh_term) values (   63, 'meat');
insert into swadesh (swadesh_number, swadesh_term) values (   64, 'blood');
insert into swadesh (swadesh_number, swadesh_term) values (   65, 'bone');
insert into swadesh (swadesh_number, swadesh_term) values (   66, 'fat (noun)');
insert into swadesh (swadesh_number, swadesh_term) values (   67, 'egg');
insert into swadesh (swadesh_number, swadesh_term) values (   68, 'horn');
insert into swadesh (swadesh_number, swadesh_term) values (   69, 'tail');
insert into swadesh (swadesh_number, swadesh_term) values (   70, 'feather');
insert into swadesh (swadesh_number, swadesh_term) values (   71, 'hair');
insert into swadesh_mapping(swadesh_number, lemma) values (71, 'θρίξ');
insert into swadesh (swadesh_number, swadesh_term) values (   72, 'head');
insert into swadesh_mapping(swadesh_number, lemma) values (72, 'κεφαλή');
insert into swadesh (swadesh_number, swadesh_term) values (   73, 'ear');
insert into swadesh_mapping(swadesh_number, lemma) values (73, 'οὖς');
insert into swadesh (swadesh_number, swadesh_term) values (   74, 'eye');
insert into swadesh_mapping(swadesh_number, lemma) values (74, 'ὀφθαλμός');
insert into swadesh (swadesh_number, swadesh_term) values (   75, 'nose');
insert into swadesh (swadesh_number, swadesh_term) values (   76, 'mouth');
insert into swadesh (swadesh_number, swadesh_term) values (   77, 'tooth');
insert into swadesh_mapping(swadesh_number, lemma) values (77, 'ὀδούς');
insert into swadesh (swadesh_number, swadesh_term) values (   78, 'tongue (organ)');
insert into swadesh (swadesh_number, swadesh_term) values (   79, 'fingernail');
insert into swadesh (swadesh_number, swadesh_term) values (   80, 'foot');
insert into swadesh_mapping(swadesh_number, lemma) values (80, 'πούς');
insert into swadesh (swadesh_number, swadesh_term) values (   81, 'leg');
insert into swadesh (swadesh_number, swadesh_term) values (   82, 'knee');
insert into swadesh (swadesh_number, swadesh_term) values (   83, 'hand');
insert into swadesh_mapping(swadesh_number, lemma) values (83, 'χείρ');
insert into swadesh (swadesh_number, swadesh_term) values (   84, 'wing');
insert into swadesh (swadesh_number, swadesh_term) values (   85, 'belly');
insert into swadesh_mapping(swadesh_number, lemma) values (85, 'κοιλία');
insert into swadesh (swadesh_number, swadesh_term) values (   86, 'guts');
insert into swadesh (swadesh_number, swadesh_term) values (   87, 'neck');
insert into swadesh (swadesh_number, swadesh_term) values (   88, 'back');
insert into swadesh (swadesh_number, swadesh_term) values (   89, 'breast');
insert into swadesh_mapping(swadesh_number, lemma) values (89, 'στῆθος');
insert into swadesh (swadesh_number, swadesh_term) values (   90, 'heart');
insert into swadesh_mapping(swadesh_number, lemma) values (90, 'καρδία');
insert into swadesh (swadesh_number, swadesh_term) values (   91, 'liver');
insert into swadesh (swadesh_number, swadesh_term) values (   92, 'to drink');
insert into swadesh (swadesh_number, swadesh_term) values (   93, 'to eat');
insert into swadesh (swadesh_number, swadesh_term) values (   94, 'to bite');
insert into swadesh (swadesh_number, swadesh_term) values (   95, 'to suck');
insert into swadesh (swadesh_number, swadesh_term) values (   96, 'to spit');
insert into swadesh (swadesh_number, swadesh_term) values (   97, 'to vomit');
insert into swadesh (swadesh_number, swadesh_term) values (   98, 'to blow');
insert into swadesh (swadesh_number, swadesh_term) values (   99, 'to breathe');
insert into swadesh (swadesh_number, swadesh_term) values (  100, 'to laugh');
insert into swadesh (swadesh_number, swadesh_term) values (  101, 'to see');
insert into swadesh (swadesh_number, swadesh_term) values (  102, 'to hear');
insert into swadesh (swadesh_number, swadesh_term) values (  103, 'to know');
insert into swadesh (swadesh_number, swadesh_term) values (  104, 'to think');
insert into swadesh (swadesh_number, swadesh_term) values (  105, 'to smell');
insert into swadesh (swadesh_number, swadesh_term) values (  106, 'to fear');
insert into swadesh (swadesh_number, swadesh_term) values (  107, 'to sleep');
insert into swadesh (swadesh_number, swadesh_term) values (  108, 'to live');
insert into swadesh (swadesh_number, swadesh_term) values (  109, 'to die');
insert into swadesh (swadesh_number, swadesh_term) values (  110, 'to kill');
insert into swadesh (swadesh_number, swadesh_term) values (  111, 'to fight');
insert into swadesh (swadesh_number, swadesh_term) values (  112, 'to hunt');
insert into swadesh (swadesh_number, swadesh_term) values (  113, 'to hit');
insert into swadesh (swadesh_number, swadesh_term) values (  114, 'to cut');
insert into swadesh (swadesh_number, swadesh_term) values (  115, 'to split');
insert into swadesh (swadesh_number, swadesh_term) values (  116, 'to stab');
insert into swadesh (swadesh_number, swadesh_term) values (  117, 'to scratch');
insert into swadesh (swadesh_number, swadesh_term) values (  118, 'to dig');
insert into swadesh (swadesh_number, swadesh_term) values (  119, 'to swim');
insert into swadesh (swadesh_number, swadesh_term) values (  120, 'to fly');
insert into swadesh (swadesh_number, swadesh_term) values (  121, 'to walk');
insert into swadesh (swadesh_number, swadesh_term) values (  122, 'to come');
insert into swadesh (swadesh_number, swadesh_term) values (  123, 'to lie (as in a bed)');
insert into swadesh (swadesh_number, swadesh_term) values (  124, 'to sit');
insert into swadesh (swadesh_number, swadesh_term) values (  125, 'to stand');
insert into swadesh (swadesh_number, swadesh_term) values (  126, 'to turn (intransitive)');
insert into swadesh (swadesh_number, swadesh_term) values (  127, 'to fall');
insert into swadesh (swadesh_number, swadesh_term) values (  128, 'to give');
insert into swadesh (swadesh_number, swadesh_term) values (  129, 'to hold');
insert into swadesh (swadesh_number, swadesh_term) values (  130, 'to squeeze');
insert into swadesh (swadesh_number, swadesh_term) values (  131, 'to rub');
insert into swadesh (swadesh_number, swadesh_term) values (  132, 'to wash');
insert into swadesh (swadesh_number, swadesh_term) values (  133, 'to wipe');
insert into swadesh (swadesh_number, swadesh_term) values (  134, 'to pull');
insert into swadesh (swadesh_number, swadesh_term) values (  135, 'to push');
insert into swadesh (swadesh_number, swadesh_term) values (  136, 'to throw');
insert into swadesh (swadesh_number, swadesh_term) values (  137, 'to tie');
insert into swadesh (swadesh_number, swadesh_term) values (  138, 'to sew');
insert into swadesh (swadesh_number, swadesh_term) values (  139, 'to count');
insert into swadesh (swadesh_number, swadesh_term) values (  140, 'to say');
insert into swadesh (swadesh_number, swadesh_term) values (  141, 'to sing');
insert into swadesh (swadesh_number, swadesh_term) values (  142, 'to play');
insert into swadesh (swadesh_number, swadesh_term) values (  143, 'to float');
insert into swadesh (swadesh_number, swadesh_term) values (  144, 'to flow');
insert into swadesh (swadesh_number, swadesh_term) values (  145, 'to freeze');
insert into swadesh (swadesh_number, swadesh_term) values (  146, 'to swell');
insert into swadesh (swadesh_number, swadesh_term) values (  147, 'sun');
insert into swadesh (swadesh_number, swadesh_term) values (  148, 'moon');
insert into swadesh (swadesh_number, swadesh_term) values (  149, 'star');
insert into swadesh_mapping(swadesh_number, lemma) values (149, 'ἀστήρ');
insert into swadesh (swadesh_number, swadesh_term) values (  150, 'water');
insert into swadesh_mapping(swadesh_number, lemma) values (150, 'ὕδωρ');
insert into swadesh (swadesh_number, swadesh_term) values (  151, 'rain');
insert into swadesh (swadesh_number, swadesh_term) values (  152, 'river');
insert into swadesh_mapping(swadesh_number, lemma) values (152, 'ποταμός');
insert into swadesh (swadesh_number, swadesh_term) values (  153, 'lake');
insert into swadesh (swadesh_number, swadesh_term) values (  154, 'sea');
insert into swadesh (swadesh_number, swadesh_term) values (  155, 'salt');
insert into swadesh (swadesh_number, swadesh_term) values (  156, 'stone');
insert into swadesh_mapping(swadesh_number, lemma) values (156, 'λίθος');
insert into swadesh (swadesh_number, swadesh_term) values (  157, 'sand');
insert into swadesh (swadesh_number, swadesh_term) values (  158, 'dust');
insert into swadesh (swadesh_number, swadesh_term) values (  159, 'earth');
insert into swadesh (swadesh_number, swadesh_term) values (  160, 'cloud');
insert into swadesh (swadesh_number, swadesh_term) values (  161, 'fog');
insert into swadesh (swadesh_number, swadesh_term) values (  162, 'sky');
insert into swadesh_mapping(swadesh_number, lemma) values (162, 'οὐρανός');
insert into swadesh (swadesh_number, swadesh_term) values (  163, 'wind');
insert into swadesh_mapping(swadesh_number, lemma) values (163, 'ἄνεμος');
insert into swadesh (swadesh_number, swadesh_term) values (  164, 'snow');
insert into swadesh (swadesh_number, swadesh_term) values (  165, 'ice');
insert into swadesh (swadesh_number, swadesh_term) values (  166, 'smoke');
insert into swadesh (swadesh_number, swadesh_term) values (  167, 'fire');
insert into swadesh (swadesh_number, swadesh_term) values (  168, 'ash');
insert into swadesh (swadesh_number, swadesh_term) values (  169, 'to burn');
insert into swadesh (swadesh_number, swadesh_term) values (  170, 'road');
insert into swadesh (swadesh_number, swadesh_term) values (  171, 'mountain');
insert into swadesh_mapping(swadesh_number, lemma) values (171, 'ὄρος');
insert into swadesh (swadesh_number, swadesh_term) values (  172, 'red');
insert into swadesh (swadesh_number, swadesh_term) values (  173, 'green');
insert into swadesh (swadesh_number, swadesh_term) values (  174, 'yellow');
insert into swadesh (swadesh_number, swadesh_term) values (  175, 'white');
insert into swadesh (swadesh_number, swadesh_term) values (  176, 'black');
insert into swadesh (swadesh_number, swadesh_term) values (  177, 'night');
insert into swadesh (swadesh_number, swadesh_term) values (  178, 'day');
insert into swadesh_mapping(swadesh_number, lemma) values (178, 'ἡμέρα');
insert into swadesh (swadesh_number, swadesh_term) values (  179, 'year');
insert into swadesh_mapping(swadesh_number, lemma) values (179, 'ἔτος');
insert into swadesh (swadesh_number, swadesh_term) values (  180, 'warm');
insert into swadesh (swadesh_number, swadesh_term) values (  181, 'cold');
insert into swadesh (swadesh_number, swadesh_term) values (  182, 'full');
insert into swadesh (swadesh_number, swadesh_term) values (  183, 'new');
insert into swadesh (swadesh_number, swadesh_term) values (  184, 'old');
insert into swadesh (swadesh_number, swadesh_term) values (  185, 'good');
insert into swadesh (swadesh_number, swadesh_term) values (  186, 'bad');
insert into swadesh (swadesh_number, swadesh_term) values (  187, 'rotten');
insert into swadesh (swadesh_number, swadesh_term) values (  188, 'dirty');
insert into swadesh (swadesh_number, swadesh_term) values (  189, 'straight');
insert into swadesh (swadesh_number, swadesh_term) values (  190, 'round');
insert into swadesh (swadesh_number, swadesh_term) values (  191, 'sharp (as a knife)');
insert into swadesh (swadesh_number, swadesh_term) values (  192, 'dull (as a knife)');
insert into swadesh (swadesh_number, swadesh_term) values (  193, 'smooth');
insert into swadesh (swadesh_number, swadesh_term) values (  194, 'wet');
insert into swadesh (swadesh_number, swadesh_term) values (  195, 'dry');
insert into swadesh (swadesh_number, swadesh_term) values (  196, 'correct');
insert into swadesh (swadesh_number, swadesh_term) values (  197, 'near');
insert into swadesh (swadesh_number, swadesh_term) values (  198, 'far');
insert into swadesh (swadesh_number, swadesh_term) values (  199, 'right');
insert into swadesh (swadesh_number, swadesh_term) values (  200, 'left');
insert into swadesh (swadesh_number, swadesh_term) values (  201, 'at');
insert into swadesh (swadesh_number, swadesh_term) values (  202, 'in');
insert into swadesh (swadesh_number, swadesh_term) values (  203, 'with');
insert into swadesh (swadesh_number, swadesh_term) values (  204, 'and');
insert into swadesh (swadesh_number, swadesh_term) values (  205, 'if');
insert into swadesh (swadesh_number, swadesh_term) values (  206, 'because');
insert into swadesh (swadesh_number, swadesh_term) values (  207, 'name');


----------------------------------------------------------------------

-- Re-doing the machine language morphology results to match what I described
-- in my thesis

-- I need to create a materialized view for "latest score" first

create materialized view machine_learning_morphology_best_scores as
select language, calculation_algorithm, algorithm_region_size_parameter,
  max(total_vocab_size_checked) as largest_vocab_size_checked,
  max(proportion_correct) as best_score
 from machine_learning_morphology_scoring
 join bible_versions on (version_id = bible_version_id)
 join language_structure_identification_results using (language)
where machine_learning_morphology_scoring.tokenisation_method_id = 'unigram'
  and language_structure_identification_results.tokenisation_method_id = 'unigram'
  group by 1,2,3;

-- Hmm... getting different values for "largest_vocab_size_checked" is very odd.
-- xon

create materialized view machine_learning_morphology_best_score_rankings as
 select language, calculation_algorithm, algorithm_region_size_parameter,
		largest_vocab_size_checked, best_score,
		rank() over (partition by language, calculation_algorithm
			     order by best_score desc, algorithm_region_size_parameter) as ranking
 from machine_learning_morphology_best_scores;

create materialized view machine_learning_morphology_best_parameters_and_scores as
  select language, calculation_algorithm, algorithm_region_size_parameter, largest_vocab_size_checked, best_score
  from machine_learning_morphology_best_score_rankings
  where ranking = 1;

create materialized view machine_learning_morphology_summary as
 select language, global_padic_linear.largest_vocab_size_checked,
	global_padic_linear.best_score as global_padic_linear_best_score,
	global_siegel.best_score as global_siegel_best_score,
	hybrid_siegel.algorithm_region_size_parameter as hybrid_siegel_best_region_size,
	hybrid_siegel.best_score as hybrid_siegel_best_score,
	local_euclidean_siegel.algorithm_region_size_parameter as local_euclidean_siegel_best_region_size,
	local_euclidean_siegel.best_score as local_euclidean_siegel_best_score,
	local_padic_linear.algorithm_region_size_parameter as local_padic_linear_best_region_size,
	local_padic_linear.best_score as local_padic_linear_best_score
  from machine_learning_morphology_best_parameters_and_scores as global_padic_linear
  join machine_learning_morphology_best_parameters_and_scores as global_siegel using (language)
  join machine_learning_morphology_best_parameters_and_scores as hybrid_siegel using (language)
  join machine_learning_morphology_best_parameters_and_scores as local_euclidean_siegel using (language)
  join machine_learning_morphology_best_parameters_and_scores as local_padic_linear using (language)
  where global_padic_linear.calculation_algorithm = 'GlobalPadicLinear'
    and global_siegel.calculation_algorithm = 'GlobalSiegel'
    and hybrid_siegel.calculation_algorithm = 'HybridSiegel'
    and local_euclidean_siegel.calculation_algorithm = 'LocalEuclideanSiegel'
    and local_padic_linear.calculation_algorithm = 'LocalPadicLinear'   ;
