Default path is not picked if any of the following is used: --paths-from, --glob, --single-line-glob:
  $ # test.md and test.txt should not be picked for the following 3 cases.
  $ docfd --debug-log - --index-only --paths-from empty-paths.txt 2>&1 | grep '^File:' | sort
  $ docfd --debug-log - --index-only --glob '*.log' 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/test.log'
  $ docfd --debug-log - --index-only --single-line-glob '*.log' 2>&1 | grep '^File:' | sort
  File: '$TESTCASE_ROOT/test.log'
  $ # test.md and test.txt should also be picked for the following cases.
  $ docfd --debug-log - --index-only --paths-from empty-paths.txt . 2>&1 | grep '^File:' | sort
  File: './empty-paths.txt'
  File: './test.log'
  File: './test.md'
  File: './test.txt'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd.txt'
  File: './test/abcd/defg.md'
  File: './test/abcd/defg.txt'
  $ docfd --debug-log - --index-only --glob '*.log' . 2>&1 | grep '^File:' | sort
  File: './empty-paths.txt'
  File: './test.log'
  File: './test.md'
  File: './test.txt'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd.txt'
  File: './test/abcd/defg.md'
  File: './test/abcd/defg.txt'
  File: '$TESTCASE_ROOT/test.log'
  $ docfd --debug-log - --index-only --single-line-glob '*.log' . 2>&1 | grep '^File:' | sort
  File: './empty-paths.txt'
  File: './test.log'
  File: './test.md'
  File: './test.txt'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd.txt'
  File: './test/abcd/defg.md'
  File: './test/abcd/defg.txt'
  File: '$TESTCASE_ROOT/test.log'

--exts and --glob do not overwrite each other:
  $ docfd --debug-log - --index-only --exts md --glob '*.log' . 2>&1 | grep '^File:' | sort
  File: './test.log'
  File: './test.md'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd/defg.md'
  File: '$TESTCASE_ROOT/test.log'

--single-line-exts and --glob do not overwrite each other:
  $ docfd --debug-log - --index-only --single-line-exts md --glob '*.log' . 2>&1 | grep '^File:' | sort
  File: './empty-paths.txt'
  File: './test.md'
  File: './test.txt'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd.txt'
  File: './test/abcd/defg.md'
  File: './test/abcd/defg.txt'
  File: '$TESTCASE_ROOT/test.log'

--exts and --single-line-glob do not overwrite each other:
  $ docfd --debug-log - --index-only --exts md --single-line-glob '*.log' . 2>&1 | grep '^File:' | sort
  File: './test.log'
  File: './test.md'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd/defg.md'
  File: '$TESTCASE_ROOT/test.log'

--single-line-exts and --single-line-glob do not overwrite each other:
  $ docfd --debug-log - --index-only --single-line-exts md --single-line-glob '*.log' . 2>&1 | grep '^File:' | sort
  File: './empty-paths.txt'
  File: './test.md'
  File: './test.txt'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd.txt'
  File: './test/abcd/defg.md'
  File: './test/abcd/defg.txt'
  File: '$TESTCASE_ROOT/test.log'

Paths from --exts, --single-line-exts, --glob, --single-line-glob, --paths-from are combined correctly:
  $ docfd --debug-log - --index-only --exts md --single-line-exts log . 2>&1 | grep '^File:' | sort
  File: './test.log'
  File: './test.md'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd/defg.md'

--add-exts:
  $ docfd --debug-log - --index-only --add-exts md . 2>&1 | grep '^File:' | sort
  File: './empty-paths.txt'
  File: './test.log'
  File: './test.md'
  File: './test.txt'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd.txt'
  File: './test/abcd/defg.md'
  File: './test/abcd/defg.txt'
  $ docfd --debug-log - --index-only --add-exts ext0 . 2>&1 | grep '^File:' | sort
  File: './empty-paths.txt'
  File: './test.ext0'
  File: './test.log'
  File: './test.md'
  File: './test.txt'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd.txt'
  File: './test/abcd/defg.md'
  File: './test/abcd/defg.txt'

--single-line-add-exts:
  $ docfd --debug-log - --index-only --single-line-add-exts md . 2>&1 | grep '^File:' | sort
  File: './empty-paths.txt'
  File: './test.log'
  File: './test.md'
  File: './test.txt'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd.txt'
  File: './test/abcd/defg.md'
  File: './test/abcd/defg.txt'
  $ docfd --debug-log - --index-only --single-line-add-exts ext0 . 2>&1 | grep '^File:' | sort
  File: './empty-paths.txt'
  File: './test.ext0'
  File: './test.log'
  File: './test.md'
  File: './test.txt'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd.txt'
  File: './test/abcd/defg.md'
  File: './test/abcd/defg.txt'

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
  Using multiline search mode for document '$TESTCASE_ROOT/test.log'
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
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
  Using multiline search mode for document '$TESTCASE_ROOT/test.log'
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd --debug-log - --index-only --glob '*.txt' --single-line-glob '*.md' --glob '*.log' 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.log'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
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
  Using multiline search mode for document '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'

