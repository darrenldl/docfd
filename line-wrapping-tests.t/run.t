Word breaking:
  $ docfd --search-result-print-snippet-min-size 0 long-words.txt --search "01 ab" --search-result-print-text-width 80
  $TESTCASE_ROOT/long-words.txt
  1: 01234567890123456789012345678901234567890123456789012345678901234567890123456
     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
     78901234567890123456789
     ^^^^^^^^^^^^^^^^^^^^^^^
  2: 
  3: abcdefghijklmnopqrstuvwxyz
     ^^^^^^^^^^^^^^^^^^^^^^^^^^
  
  16: 0123456789012345678901234567890123456789012345678901234567890123456789012345
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
      678901234567890123456789
      ^^^^^^^^^^^^^^^^^^^^^^^^
  17: 
  18: abcdefghijklmnopqrstuvwxyz
      ^^^^^^^^^^^^^^^^^^^^^^^^^^
  
  1: 01234567890123456789012345678901234567890123456789012345678901234567890123456
     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
     78901234567890123456789
     ^^^^^^^^^^^^^^^^^^^^^^^
  2: 
  3: abcdefghijklmnopqrstuvwxyz
  4: 01234567890123456789012345678901234567890123456789012345678901234567890123456
     78901234567890123456789012345678901234567890123456789012345678901234567890123
     4567890123456789012345678901234567890123456789
  5: abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz
  6: 
  7: 
  8: 
  9: 
  10: 
  11: 
  12: 
  13: 
  14: 
  15: 
  16: 0123456789012345678901234567890123456789012345678901234567890123456789012345
      678901234567890123456789
  17: 
  18: abcdefghijklmnopqrstuvwxyz
      ^^^^^^^^^^^^^^^^^^^^^^^^^^
  
  3: abcdefghijklmnopqrstuvwxyz
     ^^^^^^^^^^^^^^^^^^^^^^^^^^
  4: 01234567890123456789012345678901234567890123456789012345678901234567890123456
     78901234567890123456789012345678901234567890123456789012345678901234567890123
     4567890123456789012345678901234567890123456789
  5: abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz
  6: 
  7: 
  8: 
  9: 
  10: 
  11: 
  12: 
  13: 
  14: 
  15: 
  16: 0123456789012345678901234567890123456789012345678901234567890123456789012345
      ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
      678901234567890123456789
      ^^^^^^^^^^^^^^^^^^^^^^^^
  
  1: 01234567890123456789012345678901234567890123456789012345678901234567890123456
     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
     78901234567890123456789
     ^^^^^^^^^^^^^^^^^^^^^^^
  2: 
  3: abcdefghijklmnopqrstuvwxyz
  4: 01234567890123456789012345678901234567890123456789012345678901234567890123456
     78901234567890123456789012345678901234567890123456789012345678901234567890123
     4567890123456789012345678901234567890123456789
  5: abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz
     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  $ docfd --search-result-print-snippet-min-size 0 long-words.txt --search "01 ab" --search-result-print-text-width 20
  $TESTCASE_ROOT/long-words.txt
  1: 01234567890123456
     ^^^^^^^^^^^^^^^^^
     78901234567890123
     ^^^^^^^^^^^^^^^^^
     45678901234567890
     ^^^^^^^^^^^^^^^^^
     12345678901234567
     ^^^^^^^^^^^^^^^^^
     89012345678901234
     ^^^^^^^^^^^^^^^^^
     567890123456789
     ^^^^^^^^^^^^^^^
  2: 
  3: abcdefghijklmnopq
     ^^^^^^^^^^^^^^^^^
     rstuvwxyz
     ^^^^^^^^^
  
  16: 0123456789012345
      ^^^^^^^^^^^^^^^^
      6789012345678901
      ^^^^^^^^^^^^^^^^
      2345678901234567
      ^^^^^^^^^^^^^^^^
      8901234567890123
      ^^^^^^^^^^^^^^^^
      4567890123456789
      ^^^^^^^^^^^^^^^^
      0123456789012345
      ^^^^^^^^^^^^^^^^
      6789
      ^^^^
  17: 
  18: abcdefghijklmnop
      ^^^^^^^^^^^^^^^^
      qrstuvwxyz
      ^^^^^^^^^^
  
  1: 01234567890123456
     ^^^^^^^^^^^^^^^^^
     78901234567890123
     ^^^^^^^^^^^^^^^^^
     45678901234567890
     ^^^^^^^^^^^^^^^^^
     12345678901234567
     ^^^^^^^^^^^^^^^^^
     89012345678901234
     ^^^^^^^^^^^^^^^^^
     567890123456789
     ^^^^^^^^^^^^^^^
  2: 
  3: abcdefghijklmnopq
     rstuvwxyz
  4: 01234567890123456
     78901234567890123
     45678901234567890
     12345678901234567
     89012345678901234
     56789012345678901
     23456789012345678
     90123456789012345
     67890123456789012
     34567890123456789
     01234567890123456
     7890123456789
  5: abcdefghijklmnopq
     rstuvwxyzabcdefgh
     ijklmnopqrstuvwxy
     z
  6: 
  7: 
  8: 
  9: 
  10: 
  11: 
  12: 
  13: 
  14: 
  15: 
  16: 0123456789012345
      6789012345678901
      2345678901234567
      8901234567890123
      4567890123456789
      0123456789012345
      6789
  17: 
  18: abcdefghijklmnop
      ^^^^^^^^^^^^^^^^
      qrstuvwxyz
      ^^^^^^^^^^
  
  3: abcdefghijklmnopq
     ^^^^^^^^^^^^^^^^^
     rstuvwxyz
     ^^^^^^^^^
  4: 01234567890123456
     78901234567890123
     45678901234567890
     12345678901234567
     89012345678901234
     56789012345678901
     23456789012345678
     90123456789012345
     67890123456789012
     34567890123456789
     01234567890123456
     7890123456789
  5: abcdefghijklmnopq
     rstuvwxyzabcdefgh
     ijklmnopqrstuvwxy
     z
  6: 
  7: 
  8: 
  9: 
  10: 
  11: 
  12: 
  13: 
  14: 
  15: 
  16: 0123456789012345
      ^^^^^^^^^^^^^^^^
      6789012345678901
      ^^^^^^^^^^^^^^^^
      2345678901234567
      ^^^^^^^^^^^^^^^^
      8901234567890123
      ^^^^^^^^^^^^^^^^
      4567890123456789
      ^^^^^^^^^^^^^^^^
      0123456789012345
      ^^^^^^^^^^^^^^^^
      6789
      ^^^^
  
  1: 01234567890123456
     ^^^^^^^^^^^^^^^^^
     78901234567890123
     ^^^^^^^^^^^^^^^^^
     45678901234567890
     ^^^^^^^^^^^^^^^^^
     12345678901234567
     ^^^^^^^^^^^^^^^^^
     89012345678901234
     ^^^^^^^^^^^^^^^^^
     567890123456789
     ^^^^^^^^^^^^^^^
  2: 
  3: abcdefghijklmnopq
     rstuvwxyz
  4: 01234567890123456
     78901234567890123
     45678901234567890
     12345678901234567
     89012345678901234
     56789012345678901
     23456789012345678
     90123456789012345
     67890123456789012
     34567890123456789
     01234567890123456
     7890123456789
  5: abcdefghijklmnopq
     ^^^^^^^^^^^^^^^^^
     rstuvwxyzabcdefgh
     ^^^^^^^^^^^^^^^^^
     ijklmnopqrstuvwxy
     ^^^^^^^^^^^^^^^^^
     z
     ^
  $ docfd --search-result-print-snippet-min-size 0 words.txt --search "01 ab" --search-result-print-text-width 5
  $TESTCASE_ROOT/words.txt
  1: 01
     ^^
     23
     ^^
     45
     ^^
  2: 
  3: ab
     ^^
     cd
     ^^
     ef
     ^^
     g
     ^
  
  15: 0
      ^
      1
      ^
      2
      ^
      3
      ^
      4
      ^
      5
      ^
  16: 
  17: a
      ^
      b
      ^
      c
      ^
      d
      ^
      e
      ^
      f
      ^
      g
      ^
  
  1: 01
     ^^
     23
     ^^
     45
     ^^
  2: 
  3: ab
     cd
     ef
     g
  4: 
  5: 
  6: 
  7: 
  8: 
  9: 
  10: 
  11: 
  12: 
  13: 
  14: 
  15: 0
      1
      2
      3
      4
      5
  16: 
  17: a
      ^
      b
      ^
      c
      ^
      d
      ^
      e
      ^
      f
      ^
      g
      ^
  
  3: ab
     ^^
     cd
     ^^
     ef
     ^^
     g
     ^
  4: 
  5: 
  6: 
  7: 
  8: 
  9: 
  10: 
  11: 
  12: 
  13: 
  14: 
  15: 0
      ^
      1
      ^
      2
      ^
      3
      ^
      4
      ^
      5
      ^
  $ docfd --search-result-print-snippet-min-size 0 words.txt --search "01 ab" --search-result-print-text-width 1
  $TESTCASE_ROOT/words.txt
  1: 0
     ^
     1
     ^
     2
     ^
     3
     ^
     4
     ^
     5
     ^
  2: 
  3: a
     ^
     b
     ^
     c
     ^
     d
     ^
     e
     ^
     f
     ^
     g
     ^
  
  15: 0
      ^
      1
      ^
      2
      ^
      3
      ^
      4
      ^
      5
      ^
  16: 
  17: a
      ^
      b
      ^
      c
      ^
      d
      ^
      e
      ^
      f
      ^
      g
      ^
  
  1: 0
     ^
     1
     ^
     2
     ^
     3
     ^
     4
     ^
     5
     ^
  2: 
  3: a
     b
     c
     d
     e
     f
     g
  4: 
  5: 
  6: 
  7: 
  8: 
  9: 
  10: 
  11: 
  12: 
  13: 
  14: 
  15: 0
      1
      2
      3
      4
      5
  16: 
  17: a
      ^
      b
      ^
      c
      ^
      d
      ^
      e
      ^
      f
      ^
      g
      ^
  
  3: a
     ^
     b
     ^
     c
     ^
     d
     ^
     e
     ^
     f
     ^
     g
     ^
  4: 
  5: 
  6: 
  7: 
  8: 
  9: 
  10: 
  11: 
  12: 
  13: 
  14: 
  15: 0
      ^
      1
      ^
      2
      ^
      3
      ^
      4
      ^
      5
      ^

