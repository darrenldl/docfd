Setup:
  $ touch no-ext
  $ touch empty-paths.txt
  $ echo "test0" >> paths
  $ echo "test1/ijkl" >> paths
  $ echo "test.txt" >> paths
  $ touch test.ext0
  $ touch test.log
  $ touch test.md
  $ touch test.txt
  $ mkdir test0
  $ touch test0/1234.md
  $ touch test0/abcd.md
  $ touch test0/abcd.txt
  $ mkdir test0/abcd
  $ touch test0/abcd/efgh.md
  $ touch test0/abcd/efgh.txt
  $ mkdir test1
  $ touch test1/5678.md
  $ touch test1/ijkl.md
  $ touch test1/ijkl.txt
  $ mkdir test1/ijkl
  $ touch test1/ijkl/mnop.md
  $ touch test1/ijkl/mnop.txt
  $ tree
  .
  |-- dune -> ../../../../default/path-collecting-tests.t/dune
  |-- empty-paths.txt
  |-- no-ext
  |-- paths
  |-- test.ext0
  |-- test.log
  |-- test.md
  |-- test.txt
  |-- test0
  |   |-- 1234.md
  |   |-- abcd
  |   |   |-- efgh.md
  |   |   `-- efgh.txt
  |   |-- abcd.md
  |   `-- abcd.txt
  `-- test1
      |-- 5678.md
      |-- ijkl
      |   |-- mnop.md
      |   `-- mnop.txt
      |-- ijkl.md
      `-- ijkl.txt
  
  4 directories, 18 files

Default path is not picked if any of the following is used: --paths-from, --glob, --single-line-glob:
  $ # test.md and test.txt should not be picked for the following 3 cases.
  $ docfd --debug-log - --index-only --paths-from empty-paths.txt 2>&1 | grep '^File:' | sort
  $ docfd --debug-log - --index-only --glob '*.log' 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/test.log'
  $ docfd --debug-log - --index-only --single-line-glob '*.log' 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/test.log'
  $ # test.md and test.txt should also be picked for the following cases.
  $ docfd --debug-log - --index-only --paths-from empty-paths.txt . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd.txt'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.md'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.txt'
  File: '$TESTCASE_ROOT/test1/5678.md'
  File: '$TESTCASE_ROOT/test1/ijkl.md'
  File: '$TESTCASE_ROOT/test1/ijkl.txt'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.txt'
  $ docfd --debug-log - --index-only --glob '*.log' . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd.txt'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.md'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.txt'
  File: '$TESTCASE_ROOT/test1/5678.md'
  File: '$TESTCASE_ROOT/test1/ijkl.md'
  File: '$TESTCASE_ROOT/test1/ijkl.txt'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.txt'
  $ docfd --debug-log - --index-only --single-line-glob '*.log' . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd.txt'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.md'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.txt'
  File: '$TESTCASE_ROOT/test1/5678.md'
  File: '$TESTCASE_ROOT/test1/ijkl.md'
  File: '$TESTCASE_ROOT/test1/ijkl.txt'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.txt'

--exts and --glob do not overwrite each other:
  $ docfd --debug-log - --index-only --exts md --glob '*.log' . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.md'
  File: '$TESTCASE_ROOT/test1/5678.md'
  File: '$TESTCASE_ROOT/test1/ijkl.md'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.md'

--single-line-exts and --glob do not overwrite each other:
  $ docfd --debug-log - --index-only --single-line-exts md --glob '*.log' . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd.txt'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.md'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.txt'
  File: '$TESTCASE_ROOT/test1/5678.md'
  File: '$TESTCASE_ROOT/test1/ijkl.md'
  File: '$TESTCASE_ROOT/test1/ijkl.txt'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.txt'

--exts and --single-line-glob do not overwrite each other:
  $ docfd --debug-log - --index-only --exts md --single-line-glob '*.log' . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.md'
  File: '$TESTCASE_ROOT/test1/5678.md'
  File: '$TESTCASE_ROOT/test1/ijkl.md'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.md'

--single-line-exts and --single-line-glob do not overwrite each other:
  $ docfd --debug-log - --index-only --single-line-exts md --single-line-glob '*.log' . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd.txt'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.md'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.txt'
  File: '$TESTCASE_ROOT/test1/5678.md'
  File: '$TESTCASE_ROOT/test1/ijkl.md'
  File: '$TESTCASE_ROOT/test1/ijkl.txt'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.txt'

Paths from --exts, --single-line-exts, --glob, --single-line-glob, --paths-from are combined correctly:
  $ docfd --debug-log - --index-only --exts md --single-line-exts log . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.md'
  File: '$TESTCASE_ROOT/test1/5678.md'
  File: '$TESTCASE_ROOT/test1/ijkl.md'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.md'

--add-exts:
  $ docfd --debug-log - --index-only --add-exts md . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd.txt'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.md'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.txt'
  File: '$TESTCASE_ROOT/test1/5678.md'
  File: '$TESTCASE_ROOT/test1/ijkl.md'
  File: '$TESTCASE_ROOT/test1/ijkl.txt'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.txt'
  $ docfd --debug-log - --index-only --add-exts ext0 . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.ext0'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd.txt'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.md'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.txt'
  File: '$TESTCASE_ROOT/test1/5678.md'
  File: '$TESTCASE_ROOT/test1/ijkl.md'
  File: '$TESTCASE_ROOT/test1/ijkl.txt'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.txt'

--single-line-add-exts:
  $ docfd --debug-log - --index-only --single-line-add-exts md . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd.txt'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.md'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.txt'
  File: '$TESTCASE_ROOT/test1/5678.md'
  File: '$TESTCASE_ROOT/test1/ijkl.md'
  File: '$TESTCASE_ROOT/test1/ijkl.txt'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.txt'
  $ docfd --debug-log - --index-only --single-line-add-exts ext0 . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.ext0'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd.txt'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.md'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.txt'
  File: '$TESTCASE_ROOT/test1/5678.md'
  File: '$TESTCASE_ROOT/test1/ijkl.md'
  File: '$TESTCASE_ROOT/test1/ijkl.txt'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.txt'

Picking via multiple --glob and --single-line-glob:
  $ docfd --debug-log - --index-only --glob '*.txt' 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd --debug-log - --index-only --glob "*.txt" --glob '*.md' 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd --debug-log - --index-only --glob '*.txt' --glob '*.md' --glob '*.log' 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  $ docfd --debug-log - --index-only --single-line-glob '*.txt' 2>&1 | grep '^Using .* search mode' | sort
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd --debug-log - --index-only --single-line-glob '*.txt' --single-line-glob '*.md' 2>&1 | grep '^Using .* search mode' | sort
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd --debug-log - --index-only --single-line-glob '*.txt' --single-line-glob '*.md' --single-line-glob '*.log' 2>&1 | grep '^Using .* search mode' | sort
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd --debug-log - --index-only --single-line-glob '*.txt' --glob '*.md' --glob '*.log' 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd --debug-log - --index-only --glob '*.txt' --single-line-glob '*.md' --glob '*.log' 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  $ docfd --debug-log - --index-only --glob '*.txt' --glob '*.md' --single-line-glob '*.log' 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  $ docfd --debug-log - --index-only --glob '*.txt' --single-line-glob '*.md' --single-line-glob '*.log' 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  $ docfd --debug-log - --index-only --single-line-glob '*.txt' --glob '*.md' --single-line-glob '*.log' 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd --debug-log - --index-only --single-line-glob '*.txt' --single-line-glob '*.md' --glob '*.log' 2>&1 | grep '^Using .* search mode' | sort
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'

--single-line-glob takes precedence over --glob and --exts:
  $ docfd --debug-log - --index-only --single-line-glob '*.txt' --glob '*.txt' --exts md . 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/5678.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd --debug-log - --index-only --single-line-glob '*.md' --glob '*.txt' --exts md . 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/5678.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  $ docfd --debug-log - --index-only --single-line-glob '*.md' --single-line-glob '*.txt' --glob '*.txt' --exts md . 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/5678.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'

--single-line-exts takes precedence over --glob and --exts:
  $ docfd --debug-log - --index-only --single-line-exts txt --glob '*.txt' --exts md . 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/5678.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test1/ijkl.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.txt'
  $ docfd --debug-log - --index-only --single-line-exts md --glob '*.txt' --exts md . 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd.md'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.md'
  Using single line search mode for document '$TESTCASE_ROOT/test1/5678.md'
  Using single line search mode for document '$TESTCASE_ROOT/test1/ijkl.md'
  Using single line search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  $ docfd --debug-log - --index-only --single-line-exts txt,md --glob '*.txt' --exts md . 2>&1 | grep '^Using .* search mode' | sort
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd.md'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.md'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test1/5678.md'
  Using single line search mode for document '$TESTCASE_ROOT/test1/ijkl.md'
  Using single line search mode for document '$TESTCASE_ROOT/test1/ijkl.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  Using single line search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.txt'

--exts apply to directories in FILE in --paths-from FILE:
  $ docfd --debug-log - --index-only --paths-from paths --exts txt 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.txt'
  $ docfd --debug-log - --index-only --paths-from paths --exts md 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.md'

--single-line-exts apply to directories in FILE in --paths-from FILE:
  $ docfd --debug-log - --index-only --paths-from paths --single-line-exts txt 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.txt'
  $ docfd --debug-log - --index-only --paths-from paths --single-line-exts md 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd.md'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd/efgh.md'
  Using single line search mode for document '$TESTCASE_ROOT/test1/ijkl/mnop.md'

Top-level files do not fall into singe line search group but into the default search group:
  $ docfd --debug-log - --index-only test.txt --single-line-exts txt 2>&1 | grep '^Using .* search mode' | sort
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd --debug-log - --index-only test.txt --single-line-glob '*.txt' 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'

Top-level files with unrecognized extensions are still picked:
  $ docfd --debug-log - --index-only --exts md . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.md'
  File: '$TESTCASE_ROOT/test1/5678.md'
  File: '$TESTCASE_ROOT/test1/ijkl.md'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  $ docfd --debug-log - --index-only --exts md test.txt . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.md'
  File: '$TESTCASE_ROOT/test1/5678.md'
  File: '$TESTCASE_ROOT/test1/ijkl.md'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.md'

Top-level files without extensions are still picked:
  $ docfd --debug-log - --index-only --exts md . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.md'
  File: '$TESTCASE_ROOT/test1/5678.md'
  File: '$TESTCASE_ROOT/test1/ijkl.md'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.md'
  $ docfd --debug-log - --index-only --exts md no-ext . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/no-ext'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd/efgh.md'
  File: '$TESTCASE_ROOT/test1/5678.md'
  File: '$TESTCASE_ROOT/test1/ijkl.md'
  File: '$TESTCASE_ROOT/test1/ijkl/mnop.md'

Double asterisk glob:
  $ docfd --debug-log - --index-only --glob '**/*.txt' 2>&1 | grep -e '^Using .* search mode' -e '^Glob regex' | sort
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
  $ docfd --debug-log - --index-only --glob '**/**/*.txt' 2>&1 | grep -e '^Using .* search mode' -e '^Glob regex' | sort
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
  $ docfd --debug-log - --index-only --glob "$(pwd)/**/*.txt" 2>&1 | grep -e '^Using .* search mode' -e '^Glob regex' | sort
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
  $ docfd --debug-log - --index-only --glob "$(pwd)/**/**/*.txt" 2>&1 | grep -e '^Using .* search mode' -e '^Glob regex' | sort
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
