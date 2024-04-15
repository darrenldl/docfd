Stdin temp file cleanup:
  $ echo "abcd" | docfd --search "a" | tail -n 1
  1: abcd
  $ ls /tmp/docfd-*
  ls: cannot access '/tmp/docfd-*': No such file or directory
  [2]

Stdin and path both specified:
  $ echo "0123" | docfd abcd.txt --search "01" # Should not print anything since stdin should be ignored.
  $ echo "0123" | docfd abcd.txt --search "ab"
  $TESTCASE_ROOT/abcd.txt
  1: abcd
