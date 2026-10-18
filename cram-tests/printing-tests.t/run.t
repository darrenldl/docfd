--sample:
  $ docfd --cache-dir .cache --sample abcd .
  $TESTCASE_ROOT/test3.txt
  1: abcd
     ^^^^
  
  $TESTCASE_ROOT/test2.txt
  1: hello
  2: 
  3: abcd
     ^^^^
  4: 
  5: abcdefgh
  
  5: abcdefgh
  6: 
  7: hello world abcd
                 ^^^^
  
  3: abcd
  4: 
  5: abcdefgh
     ^^^^^^^^
  6: 
  7: hello world abcd

--search:
  $ docfd --cache-dir .cache --search abcd .
  $TESTCASE_ROOT/test3.txt
  1: abcd
     ^^^^
  
  $TESTCASE_ROOT/test2.txt
  1: hello
  2: 
  3: abcd
     ^^^^
  4: 
  5: abcdefgh
  
  5: abcdefgh
  6: 
  7: hello world abcd
                 ^^^^
  
  3: abcd
  4: 
  5: abcdefgh
     ^^^^^^^^
  6: 
  7: hello world abcd

-l/--files-with-match:
  $ docfd --cache-dir .cache --sample abcd . -l
  $TESTCASE_ROOT/test3.txt
  $TESTCASE_ROOT/test2.txt
  $ docfd --cache-dir .cache --sample abcd . --files-with-match
  $TESTCASE_ROOT/test3.txt
  $TESTCASE_ROOT/test2.txt

--files-without-match:
  $ docfd --cache-dir .cache --sample abcd . --files-without-match
  $TESTCASE_ROOT/empty.txt
  $TESTCASE_ROOT/test0.txt
  $TESTCASE_ROOT/test1.txt
  $TESTCASE_ROOT/test4.txt

--links prints resolved targets and omits links without a target:
  $ mkdir link-project
  $ printf '%s\n' '[target](target.md)' '[same document](#section)' 'https://example.com' '[[/]]' > link-project/source.md
  $ touch link-project/target.md
  $ docfd --cache-dir .links-cache --exts md --links link-project | sort
  $TESTCASE_ROOT/link-project/source.md
  $TESTCASE_ROOT/link-project/target.md
  https://example.com

--filter can select the documents whose links are printed:
  $ docfd --cache-dir .links-filter-cache --exts md --filter 'path-glob:link-project/source.md' --links link-project | sort
  $TESTCASE_ROOT/link-project/source.md
  $TESTCASE_ROOT/link-project/target.md
  https://example.com

--links exits with status 1 when no resolved links are found:
  $ docfd --cache-dir .no-links-cache --exts txt --links empty.txt
  [1]

Early-exit modes cannot silently override --links:
  $ docfd --index-only --links 2>&1
  error: --index-only and --links cannot be used together
  [1]
  $ docfd --list-scripts --links 2>&1
  error: --list-scripts and --links cannot be used together
  [1]
