Default path is not picked if any of the following is used: --paths-from, --glob, --single-line-glob:
  $ # test.md and test.txt should not be picked for the following 3 cases.
  $ docfd --debug-log - --index-only --paths-from empty-paths.txt
  Scanning for documents
  Scanning completed
  Document source: files
  $ docfd --debug-log - --index-only --glob '*.log'
  Scanning for documents
  Scanning completed
  Document source: files
  File: '$TESTCASE_ROOT/test.log'
  Loading document: '$TESTCASE_ROOT/test.log'
  Using multiline search mode for document '$TESTCASE_ROOT/test.log'
  Document '$TESTCASE_ROOT/test.log' loaded successfully
  $ docfd --debug-log - --index-only --single-line-glob '*.log'
  Scanning for documents
  Scanning completed
  Document source: files
  File: '$TESTCASE_ROOT/test.log'
  Loading document: '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Document '$TESTCASE_ROOT/test.log' loaded successfully
  $ # test.md and test.txt should also be picked for the following cases.
  $ docfd --debug-log - --index-only --paths-from empty-paths.txt .
  Scanning for documents
  Scanning completed
  Document source: files
  File: './empty-paths.txt'
  File: './test.log'
  File: './test.md'
  File: './test.txt'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd.txt'
  File: './test/abcd/defg.md'
  File: './test/abcd/defg.txt'
  Loading document: './empty-paths.txt'
  Using multiline search mode for document './empty-paths.txt'
  Loading document: './test.log'
  Using single line search mode for document './test.log'
  Loading document: './test.md'
  Using multiline search mode for document './test.md'
  Loading document: './test.txt'
  Using multiline search mode for document './test.txt'
  Loading document: './test/1234.md'
  Using multiline search mode for document './test/1234.md'
  Loading document: './test/abcd.md'
  Using multiline search mode for document './test/abcd.md'
  Loading document: './test/abcd.txt'
  Using multiline search mode for document './test/abcd.txt'
  Loading document: './test/abcd/defg.md'
  Using multiline search mode for document './test/abcd/defg.md'
  Loading document: './test/abcd/defg.txt'
  Using multiline search mode for document './test/abcd/defg.txt'
  Document './empty-paths.txt' loaded successfully
  Document './test.txt' loaded successfully
  Document './test/abcd/defg.md' loaded successfully
  Document './test.log' loaded successfully
  Document './test/1234.md' loaded successfully
  Document './test/abcd.txt' loaded successfully
  Document './test/abcd/defg.txt' loaded successfully
  Document './test/abcd.md' loaded successfully
  Document './test.md' loaded successfully
  $ docfd --debug-log - --index-only --glob '*.log' .
  Scanning for documents
  Scanning completed
  Document source: files
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
  Loading document: './empty-paths.txt'
  Using multiline search mode for document './empty-paths.txt'
  Loading document: './test.log'
  Using single line search mode for document './test.log'
  Loading document: './test.md'
  Using multiline search mode for document './test.md'
  Loading document: './test.txt'
  Using multiline search mode for document './test.txt'
  Loading document: './test/1234.md'
  Using multiline search mode for document './test/1234.md'
  Loading document: './test/abcd.md'
  Using multiline search mode for document './test/abcd.md'
  Loading document: './test/abcd.txt'
  Using multiline search mode for document './test/abcd.txt'
  Loading document: './test/abcd/defg.md'
  Using multiline search mode for document './test/abcd/defg.md'
  Loading document: './test/abcd/defg.txt'
  Using multiline search mode for document './test/abcd/defg.txt'
  Loading document: '$TESTCASE_ROOT/test.log'
  Using multiline search mode for document '$TESTCASE_ROOT/test.log'
  Document './test.log' loaded successfully
  Document './test/1234.md' loaded successfully
  Document './test/abcd/defg.md' loaded successfully
  Document './test.txt' loaded successfully
  Document './test/abcd.txt' loaded successfully
  Document '$TESTCASE_ROOT/test.log' loaded successfully
  Document './test.md' loaded successfully
  Document './test/abcd/defg.txt' loaded successfully
  Document './empty-paths.txt' loaded successfully
  Document './test/abcd.md' loaded successfully
  $ docfd --debug-log - --index-only --single-line-glob '*.log' .
  Scanning for documents
  Scanning completed
  Document source: files
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
  Loading document: './empty-paths.txt'
  Using multiline search mode for document './empty-paths.txt'
  Loading document: './test.log'
  Using single line search mode for document './test.log'
  Loading document: './test.md'
  Using multiline search mode for document './test.md'
  Loading document: './test.txt'
  Using multiline search mode for document './test.txt'
  Loading document: './test/1234.md'
  Using multiline search mode for document './test/1234.md'
  Loading document: './test/abcd.md'
  Using multiline search mode for document './test/abcd.md'
  Loading document: './test/abcd.txt'
  Using multiline search mode for document './test/abcd.txt'
  Loading document: './test/abcd/defg.md'
  Using multiline search mode for document './test/abcd/defg.md'
  Loading document: './test/abcd/defg.txt'
  Using multiline search mode for document './test/abcd/defg.txt'
  Loading document: '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Document './empty-paths.txt' loaded successfully
  Document './test.md' loaded successfully
  Document './test/abcd/defg.md' loaded successfully
  Document './test.log' loaded successfully
  Document './test/abcd.txt' loaded successfully
  Document './test/abcd.md' loaded successfully
  Document '$TESTCASE_ROOT/test.log' loaded successfully
  Document './test.txt' loaded successfully
  Document './test/1234.md' loaded successfully
  Document './test/abcd/defg.txt' loaded successfully

