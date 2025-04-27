Setup:
  $ echo "abcd" >> test0.txt
  $ echo "efgh" >> test0.txt
  $ echo "0123" >> test0.txt
  $ echo "ijkl" >> test0.txt
  $ echo "abcd" >> test1.txt
  $ echo "efgh" >> test1.txt
  $ echo "0123" >> test1.txt
  $ echo "ijkl" >> test1.txt
  $ tree
  .
  |-- dune -> ../../../../default/search-scope-narrowing-tests.t/dune
  |-- test0.txt
  `-- test1.txt
  
  0 directories, 3 files

Single restriction:
  $ # case 0 for single restriction
  $ echo "" > test.docfd_commands
  $ echo "search: 'abcd" >> test.docfd_commands
  $ echo "narrow level: 1" >> test.docfd_commands
  $ echo "search: 'efgh" >> test.docfd_commands
  $ docfd --tokens-per-search-scope-level 1 --commands-from test.docfd_commands test0.txt -l
  $TESTCASE_ROOT/test0.txt
  $ # case 1 for single restriction
  $ echo "" > test.docfd_commands
  $ echo "search: 'abcd" >> test.docfd_commands
  $ echo "narrow level: 1" >> test.docfd_commands
  $ echo "search: '0123" >> test.docfd_commands
  $ docfd --tokens-per-search-scope-level 1 --commands-from test.docfd_commands test0.txt -l
  [1]
  $ # case 2 for single restriction
  $ echo "" > test.docfd_commands
  $ echo "search: 'abcd" >> test.docfd_commands
  $ echo "narrow level: 1" >> test.docfd_commands
  $ echo "narrow level: 0" >> test.docfd_commands
  $ echo "search: '0123" >> test.docfd_commands
  $ docfd --tokens-per-search-scope-level 1 --commands-from test.docfd_commands test0.txt -l
  $TESTCASE_ROOT/test0.txt

Chained restriction:
  $ # case 0 for chained restrictions
  $ echo "" > test.docfd_commands
  $ echo "search: 'abcd" >> test.docfd_commands
  $ echo "narrow level: 1" >> test.docfd_commands
  $ echo "search: '0123" >> test.docfd_commands
  $ echo "narrow level: 1" >> test.docfd_commands
  $ echo "search: 'efgh" >> test.docfd_commands
  $ docfd --tokens-per-search-scope-level 1 --commands-from test.docfd_commands test0.txt -l
  [1]
  $ # case 1 for chained restrictions
  $ echo "" > test.docfd_commands
  $ echo "search: 'abcd" >> test.docfd_commands
  $ echo "narrow level: 2" >> test.docfd_commands
  $ echo "search: '0123" >> test.docfd_commands
  $ echo "narrow level: 2" >> test.docfd_commands
  $ echo "search: 'efgh" >> test.docfd_commands
  $ docfd --tokens-per-search-scope-level 1 --commands-from test.docfd_commands test0.txt -l
  $TESTCASE_ROOT/test0.txt
  $ # case 2 for chained restrictions
  $ echo "" > test.docfd_commands
  $ echo "search: 'abcd" >> test.docfd_commands
  $ echo "narrow level: 2" >> test.docfd_commands
  $ echo "search: '0123" >> test.docfd_commands
  $ echo "narrow level: 1" >> test.docfd_commands
  $ echo "search: 'efgh" >> test.docfd_commands
  $ docfd --tokens-per-search-scope-level 1 --commands-from test.docfd_commands test0.txt -l
  $TESTCASE_ROOT/test0.txt

File path filter + restrictions:
  $ # case 0 for file path filter + restrictions
  $ echo "" > test.docfd_commands
  $ echo "search: 'abcd" >> test.docfd_commands
  $ echo "filter: test0.txt" >> test.docfd_commands
  $ echo "search: 'efgh" >> test.docfd_commands
  $ echo "clear filter" >> test.docfd_commands
  $ docfd --tokens-per-search-scope-level 1 --commands-from test.docfd_commands -l .
  $TESTCASE_ROOT/test0.txt
  $TESTCASE_ROOT/test1.txt
  $ # case 1 for file path filter + restrictions
  $ echo "" > test.docfd_commands
  $ echo "search: 'abcd" >> test.docfd_commands
  $ echo "filter: test0.txt" >> test.docfd_commands
  $ echo "narrow level: 1" >> test.docfd_commands
  $ echo "clear filter" >> test.docfd_commands
  $ docfd --tokens-per-search-scope-level 1 --commands-from test.docfd_commands -l .
  $TESTCASE_ROOT/test0.txt
  $TESTCASE_ROOT/test1.txt
  $ # case 1 for file path filter + restrictions
  $ echo "" > test.docfd_commands
  $ echo "search: 'abcd" >> test.docfd_commands
  $ echo "filter: test0.txt" >> test.docfd_commands
  $ echo "narrow level: 1" >> test.docfd_commands
  $ echo "search: 'efgh" >> test.docfd_commands
  $ echo "clear filter" >> test.docfd_commands
  $ docfd --tokens-per-search-scope-level 1 --commands-from test.docfd_commands -l .
  $TESTCASE_ROOT/test0.txt
  $ # case 2 for file path filter + restrictions
  $ echo "" > test.docfd_commands
  $ echo "search: 'abcd" >> test.docfd_commands
  $ echo "filter: test0.txt" >> test.docfd_commands
  $ echo "narrow level: 1" >> test.docfd_commands
  $ echo "clear filter" >> test.docfd_commands
  $ echo "search: 'efgh" >> test.docfd_commands
  $ docfd --tokens-per-search-scope-level 1 --commands-from test.docfd_commands -l .
  $TESTCASE_ROOT/test0.txt
  $ # case 3 for file path filter + restrictions
  $ echo "" > test.docfd_commands
  $ echo "search: 'abcd" >> test.docfd_commands
  $ echo "filter: test0.txt" >> test.docfd_commands
  $ echo "narrow level: 1" >> test.docfd_commands
  $ echo "clear filter" >> test.docfd_commands
  $ echo "narrow level: 0" >> test.docfd_commands
  $ echo "search: 'efgh" >> test.docfd_commands
  $ docfd --tokens-per-search-scope-level 1 --commands-from test.docfd_commands -l .
  $TESTCASE_ROOT/test0.txt
  $TESTCASE_ROOT/test1.txt
  $ # case 4 for file path filter + restrictions
  $ echo "" > test.docfd_commands
  $ echo "search: 'abcd" >> test.docfd_commands
  $ echo "filter: test0.txt" >> test.docfd_commands
  $ echo "narrow level: 1" >> test.docfd_commands
  $ echo "narrow level: 0" >> test.docfd_commands
  $ echo "clear filter" >> test.docfd_commands
  $ echo "search: 'efgh" >> test.docfd_commands
  $ docfd --tokens-per-search-scope-level 1 --commands-from test.docfd_commands -l .
  $TESTCASE_ROOT/test0.txt
  $TESTCASE_ROOT/test1.txt