--single-line-glob takes precedence over --glob and --exts:
  $ docfd --debug-log - --index-only --single-line-glob '*.txt' --glob '*.txt' --exts md . 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document './test.md'
  Using multiline search mode for document './test/1234.md'
  Using multiline search mode for document './test/abcd.md'
  Using multiline search mode for document './test/abcd/defg.md'
  Using single line search mode for document './test.log'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  $ docfd --debug-log - --index-only --single-line-glob '*.md' --glob '*.txt' --exts md . 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document './test.md'
  Using multiline search mode for document './test/1234.md'
  Using multiline search mode for document './test/abcd.md'
  Using multiline search mode for document './test/abcd/defg.md'
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document './test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  $ docfd --debug-log - --index-only --single-line-glob '*.md' --single-line-glob '*.txt' --glob '*.txt' --exts md . 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document './test.md'
  Using multiline search mode for document './test/1234.md'
  Using multiline search mode for document './test/abcd.md'
  Using multiline search mode for document './test/abcd/defg.md'
  Using single line search mode for document './test.log'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'

--single-line-exts takes precedence over --glob and --exts:
  $ docfd --debug-log - --index-only --single-line-exts txt --glob '*.txt' --exts md . 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document './test.md'
  Using multiline search mode for document './test/1234.md'
  Using multiline search mode for document './test/abcd.md'
  Using multiline search mode for document './test/abcd/defg.md'
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document './empty-paths.txt'
  Using single line search mode for document './test.txt'
  Using single line search mode for document './test/abcd.txt'
  Using single line search mode for document './test/abcd/defg.txt'
  $ docfd --debug-log - --index-only --single-line-exts md --glob '*.txt' --exts md . 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document './test.md'
  Using single line search mode for document './test/1234.md'
  Using single line search mode for document './test/abcd.md'
  Using single line search mode for document './test/abcd/defg.md'
  $ docfd --debug-log - --index-only --single-line-exts txt,md --glob '*.txt' --exts md . 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document './empty-paths.txt'
  Using single line search mode for document './test.md'
  Using single line search mode for document './test.txt'
  Using single line search mode for document './test/1234.md'
  Using single line search mode for document './test/abcd.md'
  Using single line search mode for document './test/abcd.txt'
  Using single line search mode for document './test/abcd/defg.md'
  Using single line search mode for document './test/abcd/defg.txt'

--exts apply to directories in FILE in --paths-from FILE:
  $ docfd --debug-log - --index-only --paths-from paths --exts txt 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document 'test.txt'
  Using multiline search mode for document 'test/abcd.txt'
  Using multiline search mode for document 'test/abcd/defg.txt'
  $ docfd --debug-log - --index-only --paths-from paths --exts md 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document 'test.txt'
  Using multiline search mode for document 'test/1234.md'
  Using multiline search mode for document 'test/abcd.md'
  Using multiline search mode for document 'test/abcd/defg.md'

--single-line-exts apply to directories in FILE in --paths-from FILE:
  $ docfd --debug-log - --index-only --paths-from paths --single-line-exts txt 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document 'test/1234.md'
  Using multiline search mode for document 'test/abcd.md'
  Using multiline search mode for document 'test/abcd/defg.md'
  Using single line search mode for document 'test.txt'
  Using single line search mode for document 'test/abcd.txt'
  Using single line search mode for document 'test/abcd/defg.txt'
  $ docfd --debug-log - --index-only --paths-from paths --single-line-exts md 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document 'test.txt'
  Using multiline search mode for document 'test/abcd.txt'
  Using multiline search mode for document 'test/abcd/defg.txt'
  Using single line search mode for document 'test/1234.md'
  Using single line search mode for document 'test/abcd.md'
  Using single line search mode for document 'test/abcd/defg.md'

Top-level files do not fall into singe line search group but into the default search group:
  $ docfd --debug-log - --index-only test.txt --single-line-exts txt 2>&1 | grep '^Using .* search mode' | sort
  Using single line search mode for document 'test.txt'
  $ docfd --debug-log - --index-only test.txt --single-line-glob '*.txt' 2>&1 | grep '^Using .* search mode' | sort
  Using multiline search mode for document 'test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'

Top-level files with unrecognized extensions are still picked:
  $ docfd --debug-log - --index-only --exts md . 2>&1 | grep '^File:' | sort
  File: './test.log'
  File: './test.md'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd/defg.md'
  $ docfd --debug-log - --index-only --exts md test.txt . 2>&1 | grep '^File:' | sort
  File: './test.log'
  File: './test.md'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd/defg.md'
  File: 'test.txt'

Top-level files without extensions are still picked:
  $ docfd --debug-log - --index-only --exts md . 2>&1 | grep '^File:' | sort
  File: './test.log'
  File: './test.md'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd/defg.md'
  $ docfd --debug-log - --index-only --exts md no-ext . 2>&1 | grep '^File:' | sort
  File: './test.log'
  File: './test.md'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd/defg.md'
  File: 'no-ext'

Double asterisk glob:
  $ docfd --debug-log - --index-only --glob '**/*.txt' 2>&1 | grep '^Using .* search mode' | sort