--exts and --glob do not overwrite each other:
  $ docfd --debug-log - --index-only --exts md --glob '*.log' .
  Scanning for documents
  Scanning completed
  Document source: files
  File: './test.log'
  File: './test.md'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd/defg.md'
  File: '$TESTCASE_ROOT/test.log'
  Loading document: './test.log'
  Using single line search mode for document './test.log'
  Loading document: './test.md'
  Using multiline search mode for document './test.md'
  Loading document: './test/1234.md'
  Using multiline search mode for document './test/1234.md'
  Loading document: './test/abcd.md'
  Using multiline search mode for document './test/abcd.md'
  Loading document: './test/abcd/defg.md'
  Using multiline search mode for document './test/abcd/defg.md'
  Loading document: '$TESTCASE_ROOT/test.log'
  Using multiline search mode for document '$TESTCASE_ROOT/test.log'
  Document './test.md' loaded successfully
  Document './test/abcd.md' loaded successfully
  Document './test/1234.md' loaded successfully
  Document './test.log' loaded successfully
  Document './test/abcd/defg.md' loaded successfully
  Document '$TESTCASE_ROOT/test.log' loaded successfully

--single-line-exts and --glob do not overwrite each other:
  $ docfd --debug-log - --index-only --single-line-exts md --glob '*.log' .
  Scanning for documents
  Scanning completed
  Document source: files
  File: './empty-paths.txt'
  File: './test.md'
  File: './test.txt'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd.txt'
  File: './test/abcd/defg.md'
  File: './test/abcd/defg.txt'
  File: '$TESTCASE_ROOT/test.log'
  Loading document: './empty-paths.txt'
  Using multiline search mode for document './empty-paths.txt'
  Loading document: './test.md'
  Using single line search mode for document './test.md'
  Loading document: './test.txt'
  Using multiline search mode for document './test.txt'
  Loading document: './test/1234.md'
  Using single line search mode for document './test/1234.md'
  Loading document: './test/abcd.md'
  Using single line search mode for document './test/abcd.md'
  Loading document: './test/abcd.txt'
  Using multiline search mode for document './test/abcd.txt'
  Loading document: './test/abcd/defg.md'
  Using single line search mode for document './test/abcd/defg.md'
  Loading document: './test/abcd/defg.txt'
  Using multiline search mode for document './test/abcd/defg.txt'
  Loading document: '$TESTCASE_ROOT/test.log'
  Using multiline search mode for document '$TESTCASE_ROOT/test.log'
  Document './test/abcd.md' loaded successfully
  Document './test.txt' loaded successfully
  Document './test/abcd/defg.txt' loaded successfully
  Document './test/1234.md' loaded successfully
  Document './empty-paths.txt' loaded successfully
  Document './test.md' loaded successfully
  Document './test/abcd.txt' loaded successfully
  Document '$TESTCASE_ROOT/test.log' loaded successfully
  Document './test/abcd/defg.md' loaded successfully

--exts and --single-line-glob do not overwrite each other:
  $ docfd --debug-log - --index-only --exts md --single-line-glob '*.log' .
  Scanning for documents
  Scanning completed
  Document source: files
  File: './test.log'
  File: './test.md'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd/defg.md'
  File: '$TESTCASE_ROOT/test.log'
  Loading document: './test.log'
  Using single line search mode for document './test.log'
  Loading document: './test.md'
  Using multiline search mode for document './test.md'
  Loading document: './test/1234.md'
  Using multiline search mode for document './test/1234.md'
  Loading document: './test/abcd.md'
  Using multiline search mode for document './test/abcd.md'
  Loading document: './test/abcd/defg.md'
  Using multiline search mode for document './test/abcd/defg.md'
  Loading document: '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Document './test.log' loaded successfully
  Document './test/1234.md' loaded successfully
  Document './test/abcd/defg.md' loaded successfully
  Document '$TESTCASE_ROOT/test.log' loaded successfully
  Document './test.md' loaded successfully
  Document './test/abcd.md' loaded successfully

--single-line-exts and --single-line-glob do not overwrite each other:
  $ docfd --debug-log - --index-only --single-line-exts md --single-line-glob '*.log' .
  Scanning for documents
  Scanning completed
  Document source: files
  File: './empty-paths.txt'
  File: './test.md'
  File: './test.txt'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd.txt'
  File: './test/abcd/defg.md'
  File: './test/abcd/defg.txt'
  File: '$TESTCASE_ROOT/test.log'
  Loading document: './empty-paths.txt'
  Using multiline search mode for document './empty-paths.txt'
  Loading document: './test.md'
  Using single line search mode for document './test.md'
  Loading document: './test.txt'
  Using multiline search mode for document './test.txt'
  Loading document: './test/1234.md'
  Using single line search mode for document './test/1234.md'
  Loading document: './test/abcd.md'
  Using single line search mode for document './test/abcd.md'
  Loading document: './test/abcd.txt'
  Using multiline search mode for document './test/abcd.txt'
  Loading document: './test/abcd/defg.md'
  Using single line search mode for document './test/abcd/defg.md'
  Loading document: './test/abcd/defg.txt'
  Using multiline search mode for document './test/abcd/defg.txt'
  Loading document: '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Document './empty-paths.txt' loaded successfully
  Document './test.md' loaded successfully
  Document './test/abcd.md' loaded successfully
  Document './test/abcd/defg.md' loaded successfully
  Document './test/abcd/defg.txt' loaded successfully
  Document '$TESTCASE_ROOT/test.log' loaded successfully
  Document './test/1234.md' loaded successfully
  Document './test.txt' loaded successfully
  Document './test/abcd.txt' loaded successfully

