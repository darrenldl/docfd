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
  |-- test0.txt
  |-- test1.txt
  |-- test2.txt
  `-- test3.txt
  
  0 directories, 6 files

Basic:
  $ docfd -l --script 0.docfd-script .
  $TESTCASE_ROOT/test0.txt
  $ docfd -l --script 1.docfd-script .
  [1]

List scripts in the script directory:
  $ mkdir -p data/scripts data/scripts/nested
  $ cp 0.docfd-script data/scripts/a.docfd-script
  $ cp 1.docfd-script data/scripts/z.docfd-script
  $ touch data/scripts/not-a-script.txt
  $ touch data/scripts/nested/nested.docfd-script
  $ docfd --data-dir data --cache-dir list-cache --list-scripts
  a.docfd-script
  z.docfd-script
  $ test ! -e list-cache

Fall back to the script directory for a bare filename:
  $ docfd --data-dir data -l --script a.docfd-script .
  $TESTCASE_ROOT/test0.txt

A file in the current directory takes precedence over the fallback:
  $ cp 1.docfd-script a.docfd-script
  $ docfd --data-dir data -l --script a.docfd-script .
  [1]

Paths containing directory components do not fall back:
  $ docfd --data-dir data -l --script missing/a.docfd-script .
  error: failed to read script 'missing/a.docfd-script'
  [1]

--start-with-script uses the same fallback:
  $ printf '%s\n' 'not a command' > data/scripts/invalid.docfd-script
  $ docfd --data-dir data --start-with-script invalid.docfd-script . > start-with-script.out 2>&1; status=$?; grep '^error:' start-with-script.out; echo "status=$status"
  error: failed to parse command on line 1: not a command
  status=1
