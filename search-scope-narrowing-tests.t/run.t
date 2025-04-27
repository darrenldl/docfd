Setup:
  $ echo "abcd" >> test0.txt
  $ echo "efgh" >> test0.txt
  $ echo "0123" >> test0.txt
  $ echo "ijkl" >> test0.txt
  $ echo "abcd" >> test1.txt
  $ echo "efgh" >> test1.txt
  $ echo "0123" >> test1.txt
  $ echo "ijkl" >> test1.txt
  $ # s0 - case 0 for single restriction
  $ echo "search: 'abcd" >> s0.docfd_commands
  $ echo "narrow level: 1" >> s0.docfd_commands
  $ echo "search: 'efgh" >> s0.docfd_commands
  $ # s1 - case 1 for single restriction
  $ echo "search: 'abcd" >> s1.docfd_commands
  $ echo "narrow level: 1" >> s1.docfd_commands
  $ echo "search: '0123" >> s1.docfd_commands
  $ # s2 - case 2 for single restriction
  $ echo "search: 'abcd" >> s2.docfd_commands
  $ echo "narrow level: 1" >> s2.docfd_commands
  $ echo "narrow level: 0" >> s2.docfd_commands
  $ echo "search: '0123" >> s2.docfd_commands
  $ # c0 - case 0 for chained restrictions
  $ echo "search: 'abcd" >> c0.docfd_commands
  $ echo "narrow level: 1" >> c0.docfd_commands
  $ echo "search: '0123" >> c0.docfd_commands
  $ echo "narrow level: 1" >> c0.docfd_commands
  $ echo "search: 'efgh" >> c0.docfd_commands
  $ # c1 - case 1 for chained restrictions
  $ echo "search: 'abcd" >> c1.docfd_commands
  $ echo "narrow level: 2" >> c1.docfd_commands
  $ echo "search: '0123" >> c1.docfd_commands
  $ echo "narrow level: 2" >> c1.docfd_commands
  $ echo "search: 'efgh" >> c1.docfd_commands
  $ # c2 - case 2 for chained restrictions
  $ echo "search: 'abcd" >> c2.docfd_commands
  $ echo "narrow level: 2" >> c2.docfd_commands
  $ echo "search: '0123" >> c2.docfd_commands
  $ echo "narrow level: 1" >> c2.docfd_commands
  $ echo "search: 'efgh" >> c2.docfd_commands
  $ # f0 - case 0 for file path filter + restrictions
  $ echo "search: 'abcd" >> f0.docfd_commands
  $ echo "filter: test0.txt" >> f0.docfd_commands
  $ echo "search: 'efgh" >> f0.docfd_commands
  $ echo "clear filter" >> f0.docfd_commands
  $ # f1 - case 1 for file path filter + restrictions
  $ echo "search: 'abcd" >> f1.docfd_commands
  $ echo "filter: test0.txt" >> f1.docfd_commands
  $ echo "narrow level: 1" >> f1.docfd_commands
  $ echo "search: 'efgh" >> f1.docfd_commands
  $ echo "clear filter" >> f1.docfd_commands
  $ # f2 - case 2 for file path filter + restrictions
  $ echo "search: 'abcd" >> f2.docfd_commands
  $ echo "filter: test0.txt" >> f2.docfd_commands
  $ echo "narrow level: 1" >> f2.docfd_commands
  $ echo "clear filter" >> f2.docfd_commands
  $ echo "search: 'efgh" >> f2.docfd_commands
  $ # f3 - case 3 for file path filter + restrictions
  $ echo "search: 'abcd" >> f3.docfd_commands
  $ echo "filter: test0.txt" >> f3.docfd_commands
  $ echo "narrow level: 1" >> f3.docfd_commands
  $ echo "clear filter" >> f3.docfd_commands
  $ echo "narrow level: 0" >> f3.docfd_commands
  $ echo "search: 'efgh" >> f3.docfd_commands
  $ # f4 - case 4 for file path filter + restrictions
  $ echo "search: 'abcd" >> f4.docfd_commands
  $ echo "filter: test0.txt" >> f4.docfd_commands
  $ echo "narrow level: 1" >> f4.docfd_commands
  $ echo "narrow level: 0" >> f4.docfd_commands
  $ echo "clear filter" >> f4.docfd_commands
  $ echo "search: 'efgh" >> f4.docfd_commands
  $ tree
  .
  |-- c0.docfd_commands
  |-- c1.docfd_commands
  |-- c2.docfd_commands
  |-- dune -> ../../../../default/search-scope-narrowing-tests.t/dune
  |-- f0.docfd_commands
  |-- f1.docfd_commands
  |-- f2.docfd_commands
  |-- f3.docfd_commands
  |-- f4.docfd_commands
  |-- s0.docfd_commands
  |-- s1.docfd_commands
  |-- s2.docfd_commands
  |-- test0.txt
  `-- test1.txt
  
  0 directories, 14 files

Single restriction:
  $ docfd --tokens-per-search-scope-level 1 --commands-from s0.docfd_commands test0.txt -l
  $TESTCASE_ROOT/test0.txt
  $ docfd --tokens-per-search-scope-level 1 --commands-from s1.docfd_commands test0.txt -l
  [1]
  $ docfd --tokens-per-search-scope-level 1 --commands-from s2.docfd_commands test0.txt -l
  $TESTCASE_ROOT/test0.txt

Chained restriction:
  $ docfd --tokens-per-search-scope-level 1 --commands-from c0.docfd_commands test0.txt -l
  [1]
  $ docfd --tokens-per-search-scope-level 1 --commands-from c1.docfd_commands test0.txt -l
  $TESTCASE_ROOT/test0.txt
  $ docfd --tokens-per-search-scope-level 1 --commands-from c2.docfd_commands test0.txt -l
  $TESTCASE_ROOT/test0.txt

File path filter + restrictions:
  $ docfd --tokens-per-search-scope-level 1 --commands-from f0.docfd_commands -l .
  $TESTCASE_ROOT/test0.txt
  $TESTCASE_ROOT/test1.txt
  $ docfd --tokens-per-search-scope-level 1 --commands-from f1.docfd_commands -l .
  $TESTCASE_ROOT/test0.txt
  $ docfd --tokens-per-search-scope-level 1 --commands-from f2.docfd_commands -l .
  $TESTCASE_ROOT/test0.txt
  $ docfd --tokens-per-search-scope-level 1 --commands-from f3.docfd_commands -l .
  $TESTCASE_ROOT/test0.txt
  $TESTCASE_ROOT/test1.txt
  $ docfd --tokens-per-search-scope-level 1 --commands-from f4.docfd_commands -l .
  $TESTCASE_ROOT/test0.txt
  $TESTCASE_ROOT/test1.txt