Paths from --exts, --single-line-exts, --glob, --single-line-glob, --paths-from are combined correctly:
  $ docfd --debug-log - --index-only --exts md --single-line-exts log .
  Scanning for documents
  Scanning completed
  Document source: files
  File: './test.log'
  File: './test.md'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd/defg.md'
  Loading document: './test.log'
  Using single line search mode for document './test.log'
  Loading document: './test.md'
  Using multiline search mode for document './test.md'
  Loading document: './test/1234.md'
  Using multiline search mode for document './test/1234.md'
  Loading document: './test/abcd.md'
  Using multiline search mode for document './test/abcd.md'
  Loading document: './test/abcd/defg.md'
  Using multiline search mode for document './test/abcd/defg.md'
  Document './test.md' loaded successfully
  Document './test.log' loaded successfully
  Document './test/1234.md' loaded successfully
  Document './test/abcd.md' loaded successfully
  Document './test/abcd/defg.md' loaded successfully

--add-exts:
  $ docfd --debug-log - --index-only --add-exts md .
  Scanning for documents
  Scanning completed
  Document source: files
  File: './empty-paths.txt'
  File: './test.log'
  File: './test.md'
  File: './test.txt'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd.txt'
  File: './test/abcd/defg.md'
  File: './test/abcd/defg.txt'
  Loading document: './empty-paths.txt'
  Using multiline search mode for document './empty-paths.txt'
  Loading document: './test.log'
  Using single line search mode for document './test.log'
  Loading document: './test.md'
  Using multiline search mode for document './test.md'
  Loading document: './test.txt'
  Using multiline search mode for document './test.txt'
  Loading document: './test/1234.md'
  Using multiline search mode for document './test/1234.md'
  Loading document: './test/abcd.md'
  Using multiline search mode for document './test/abcd.md'
  Loading document: './test/abcd.txt'
  Using multiline search mode for document './test/abcd.txt'
  Loading document: './test/abcd/defg.md'
  Using multiline search mode for document './test/abcd/defg.md'
  Loading document: './test/abcd/defg.txt'
  Using multiline search mode for document './test/abcd/defg.txt'
  Document './test.log' loaded successfully
  Document './test/1234.md' loaded successfully
  Document './test/abcd/defg.md' loaded successfully
  Document './test.txt' loaded successfully
  Document './test/abcd.txt' loaded successfully
  Document './test/abcd/defg.txt' loaded successfully
  Document './empty-paths.txt' loaded successfully
  Document './test.md' loaded successfully
  Document './test/abcd.md' loaded successfully
  $ docfd --debug-log - --index-only --add-exts ext0 .
  Scanning for documents
  Scanning completed
  Document source: files
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
  Loading document: './empty-paths.txt'
  Using multiline search mode for document './empty-paths.txt'
  Loading document: './test.ext0'
  Using multiline search mode for document './test.ext0'
  Loading document: './test.log'
  Using single line search mode for document './test.log'
  Loading document: './test.md'
  Using multiline search mode for document './test.md'
  Loading document: './test.txt'
  Using multiline search mode for document './test.txt'
  Loading document: './test/1234.md'
  Using multiline search mode for document './test/1234.md'
  Loading document: './test/abcd.md'
  Using multiline search mode for document './test/abcd.md'
  Loading document: './test/abcd.txt'
  Using multiline search mode for document './test/abcd.txt'
  Loading document: './test/abcd/defg.md'
  Using multiline search mode for document './test/abcd/defg.md'
  Loading document: './test/abcd/defg.txt'
  Using multiline search mode for document './test/abcd/defg.txt'
  Document './test.md' loaded successfully
  Document './test/abcd.txt' loaded successfully
  Document './test.log' loaded successfully
  Document './test.ext0' loaded successfully
  Document './empty-paths.txt' loaded successfully
  Document './test.txt' loaded successfully
  Document './test/abcd.md' loaded successfully
  Document './test/abcd/defg.md' loaded successfully
  Document './test/1234.md' loaded successfully
  Document './test/abcd/defg.txt' loaded successfully

