Default path is not picked if any of the following is used: --paths-from, --glob, --single-line-glob:
  $ # test.md and test.txt should not be picked for the following 3 cases.
  $ docfd --debug-log - --index-only --paths-from empty-paths.txt
  $ docfd --debug-log - --index-only --glob "*.log"
  $ docfd --debug-log - --index-only --single-line-glob "*.log"
  $ # test.md and test.txt should also be picked for the following cases.
  $ docfd --debug-log - --index-only --paths-from empty-paths.txt .
  $ docfd --debug-log - --index-only --glob "*.log" .
  $ docfd --debug-log - --index-only --single-line-glob "*.log" .

--exts and --glob do not overwrite each other:
  $ docfd --debug-log - --index-only --exts md --glob "*.log" .

--single-line-exts and --glob do not overwrite each other:
  $ docfd --debug-log - --index-only --single-line-exts md --glob "*.log" .

Paths from --exts, --single-line-exts, --glob, --single-line-glob are combined correctly:
  $ docfd --debug-log - --index-only --exts md --single-line-exts log .

--add-exts:
  $ docfd --debug-log - --index-only --add-exts md .
  $ docfd --debug-log - --index-only --add-exts ext0 .

--single-line-add-exts:
  $ docfd --debug-log - --index-only --single-line-add-exts md .
  $ docfd --debug-log - --index-only --single-line-add-exts ext0 .

--exts does not intefere with --single-line-glob:

--single-line-exts does not intefere with --single-line-glob:

Picking via multiple --glob and --single-line-glob:

--single-line-glob takes precedence over --glob:

--single-line-exts takes precedence over --exts:

--exts apply to paths from FILE in --paths-from FILE

--single-line-exts apply to paths from FILE in --paths-from FILE

Top-level files do not fall into singe line search group but into the default search group:

Top-level files with non-recognized extensions are still picked:

Top-level files without extensions are still picked:
