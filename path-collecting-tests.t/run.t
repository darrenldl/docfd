Default path is not picked if any of the following is used: --paths-from, --glob, --single-line-glob:
  $ # test.md and test.txt should not be picked for the following 3 cases.
  $ docfd -L --debug-log - --index-only --paths-from empty-paths.txt 2>&1 | grep '^File:' | sort
  $ docfd -L --debug-log - --index-only --glob '*.log' 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/test.log'
  $ docfd -L --debug-log - --index-only --single-line-glob '*.log' 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/test.log'
  $ # test.md and test.txt should also be picked for the following cases.
  $ docfd -L --debug-log - --index-only --paths-from empty-paths.txt . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd.txt'
  File: '$TESTCASE_ROOT/test0/abcd/defg.md'
  File: '$TESTCASE_ROOT/test0/abcd/defg.txt'
  File: '$TESTCASE_ROOT/test1/7890.md'
  File: '$TESTCASE_ROOT/test1/efgh.md'
  File: '$TESTCASE_ROOT/test1/efgh.txt'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.md'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.txt'
  $ docfd -L --debug-log - --index-only --glob '*.log' . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd.txt'
  File: '$TESTCASE_ROOT/test0/abcd/defg.md'
  File: '$TESTCASE_ROOT/test0/abcd/defg.txt'
  File: '$TESTCASE_ROOT/test1/7890.md'
  File: '$TESTCASE_ROOT/test1/efgh.md'
  File: '$TESTCASE_ROOT/test1/efgh.txt'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.md'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.txt'
  $ docfd -L --debug-log - --index-only --single-line-glob '*.log' . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd.txt'
  File: '$TESTCASE_ROOT/test0/abcd/defg.md'
  File: '$TESTCASE_ROOT/test0/abcd/defg.txt'
  File: '$TESTCASE_ROOT/test1/7890.md'
  File: '$TESTCASE_ROOT/test1/efgh.md'
  File: '$TESTCASE_ROOT/test1/efgh.txt'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.md'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.txt'

--exts and --glob do not overwrite each other:
  $ docfd -L --debug-log - --index-only --exts md --glob '*.log' . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd/defg.md'
  File: '$TESTCASE_ROOT/test1/7890.md'
  File: '$TESTCASE_ROOT/test1/efgh.md'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.md'

--single-line-exts and --glob do not overwrite each other:
  $ docfd -L --debug-log - --index-only --single-line-exts md --glob '*.log' . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd.txt'
  File: '$TESTCASE_ROOT/test0/abcd/defg.md'
  File: '$TESTCASE_ROOT/test0/abcd/defg.txt'
  File: '$TESTCASE_ROOT/test1/7890.md'
  File: '$TESTCASE_ROOT/test1/efgh.md'
  File: '$TESTCASE_ROOT/test1/efgh.txt'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.md'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.txt'

--exts and --single-line-glob do not overwrite each other:
  $ docfd -L --debug-log - --index-only --exts md --single-line-glob '*.log' . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd/defg.md'
  File: '$TESTCASE_ROOT/test1/7890.md'
  File: '$TESTCASE_ROOT/test1/efgh.md'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.md'

--single-line-exts and --single-line-glob do not overwrite each other:
  $ docfd -L --debug-log - --index-only --single-line-exts md --single-line-glob '*.log' . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd.txt'
  File: '$TESTCASE_ROOT/test0/abcd/defg.md'
  File: '$TESTCASE_ROOT/test0/abcd/defg.txt'
  File: '$TESTCASE_ROOT/test1/7890.md'
  File: '$TESTCASE_ROOT/test1/efgh.md'
  File: '$TESTCASE_ROOT/test1/efgh.txt'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.md'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.txt'

Paths from --exts, --single-line-exts, --glob, --single-line-glob, --paths-from are combined correctly:
  $ docfd -L --debug-log - --index-only --exts md --single-line-exts log . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd/defg.md'
  File: '$TESTCASE_ROOT/test1/7890.md'
  File: '$TESTCASE_ROOT/test1/efgh.md'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.md'

--add-exts:
  $ docfd -L --debug-log - --index-only --add-exts md . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd.txt'
  File: '$TESTCASE_ROOT/test0/abcd/defg.md'
  File: '$TESTCASE_ROOT/test0/abcd/defg.txt'
  File: '$TESTCASE_ROOT/test1/7890.md'
  File: '$TESTCASE_ROOT/test1/efgh.md'
  File: '$TESTCASE_ROOT/test1/efgh.txt'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.md'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.txt'
  $ docfd -L --debug-log - --index-only --add-exts ext0 . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.ext0'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd.txt'
  File: '$TESTCASE_ROOT/test0/abcd/defg.md'
  File: '$TESTCASE_ROOT/test0/abcd/defg.txt'
  File: '$TESTCASE_ROOT/test1/7890.md'
  File: '$TESTCASE_ROOT/test1/efgh.md'
  File: '$TESTCASE_ROOT/test1/efgh.txt'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.md'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.txt'