--single-line-add-exts:
  $ docfd --debug-log - --index-only --single-line-add-exts md .
  Scanning for documents
  Scanning completed
  Document source: files
  File: './empty-paths.txt'
  File: './test.log'
  File: './test.md'
  File: './test.txt'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd.txt'
  File: './test/abcd/defg.md'
  File: './test/abcd/defg.txt'
  Loading document: './empty-paths.txt'
  Using multiline search mode for document './empty-paths.txt'
  Loading document: './test.log'
  Using single line search mode for document './test.log'
  Loading document: './test.md'
  Using single line search mode for document './test.md'
  Loading document: './test.txt'
  Using multiline search mode for document './test.txt'
  Loading document: './test/1234.md'
  Using single line search mode for document './test/1234.md'
  Loading document: './test/abcd.md'
  Using single line search mode for document './test/abcd.md'
  Loading document: './test/abcd.txt'
  Using multiline search mode for document './test/abcd.txt'
  Loading document: './test/abcd/defg.md'
  Using single line search mode for document './test/abcd/defg.md'
  Loading document: './test/abcd/defg.txt'
  Using multiline search mode for document './test/abcd/defg.txt'
  Document './test.txt' loaded successfully
  Document './test.log' loaded successfully
  Document './test/abcd/defg.txt' loaded successfully
  Document './test.md' loaded successfully
  Document './test/abcd.md' loaded successfully
  Document './test/abcd/defg.md' loaded successfully
  Document './test/1234.md' loaded successfully
  Document './empty-paths.txt' loaded successfully
  Document './test/abcd.txt' loaded successfully
  $ docfd --debug-log - --index-only --single-line-add-exts ext0 .
  Scanning for documents
  Scanning completed
  Document source: files
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
  Loading document: './empty-paths.txt'
  Using multiline search mode for document './empty-paths.txt'
  Loading document: './test.ext0'
  Using single line search mode for document './test.ext0'
  Loading document: './test.log'
  Using single line search mode for document './test.log'
  Loading document: './test.md'
  Using multiline search mode for document './test.md'
  Loading document: './test.txt'
  Using multiline search mode for document './test.txt'
  Loading document: './test/1234.md'
  Using multiline search mode for document './test/1234.md'
  Loading document: './test/abcd.md'
  Using multiline search mode for document './test/abcd.md'
  Loading document: './test/abcd.txt'
  Using multiline search mode for document './test/abcd.txt'
  Loading document: './test/abcd/defg.md'
  Using multiline search mode for document './test/abcd/defg.md'
  Loading document: './test/abcd/defg.txt'
  Using multiline search mode for document './test/abcd/defg.txt'
  Document './test.md' loaded successfully
  Document './empty-paths.txt' loaded successfully
  Document './test.ext0' loaded successfully
  Document './test.log' loaded successfully
  Document './test.txt' loaded successfully
  Document './test/abcd.md' loaded successfully
  Document './test/abcd.txt' loaded successfully
  Document './test/abcd/defg.md' loaded successfully
  Document './test/abcd/defg.txt' loaded successfully
  Document './test/1234.md' loaded successfully

