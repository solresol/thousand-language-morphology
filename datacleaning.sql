update bible_versions set version_worth_fetching = false
  where version_name in
   ('psalms of david in metre 1650 scottish psalter',
    'st paul from the trenches 1916')
    ;
