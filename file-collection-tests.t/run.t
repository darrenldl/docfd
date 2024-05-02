Setup:
  $ TMP0=$(mktemp)
  $ TMP1=$(mktemp)
  $ touch no-ext
  $ touch empty-paths.txt
  $ echo "test.txt" >> paths
  $ echo "test-symlink.txt" >> paths
  $ echo "test0" >> paths
  $ echo "test1/ijkl" >> paths
  $ echo "test2/" >> paths
  $ echo "test3/" >> paths
  $ touch test.ext0
  $ touch test.log
  $ touch test.md
  $ touch test.txt
  $ mkdir test0
  $ touch test0/1234.md
  $ touch test0/abcd.txt
  $ mkdir test0/abcd
  $ touch test0/abcd/efgh.md
  $ touch test0/abcd/efgh.txt
  $ mkdir test1
  $ touch test1/5678.md
  $ touch test1/ijkl.txt
  $ mkdir test1/ijkl
  $ touch test1/ijkl/mnop.md
  $ touch test1/ijkl/mnop.txt
  $ mkdir test2
  $ touch test2/1234.md
  $ mkdir test2/abcd
  $ touch test2/abcd/efgh.md
  $ ln -s $(pwd)/test0/abcd/efgh.txt test2/abcd/efgh.txt
  $ ln -s ../test1/5678.md test2/56.md
  $ ln -s ../test1/ijkl test2/ijkl
  $ ln -s test2 test3
  $ ln -s test.txt test-symlink.txt
  $ tree
  .
  |-- dune -> ../../../../default/file-collection-tests.t/dune
  |-- empty-paths.txt
  |-- no-ext
  |-- paths
  |-- test-symlink.txt -> test.txt
  |-- test.ext0
  |-- test.log
  |-- test.md
  |-- test.txt
  |-- test0
  |   |-- 1234.md
  |   |-- abcd
  |   |   |-- efgh.md
  |   |   `-- efgh.txt
  |   `-- abcd.txt
  |-- test1
  |   |-- 5678.md
  |   |-- ijkl
  |   |   |-- mnop.md
  |   |   `-- mnop.txt
  |   `-- ijkl.txt
  |-- test2
  |   |-- 1234.md
  |   |-- 56.md -> ../test1/5678.md
  |   |-- abcd
  |   |   |-- efgh.md
  |   |   `-- efgh.txt -> $TESTCASE_ROOT/test0/abcd/efgh.txt
  |   `-- ijkl -> ../test1/ijkl
  `-- test3 -> test2
  
  6 directories, 23 files

Default path is not picked if --paths-from is used:
  $ docfd    --debug-log - --index-only --paths-from empty-paths.txt 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  $ docfd -L --debug-log - --index-only --paths-from empty-paths.txt 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""

Default path is not picked if --glob is used:
  $ docfd    --debug-log - --index-only --glob '*.log' 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  $ docfd -L --debug-log - --index-only --glob '*.log' 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""

Default path is not picked if --single-line-glob is used:
  $ docfd    --debug-log - --index-only --single-line-glob '*.log' 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  $ docfd -L --debug-log - --index-only --single-line-glob '*.log' 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""

Empty --exts:
  $ docfd --debug-log - --index-only --exts "" . 2>&1 | grep '^Using .* search mode' | sort
  Using single line search mode for document '$TESTCASE_ROOT/test.log'

Empty --single-line-exts:
  $ docfd --debug-log - --index-only --single-line-exts "" . 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/5678.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test2/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test2/abcd/efgh.md'

Empty --exts and --single-line-exts:
  $ docfd --debug-log - --index-only --exts "" --single-line-exts "" .
  error: no usable file extensions or glob patterns
  [1]

--add-exts:
  $ docfd --debug-log - --index-only --add-exts ext0 . 2>&1 | grep '^Using .* search mode' | sort | grep "ext0"
  Using multiline search mode for document '$TESTCASE_ROOT/test.ext0'

--single-line-add-exts:
  $ docfd --debug-log - --index-only --single-line-add-exts ext0 . 2>&1 | grep '^Using .* search mode' | sort | grep "ext0"
  Using single line search mode for document '$TESTCASE_ROOT/test.ext0'

Picking via multiple --glob:
  $ docfd    --debug-log - --index-only --glob '*.txt' --glob '*.md' --glob '*.log' 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test-symlink.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  $ docfd -L --debug-log - --index-only --glob '*.txt' --glob '*.md' --glob '*.log' 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""

Picking via multiple --single-line-glob:
  $ docfd    --debug-log - --index-only --single-line-glob '*.txt' --single-line-glob '*.md' --single-line-glob '*.log' 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test-symlink.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd -L --debug-log - --index-only --single-line-glob '*.txt' --single-line-glob '*.md' --single-line-glob '*.log' 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""

Picking via multiple --glob and --single-line-glob:
  $ # --single-line-glob for .txt files
  $ docfd    --debug-log - --index-only --single-line-glob '*.txt' --glob '*.md' --glob '*.log' 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test-symlink.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd -L --debug-log - --index-only --single-line-glob '*.txt' --glob '*.md' --glob '*.log' 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""
  $ # --single-line-glob for .md files
  $ docfd    --debug-log - --index-only --glob '*.txt' --single-line-glob '*.md' --glob '*.log' 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test-symlink.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  $ docfd -L --debug-log - --index-only --glob '*.txt' --single-line-glob '*.md' --glob '*.log' 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""
  $ # --single-line-glob for .log files
  $ docfd    --debug-log - --index-only --glob '*.txt' --glob '*.md' --single-line-glob '*.log' 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test-symlink.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  $ docfd -L --debug-log - --index-only --glob '*.txt' --glob '*.md' --single-line-glob '*.log' 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""
  $ # --glob for .txt files
  $ docfd    --debug-log - --index-only --glob '*.txt' --single-line-glob '*.md' --single-line-glob '*.log' 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test-symlink.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  $ docfd -L --debug-log - --index-only --glob '*.txt' --single-line-glob '*.md' --single-line-glob '*.log' 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""
  $ # --glob for .md files
  $ docfd    --debug-log - --index-only --single-line-glob '*.txt' --glob '*.md' --single-line-glob '*.log' 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test-symlink.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd -L --debug-log - --index-only --single-line-glob '*.txt' --glob '*.md' --single-line-glob '*.log' 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""
  $ # --glob for .log files
  $ docfd    --debug-log - --index-only --single-line-glob '*.txt' --single-line-glob '*.md' --glob '*.log' 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test-symlink.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd -L --debug-log - --index-only --single-line-glob '*.txt' --single-line-glob '*.md' --glob '*.log' 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""

--single-line-exts and --exts:
  $ docfd    --debug-log - --index-only --single-line-exts md --exts md . 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.md'
  Using single line search mode for document '$TESTCASE_ROOT/test1/5678.md'
  Using single line search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  Using single line search mode for document '$TESTCASE_ROOT/test2/1234.md'
  Using single line search mode for document '$TESTCASE_ROOT/test2/abcd/efgh.md'
  $ docfd -L --debug-log - --index-only --single-line-exts md --exts md . 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""
  +Using single line search mode for document '$TESTCASE_ROOT/test2/56.md'
  +Using single line search mode for document '$TESTCASE_ROOT/test2/ijkl/mnop.md'
  +Using single line search mode for document '$TESTCASE_ROOT/test3/1234.md'
  +Using single line search mode for document '$TESTCASE_ROOT/test3/56.md'
  +Using single line search mode for document '$TESTCASE_ROOT/test3/abcd/efgh.md'
  +Using single line search mode for document '$TESTCASE_ROOT/test3/ijkl/mnop.md'

--single-line-exts and --glob:
  $ docfd    --debug-log - --index-only --exts "" --single-line-exts md --glob '**/*.md' 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.md'
  Using single line search mode for document '$TESTCASE_ROOT/test1/5678.md'
  Using single line search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  Using single line search mode for document '$TESTCASE_ROOT/test2/1234.md'
  Using single line search mode for document '$TESTCASE_ROOT/test2/abcd/efgh.md'
  $ docfd -L --debug-log - --index-only --exts "" --single-line-exts md --glob '**/*.md' 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""
  +Using single line search mode for document '$TESTCASE_ROOT/test2/56.md'
  +Using single line search mode for document '$TESTCASE_ROOT/test2/ijkl/mnop.md'
  +Using single line search mode for document '$TESTCASE_ROOT/test3/1234.md'
  +Using single line search mode for document '$TESTCASE_ROOT/test3/56.md'
  +Using single line search mode for document '$TESTCASE_ROOT/test3/abcd/efgh.md'
  +Using single line search mode for document '$TESTCASE_ROOT/test3/ijkl/mnop.md'

--single-line-glob and --exts:
  $ docfd    --debug-log - --index-only --single-line-glob '*.md' --exts md . 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using multiline search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/5678.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test2/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test2/abcd/efgh.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  $ docfd -L --debug-log - --index-only --single-line-glob '*.md' --exts md . 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/56.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/ijkl/mnop.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/1234.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/56.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/abcd/efgh.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/ijkl/mnop.md'

--single-line-glob and --glob:
  $ docfd    --debug-log - --index-only --single-line-glob '*.md' --glob '**/*.md' 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using multiline search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/5678.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test2/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test2/abcd/efgh.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  $ docfd -L --debug-log - --index-only --single-line-glob '*.md' --glob '**/*.md' 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/56.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/ijkl/mnop.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/1234.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/56.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/abcd/efgh.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/ijkl/mnop.md'

--exts applies to directories in FILE in --paths-from FILE:
  $ docfd    --debug-log - --index-only --paths-from paths --exts md 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using multiline search mode for document '$TESTCASE_ROOT/test-symlink.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test2/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test2/abcd/efgh.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test3/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test3/abcd/efgh.md'
  $ docfd -L --debug-log - --index-only --paths-from paths --exts md 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/56.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/ijkl/mnop.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/56.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/ijkl/mnop.md'

--single-line-exts apply to directories in FILE in --paths-from FILE:
  $ docfd    --debug-log - --index-only --paths-from paths --single-line-exts md 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using multiline search mode for document '$TESTCASE_ROOT/test-symlink.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.md'
  Using single line search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  Using single line search mode for document '$TESTCASE_ROOT/test2/1234.md'
  Using single line search mode for document '$TESTCASE_ROOT/test2/abcd/efgh.md'
  Using single line search mode for document '$TESTCASE_ROOT/test3/1234.md'
  Using single line search mode for document '$TESTCASE_ROOT/test3/abcd/efgh.md'
  $ docfd -L --debug-log - --index-only --paths-from paths --single-line-exts md 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/abcd/efgh.txt'
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/ijkl/mnop.txt'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/abcd/efgh.txt'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/ijkl/mnop.txt'
  +Using single line search mode for document '$TESTCASE_ROOT/test2/56.md'
  +Using single line search mode for document '$TESTCASE_ROOT/test2/ijkl/mnop.md'
  +Using single line search mode for document '$TESTCASE_ROOT/test3/56.md'
  +Using single line search mode for document '$TESTCASE_ROOT/test3/ijkl/mnop.md'

Top-level symlinks:
  $ docfd    --debug-log - --index-only test-symlink.txt 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using multiline search mode for document '$TESTCASE_ROOT/test-symlink.txt'
  $ docfd -L --debug-log - --index-only test-symlink.txt 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""
  $ docfd    --debug-log - --index-only test3 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using multiline search mode for document '$TESTCASE_ROOT/test3/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test3/abcd/efgh.md'
  $ docfd -L --debug-log - --index-only test3 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/56.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/abcd/efgh.txt'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/ijkl/mnop.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/ijkl/mnop.txt'

Top-level files and --single-line-exts:
  $ docfd    --debug-log - --index-only test.txt --single-line-exts txt 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd -L --debug-log - --index-only test.txt --single-line-exts txt 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""

Top-level files and --single-line-glob:
  $ docfd    --debug-log - --index-only test.txt --single-line-glob '*.txt' 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test-symlink.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd -L --debug-log - --index-only test.txt --single-line-glob '*.txt' 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""

--glob and unrecognized extensions:
  $ docfd    --debug-log - --index-only --exts md --glob "*.txt" . 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test-symlink.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/5678.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test2/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test2/abcd/efgh.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  $ docfd -L --debug-log - --index-only --exts md --glob "*.txt" . 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/56.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/ijkl/mnop.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/1234.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/56.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/abcd/efgh.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/ijkl/mnop.md'

--single-line-glob and unrecognized extensions:
  $ docfd    --debug-log - --index-only --exts md --single-line-glob "*.txt" . 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/5678.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test2/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test2/abcd/efgh.md'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test-symlink.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd -L --debug-log - --index-only --exts md --single-line-glob "*.txt" . 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/56.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/ijkl/mnop.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/1234.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/56.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/abcd/efgh.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/ijkl/mnop.md'

Top-level files with unrecognized extensions are still picked:
  $ docfd --debug-log - --index-only --exts md test.txt . 2>&1 | grep '^Using .* search mode' | sort | grep 'test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'

Top-level files without extensions are still picked:
  $ docfd --debug-log - --index-only --exts md no-ext . 2>&1 | grep '^Using .* search mode' | sort | grep 'no-ext'
  Using multiline search mode for document '$TESTCASE_ROOT/no-ext'

Current working directory is symlink:
  $ cd test3
  $ docfd    --debug-log - --index-only . 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using multiline search mode for document '$TESTCASE_ROOT/test2/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test2/abcd/efgh.md'
  $ docfd -L --debug-log - --index-only . 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/56.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/abcd/efgh.txt'
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/ijkl/mnop.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/ijkl/mnop.txt'
  $ docfd    --debug-log - --index-only --glob '*.txt' . 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using multiline search mode for document '$TESTCASE_ROOT/test2/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test2/abcd/efgh.md'
  $ docfd    --debug-log - --index-only --glob '**/*.txt' . 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using multiline search mode for document '$TESTCASE_ROOT/test2/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test2/abcd/efgh.md'
  $ docfd -L --debug-log - --index-only --glob '**/*.txt' . 2>&1 | grep '^Using .* search mode' | sort | tee > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/56.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/abcd/efgh.txt'
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/ijkl/mnop.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/ijkl/mnop.txt'
  $ docfd    --debug-log - --index-only --glob '$(pwd)/**/*.txt' . 2>&1 | grep '^Using .* search mode' | sort | tee $TMP0
  Using multiline search mode for document '$TESTCASE_ROOT/test2/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test2/abcd/efgh.md'
  $ docfd -L --debug-log - --index-only --glob '$(pwd)/**/*.txt' . 2>&1 | grep '^Using .* search mode' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/56.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/abcd/efgh.txt'
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/ijkl/mnop.md'
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/ijkl/mnop.txt'
  $ cd ..

'..' in glob:
  $ docfd    --debug-log - --index-only --glob 'test3/../*.txt' 2>&1 | grep -e '^Using .* search mode' -e '^Glob regex' | sort | tee $TMP0
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test-symlink.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd -L --debug-log - --index-only --glob 'test3/../*.txt' 2>&1 | grep -e '^Using .* search mode' -e '^Glob regex' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""

'**' in glob:
  $ docfd    --debug-log - --index-only --glob '**/*.txt' 2>&1 | grep -e '^Using .* search mode' -e '^Glob regex' | sort | tee $TMP0
  Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/empty-paths.txt
  Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test.txt
  Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test0/abcd.txt
  Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test0/abcd/efgh.txt
  Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test1/ijkl.txt
  Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test1/ijkl/mnop.txt
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.txt'
  $ docfd -L --debug-log - --index-only --glob '**/*.txt' 2>&1 | grep -e '^Using .* search mode' -e '^Glob regex' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""
  +Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test-symlink.txt
  +Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test2/abcd/efgh.txt
  +Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test2/ijkl/mnop.txt
  +Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test3/abcd/efgh.txt
  +Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test3/ijkl/mnop.txt
  +Using multiline search mode for document '$TESTCASE_ROOT/test-symlink.txt'
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/abcd/efgh.txt'
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/ijkl/mnop.txt'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/abcd/efgh.txt'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/ijkl/mnop.txt'
  $ docfd    --debug-log - --index-only --glob '**/**/*.txt' 2>&1 | grep -e '^Using .* search mode' -e '^Glob regex' | sort | tee $TMP0
  Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/empty-paths.txt
  Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test.txt
  Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test0/abcd.txt
  Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test0/abcd/efgh.txt
  Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test1/ijkl.txt
  Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test1/ijkl/mnop.txt
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.txt'
  $ docfd -L --debug-log - --index-only --glob '**/**/*.txt' 2>&1 | grep -e '^Using .* search mode' -e '^Glob regex' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""
  +Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test-symlink.txt
  +Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test2/abcd/efgh.txt
  +Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test2/ijkl/mnop.txt
  +Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test3/abcd/efgh.txt
  +Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test3/ijkl/mnop.txt
  +Using multiline search mode for document '$TESTCASE_ROOT/test-symlink.txt'
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/abcd/efgh.txt'
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/ijkl/mnop.txt'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/abcd/efgh.txt'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/ijkl/mnop.txt'
  $ docfd    --debug-log - --index-only --glob "$(pwd)/**/*.txt" 2>&1 | grep -e '^Using .* search mode' -e '^Glob regex' | sort | tee $TMP0
  Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/empty-paths.txt
  Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test.txt
  Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test0/abcd.txt
  Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test0/abcd/efgh.txt
  Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test1/ijkl.txt
  Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test1/ijkl/mnop.txt
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.txt'
  $ docfd -L --debug-log - --index-only --glob "$(pwd)/**/*.txt" 2>&1 | grep -e '^Using .* search mode' -e '^Glob regex' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""
  +Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test-symlink.txt
  +Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test2/abcd/efgh.txt
  +Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test2/ijkl/mnop.txt
  +Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test3/abcd/efgh.txt
  +Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test3/ijkl/mnop.txt
  +Using multiline search mode for document '$TESTCASE_ROOT/test-symlink.txt'
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/abcd/efgh.txt'
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/ijkl/mnop.txt'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/abcd/efgh.txt'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/ijkl/mnop.txt'
  $ docfd    --debug-log - --index-only --glob "$(pwd)/**/**/*.txt" 2>&1 | grep -e '^Using .* search mode' -e '^Glob regex' | sort | tee $TMP0
  Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/empty-paths.txt
  Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test.txt
  Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test0/abcd.txt
  Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test0/abcd/efgh.txt
  Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test1/ijkl.txt
  Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test1/ijkl/mnop.txt
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.txt'
  $ docfd -L --debug-log - --index-only --glob "$(pwd)/**/**/*.txt" 2>&1 | grep -e '^Using .* search mode' -e '^Glob regex' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""
  +Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test-symlink.txt
  +Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test2/abcd/efgh.txt
  +Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test2/ijkl/mnop.txt
  +Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test3/abcd/efgh.txt
  +Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test3/ijkl/mnop.txt
  +Using multiline search mode for document '$TESTCASE_ROOT/test-symlink.txt'
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/abcd/efgh.txt'
  +Using multiline search mode for document '$TESTCASE_ROOT/test2/ijkl/mnop.txt'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/abcd/efgh.txt'
  +Using multiline search mode for document '$TESTCASE_ROOT/test3/ijkl/mnop.txt'
  $ docfd    --debug-log - --index-only --glob "**/test[01]/*.txt" 2>&1 | grep -e '^Using .* search mode' -e '^Glob regex' | sort | tee $TMP0
  Glob regex $TESTCASE_ROOT/**/test[01]/*.txt matches path $TESTCASE_ROOT/test0/abcd.txt
  Glob regex $TESTCASE_ROOT/**/test[01]/*.txt matches path $TESTCASE_ROOT/test1/ijkl.txt
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl.txt'
  $ docfd -L --debug-log - --index-only --glob "**/test[01]/*.txt" 2>&1 | grep -e '^Using .* search mode' -e '^Glob regex' | sort > $TMP1
  $ diff $TMP0 $TMP1 | tail -n +4 | grep -e '^+' -e '^-'; echo -n ""

Cleanup:
  $ rm $TMP0
  $ rm $TMP1