--single-line-add-exts:
  $ docfd -L --debug-log - --index-only --single-line-add-exts md . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd.txt'
  File: '$TESTCASE_ROOT/test0/abcd/defg.md'
  File: '$TESTCASE_ROOT/test0/abcd/defg.txt'
  File: '$TESTCASE_ROOT/test1/7890.md'
  File: '$TESTCASE_ROOT/test1/efgh.md'
  File: '$TESTCASE_ROOT/test1/efgh.txt'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.md'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.txt'
  $ docfd -L --debug-log - --index-only --single-line-add-exts ext0 . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.ext0'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd.txt'
  File: '$TESTCASE_ROOT/test0/abcd/defg.md'
  File: '$TESTCASE_ROOT/test0/abcd/defg.txt'
  File: '$TESTCASE_ROOT/test1/7890.md'
  File: '$TESTCASE_ROOT/test1/efgh.md'
  File: '$TESTCASE_ROOT/test1/efgh.txt'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.md'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.txt'

Picking via multiple --glob and --single-line-glob:
  $ docfd -L --debug-log - --index-only --glob '*.txt' 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd -L --debug-log - --index-only --glob "*.txt" --glob '*.md' 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd -L --debug-log - --index-only --glob '*.txt' --glob '*.md' --glob '*.log' 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  $ docfd -L --debug-log - --index-only --single-line-glob '*.txt' 2>&1 | grep '^Using .* search mode' | sort
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd -L --debug-log - --index-only --single-line-glob '*.txt' --single-line-glob '*.md' 2>&1 | grep '^Using .* search mode' | sort
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd -L --debug-log - --index-only --single-line-glob '*.txt' --single-line-glob '*.md' --single-line-glob '*.log' 2>&1 | grep '^Using .* search mode' | sort
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd -L --debug-log - --index-only --single-line-glob '*.txt' --glob '*.md' --glob '*.log' 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd -L --debug-log - --index-only --glob '*.txt' --single-line-glob '*.md' --glob '*.log' 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  $ docfd -L --debug-log - --index-only --glob '*.txt' --glob '*.md' --single-line-glob '*.log' 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  $ docfd -L --debug-log - --index-only --glob '*.txt' --single-line-glob '*.md' --single-line-glob '*.log' 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  $ docfd -L --debug-log - --index-only --single-line-glob '*.txt' --glob '*.md' --single-line-glob '*.log' 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd -L --debug-log - --index-only --single-line-glob '*.txt' --single-line-glob '*.md' --glob '*.log' 2>&1 | grep '^Using .* search mode' | sort
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'

--single-line-glob takes precedence over --glob and --exts:
  $ docfd -L --debug-log - --index-only --single-line-glob '*.txt' --glob '*.txt' --exts md . 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/defg.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/7890.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/efgh.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/efgh/hijk.md'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd -L --debug-log - --index-only --single-line-glob '*.md' --glob '*.txt' --exts md . 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/defg.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/7890.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/efgh.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/efgh/hijk.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  $ docfd -L --debug-log - --index-only --single-line-glob '*.md' --single-line-glob '*.txt' --glob '*.txt' --exts md . 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/defg.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/7890.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/efgh.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/efgh/hijk.md'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'

--single-line-exts takes precedence over --glob and --exts:
  $ docfd -L --debug-log - --index-only --single-line-exts txt --glob '*.txt' --exts md . 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/defg.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/7890.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/efgh.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/efgh/hijk.md'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd/defg.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test1/efgh.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test1/efgh/hijk.txt'
  $ docfd -L --debug-log - --index-only --single-line-exts md --glob '*.txt' --exts md . 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd.md'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd/defg.md'
  Using single line search mode for document '$TESTCASE_ROOT/test1/7890.md'
  Using single line search mode for document '$TESTCASE_ROOT/test1/efgh.md'
  Using single line search mode for document '$TESTCASE_ROOT/test1/efgh/hijk.md'
  $ docfd -L --debug-log - --index-only --single-line-exts txt,md --glob '*.txt' --exts md . 2>&1 | grep '^Using .* search mode' | sort
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd.md'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd/defg.md'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd/defg.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test1/7890.md'
  Using single line search mode for document '$TESTCASE_ROOT/test1/efgh.md'
  Using single line search mode for document '$TESTCASE_ROOT/test1/efgh.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test1/efgh/hijk.md'
  Using single line search mode for document '$TESTCASE_ROOT/test1/efgh/hijk.txt'

