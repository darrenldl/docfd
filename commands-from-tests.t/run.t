Setup:
  $ echo "abcd" > test0.txt
  $ echo "efgh" > test1.txt
  $ echo "hijk" > test2.txt
  $ echo "0123" > test3.txt
  $ echo "search: ^ab" >> 0.docfd_commands
  $ echo "search: 'xyz" >> 1.docfd_commands
  $ tree
  .
  |-- 0.docfd_commands
  |-- 1.docfd_commands
  |-- dune -> ../../../../default/commands-from-tests.t/dune
  |-- test0.txt
  |-- test1.txt
  |-- test2.txt
  `-- test3.txt
  
  0 directories, 7 files

Commands:
  $ docfd -l --commands-from 0.docfd_commands .
  $TESTCASE_ROOT/test0.txt
  $ docfd -l --commands-from 1.docfd_commands .
  [1]
