select '\vocabitem{' ||
       language_name || '}{' ||
      family_summary || '}{' ||
       language || '}{' ||
       english_translation || '}{' ||
       lemma || '}{' ||
       gender || '}{' ||
       noun_case || '}{' ||
       singular.target_language_assessed_word || '}{' ||
       plural.target_language_assessed_word || '}'
  from
    human_scoring_of_vocab_lists as singular
    join     human_scoring_of_vocab_lists as plural
    using (language, lemma, gender, noun_case)
    join common_noun_baker_translations using (lemma)
    join language_family_summary on (language = iso_639_3_code)
  where singular.assessment = 'correct'
    and singular.noun_number = 'singular'
    and plural.noun_number = 'plural'
    and plural.assessment = 'correct'
    and language not in ('deu', 'epo', 'fra')
    and english_translation != singular.target_language_assessed_word
    and english_translation != plural.target_language_assessed_word
    and (language_name != 'Gunwinggu' or (singular.target_language_assessed_word not in ('dollars', 'tax')))
    ;



