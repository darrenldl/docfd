open Docfd_lib
open Test_utils

module Alco = struct
  let link start_pos end_inc_pos typ link =
    Link.{ start_pos; end_inc_pos; typ; link }

  let corpus () =
    let test (expected_links : Link.t list) input =
      let line = Tokenization.tokenize_with_pos ~drop_spaces:false input
        |> Dynarray.of_seq
      in
      let links = Link_extraction.links_of_line line in
      Alcotest.(check (list link_testable))
        Fmt.(str "%s gives %a" input (list Link.pp) expected_links)
        expected_links
        links
    in
    (* Markdown inline links *)
    test [ link 4 6 `Markdown "file.md" ] "[label](file.md)";
    test [ link 3 5 `Markdown "file.md" ] "[](file.md)";
    test [ link 4 10 `Markdown "./dir/file.md" ] "[label](./dir/file.md)";
    test [ link 4 9 `Markdown "../file.md" ] "[label](../file.md)";
    test [ link 4 9 `Markdown "/dir/file.md" ] "[label](/dir/file.md)";
    test [ link 4 8 `Markdown "file%20name.md" ] "[label](file%20name.md)";
    test [ link 4 8 `Markdown "file%23notes.md" ] "[label](file%23notes.md)";
    test [ link 4 8 `Markdown "file%25notes.md" ] "[label](file%25notes.md)";
    test [ link 4 10 `Markdown "caf%C3%A9.md" ] "[label](caf%C3%A9.md)";
    test [ link 4 8 `Markdown "dir%2Ffile.md" ] "[label](dir%2Ffile.md)";
    test [ link 5 9 `Markdown "file name.md" ] "[label](<file name.md>)";
    test [ link 4 10 `URL "https://example.com" ] "[label](https://example.com)";
    test [ link 5 11 `URL "https://example.com" ] "[label]( https://example.com)";
    test [ link 5 11 `URL "mailto:user@example.com" ] "[label]( mailto:user@example.com)";
    test [ link 4 16 `URL "https://example.com?q=a#section" ] "[label](https://example.com?q=a#section)";
    test [ link 4 8 `Markdown "file.md#heading" ] "[label](file.md#heading)";
    test [ link 4 5 `Markdown "#heading" ] "[label](#heading)";
    test [ link 4 10 `Markdown "file_(draft).md" ] "[label](file_(draft).md)";
    test [ link 4 11 `Markdown "file(draft).md" ] "[label](file\\(draft\\).md)";
    test [ link 4 11 `Markdown "file[draft].md" ] "[label](file\\[draft\\].md)";
    test [ link 4 7 `Markdown "file.md" ] "[label](file.md \"title\")";
    test [ link 4 7 `Markdown "file.md" ] "[label](file.md 'title')";
    test [ link 5 9 `Markdown "file name.md" ] "[label](<file name.md> \"title\")";
    test [ link 5 8 `Markdown "file.md" ] "[label](  file.md  \"title\"  )";
    test [ link 10 12 `Markdown "file.md" ] "[a [nested] label](file.md)";
    test [ link 11 13 `Markdown "file.md" ] "[an escaped \\] label](file.md)";
    test [] "[label]()";
    test [] "[label](<>)";
    (* Tolerative parser being permissive *)
    test [ link 4 8 `Markdown "file name.md" ] "[label](file name.md)";
    test [ link 4 9 `Markdown "file name.md" ] "[label](file\\ name.md)";
    test [ link 4 6 `Markdown "one.md"; link 15 17 `Markdown "two.md" ] "[one](one.md) and [two](two.md)";

    (* Markdown autolinks and bare URLs *)
    test [ link 1 9 `URL "http://example.com/path" ] "<http://example.com/path>";
    test [ link 1 9 `URL "https://example.com/path" ] "<https://example.com/path>";
    test [ link 1 10 `URL "file:///tmp/document.txt" ] "<file:///tmp/document.txt>";
    test [ link 1 7 `URL "mailto:user@example.com" ] "<mailto:user@example.com>";
    test [ link 0 8 `URL "http://example.com/path" ] "http://example.com/path";
    test [ link 0 8 `URL "https://example.com/path" ] "https://example.com/path";
    test [ link 0 9 `URL "file:///tmp/document.txt" ] "file:///tmp/document.txt";
    test [ link 0 12 `URL "https://example.com/a_(b)" ] "https://example.com/a_(b)";
    test [ link 0 12 `URL "https://example.com?q=a|b" ] "https://example.com?q=a|b";
    test [ link 0 14 `URL "https://example.com?q=a&sort=desc" ] "https://example.com?q=a&sort=desc";
    test [ link 0 10 `URL "https://example.com/path#fragment" ] "https://example.com/path#fragment";
    test [ link 0 10 `URL "https://example.com:8443/path" ] "https://example.com:8443/path";
    test [ link 1 9 `URL "https://example.com/path" ] "(https://example.com/path)";

    (* Wiki links *)
    test [ link 2 2 `Wiki "Note" ] "[[Note]]";
    test [ link 2 4 `Wiki "Note name" ] "[[Note name]]";
    test [ link 2 4 `Wiki "Note.md" ] "[[Note.md]]";
    test [ link 2 6 `Wiki "Figure 1.png" ] "[[Figure 1.png]]";
    test [ link 2 6 `Wiki "folder/Note name" ] "[[folder/Note name]]";
    test [ link 2 4 `Wiki "./Note" ] "[[./Note]]";
    test [ link 2 5 `Wiki "../Note" ] "[[../Note]]";
    test [ link 2 5 `Wiki "/folder/Note" ] "[[/folder/Note]]";
    test [ link 2 2 `Wiki "Note" ] "[[Note|Display label]]";
    test [ link 2 4 `Wiki "Note name" ] "[[Note name|Readable label]]";
    test [ link 2 4 `Wiki "Note#Heading" ] "[[Note#Heading]]";
    test [ link 2 4 `Wiki "Note#Heading" ] "[[Note#Heading|Section label]]";
    test [ link 2 6 `Wiki "Note#Heading#Subheading" ] "[[Note#Heading#Subheading]]";
    test [ link 2 7 `Wiki "Note#^block-id" ] "[[Note#^block-id]]";
    test [ link 2 7 `Wiki "Note#^block-id" ] "[[Note#^block-id|Block label]]";
    test [ link 2 3 `Wiki "#Heading" ] "[[#Heading]]";
    test [ link 2 6 `Wiki "#^block-id" ] "[[#^block-id]]";
    test [ link 2 8 `Wiki "日本語のノート" ] "[[日本語のノート]]";
    test [ link 2 2 `Wiki "Note" ] "[[Note";
    test [] "[[]]";
    test [] "[[|Label]]";
    test [ link 2 2 `Wiki "One"; link 7 7 `Wiki "Two" ] "[[One]][[Two]]";

    (* Wiki embeds and Markdown images *)
    test [ link 3 3 `Wiki "Note" ] "![[Note]]";
    test [ link 3 5 `Wiki "image.png" ] "![[image.png]]";
    test [ link 3 5 `Wiki "image.png" ] "![[image.png|300]]";
    test [ link 3 5 `Wiki "Note#Heading" ] "![[Note#Heading]]";
    test [ link 3 8 `Wiki "Note#^block-id" ] "![[Note#^block-id]]";
    test [ link 5 7 `Markdown "image.png" ] "![alt](image.png)";
    test [ link 6 10 `Markdown "image file.png" ] "![alt](<image file.png> \"title\")";
    test [ link 6 8 `Markdown "image.png"; link 12 14 `Markdown "page.md" ] "[![alt](image.png)](page.md)";

    (* Other URI schemes *)
    test [ link 0 8 `URL "ftp://example.com/file" ] "ftp://example.com/file";
    test [ link 0 12 `URL "obsidian://open?vault=Notes&file=Note" ] "obsidian://open?vault=Notes&file=Note";
    test [] "custom-scheme:value";

    (* Negative and malformed cases *)
    test [] "[label] (file.md)";
    test [ link 4 6 `Markdown "file.md" ] "[label](file.md";
    test [ link 5 9 `Markdown "file name.md" ] "[label](<file name.md)";
    test [] "[not a link]";
    test [ link 5 7 `Markdown "file.md" ] "\\[label](file.md)";
    test [ link 3 3 `Wiki "Note" ] "\\[[Note]]";
    test [ link 5 7 `Markdown "file.md" ] "`[label](file.md)`";
    test [ link 1 7 `URL "https://example.com" ] "`https://example.com`";

    (* Unsupported cases, extraction results are incorrect *)
    test [ link 4 10 `Markdown "file.md (title)" ] "[label](file.md (title))";
    test [] "[label](\"file.md\")";
    test [] "<user@example.com>";
    test [] "user@example.com";
    test [] "www.example.com/path";
    test [ link 2 9 `URL "https://example.com." ] "See https://example.com.";
    test [ link 2 9 `URL "https://example.com," ] "See https://example.com, next";
    ()

  let suite =
    [
      Alcotest.test_case "corpus" `Quick corpus;
    ]
end
