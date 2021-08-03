update bible_versions set version_worth_fetching = false
  where version_name in
   ('psalms of david in metre 1650 scottish psalter',
    'st paul from the trenches 1916',
    'gurindji ruth',
    'kurti baibel',
    'marku mau sau 1951 zaiwa',
    'fu in ma tai 1904',
    'tolomaku portions 1909',
    'liaa chuanshi dios shinaa',
    'awara baibel',
    'o evangelio jezus kristusester pala markus 1912 sinte',
    'western armenian new translation armenian catholicosate of cilicia new testament',
    'wester boswell scripture selections 1874',
    'warda kwabba luke ang',
    'yanyuwa',
    'ghayavi mak',
    'nteto mbega ta bra yandkirwe n luka',
    'sailm dhaibhidh 1694 seanadh earra ghaidheal',
    'wurkapm a maur wailen',
    'garrwa mini bible',
    'unimbti nybundi gbku', -- but this can be fixed later
    'latviesu jauna deriba', --  also, should be fixable
    'eesti piibel', -- should be fixable
    'lukaady shaddy habar',
    'wel puat ci mak ke gor 1916',
    'ootech oochu takehniya tinkles st mark',
    'laru',
    'testing aheri gondi',
    'book hoa matthew 1816',
    'evanghelia pala o marco 1996 caldararilor romania',
    'predigimo a johannesko 1930',
    'salmau dafydd broffwyd 1603 edward kyffin',
    'matyu sank wulapm weinkel ka matyu apulel'
)
    ;



update bible_versions set version_worth_fetching = false
 where version_name = 'bibel' and version_id = 241;
  -- the URLs are really mangled, but could be fixed 



insert into raw_wikidata_iso639_code_deprecations values ('Q12953185', 'suf');
insert into raw_wikidata_iso639_code_deprecations values ('Q20050850', 'duj');
insert into raw_wikidata_iso639_code_deprecations values ('Q2386361', 'nln'); 
insert into raw_wikidata_iso639_code_deprecations values ('Q2478711', 'nbf');
insert into raw_wikidata_iso639_code_deprecations values ('Q3033556', 'sap');
insert into raw_wikidata_iso639_code_deprecations values ('Q3327445', 'azr');
insert into raw_wikidata_iso639_code_deprecations values ('Q33394', 'vmd');  
insert into raw_wikidata_iso639_code_deprecations values ('Q33880', 'xst');
insert into raw_wikidata_iso639_code_deprecations values ('Q33916', 'suh');
insert into raw_wikidata_iso639_code_deprecations values ('Q6931573', 'mwd');
insert into raw_wikidata_iso639_code_deprecations values ('Q7103752', 'ork');
insert into raw_wikidata_iso639_code_deprecations values ('Q9072', 'ekk');   
insert into raw_wikidata_iso639_code_deprecations values ('Q9078', 'lvs');


insert into raw_wikidata_iso639_code_deprecations values ('Q2928261', 'bwx');
insert into raw_wikidata_iso639_code_deprecations values ('Q17622364', 'bwx');
insert into raw_wikidata_iso639_code_deprecations values ('Q17625834', 'bwx');
insert into raw_wikidata_iso639_code_deprecations values ('Q3412231', 'bfa'); 
insert into raw_wikidata_iso639_code_deprecations values ('Q3346585', 'bfa');
insert into raw_wikidata_iso639_code_deprecations values ('Q3339369', 'bfa');
insert into raw_wikidata_iso639_code_deprecations values ('Q9129', 'ell');   
insert into raw_wikidata_iso639_code_deprecations values ('Q3565171', 'xal');
insert into raw_wikidata_iso639_code_deprecations values ('Q56959', 'xal');  
insert into raw_wikidata_iso639_code_deprecations values ('Q9288', 'heb');

insert into iso639_aliases (language_alias, normally_known_as) values ('diq', 'zza');
insert into iso639_aliases (language_alias, normally_known_as) values ('esi', 'ipk');
insert into iso639_aliases (language_alias, normally_known_as) values ('daf', 'dnj');
insert into iso639_aliases (language_alias, normally_known_as) values ('rmy_ch', 'rmy');
insert into iso639_aliases (language_alias, normally_known_as) values ('zho_tw', 'zho');

insert into iso639_aliases (language_alias, normally_known_as) values ('fuv_ar','fuv');
insert into iso639_aliases (language_alias, normally_known_as) values ('rmn_arl','rmn');
insert into iso639_aliases (language_alias, normally_known_as) values ('sus_ar','sus');
insert into iso639_aliases (language_alias, normally_known_as) values ('hin_ro','hin');
insert into iso639_aliases (language_alias, normally_known_as) values ('lif_dev','lif');
insert into iso639_aliases (language_alias, normally_known_as) values ('ike_lab','ike');
insert into iso639_aliases (language_alias, normally_known_as) values ('shu_rom','shu');
insert into iso639_aliases (language_alias, normally_known_as) values ('urd_rom','urd');
insert into iso639_aliases (language_alias, normally_known_as) values ('kde_mz','kde');
insert into iso639_aliases (language_alias, normally_known_as) values ('rmy_ch','rmy');
insert into iso639_aliases (language_alias, normally_known_as) values ('uig_cyr','uig');
insert into iso639_aliases (language_alias, normally_known_as) values ('tuk_arb','tuk');
insert into iso639_aliases (language_alias, normally_known_as) values ('rmy_lov','rmy');
insert into iso639_aliases (language_alias, normally_known_as) values ('hak_rom','hak');
insert into iso639_aliases (language_alias, normally_known_as) values ('fub_ar','fub');
insert into iso639_aliases (language_alias, normally_known_as) values ('syl_nag','syl');
insert into iso639_aliases (language_alias, normally_known_as) values ('urd_dv','urd');
insert into iso639_aliases (language_alias, normally_known_as) values ('zho_tw','zho');
insert into iso639_aliases (language_alias, normally_known_as) values ('bcc_rom','bcc');
insert into iso639_aliases (language_alias, normally_known_as) values ('mya_zaw','mya');
insert into iso639_aliases (language_alias, normally_known_as) values ('rmy_fr','rmy');
insert into iso639_aliases (language_alias, normally_known_as) values ('sco_uls','sco');
insert into iso639_aliases (language_alias, normally_known_as) values ('por_pt','por');
insert into iso639_aliases (language_alias, normally_known_as) values ('spa_es','spa');