Picking via multiple --glob and --single-line-glob:
  $ docfd --debug-log - --index-only --glob '*.txt'
  Scanning for documents
  Scanning completed
  Document source: files
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.txt'
  Loading document: '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Loading document: '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Document '$TESTCASE_ROOT/empty-paths.txt' loaded successfully
  Document '$TESTCASE_ROOT/test.txt' loaded successfully
  $ docfd --debug-log - --index-only --glob "*.txt" --glob '*.md'
  Scanning for documents
  Scanning completed
  Document source: files
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  Loading document: '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Loading document: '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Loading document: '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Document '$TESTCASE_ROOT/empty-paths.txt' loaded successfully
  Document '$TESTCASE_ROOT/test.md' loaded successfully
  Document '$TESTCASE_ROOT/test.txt' loaded successfully
  $ docfd --debug-log - --index-only --glob '*.txt' --glob '*.md' --glob '*.log'
  Scanning for documents
  Scanning completed
  Document source: files
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  Loading document: '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Loading document: '$TESTCASE_ROOT/test.log'
  Using multiline search mode for document '$TESTCASE_ROOT/test.log'
  Loading document: '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Loading document: '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Document '$TESTCASE_ROOT/test.txt' loaded successfully
  Document '$TESTCASE_ROOT/test.log' loaded successfully
  Document '$TESTCASE_ROOT/test.md' loaded successfully
  Document '$TESTCASE_ROOT/empty-paths.txt' loaded successfully
  $ docfd --debug-log - --index-only --single-line-glob '*.txt'
  Scanning for documents
  Scanning completed
  Document source: files
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.txt'
  Loading document: '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Loading document: '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  Document '$TESTCASE_ROOT/test.txt' loaded successfully
  Document '$TESTCASE_ROOT/empty-paths.txt' loaded successfully
  $ docfd --debug-log - --index-only --single-line-glob '*.txt' --single-line-glob '*.md'
  Scanning for documents
  Scanning completed
  Document source: files
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  Loading document: '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Loading document: '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Loading document: '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  Document '$TESTCASE_ROOT/empty-paths.txt' loaded successfully
  Document '$TESTCASE_ROOT/test.md' loaded successfully
  Document '$TESTCASE_ROOT/test.txt' loaded successfully
  $ docfd --debug-log - --index-only --single-line-glob '*.txt' --single-line-glob '*.md' --single-line-glob '*.log'
  Scanning for documents
  Scanning completed
  Document source: files
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  Loading document: '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Loading document: '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Loading document: '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Loading document: '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  Document '$TESTCASE_ROOT/test.log' loaded successfully
  Document '$TESTCASE_ROOT/test.md' loaded successfully
  Document '$TESTCASE_ROOT/empty-paths.txt' loaded successfully
  Document '$TESTCASE_ROOT/test.txt' loaded successfully
  $ docfd --debug-log - --index-only --single-line-glob '*.txt' --glob '*.md' --glob '*.log'
  Scanning for documents
  Scanning completed
  Document source: files
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  Loading document: '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Loading document: '$TESTCASE_ROOT/test.log'
  Using multiline search mode for document '$TESTCASE_ROOT/test.log'
  Loading document: '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Loading document: '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  Document '$TESTCASE_ROOT/test.log' loaded successfully
  Document '$TESTCASE_ROOT/test.txt' loaded successfully
  Document '$TESTCASE_ROOT/test.md' loaded successfully
  Document '$TESTCASE_ROOT/empty-paths.txt' loaded successfully
  $ docfd --debug-log - --index-only --glob '*.txt' --single-line-glob '*.md' --glob '*.log'
  Scanning for documents
  Scanning completed
  Document source: files
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  Loading document: '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Loading document: '$TESTCASE_ROOT/test.log'
  Using multiline search mode for document '$TESTCASE_ROOT/test.log'
  Loading document: '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Loading document: '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Document '$TESTCASE_ROOT/empty-paths.txt' loaded successfully
  Document '$TESTCASE_ROOT/test.log' loaded successfully
  Document '$TESTCASE_ROOT/test.md' loaded successfully
  Document '$TESTCASE_ROOT/test.txt' loaded successfully
  $ docfd --debug-log - --index-only --glob '*.txt' --glob '*.md' --single-line-glob '*.log'
  Scanning for documents
  Scanning completed
  Document source: files
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  Loading document: '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Loading document: '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Loading document: '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Loading document: '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Document '$TESTCASE_ROOT/empty-paths.txt' loaded successfully
  Document '$TESTCASE_ROOT/test.log' loaded successfully
  Document '$TESTCASE_ROOT/test.md' loaded successfully
  Document '$TESTCASE_ROOT/test.txt' loaded successfully
  $ docfd --debug-log - --index-only --glob '*.txt' --single-line-glob '*.md' --single-line-glob '*.log'
  Scanning for documents
  Scanning completed
  Document source: files
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  Loading document: '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Loading document: '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Loading document: '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Loading document: '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Document '$TESTCASE_ROOT/test.txt' loaded successfully
  Document '$TESTCASE_ROOT/test.log' loaded successfully
  Document '$TESTCASE_ROOT/empty-paths.txt' loaded successfully
  Document '$TESTCASE_ROOT/test.md' loaded successfully
  $ docfd --debug-log - --index-only --single-line-glob '*.txt' --glob '*.md' --single-line-glob '*.log'
  Scanning for documents
  Scanning completed
  Document source: files
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  Loading document: '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Loading document: '$TESTCASE_ROOT/test.log'
  Using single line search mode for document '$TESTCASE_ROOT/test.log'
  Loading document: '$TESTCASE_ROOT/test.md'
  Using multiline search mode for document '$TESTCASE_ROOT/test.md'
  Loading document: '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  Document '$TESTCASE_ROOT/test.txt' loaded successfully
  Document '$TESTCASE_ROOT/test.log' loaded successfully
  Document '$TESTCASE_ROOT/empty-paths.txt' loaded successfully
  Document '$TESTCASE_ROOT/test.md' loaded successfully
  $ docfd --debug-log - --index-only --single-line-glob '*.txt' --single-line-glob '*.md' --glob '*.log'
  Scanning for documents
  Scanning completed
  Document source: files
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.log'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  Loading document: '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Loading document: '$TESTCASE_ROOT/test.log'
  Using multiline search mode for document '$TESTCASE_ROOT/test.log'
  Loading document: '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Loading document: '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  Document '$TESTCASE_ROOT/empty-paths.txt' loaded successfully
  Document '$TESTCASE_ROOT/test.log' loaded successfully
  Document '$TESTCASE_ROOT/test.md' loaded successfully
  Document '$TESTCASE_ROOT/test.txt' loaded successfully