--exts apply to directories in FILE in --paths-from FILE:
  $ docfd -L --debug-log - --index-only --paths-from paths --exts txt 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/defg.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/efgh/hijk.txt'
  $ docfd -L --debug-log - --index-only --paths-from paths --exts md 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/defg.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/efgh/hijk.md'

--single-line-exts apply to directories in FILE in --paths-from FILE:
  $ docfd -L --debug-log - --index-only --paths-from paths --single-line-exts txt 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/defg.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/efgh/hijk.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd/defg.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test1/efgh/hijk.txt'
  $ docfd -L --debug-log - --index-only --paths-from paths --single-line-exts md 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/defg.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/efgh/hijk.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test0/1234.md'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd.md'
  Using single line search mode for document '$TESTCASE_ROOT/test0/abcd/defg.md'
  Using single line search mode for document '$TESTCASE_ROOT/test1/efgh/hijk.md'

Top-level files do not fall into singe line search group but into the default search group:
  $ docfd -L --debug-log - --index-only test.txt --single-line-exts txt 2>&1 | grep '^Using .* search mode' | sort
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd -L --debug-log - --index-only test.txt --single-line-glob '*.txt' 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'

Top-level files with unrecognized extensions are still picked:
  $ docfd -L --debug-log - --index-only --exts md . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd/defg.md'
  File: '$TESTCASE_ROOT/test1/7890.md'
  File: '$TESTCASE_ROOT/test1/efgh.md'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.md'
  $ docfd -L --debug-log - --index-only --exts md test.txt . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd/defg.md'
  File: '$TESTCASE_ROOT/test1/7890.md'
  File: '$TESTCASE_ROOT/test1/efgh.md'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.md'

Top-level files without extensions are still picked:
  $ docfd -L --debug-log - --index-only --exts md . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd/defg.md'
  File: '$TESTCASE_ROOT/test1/7890.md'
  File: '$TESTCASE_ROOT/test1/efgh.md'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.md'
  $ docfd -L --debug-log - --index-only --exts md no-ext . 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/no-ext'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test0/1234.md'
  File: '$TESTCASE_ROOT/test0/abcd.md'
  File: '$TESTCASE_ROOT/test0/abcd/defg.md'
  File: '$TESTCASE_ROOT/test1/7890.md'
  File: '$TESTCASE_ROOT/test1/efgh.md'
  File: '$TESTCASE_ROOT/test1/efgh/hijk.md'

Double asterisk glob:
  $ docfd -L --debug-log - --index-only --glob '**/*.txt' 2>&1 | grep -e '^Using .* search mode' -e '^Glob regex' | sort
  Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/empty-paths.txt
  Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test.txt
  Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test0/abcd.txt
  Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test0/abcd/defg.txt
  Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test1/efgh.txt
  Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test1/efgh/hijk.txt
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/defg.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/efgh.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/efgh/hijk.txt'
  $ docfd -L --debug-log - --index-only --glob '**/**/*.txt' 2>&1 | grep -e '^Using .* search mode' -e '^Glob regex' | sort
  Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/empty-paths.txt
  Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test.txt
  Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test0/abcd.txt
  Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test0/abcd/defg.txt
  Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test1/efgh.txt
  Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test1/efgh/hijk.txt
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/defg.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/efgh.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/efgh/hijk.txt'
  $ docfd -L --debug-log - --index-only --glob "$(pwd)/**/*.txt" 2>&1 | grep -e '^Using .* search mode' -e '^Glob regex' | sort
  Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/empty-paths.txt
  Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test.txt
  Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test0/abcd.txt
  Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test0/abcd/defg.txt
  Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test1/efgh.txt
  Glob regex $TESTCASE_ROOT/**/*.txt matches path $TESTCASE_ROOT/test1/efgh/hijk.txt
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/defg.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/efgh.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/efgh/hijk.txt'
  $ docfd -L --debug-log - --index-only --glob "$(pwd)/**/**/*.txt" 2>&1 | grep -e '^Using .* search mode' -e '^Glob regex' | sort
  Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/empty-paths.txt
  Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test.txt
  Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test0/abcd.txt
  Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test0/abcd/defg.txt
  Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test1/efgh.txt
  Glob regex $TESTCASE_ROOT/**/**/*.txt matches path $TESTCASE_ROOT/test1/efgh/hijk.txt
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test0/abcd/defg.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/efgh.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test1/efgh/hijk.txt'
