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

--exts and --single-line-glob do not overwrite each other:
  $ docfd --debug-log - --index-only --exts md --single-line-glob "*.log" .

--single-line-exts and --single-line-glob do not overwrite each other:
  $ docfd --debug-log - --index-only --single-line-exts md --single-line-glob "*.log" .

Paths from --exts, --single-line-exts, --glob, --single-line-glob, --paths-from are combined correctly:
  $ docfd --debug-log - --index-only --exts md --single-line-exts log .

--add-exts:
  $ docfd --debug-log - --index-only --add-exts md .
  $ docfd --debug-log - --index-only --add-exts ext0 .

--single-line-add-exts:
  $ docfd --debug-log - --index-only --single-line-add-exts md .
  $ docfd --debug-log - --index-only --single-line-add-exts ext0 .

Picking via multiple --glob and --single-line-glob:
  $ docfd --debug-log - --index-only --glob "*.txt"
  $ docfd --debug-log - --index-only --glob "*.txt" --glob "*.md"
  $ docfd --debug-log - --index-only --glob "*.txt" --glob "*.md" --glob "*.log"
  $ docfd --debug-log - --index-only --single-line-glob "*.txt"
  $ docfd --debug-log - --index-only --single-line-glob "*.txt" --single-line-glob "*.md"
  $ docfd --debug-log - --index-only --single-line-glob "*.txt" --single-line-glob "*.md" --single-line-glob "*.log"
  $ docfd --debug-log - --index-only --single-line-glob "*.txt" --glob "*.md" --glob "*.log"
  $ docfd --debug-log - --index-only --glob "*.txt" --single-line-glob "*.md" --glob "*.log"
  $ docfd --debug-log - --index-only --glob "*.txt" --glob "*.md" --single-line-glob "*.log"
  $ docfd --debug-log - --index-only --glob "*.txt" --single-line-glob "*.md" --single-line-glob "*.log"
  $ docfd --debug-log - --index-only --single-line-glob "*.txt" --glob "*.md" --single-line-glob "*.log"
  $ docfd --debug-log - --index-only --single-line-glob "*.txt" --single-line-glob "*.md" --glob "*.log"

--single-line-glob takes precedence over --glob and --exts:
  $ docfd --debug-log - --index-only --single-line-glob "*.txt" --glob "*.txt" --exts md .
  $ docfd --debug-log - --index-only --single-line-glob "*.md" --glob "*.txt" --exts md .
  $ docfd --debug-log - --index-only --single-line-glob "*.md" --single-line-glob "*.txt" --glob "*.txt" --exts md .

--single-line-exts takes precedence over --glob and --exts:
  $ docfd --debug-log - --index-only --single-line-exts txt --glob "*.txt" --exts md .
  $ docfd --debug-log - --index-only --single-line-exts md --glob "*.txt" --exts md .
  $ docfd --debug-log - --index-only --single-line-exts txt,md --glob "*.txt" --exts md .

--exts apply to directories in FILE in --paths-from FILE:
  $ docfd --debug-log - --index-only --paths-from paths --exts txt
  $ docfd --debug-log - --index-only --paths-from paths --exts md

--single-line-exts apply to directories in FILE in --paths-from FILE:
  $ docfd --debug-log - --index-only --paths-from paths --single-line-exts txt
  $ docfd --debug-log - --index-only --paths-from paths --single-line-exts md

Top-level files do not fall into singe line search group but into the default search group:
  $ docfd --debug-log - --index-only test.txt --single-line-exts txt
  $ docfd --debug-log - --index-only test.txt --single-line-glob "*.txt"

Top-level files with unrecognized extensions are still picked:
  $ docfd --debug-log - --index-only --exts md .
  $ docfd --debug-log - --index-only --exts md test.txt .

Top-level files without extensions are still picked:
  $ docfd --debug-log - --index-only --exts md .
  $ docfd --debug-log - --index-only --exts md no-ext .

Double asterisk glob:
  $ docfd --debug-log - --index-only --glob "**/*.txt"