--single-line-glob takes precedence over --glob and --exts:
  $ docfd --debug-log - --index-only --single-line-glob '*.txt' --glob '*.txt' --exts md .
  Scanning for documents
  Scanning completed
  Document source: files
  File: './test.log'
  File: './test.md'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd/defg.md'
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.txt'
  Loading document: './test.log'
  Using single line search mode for document './test.log'
  Loading document: './test.md'
  Using multiline search mode for document './test.md'
  Loading document: './test/1234.md'
  Using multiline search mode for document './test/1234.md'
  Loading document: './test/abcd.md'
  Using multiline search mode for document './test/abcd.md'
  Loading document: './test/abcd/defg.md'
  Using multiline search mode for document './test/abcd/defg.md'
  Loading document: '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Loading document: '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  Document './test.log' loaded successfully
  Document './test/abcd.md' loaded successfully
  Document './test.md' loaded successfully
  Document './test/1234.md' loaded successfully
  Document './test/abcd/defg.md' loaded successfully
  Document '$TESTCASE_ROOT/empty-paths.txt' loaded successfully
  Document '$TESTCASE_ROOT/test.txt' loaded successfully
  $ docfd --debug-log - --index-only --single-line-glob '*.md' --glob '*.txt' --exts md .
  Scanning for documents
  Scanning completed
  Document source: files
  File: './test.log'
  File: './test.md'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd/defg.md'
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  Loading document: './test.log'
  Using single line search mode for document './test.log'
  Loading document: './test.md'
  Using multiline search mode for document './test.md'
  Loading document: './test/1234.md'
  Using multiline search mode for document './test/1234.md'
  Loading document: './test/abcd.md'
  Using multiline search mode for document './test/abcd.md'
  Loading document: './test/abcd/defg.md'
  Using multiline search mode for document './test/abcd/defg.md'
  Loading document: '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Loading document: '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Loading document: '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Document './test.log' loaded successfully
  Document './test.md' loaded successfully
  Document './test/1234.md' loaded successfully
  Document '$TESTCASE_ROOT/empty-paths.txt' loaded successfully
  Document '$TESTCASE_ROOT/test.md' loaded successfully
  Document '$TESTCASE_ROOT/test.txt' loaded successfully
  Document './test/abcd.md' loaded successfully
  Document './test/abcd/defg.md' loaded successfully
  $ docfd --debug-log - --index-only --single-line-glob '*.md' --single-line-glob '*.txt' --glob '*.txt' --exts md .
  Scanning for documents
  Scanning completed
  Document source: files
  File: './test.log'
  File: './test.md'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd/defg.md'
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.md'
  File: '$TESTCASE_ROOT/test.txt'
  Loading document: './test.log'
  Using single line search mode for document './test.log'
  Loading document: './test.md'
  Using multiline search mode for document './test.md'
  Loading document: './test/1234.md'
  Using multiline search mode for document './test/1234.md'
  Loading document: './test/abcd.md'
  Using multiline search mode for document './test/abcd.md'
  Loading document: './test/abcd/defg.md'
  Using multiline search mode for document './test/abcd/defg.md'
  Loading document: '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Loading document: '$TESTCASE_ROOT/test.md'
  Using single line search mode for document '$TESTCASE_ROOT/test.md'
  Loading document: '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  Document './test/1234.md' loaded successfully
  Document './test.md' loaded successfully
  Document '$TESTCASE_ROOT/empty-paths.txt' loaded successfully
  Document './test.log' loaded successfully
  Document '$TESTCASE_ROOT/test.md' loaded successfully
  Document './test/abcd.md' loaded successfully
  Document './test/abcd/defg.md' loaded successfully
  Document '$TESTCASE_ROOT/test.txt' loaded successfully

--single-line-exts takes precedence over --glob and --exts:
  $ docfd --debug-log - --index-only --single-line-exts txt --glob '*.txt' --exts md .
  Scanning for documents
  Scanning completed
  Document source: files
  File: './empty-paths.txt'
  File: './test.md'
  File: './test.txt'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd.txt'
  File: './test/abcd/defg.md'
  File: './test/abcd/defg.txt'
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.txt'
  Loading document: './empty-paths.txt'
  Using single line search mode for document './empty-paths.txt'
  Loading document: './test.md'
  Using multiline search mode for document './test.md'
  Loading document: './test.txt'
  Using single line search mode for document './test.txt'
  Loading document: './test/1234.md'
  Using multiline search mode for document './test/1234.md'
  Loading document: './test/abcd.md'
  Using multiline search mode for document './test/abcd.md'
  Loading document: './test/abcd.txt'
  Using single line search mode for document './test/abcd.txt'
  Loading document: './test/abcd/defg.md'
  Using multiline search mode for document './test/abcd/defg.md'
  Loading document: './test/abcd/defg.txt'
  Using single line search mode for document './test/abcd/defg.txt'
  Loading document: '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Loading document: '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Document './test/1234.md' loaded successfully
  Document './empty-paths.txt' loaded successfully
  Document './test.md' loaded successfully
  Document './test.txt' loaded successfully
  Document './test/abcd.md' loaded successfully
  Document './test/abcd/defg.md' loaded successfully
  Document '$TESTCASE_ROOT/empty-paths.txt' loaded successfully
  Document '$TESTCASE_ROOT/test.txt' loaded successfully
  Document './test/abcd.txt' loaded successfully
  Document './test/abcd/defg.txt' loaded successfully
  $ docfd --debug-log - --index-only --single-line-exts md --glob '*.txt' --exts md .
  Scanning for documents
  Scanning completed
  Document source: files
  File: './test.md'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd/defg.md'
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.txt'
  Loading document: './test.md'
  Using single line search mode for document './test.md'
  Loading document: './test/1234.md'
  Using single line search mode for document './test/1234.md'
  Loading document: './test/abcd.md'
  Using single line search mode for document './test/abcd.md'
  Loading document: './test/abcd/defg.md'
  Using single line search mode for document './test/abcd/defg.md'
  Loading document: '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Loading document: '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Document './test/1234.md' loaded successfully
  Document './test.md' loaded successfully
  Document '$TESTCASE_ROOT/empty-paths.txt' loaded successfully
  Document './test/abcd.md' loaded successfully
  Document '$TESTCASE_ROOT/test.txt' loaded successfully
  Document './test/abcd/defg.md' loaded successfully
  $ docfd --debug-log - --index-only --single-line-exts txt,md --glob '*.txt' --exts md .
  Scanning for documents
  Scanning completed
  Document source: files
  File: './empty-paths.txt'
  File: './test.md'
  File: './test.txt'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd.txt'
  File: './test/abcd/defg.md'
  File: './test/abcd/defg.txt'
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.txt'
  Loading document: './empty-paths.txt'
  Using single line search mode for document './empty-paths.txt'
  Loading document: './test.md'
  Using single line search mode for document './test.md'
  Loading document: './test.txt'
  Using single line search mode for document './test.txt'
  Loading document: './test/1234.md'
  Using single line search mode for document './test/1234.md'
  Loading document: './test/abcd.md'
  Using single line search mode for document './test/abcd.md'
  Loading document: './test/abcd.txt'
  Using single line search mode for document './test/abcd.txt'
  Loading document: './test/abcd/defg.md'
  Using single line search mode for document './test/abcd/defg.md'
  Loading document: './test/abcd/defg.txt'
  Using single line search mode for document './test/abcd/defg.txt'
  Loading document: '$TESTCASE_ROOT/empty-paths.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Loading document: '$TESTCASE_ROOT/test.txt'
  Using multiline search mode for document '$TESTCASE_ROOT/test.txt'
  Document './test.txt' loaded successfully
  Document './test/abcd/defg.txt' loaded successfully
  Document './test.md' loaded successfully
  Document '$TESTCASE_ROOT/test.txt' loaded successfully
  Document './test/abcd.md' loaded successfully
  Document './test/abcd.txt' loaded successfully
  Document './test/abcd/defg.md' loaded successfully
  Document '$TESTCASE_ROOT/empty-paths.txt' loaded successfully
  Document './test/1234.md' loaded successfully
  Document './empty-paths.txt' loaded successfully

