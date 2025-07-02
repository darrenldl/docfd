Setup:
  $ echo "abcd" >> test0.txt
  $ echo "efgh" >> test0.txt
  $ echo "0123" >> test0.txt
  $ echo "ijkl" >> test0.txt
  $ echo "abcd" >> test1.txt
  $ echo "efgh" >> test1.txt
  $ echo "0123" >> test1.txt
  $ echo "ijkl" >> test1.txt
  $ tree
  .
  |-- dune -> ../../../../default/search-scope-narrowing-tests.t/dune
  |-- test0.txt
  `-- test1.txt
  
  0 directories, 3 files

Single restriction:
  $ # Case 0 for single restriction
  $ echo "" > test.docfd-script
  $ echo "search: 'abcd" >> test.docfd-script
  $ echo "narrow level: 1" >> test.docfd-script
  $ echo "search: 'efgh" >> test.docfd-script
  $ docfd --tokens-per-search-scope-level 1 --script test.docfd-script test0.txt -l
  $TESTCASE_ROOT/test0.txt
  $ # Case 1 for single restriction
  $ echo "" > test.docfd-script
  $ echo "search: 'abcd" >> test.docfd-script
  $ echo "narrow level: 1" >> test.docfd-script
  $ echo "search: '0123" >> test.docfd-script
  $ docfd --tokens-per-search-scope-level 1 --script test.docfd-script test0.txt -l
  [1]
  $ # Case 2 for single restriction
  $ echo "" > test.docfd-script
  $ echo "search: 'abcd" >> test.docfd-script
  $ echo "narrow level: 1" >> test.docfd-script
  $ echo "narrow level: 0" >> test.docfd-script
  $ echo "search: '0123" >> test.docfd-script
  $ docfd --tokens-per-search-scope-level 1 --script test.docfd-script test0.txt -l
  $TESTCASE_ROOT/test0.txt

Chained restriction:
  $ # Case 0 for chained restrictions
  $ echo "" > test.docfd-script
  $ echo "search: 'abcd" >> test.docfd-script
  $ echo "narrow level: 1" >> test.docfd-script
  $ echo "search: '0123" >> test.docfd-script
  $ echo "narrow level: 1" >> test.docfd-script
  $ echo "search: 'efgh" >> test.docfd-script
  $ docfd --tokens-per-search-scope-level 1 --script test.docfd-script test0.txt -l
  [1]
  $ # Case 1 for chained restrictions
  $ echo "" > test.docfd-script
  $ echo "search: 'abcd" >> test.docfd-script
  $ echo "narrow level: 2" >> test.docfd-script
  $ echo "search: '0123" >> test.docfd-script
  $ echo "narrow level: 2" >> test.docfd-script
  $ echo "search: 'efgh" >> test.docfd-script
  $ docfd --tokens-per-search-scope-level 1 --script test.docfd-script test0.txt -l
  $TESTCASE_ROOT/test0.txt
  $ # Case 2 for chained restrictions
  $ echo "" > test.docfd-script
  $ echo "search: 'abcd" >> test.docfd-script
  $ echo "narrow level: 2" >> test.docfd-script
  $ echo "search: '0123" >> test.docfd-script
  $ echo "narrow level: 1" >> test.docfd-script
  $ echo "search: 'efgh" >> test.docfd-script
  $ docfd --tokens-per-search-scope-level 1 --script test.docfd-script test0.txt -l
  $TESTCASE_ROOT/test0.txt

File path filter + restrictions:
  $ # Baseline case: "clear filter" after "search" should trigger a search for each file that has not been searched through yet
  $ # So both documents should appear
  $ echo "" > test.docfd-script
  $ echo "search: 'abcd" >> test.docfd-script
  $ echo "filter: path-glob:test0.txt" >> test.docfd-script
  $ echo "search: 'efgh" >> test.docfd-script
  $ echo "clear filter" >> test.docfd-script
  $ docfd --tokens-per-search-scope-level 1 --script test.docfd-script -l .
  $TESTCASE_ROOT/test0.txt
  $TESTCASE_ROOT/test1.txt
  $ # Baseline case quoted string using single quote
  $ echo "" > test.docfd-script
  $ echo "search: 'abcd" >> test.docfd-script
  $ echo "filter: path-glob:'test0.txt'" >> test.docfd-script
  $ echo "search: 'efgh" >> test.docfd-script
  $ echo "clear filter" >> test.docfd-script
  $ docfd --tokens-per-search-scope-level 1 --script test.docfd-script -l .
  $TESTCASE_ROOT/test0.txt
  $TESTCASE_ROOT/test1.txt
  $ # Baseline case quoted string using double quote
  $ echo "" > test.docfd-script
  $ echo "search: 'abcd" >> test.docfd-script
  $ echo 'filter: path-glob:"test0.txt"' >> test.docfd-script
  $ echo "search: 'efgh" >> test.docfd-script
  $ echo "clear filter" >> test.docfd-script
  $ docfd --tokens-per-search-scope-level 1 --script test.docfd-script -l .
  $TESTCASE_ROOT/test0.txt
  $TESTCASE_ROOT/test1.txt
  $ # Since there is no "search" after "narrow", both documents should still appear
  $ echo "" > test.docfd-script
  $ echo "search: 'abcd" >> test.docfd-script
  $ echo "filter: path-glob:test0.txt" >> test.docfd-script
  $ echo "narrow level: 1" >> test.docfd-script
  $ echo "clear filter" >> test.docfd-script
  $ docfd --tokens-per-search-scope-level 1 --script test.docfd-script -l .
  $TESTCASE_ROOT/test0.txt
  $TESTCASE_ROOT/test1.txt
  $ # "narrow" + "search" after filtering should prevent test1.txt from appearing, even after we clear the filter
  $ echo "" > test.docfd-script
  $ echo "search: 'abcd" >> test.docfd-script
  $ echo "filter: path-glob:test0.txt" >> test.docfd-script
  $ echo "narrow level: 1" >> test.docfd-script
  $ echo "search: 'efgh" >> test.docfd-script
  $ echo "clear filter" >> test.docfd-script
  $ docfd --tokens-per-search-scope-level 1 --script test.docfd-script -l .
  $TESTCASE_ROOT/test0.txt
  $ # Similar to the above case, but the order of "search" and "clear filter" is swapped
  $ # test1.txt still should not appear
  $ echo "" > test.docfd-script
  $ echo "search: 'abcd" >> test.docfd-script
  $ echo "filter: path-glob:test0.txt" >> test.docfd-script
  $ echo "narrow level: 1" >> test.docfd-script
  $ echo "clear filter" >> test.docfd-script
  $ echo "search: 'efgh" >> test.docfd-script
  $ docfd --tokens-per-search-scope-level 1 --script test.docfd-script -l .
  $TESTCASE_ROOT/test0.txt
  $ # Similar to the above case, but we also reset the search scope via "narrow level: 0"
  $ # Since resetting the search scope does not refresh the search results, test1.txt should still not appear as there is not another "search"
  $ echo "" > test.docfd-script
  $ echo "search: 'abcd" >> test.docfd-script
  $ echo "filter: path-glob:test0.txt" >> test.docfd-script
  $ echo "narrow level: 1" >> test.docfd-script
  $ echo "clear filter" >> test.docfd-script
  $ echo "search: 'efgh" >> test.docfd-script
  $ echo "narrow level: 0" >> test.docfd-script
  $ docfd --tokens-per-search-scope-level 1 --script test.docfd-script -l .
  $TESTCASE_ROOT/test0.txt
  $ # Similar to the above case, but we search again after resetting search scope
  $ echo "" > test.docfd-script
  $ echo "search: 'abcd" >> test.docfd-script
  $ echo "filter: path-glob:test0.txt" >> test.docfd-script
  $ echo "narrow level: 1" >> test.docfd-script
  $ echo "clear filter" >> test.docfd-script
  $ echo "search: 'efgh" >> test.docfd-script
  $ echo "narrow level: 0" >> test.docfd-script
  $ echo "search: 'efgh" >> test.docfd-script
  $ docfd --tokens-per-search-scope-level 1 --script test.docfd-script -l .
  $TESTCASE_ROOT/test0.txt
  $TESTCASE_ROOT/test1.txt
  $ # Simplified version of the above case where we skip the search before "narrow level: 0"
  $ echo "" > test.docfd-script
  $ echo "search: 'abcd" >> test.docfd-script
  $ echo "filter: path-glob:test0.txt" >> test.docfd-script
  $ echo "narrow level: 1" >> test.docfd-script
  $ echo "clear filter" >> test.docfd-script
  $ echo "narrow level: 0" >> test.docfd-script
  $ echo "search: 'efgh" >> test.docfd-script
  $ docfd --tokens-per-search-scope-level 1 --script test.docfd-script -l .
  $TESTCASE_ROOT/test0.txt
  $TESTCASE_ROOT/test1.txt
  $ # Similar to the above case, but the order of "clear filter" and "narrow level: 0" is swapped
  $ # Both documents should still appear
  $ echo "" > test.docfd-script
  $ echo "search: 'abcd" >> test.docfd-script
  $ echo "filter: path-glob:test0.txt" >> test.docfd-script
  $ echo "narrow level: 1" >> test.docfd-script
  $ echo "narrow level: 0" >> test.docfd-script
  $ echo "clear filter" >> test.docfd-script
  $ echo "search: 'efgh" >> test.docfd-script
  $ docfd --tokens-per-search-scope-level 1 --script test.docfd-script -l .
  $TESTCASE_ROOT/test0.txt
  $TESTCASE_ROOT/test1.txt
  $ # Similar to the above case, but the order of "clear filter" and "search" is swapped
  $ # Both documents should still appear
  $ echo "" > test.docfd-script
  $ echo "search: 'abcd" >> test.docfd-script
  $ echo "filter: path-glob:test0.txt" >> test.docfd-script
  $ echo "narrow level: 1" >> test.docfd-script
  $ echo "narrow level: 0" >> test.docfd-script
  $ echo "search: 'efgh" >> test.docfd-script
  $ echo "clear filter" >> test.docfd-script
  $ docfd --tokens-per-search-scope-level 1 --script test.docfd-script -l .
  $TESTCASE_ROOT/test0.txt
  $TESTCASE_ROOT/test1.txt
