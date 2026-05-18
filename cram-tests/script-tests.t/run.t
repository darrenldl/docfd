Setup:
  $ echo "abcd" > test0.txt
  $ echo "efgh" > test1.txt
  $ echo "hijk" > test2.txt
  $ echo "0123" > test3.txt
  $ echo "search: ^ab" >> 0.docfd-script
  $ echo "search: 'xyz" >> 1.docfd-script
  $ tree
  .
  |-- 0.docfd-script
  |-- 1.docfd-script
  |-- dune -> ../../../../default/script-tests.t/dune
  |-- test0.txt
  |-- test1.txt
  |-- test2.txt
  `-- test3.txt
  
  0 directories, 7 files

Basic:
  $ docfd -l --script 0.docfd-script .
  $TESTCASE_ROOT/test0.txt
  $ docfd -l --script 1.docfd-script .
  [1]
