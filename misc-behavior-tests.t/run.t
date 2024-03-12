Stdin temp file cleanup:
  $ echo "abcd" | docfd --search "a" | tail -n 1
  1: abcd
  $ ls /tmp/docfd-*
  ls: cannot access '/tmp/docfd-*': No such file or directory
  [2]

Stdin and path both specified:
  $ echo "0123" | docfd abcd.txt --search "01"
  $ echo "0123" | docfd abcd.txt --search "ab"
  abcd.txt
  1: abcd
