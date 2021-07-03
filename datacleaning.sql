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