--exts apply to directories in FILE in --paths-from FILE:
  $ docfd --debug-log - --index-only --paths-from paths --exts txt
  Scanning for documents
  Scanning completed
  Document source: files
  File: 'test.txt'
  File: 'test/abcd.txt'
  File: 'test/abcd/defg.txt'
  Loading document: 'test.txt'
  Using multiline search mode for document 'test.txt'
  Loading document: 'test/abcd.txt'
  Using multiline search mode for document 'test/abcd.txt'
  Loading document: 'test/abcd/defg.txt'
  Using multiline search mode for document 'test/abcd/defg.txt'
  Document 'test.txt' loaded successfully
  Document 'test/abcd.txt' loaded successfully
  Document 'test/abcd/defg.txt' loaded successfully
  $ docfd --debug-log - --index-only --paths-from paths --exts md
  Scanning for documents
  Scanning completed
  Document source: files
  File: 'test.txt'
  File: 'test/1234.md'
  File: 'test/abcd.md'
  File: 'test/abcd/defg.md'
  Loading document: 'test.txt'
  Using multiline search mode for document 'test.txt'
  Loading document: 'test/1234.md'
  Using multiline search mode for document 'test/1234.md'
  Loading document: 'test/abcd.md'
  Using multiline search mode for document 'test/abcd.md'
  Loading document: 'test/abcd/defg.md'
  Using multiline search mode for document 'test/abcd/defg.md'
  Document 'test/1234.md' loaded successfully
  Document 'test/abcd.md' loaded successfully
  Document 'test/abcd/defg.md' loaded successfully
  Document 'test.txt' loaded successfully

--single-line-exts apply to directories in FILE in --paths-from FILE:
  $ docfd --debug-log - --index-only --paths-from paths --single-line-exts txt
  Scanning for documents
  Scanning completed
  Document source: files
  File: 'test.txt'
  File: 'test/1234.md'
  File: 'test/abcd.md'
  File: 'test/abcd.txt'
  File: 'test/abcd/defg.md'
  File: 'test/abcd/defg.txt'
  Loading document: 'test.txt'
  Using single line search mode for document 'test.txt'
  Loading document: 'test/1234.md'
  Using multiline search mode for document 'test/1234.md'
  Loading document: 'test/abcd.md'
  Using multiline search mode for document 'test/abcd.md'
  Loading document: 'test/abcd.txt'
  Using single line search mode for document 'test/abcd.txt'
  Loading document: 'test/abcd/defg.md'
  Using multiline search mode for document 'test/abcd/defg.md'
  Loading document: 'test/abcd/defg.txt'
  Using single line search mode for document 'test/abcd/defg.txt'
  Document 'test/abcd.txt' loaded successfully
  Document 'test/1234.md' loaded successfully
  Document 'test/abcd/defg.md' loaded successfully
  Document 'test/abcd.md' loaded successfully
  Document 'test.txt' loaded successfully
  Document 'test/abcd/defg.txt' loaded successfully
  $ docfd --debug-log - --index-only --paths-from paths --single-line-exts md
  Scanning for documents
  Scanning completed
  Document source: files
  File: 'test.txt'
  File: 'test/1234.md'
  File: 'test/abcd.md'
  File: 'test/abcd.txt'
  File: 'test/abcd/defg.md'
  File: 'test/abcd/defg.txt'
  Loading document: 'test.txt'
  Using multiline search mode for document 'test.txt'
  Loading document: 'test/1234.md'
  Using single line search mode for document 'test/1234.md'
  Loading document: 'test/abcd.md'
  Using single line search mode for document 'test/abcd.md'
  Loading document: 'test/abcd.txt'
  Using multiline search mode for document 'test/abcd.txt'
  Loading document: 'test/abcd/defg.md'
  Using single line search mode for document 'test/abcd/defg.md'
  Loading document: 'test/abcd/defg.txt'
  Using multiline search mode for document 'test/abcd/defg.txt'
  Document 'test.txt' loaded successfully
  Document 'test/abcd.txt' loaded successfully
  Document 'test/1234.md' loaded successfully
  Document 'test/abcd/defg.txt' loaded successfully
  Document 'test/abcd/defg.md' loaded successfully
  Document 'test/abcd.md' loaded successfully

