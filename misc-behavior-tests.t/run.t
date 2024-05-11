Stdin temp file cleanup:
  $ echo "abcd" | docfd --search "a" | tail -n +2
  1: abcd
     ^^^^
  $ ls /tmp/docfd-*
  ls: cannot access '/tmp/docfd-*': No such file or directory
  [2]

Stdin and path both specified:
  $ echo "0123" | docfd abcd.txt --search "01" # Should not print anything since stdin should be ignored.
  $ echo "0123" | docfd abcd.txt --search "ab"
  $TESTCASE_ROOT/abcd.txt
  1: abcd
     ^^^^

--underline:
  $ docfd --underline never abcd.txt --search "ab|cd"
  $TESTCASE_ROOT/abcd.txt
  1: abcd
  
  1: abcd
  $ docfd --underline always abcd.txt --search "ab|cd"
  $TESTCASE_ROOT/abcd.txt
  1: abcd
     ^^^^
  
  1: abcd
     ^^^^
  $ docfd --underline auto abcd.txt --search "ab|cd"
  $TESTCASE_ROOT/abcd.txt
  1: abcd
     ^^^^
  
  1: abcd
     ^^^^

--color:
  $ docfd --color never abcd.txt --search "ab|cd"
  $TESTCASE_ROOT/abcd.txt
  1: abcd
     ^^^^
  
  1: abcd
     ^^^^
  $ # The output below is messed up after passing through dune.
  $ docfd --color always abcd.txt --search "ab|cd"
  $TESTCASE_ROOT/abcd.txt1: abcd   ^^^^1: abcd   ^^^^
  $ docfd --color auto abcd.txt --search "ab|cd"
  $TESTCASE_ROOT/abcd.txt
  1: abcd
     ^^^^
  
  1: abcd
     ^^^^
