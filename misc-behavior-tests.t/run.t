Stdin temp file cleanup:
  $ echo "abcd" | docfd --cache-dir .cache --search "a" | tail -n +2
  1: abcd
     ^^^^
  $ ls /tmp/docfd-*
  ls: cannot access '/tmp/docfd-*': No such file or directory
  [2]

Stdin and path both specified:
  $ echo "0123" | docfd --cache-dir .cache abcd.txt --search "01" # Should not print anything since stdin should be ignored.
  [1]
  $ echo "0123" | docfd --cache-dir .cache abcd.txt --search "ab"
  $TESTCASE_ROOT/abcd.txt
  1: abcd
     ^^^^

--underline:
  $ docfd --cache-dir .cache --underline never abcd.txt --search "ab|cd"
  $TESTCASE_ROOT/abcd.txt
  1: abcd
  
  1: abcd
  $ docfd --cache-dir .cache --underline always abcd.txt --search "ab|cd"
  $TESTCASE_ROOT/abcd.txt
  1: abcd
     ^^^^
  
  1: abcd
     ^^^^
  $ docfd --cache-dir .cache --underline auto abcd.txt --search "ab|cd"
  $TESTCASE_ROOT/abcd.txt
  1: abcd
     ^^^^
  
  1: abcd
     ^^^^

--color:
  $ docfd --cache-dir .cache --color never abcd.txt --search "ab|cd"
  $TESTCASE_ROOT/abcd.txt
  1: abcd
     ^^^^
  
  1: abcd
     ^^^^
  $ # The output below is messed up after passing through Dune, I do not know why.
  $ docfd --cache-dir .cache --color always abcd.txt --search "ab|cd"
  $TESTCASE_ROOT/abcd.txt1: abcd   ^^^^
  1: abcd   ^^^^
  $ docfd --cache-dir .cache --color auto abcd.txt --search "ab|cd"
  $TESTCASE_ROOT/abcd.txt
  1: abcd
     ^^^^
  
  1: abcd
     ^^^^
