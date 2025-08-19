--sample:
  $ docfd --cache-dir .cache --sample abcd .
  $TESTCASE_ROOT/test3.txt
  1: abcd
     ^^^^
  
  $TESTCASE_ROOT/test2.txt
  1: hello
  2: 
  3: abcd
     ^^^^
  4: 
  5: abcdefgh
  
  5: abcdefgh
  6: 
  7: hello world abcd
                 ^^^^
  
  3: abcd
  4: 
  5: abcdefgh
     ^^^^^^^^
  6: 
  7: hello world abcd

--search:
  $ docfd --cache-dir .cache --search abcd .
  $TESTCASE_ROOT/test3.txt
  1: abcd
     ^^^^
  
  $TESTCASE_ROOT/test2.txt
  1: hello
  2: 
  3: abcd
     ^^^^
  4: 
  5: abcdefgh
  
  5: abcdefgh
  6: 
  7: hello world abcd
                 ^^^^
  
  3: abcd
  4: 
  5: abcdefgh
     ^^^^^^^^
  6: 
  7: hello world abcd

-l/--files-with-match:
  $ docfd --cache-dir .cache --sample abcd . -l
  $TESTCASE_ROOT/test3.txt
  $TESTCASE_ROOT/test2.txt
  $ docfd --cache-dir .cache --sample abcd . --files-with-match
  $TESTCASE_ROOT/test3.txt
  $TESTCASE_ROOT/test2.txt

--files-without-match:
  $ docfd --cache-dir .cache --sample abcd . --files-without-match
  $TESTCASE_ROOT/empty.txt
  $TESTCASE_ROOT/test0.txt
  $TESTCASE_ROOT/test1.txt
  $TESTCASE_ROOT/test4.txt
