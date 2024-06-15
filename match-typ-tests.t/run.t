Exact match:
  $ docfd test.txt --sample "'abc"
  $ docfd test.txt --sample "'abcd"
  $TESTCASE_ROOT/test.txt
  1: abcd
     ^^^^
  2: abcdef
  3: ABCD
  
  1: abcd
  2: abcdef
  3: ABCD
     ^^^^
  4: ABCDEF
  5: ABcd
  
  3: ABCD
  4: ABCDEF
  5: ABcd
     ^^^^
  6: ABcdEF
  7: 
  
  6: ABcdEF
  7: 
  8: 'abcd
      ^^^^
  9: 'abcd'
  10: ^efgh
  
  7: 
  8: 'abcd
  9: 'abcd'
      ^^^^
  10: ^efgh
  11: ^^efgh
  $ docfd test.txt --sample "\\'abcd"
  $TESTCASE_ROOT/test.txt
  6: ABcdEF
  7: 
  8: 'abcd
     ^^^^^
  9: 'abcd'
  10: ^efgh
  
  7: 
  8: 'abcd
  9: 'abcd'
     ^^^^^
  10: ^efgh
  11: ^^efgh
  
  6: ABcdEF
  7: 
  8: 'abcd
     ^
  9: 'abcd'
      ^^^^
  10: ^efgh
  11: ^^efgh
  
  6: ABcdEF
  7: 
  8: 'abcd
      ^^^^
  9: 'abcd'
     ^
  10: ^efgh
  11: ^^efgh
  
  7: 
  8: 'abcd
  9: 'abcd'
      ^^^^^
  10: ^efgh
  11: ^^efgh
  $ docfd test.txt --sample "'abcdef"
  $TESTCASE_ROOT/test.txt
  1: abcd
  2: abcdef
     ^^^^^^
  3: ABCD
  4: ABCDEF
  
  2: abcdef
  3: ABCD
  4: ABCDEF
     ^^^^^^
  5: ABcd
  6: ABcdEF
  
  4: ABCDEF
  5: ABcd
  6: ABcdEF
     ^^^^^^
  7: 
  8: 'abcd
  $ docfd test.txt --sample "''abcd"
  $TESTCASE_ROOT/test.txt
  6: ABcdEF
  7: 
  8: 'abcd
     ^^^^^
  9: 'abcd'
  10: ^efgh
  
  7: 
  8: 'abcd
  9: 'abcd'
     ^^^^^
  10: ^efgh
  11: ^^efgh

Exact match smart case sensitivity:
  $ docfd test.txt --sample "'ABCD"
  $TESTCASE_ROOT/test.txt
  1: abcd
  2: abcdef
  3: ABCD
     ^^^^
  4: ABCDEF
  5: ABcd
  $ docfd test.txt --sample "'ABcd"
  $TESTCASE_ROOT/test.txt
  3: ABCD
  4: ABCDEF
  5: ABcd
     ^^^^
  6: ABcdEF
  7: 

Prefix match:
  $ docfd test.txt --sample "^bcd"
  $ docfd test.txt --sample "^abcd"
  $TESTCASE_ROOT/test.txt
  1: abcd
     ^^^^
  2: abcdef
  3: ABCD
  
  1: abcd
  2: abcdef
  3: ABCD
     ^^^^
  4: ABCDEF
  5: ABcd
  
  3: ABCD
  4: ABCDEF
  5: ABcd
     ^^^^
  6: ABcdEF
  7: 
  
  6: ABcdEF
  7: 
  8: 'abcd
      ^^^^
  9: 'abcd'
  10: ^efgh
  
  7: 
  8: 'abcd
  9: 'abcd'
      ^^^^
  10: ^efgh
  11: ^^efgh
  $ docfd test.txt --sample "^abcdef"
  $TESTCASE_ROOT/test.txt
  1: abcd
  2: abcdef
     ^^^^^^
  3: ABCD
  4: ABCDEF
  
  2: abcdef
  3: ABCD
  4: ABCDEF
     ^^^^^^
  5: ABcd
  6: ABcdEF
  
  4: ABCDEF
  5: ABcd
  6: ABcdEF
     ^^^^^^
  7: 
  8: 'abcd
  $ docfd test.txt --sample "^'abcd"
  $TESTCASE_ROOT/test.txt
  6: ABcdEF
  7: 
  8: 'abcd
     ^^^^^
  9: 'abcd'
  10: ^efgh
  
  7: 
  8: 'abcd
  9: 'abcd'
     ^^^^^
  10: ^efgh
  11: ^^efgh

Prefix match smart case sensitivity:
  $ docfd test.txt --sample "^ABCD"
  $TESTCASE_ROOT/test.txt
  1: abcd
  2: abcdef
  3: ABCD
     ^^^^
  4: ABCDEF
  5: ABcd
  
  2: abcdef
  3: ABCD
  4: ABCDEF
     ^^^^^^
  5: ABcd
  6: ABcdEF
  $ docfd test.txt --sample "^ABcd"
  $TESTCASE_ROOT/test.txt
  3: ABCD
  4: ABCDEF
  5: ABcd
     ^^^^
  6: ABcdEF
  7: 
  
  4: ABCDEF
  5: ABcd
  6: ABcdEF
     ^^^^^^
  7: 
  8: 'abcd

Suffix match:
  $ docfd test.txt --sample 'bcd$'
  $TESTCASE_ROOT/test.txt
  1: abcd
     ^^^^
  2: abcdef
  3: ABCD
  
  1: abcd
  2: abcdef
  3: ABCD
     ^^^^
  4: ABCDEF
  5: ABcd
  
  3: ABCD
  4: ABCDEF
  5: ABcd
     ^^^^
  6: ABcdEF
  7: 
  
  6: ABcdEF
  7: 
  8: 'abcd
      ^^^^
  9: 'abcd'
  10: ^efgh
  
  7: 
  8: 'abcd
  9: 'abcd'
      ^^^^
  10: ^efgh
  11: ^^efgh
  $ docfd test.txt --sample 'abcd$$'
  $TESTCASE_ROOT/test.txt
  13: efgh$$
  14: 
  15: abcd$
      ^^^^^
  16: efgh$
  17: 
  $ docfd test.txt --sample 'ef$'
  $TESTCASE_ROOT/test.txt
  1: abcd
  2: abcdef
     ^^^^^^
  3: ABCD
  4: ABCDEF
  
  2: abcdef
  3: ABCD
  4: ABCDEF
     ^^^^^^
  5: ABcd
  6: ABcdEF
  
  4: ABCDEF
  5: ABcd
  6: ABcdEF
     ^^^^^^
  7: 
  8: 'abcd

Suffix match smart case sensitivity:
  $ docfd test.txt --sample 'ABCD$'
  $TESTCASE_ROOT/test.txt
  1: abcd
  2: abcdef
  3: ABCD
     ^^^^
  4: ABCDEF
  5: ABcd
  $ docfd test.txt --sample 'EF$'
  $TESTCASE_ROOT/test.txt
  2: abcdef
  3: ABCD
  4: ABCDEF
     ^^^^^^
  5: ABcd
  6: ABcdEF
  
  4: ABCDEF
  5: ABcd
  6: ABcdEF
     ^^^^^^
  7: 
  8: 'abcd
