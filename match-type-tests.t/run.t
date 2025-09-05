Exact match:
  $ docfd --cache-dir .cache test.txt --sample "'abc"
  [1]
  $ docfd --cache-dir .cache test.txt --sample "'abcd"
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
  $ docfd --cache-dir .cache test.txt --sample "\\'abcd"
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
  
  4: ABCDEF
  5: ABcd
  6: ABcdEF
     ^^^^^^
  7: 
  8: 'abcd
     ^
  9: 'abcd'
  10: ^efgh
  $ docfd --cache-dir .cache test.txt --sample "'abcdef"
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
  $ docfd --cache-dir .cache test.txt --sample "''abcd"
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
  $ docfd --cache-dir .cache test.txt --sample "'ABCD"
  $TESTCASE_ROOT/test.txt
  1: abcd
  2: abcdef
  3: ABCD
     ^^^^
  4: ABCDEF
  5: ABcd
  $ docfd --cache-dir .cache test.txt --sample "'ABcd"
  $TESTCASE_ROOT/test.txt
  3: ABCD
  4: ABCDEF
  5: ABcd
     ^^^^
  6: ABcdEF
  7: 

Prefix match:
  $ docfd --cache-dir .cache test.txt --sample "^bcd"
  [1]
  $ docfd --cache-dir .cache test.txt --sample "^abcd"
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
  $ docfd --cache-dir .cache test.txt --sample "^abcdef"
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
  $ docfd --cache-dir .cache test.txt --sample "^'abcd"
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
  $ docfd --cache-dir .cache test.txt --sample "^ABCD"
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
  $ docfd --cache-dir .cache test.txt --sample "^ABcd"
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
  $ docfd --cache-dir .cache test.txt --sample 'bcd$'
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
  $ docfd --cache-dir .cache test.txt --sample 'abcd$$'
  $TESTCASE_ROOT/test.txt
  13: efgh$$
  14: 
  15: abcd$
      ^^^^^
  16: efgh$
  17: 
  $ docfd --cache-dir .cache test.txt --sample 'ef$'
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
  $ docfd --cache-dir .cache test.txt --sample 'ABCD$'
  $TESTCASE_ROOT/test.txt
  1: abcd
  2: abcdef
  3: ABCD
     ^^^^
  4: ABCDEF
  5: ABcd
  $ docfd --cache-dir .cache test.txt --sample 'EF$'
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

Fuzzy match explicit spaces:
  $ docfd --cache-dir .cache test.txt --sample 'hel~word'
  $TESTCASE_ROOT/test.txt
  16: efgh$
  17: 
  18: hello world
      ^^^^^^^^^^^
  19: hello   world
  20: 
  
  17: 
  18: hello world
  19: hello   world
      ^^^^^^^^^^^^^
  20: 
  21: Hello world
  
  19: hello   world
  20: 
  21: Hello world
      ^^^^^^^^^^^
  22: 
  23: HELLO WORLD
  
  21: Hello world
  22: 
  23: HELLO WORLD
      ^^^^^^^^^^^
  
  16: efgh$
  17: 
  18: hello world
           ^^^^^^
  19: hello   world
      ^^^^^
  20: 
  21: Hello world

Exact match explicit spaces:
  $ docfd --cache-dir .cache test.txt --sample "'hello~world"
  $TESTCASE_ROOT/test.txt
  16: efgh$
  17: 
  18: hello world
      ^^^^^^^^^^^
  19: hello   world
  20: 
  
  17: 
  18: hello world
  19: hello   world
      ^^^^^^^^^^^^^
  20: 
  21: Hello world
  
  19: hello   world
  20: 
  21: Hello world
      ^^^^^^^^^^^
  22: 
  23: HELLO WORLD
  
  21: Hello world
  22: 
  23: HELLO WORLD
      ^^^^^^^^^^^
  $ docfd --cache-dir .cache test.txt --sample "'Hello~world"
  $TESTCASE_ROOT/test.txt
  19: hello   world
  20: 
  21: Hello world
      ^^^^^^^^^^^
  22: 
  23: HELLO WORLD
  $ docfd --cache-dir .cache test.txt --sample "'Hello~World"
  [1]

Prefix match explicit spaces:
  $ docfd --cache-dir .cache test.txt --sample '^hello~wo'
  $TESTCASE_ROOT/test.txt
  16: efgh$
  17: 
  18: hello world
      ^^^^^^^^^^^
  19: hello   world
  20: 
  
  17: 
  18: hello world
  19: hello   world
      ^^^^^^^^^^^^^
  20: 
  21: Hello world
  
  19: hello   world
  20: 
  21: Hello world
      ^^^^^^^^^^^
  22: 
  23: HELLO WORLD
  
  21: Hello world
  22: 
  23: HELLO WORLD
      ^^^^^^^^^^^
  $ docfd --cache-dir .cache test.txt --sample '^ello~wo'
  [1]

Suffix match explicit spaces:
  $ docfd --cache-dir .cache test.txt --sample 'lo~world$'
  $TESTCASE_ROOT/test.txt
  16: efgh$
  17: 
  18: hello world
      ^^^^^^^^^^^
  19: hello   world
  20: 
  
  17: 
  18: hello world
  19: hello   world
      ^^^^^^^^^^^^^
  20: 
  21: Hello world
  
  19: hello   world
  20: 
  21: Hello world
      ^^^^^^^^^^^
  22: 
  23: HELLO WORLD
  
  21: Hello world
  22: 
  23: HELLO WORLD
      ^^^^^^^^^^^
  $ docfd --cache-dir .cache test.txt --sample 'lo~worl$'
  [1]
