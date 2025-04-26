Setup:
  $ echo "abcd" >> test.txt
  $ echo "efgh" >> test.txt
  $ echo "0123" >> test.txt
  $ echo "ijkl" >> test.txt
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
  $ tree
  .
  |-- c0.docfd_commands
  |-- c1.docfd_commands
  |-- c2.docfd_commands
  |-- dune -> ../../../../default/search-scope-narrowing-tests.t/dune
  |-- s0.docfd_commands
  |-- s1.docfd_commands
  |-- s2.docfd_commands
  `-- test.txt
  
  0 directories, 8 files

Single restriction:
  $ docfd --tokens-per-search-scope-level 1 --commands-from s0.docfd_commands test.txt -l
  $TESTCASE_ROOT/test.txt
  $ docfd --tokens-per-search-scope-level 1 --commands-from s1.docfd_commands test.txt -l
  [1]
  $ docfd --tokens-per-search-scope-level 1 --commands-from s2.docfd_commands test.txt -l
  $TESTCASE_ROOT/test.txt

Chained restriction:
  $ docfd --tokens-per-search-scope-level 1 --commands-from c0.docfd_commands test.txt -l
  [1]
  $ docfd --tokens-per-search-scope-level 1 --commands-from c1.docfd_commands test.txt -l
  $TESTCASE_ROOT/test.txt
  $ docfd --tokens-per-search-scope-level 1 --commands-from c2.docfd_commands test.txt -l
  $TESTCASE_ROOT/test.txt