Line wrapping and word breaking:
  $ docfd --search-result-print-snippet-min-size 0 sentences.txt --search "lorem" --search-result-print-text-width 80
  $TESTCASE_ROOT/sentences.txt
  1:     Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod 
         ^^^^^
     tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, 
     quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo 
     consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse 
     cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non
      proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
  $ docfd --search-result-print-snippet-min-size 0 sentences.txt --search "lorem" --search-result-print-text-width 20
  $TESTCASE_ROOT/sentences.txt
  1:     Lorem ipsum 
         ^^^^^
     dolor sit amet, 
     consectetur 
     adipiscing elit, 
     sed do eiusmod 
     tempor incididunt
      ut labore et 
     dolore magna 
     aliqua. Ut enim 
     ad minim veniam, 
     quis nostrud 
     exercitation 
     ullamco laboris 
     nisi ut aliquip 
     ex ea commodo 
     consequat. Duis 
     aute irure dolor 
     in reprehenderit 
     in voluptate 
     velit esse cillum
      dolore eu fugiat
      nulla pariatur. 
     Excepteur sint 
     occaecat 
     cupidatat non 
     proident, sunt in
      culpa qui 
     officia deserunt 
     mollit anim id 
     est laborum.
  $ docfd --search-result-print-snippet-min-size 0 sentences.txt --search "lorem" --search-result-print-text-width 10
  $TESTCASE_ROOT/sentences.txt
  1:     
     Lorem 
     ^^^^^
     ipsum 
     dolor 
     sit 
     amet, 
     consect
     etur
      
     adipisc
     ing
      elit, 
     sed do 
     eiusmod
      tempor
      
     incidid
     unt
      ut 
     labore 
     et 
     dolore 
     magna 
     aliqua.
      Ut 
     enim ad
      minim 
     veniam,
      quis 
     nostrud
      
     exercit
     ation
      
     ullamco
      
     laboris
      nisi 
     ut 
     aliquip
      ex ea 
     commodo
      
     consequ
     at
     . Duis 
     aute 
     irure 
     dolor 
     in 
     reprehe
     nderit
      in 
     volupta
     te
      velit 
     esse 
     cillum 
     dolore 
     eu 
     fugiat 
     nulla 
     pariatu
     r
     . 
     Excepte
     ur
      sint 
     occaeca
     t
      
     cupidat
     at
      non 
     proiden
     t
     , sunt 
     in 
     culpa 
     qui 
     officia
      
     deserun
     t
      mollit
      anim 
     id est 
     laborum
     .
  $ docfd --search-result-print-snippet-min-size 0 sentences.txt --search "laborum 0" --search-result-print-text-width 80
  $TESTCASE_ROOT/sentences.txt
  1:     Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod 
     tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, 
     quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo 
     consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse 
     cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non
      proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
                                                                      ^^^^^^^
  2: 0 12 abcd efghi jkl mnopqrst uvwx yz 0123456 789012345
     ^
  
  1:     Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod 
     tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, 
     quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo 
     consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse 
     cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non
      proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
                                                                      ^^^^^^^
  2: 0 12 abcd efghi jkl mnopqrst uvwx yz 0123456 789012345
                                          ^^^^^^^
  
  1:     Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod 
     tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, 
     quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo 
     consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse 
     cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non
      proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
                                                                      ^^^^^^^
  2: 0 12 abcd efghi jkl mnopqrst uvwx yz 0123456 789012345
                                                  ^^^^^^^^^
  $ docfd --search-result-print-snippet-min-size 0 sentences.txt --search "laborum 0" --search-result-print-text-width 20
  $TESTCASE_ROOT/sentences.txt
  1:     Lorem ipsum 
     dolor sit amet, 
     consectetur 
     adipiscing elit, 
     sed do eiusmod 
     tempor incididunt
      ut labore et 
     dolore magna 
     aliqua. Ut enim 
     ad minim veniam, 
     quis nostrud 
     exercitation 
     ullamco laboris 
     nisi ut aliquip 
     ex ea commodo 
     consequat. Duis 
     aute irure dolor 
     in reprehenderit 
     in voluptate 
     velit esse cillum
      dolore eu fugiat
      nulla pariatur. 
     Excepteur sint 
     occaecat 
     cupidatat non 
     proident, sunt in
      culpa qui 
     officia deserunt 
     mollit anim id 
     est laborum.
         ^^^^^^^
  2: 0 12 abcd efghi 
     ^
     jkl mnopqrst uvwx
      yz 0123456 
     789012345
  
  1:     Lorem ipsum 
     dolor sit amet, 
     consectetur 
     adipiscing elit, 
     sed do eiusmod 
     tempor incididunt
      ut labore et 
     dolore magna 
     aliqua. Ut enim 
     ad minim veniam, 
     quis nostrud 
     exercitation 
     ullamco laboris 
     nisi ut aliquip 
     ex ea commodo 
     consequat. Duis 
     aute irure dolor 
     in reprehenderit 
     in voluptate 
     velit esse cillum
      dolore eu fugiat
      nulla pariatur. 
     Excepteur sint 
     occaecat 
     cupidatat non 
     proident, sunt in
      culpa qui 
     officia deserunt 
     mollit anim id 
     est laborum.
         ^^^^^^^
  2: 0 12 abcd efghi 
     jkl mnopqrst uvwx
      yz 0123456 
         ^^^^^^^
     789012345
  
  1:     Lorem ipsum 
     dolor sit amet, 
     consectetur 
     adipiscing elit, 
     sed do eiusmod 
     tempor incididunt
      ut labore et 
     dolore magna 
     aliqua. Ut enim 
     ad minim veniam, 
     quis nostrud 
     exercitation 
     ullamco laboris 
     nisi ut aliquip 
     ex ea commodo 
     consequat. Duis 
     aute irure dolor 
     in reprehenderit 
     in voluptate 
     velit esse cillum
      dolore eu fugiat
      nulla pariatur. 
     Excepteur sint 
     occaecat 
     cupidatat non 
     proident, sunt in
      culpa qui 
     officia deserunt 
     mollit anim id 
     est laborum.
         ^^^^^^^
  2: 0 12 abcd efghi 
     jkl mnopqrst uvwx
      yz 0123456 
     789012345
     ^^^^^^^^^
  $ docfd --search-result-print-snippet-min-size 0 sentences.txt --search "laborum 0" --search-result-print-text-width 10
  $TESTCASE_ROOT/sentences.txt
  1:     
     Lorem 
     ipsum 
     dolor 
     sit 
     amet, 
     consect
     etur
      
     adipisc
     ing
      elit, 
     sed do 
     eiusmod
      tempor
      
     incidid
     unt
      ut 
     labore 
     et 
     dolore 
     magna 
     aliqua.
      Ut 
     enim ad
      minim 
     veniam,
      quis 
     nostrud
      
     exercit
     ation
      
     ullamco
      
     laboris
      nisi 
     ut 
     aliquip
      ex ea 
     commodo
      
     consequ
     at
     . Duis 
     aute 
     irure 
     dolor 
     in 
     reprehe
     nderit
      in 
     volupta
     te
      velit 
     esse 
     cillum 
     dolore 
     eu 
     fugiat 
     nulla 
     pariatu
     r
     . 
     Excepte
     ur
      sint 
     occaeca
     t
      
     cupidat
     at
      non 
     proiden
     t
     , sunt 
     in 
     culpa 
     qui 
     officia
      
     deserun
     t
      mollit
      anim 
     id est 
     laborum
     ^^^^^^^
     .
  2: 0 12 
     ^
     abcd 
     efghi 
     jkl 
     mnopqrs
     t
      uvwx 
     yz 
     0123456
      
     7890123
     45
  
  1:     
     Lorem 
     ipsum 
     dolor 
     sit 
     amet, 
     consect
     etur
      
     adipisc
     ing
      elit, 
     sed do 
     eiusmod
      tempor
      
     incidid
     unt
      ut 
     labore 
     et 
     dolore 
     magna 
     aliqua.
      Ut 
     enim ad
      minim 
     veniam,
      quis 
     nostrud
      
     exercit
     ation
      
     ullamco
      
     laboris
      nisi 
     ut 
     aliquip
      ex ea 
     commodo
      
     consequ
     at
     . Duis 
     aute 
     irure 
     dolor 
     in 
     reprehe
     nderit
      in 
     volupta
     te
      velit 
     esse 
     cillum 
     dolore 
     eu 
     fugiat 
     nulla 
     pariatu
     r
     . 
     Excepte
     ur
      sint 
     occaeca
     t
      
     cupidat
     at
      non 
     proiden
     t
     , sunt 
     in 
     culpa 
     qui 
     officia
      
     deserun
     t
      mollit
      anim 
     id est 
     laborum
     ^^^^^^^
     .
  2: 0 12 
     abcd 
     efghi 
     jkl 
     mnopqrs
     t
      uvwx 
     yz 
     0123456
     ^^^^^^^
      
     7890123
     45
  
  1:     
     Lorem 
     ipsum 
     dolor 
     sit 
     amet, 
     consect
     etur
      
     adipisc
     ing
      elit, 
     sed do 
     eiusmod
      tempor
      
     incidid
     unt
      ut 
     labore 
     et 
     dolore 
     magna 
     aliqua.
      Ut 
     enim ad
      minim 
     veniam,
      quis 
     nostrud
      
     exercit
     ation
      
     ullamco
      
     laboris
      nisi 
     ut 
     aliquip
      ex ea 
     commodo
      
     consequ
     at
     . Duis 
     aute 
     irure 
     dolor 
     in 
     reprehe
     nderit
      in 
     volupta
     te
      velit 
     esse 
     cillum 
     dolore 
     eu 
     fugiat 
     nulla 
     pariatu
     r
     . 
     Excepte
     ur
      sint 
     occaeca
     t
      
     cupidat
     at
      non 
     proiden
     t
     , sunt 
     in 
     culpa 
     qui 
     officia
      
     deserun
     t
      mollit
      anim 
     id est 
     laborum
     ^^^^^^^
     .
  2: 0 12 
     abcd 
     efghi 
     jkl 
     mnopqrs
     t
      uvwx 
     yz 
     0123456
      
     7890123
     ^^^^^^^
     45
     ^^
