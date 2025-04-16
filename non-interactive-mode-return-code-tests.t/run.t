Setup:
  $ echo "0123 abcd" >> test0.txt
  $ echo "0123 efgh" >> test1.txt

--sample, text all files:
  $ docfd --sample "'0123" .
  $TESTCASE_ROOT/test1.txt
  1: 0123 efgh
     ^^^^
  
  $TESTCASE_ROOT/test0.txt
  1: 0123 abcd
     ^^^^
  $ docfd --sample "'0123" . -l
  $TESTCASE_ROOT/test0.txt
  $TESTCASE_ROOT/test1.txt
  $ docfd --sample "'0123" . --files-without-match
  [1]

--sample, text in only one file:
  $ docfd --sample "'abcd" .
  $TESTCASE_ROOT/test0.txt
  1: 0123 abcd
          ^^^^
  $ docfd --sample "'abcd" . -l
  $TESTCASE_ROOT/test0.txt
  $ docfd --sample "'abcd" . --files-without-match
  $TESTCASE_ROOT/test1.txt

--sample, text not in any file:
  $ docfd --sample "'hello" .
  [1]
  $ docfd --sample "'hello" . -l
  [1]
  $ docfd --sample "'hello" . --files-without-match
  $TESTCASE_ROOT/test0.txt
  $TESTCASE_ROOT/test1.txt

--search, text all files:
  $ docfd --search "'0123" .
  $TESTCASE_ROOT/test1.txt
  1: 0123 efgh
     ^^^^
  
  $TESTCASE_ROOT/test0.txt
  1: 0123 abcd
     ^^^^
  $ docfd --search "'0123" . -l
  $TESTCASE_ROOT/test0.txt
  $TESTCASE_ROOT/test1.txt
  $ docfd --search "'0123" . --files-without-match
  [1]

--search, text in only one file:
  $ docfd --search "'abcd" .
  $TESTCASE_ROOT/test0.txt
  1: 0123 abcd
          ^^^^
  $ docfd --search "'abcd" . -l
  $TESTCASE_ROOT/test0.txt
  $ docfd --search "'abcd" . --files-without-match
  $TESTCASE_ROOT/test1.txt

--search, text not in any file:
  $ docfd --search "'hello" .
  [1]
  $ docfd --search "'hello" . -l
  [1]
  $ docfd --search "'hello" . --files-without-match
  $TESTCASE_ROOT/test0.txt
  $TESTCASE_ROOT/test1.txt