Top-level files do not fall into singe line search group but into the default search group:
  $ docfd --debug-log - --index-only test.txt --single-line-exts txt
  Scanning for documents
  Scanning completed
  Document source: files
  File: 'test.txt'
  Loading document: 'test.txt'
  Using single line search mode for document 'test.txt'
  Document 'test.txt' loaded successfully
  $ docfd --debug-log - --index-only test.txt --single-line-glob '*.txt'
  Scanning for documents
  Scanning completed
  Document source: files
  File: '$TESTCASE_ROOT/empty-paths.txt'
  File: '$TESTCASE_ROOT/test.txt'
  File: 'test.txt'
  Loading document: '$TESTCASE_ROOT/empty-paths.txt'
  Using single line search mode for document '$TESTCASE_ROOT/empty-paths.txt'
  Loading document: '$TESTCASE_ROOT/test.txt'
  Using single line search mode for document '$TESTCASE_ROOT/test.txt'
  Loading document: 'test.txt'
  Using multiline search mode for document 'test.txt'
  Document '$TESTCASE_ROOT/empty-paths.txt' loaded successfully
  Document '$TESTCASE_ROOT/test.txt' loaded successfully
  Document 'test.txt' loaded successfully

Top-level files with unrecognized extensions are still picked:
  $ docfd --debug-log - --index-only --exts md .
  Scanning for documents
  Scanning completed
  Document source: files
  File: './test.log'
  File: './test.md'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd/defg.md'
  Loading document: './test.log'
  Using single line search mode for document './test.log'
  Loading document: './test.md'
  Using multiline search mode for document './test.md'
  Loading document: './test/1234.md'
  Using multiline search mode for document './test/1234.md'
  Loading document: './test/abcd.md'
  Using multiline search mode for document './test/abcd.md'
  Loading document: './test/abcd/defg.md'
  Using multiline search mode for document './test/abcd/defg.md'
  Document './test.log' loaded successfully
  Document './test.md' loaded successfully
  Document './test/abcd/defg.md' loaded successfully
  Document './test/1234.md' loaded successfully
  Document './test/abcd.md' loaded successfully
  $ docfd --debug-log - --index-only --exts md test.txt .
  Scanning for documents
  Scanning completed
  Document source: files
  File: './test.log'
  File: './test.md'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd/defg.md'
  File: 'test.txt'
  Loading document: './test.log'
  Using single line search mode for document './test.log'
  Loading document: './test.md'
  Using multiline search mode for document './test.md'
  Loading document: './test/1234.md'
  Using multiline search mode for document './test/1234.md'
  Loading document: './test/abcd.md'
  Using multiline search mode for document './test/abcd.md'
  Loading document: './test/abcd/defg.md'
  Using multiline search mode for document './test/abcd/defg.md'
  Loading document: 'test.txt'
  Using multiline search mode for document 'test.txt'
  Document './test/abcd.md' loaded successfully
  Document './test.md' loaded successfully
  Document './test/abcd/defg.md' loaded successfully
  Document './test/1234.md' loaded successfully
  Document './test.log' loaded successfully
  Document 'test.txt' loaded successfully

Top-level files without extensions are still picked:
  $ docfd --debug-log - --index-only --exts md .
  Scanning for documents
  Scanning completed
  Document source: files
  File: './test.log'
  File: './test.md'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd/defg.md'
  Loading document: './test.log'
  Using single line search mode for document './test.log'
  Loading document: './test.md'
  Using multiline search mode for document './test.md'
  Loading document: './test/1234.md'
  Using multiline search mode for document './test/1234.md'
  Loading document: './test/abcd.md'
  Using multiline search mode for document './test/abcd.md'
  Loading document: './test/abcd/defg.md'
  Using multiline search mode for document './test/abcd/defg.md'
  Document './test/abcd.md' loaded successfully
  Document './test.log' loaded successfully
  Document './test.md' loaded successfully
  Document './test/1234.md' loaded successfully
  Document './test/abcd/defg.md' loaded successfully
  $ docfd --debug-log - --index-only --exts md no-ext .
  Scanning for documents
  Scanning completed
  Document source: files
  File: './test.log'
  File: './test.md'
  File: './test/1234.md'
  File: './test/abcd.md'
  File: './test/abcd/defg.md'
  File: 'no-ext'
  Loading document: './test.log'
  Using single line search mode for document './test.log'
  Loading document: './test.md'
  Using multiline search mode for document './test.md'
  Loading document: './test/1234.md'
  Using multiline search mode for document './test/1234.md'
  Loading document: './test/abcd.md'
  Using multiline search mode for document './test/abcd.md'
  Loading document: './test/abcd/defg.md'
  Using multiline search mode for document './test/abcd/defg.md'
  Loading document: 'no-ext'
  Using multiline search mode for document 'no-ext'
  Document './test.md' loaded successfully
  Document './test.log' loaded successfully
  Document './test/1234.md' loaded successfully
  Document './test/abcd/defg.md' loaded successfully
  Document './test/abcd.md' loaded successfully
  Document 'no-ext' loaded successfully

Double asterisk glob:
  $ docfd --debug-log - --index-only --glob '**/*.txt'
  Scanning for documents
  Scanning completed
  Document source: files
