open Docfd_lib

module Alco = struct
  let corpus () =
    let test expected_links input =
      let line = Tokenization.tokenize_with_pos ~drop_spaces:false input
        |> Dynarray.of_seq
      in
      let links = Link_extraction.links_of_line line
        |> List.map (fun (link : Link.t) -> link.link)
      in
      Alcotest.(check (list string))
        Fmt.(str "%s gives %a" input (list string) expected_links)
        expected_links
        links
    in
    (* Markdown inline links *)
    test [ "file.md" ] "[label](file.md)";
    test [ "file.md" ] "[](file.md)";
    test [ "./dir/file.md" ] "[label](./dir/file.md)";
    test [ "../file.md" ] "[label](../file.md)";
    test [ "/dir/file.md" ] "[label](/dir/file.md)";
    test [ "file%20name.md" ] "[label](file%20name.md)";
    test [ "file%23notes.md" ] "[label](file%23notes.md)";
    test [ "file%25notes.md" ] "[label](file%25notes.md)";
    test [ "caf%C3%A9.md" ] "[label](caf%C3%A9.md)";
    test [ "dir%2Ffile.md" ] "[label](dir%2Ffile.md)";
    test [ "file name.md" ] "[label](<file name.md>)";
    test [ "https://example.com" ] "[label](https://example.com)";
    test [ "https://example.com?q=a#section" ]
      "[label](https://example.com?q=a#section)";
    test [ "file.md#heading" ] "[label](file.md#heading)";
    test [ "#heading" ] "[label](#heading)";
    test [ "file_(draft).md" ] "[label](file_(draft).md)";
    test [ "file(draft).md" ] "[label](file\\(draft\\).md)";
    test [ "file[draft].md" ] "[label](file\\[draft\\].md)";
    test [ "file.md" ] "[label](file.md \"title\")";
    test [ "file.md" ] "[label](file.md 'title')";
    test [ "file name.md" ] "[label](<file name.md> \"title\")";
    test [ "file.md" ] "[label](  file.md  \"title\"  )";
    test [ "file.md" ] "[a [nested] label](file.md)";
    test [ "file.md" ] "[an escaped \\] label](file.md)";
    test [] "[label]()";
    test [] "[label](<>)";
    (* Tolerative parser being permissive *)
    test [ "file name.md" ] "[label](file name.md)";
    test [ "file name.md" ] "[label](file\\ name.md)";
    test [ "one.md"; "two.md" ] "[one](one.md) and [two](two.md)";

    (* Markdown autolinks and bare URLs *)
    test [ "http://example.com/path" ] "<http://example.com/path>";
    test [ "https://example.com/path" ] "<https://example.com/path>";
    test [ "file:///tmp/document.txt" ] "<file:///tmp/document.txt>";
    test [ "mailto:user@example.com" ] "<mailto:user@example.com>";
    test [ "http://example.com/path" ] "http://example.com/path";
    test [ "https://example.com/path" ] "https://example.com/path";
    test [ "file:///tmp/document.txt" ] "file:///tmp/document.txt";
    test [ "https://example.com/a_(b)" ] "https://example.com/a_(b)";
    test [ "https://example.com?q=a|b" ] "https://example.com?q=a|b";
    test [ "https://example.com?q=a&sort=desc" ]
      "https://example.com?q=a&sort=desc";
    test [ "https://example.com/path#fragment" ]
      "https://example.com/path#fragment";
    test [ "https://example.com:8443/path" ]
      "https://example.com:8443/path";
    test [ "https://example.com/path" ] "(https://example.com/path)";

    (* Wiki links *)
    test [ "Note" ] "[[Note]]";
    test [ "Note name" ] "[[Note name]]";
    test [ "Note.md" ] "[[Note.md]]";
    test [ "Figure 1.png" ] "[[Figure 1.png]]";
    test [ "folder/Note name" ] "[[folder/Note name]]";
    test [ "./Note" ] "[[./Note]]";
    test [ "../Note" ] "[[../Note]]";
    test [ "/folder/Note" ] "[[/folder/Note]]";
    test [ "Note" ] "[[Note|Display label]]";
    test [ "Note name" ] "[[Note name|Readable label]]";
    test [ "Note#Heading" ] "[[Note#Heading]]";
    test [ "Note#Heading" ] "[[Note#Heading|Section label]]";
    test [ "Note#Heading#Subheading" ] "[[Note#Heading#Subheading]]";
    test [ "Note#^block-id" ] "[[Note#^block-id]]";
    test [ "Note#^block-id" ] "[[Note#^block-id|Block label]]";
    test [ "#Heading" ] "[[#Heading]]";
    test [ "#^block-id" ] "[[#^block-id]]";
    test [ "日本語のノート" ] "[[日本語のノート]]";
    test [ "Note" ] "[[Note";
    test [] "[[]]";
    test [] "[[|Label]]";
    test [ "One"; "Two" ] "[[One]][[Two]]";

    (* Wiki embeds and Markdown images *)
    test [ "Note" ] "![[Note]]";
    test [ "image.png" ] "![[image.png]]";
    test [ "image.png" ] "![[image.png|300]]";
    test [ "Note#Heading" ] "![[Note#Heading]]";
    test [ "Note#^block-id" ] "![[Note#^block-id]]";
    test [ "image.png" ] "![alt](image.png)";
    test [ "image file.png" ] "![alt](<image file.png> \"title\")";
    test [ "image.png"; "page.md" ] "[![alt](image.png)](page.md)";

    (* Other URI schemes *)
    test [ "ftp://example.com/file" ] "ftp://example.com/file";
    test [ "obsidian://open?vault=Notes&file=Note" ]
      "obsidian://open?vault=Notes&file=Note";
    test [] "custom-scheme:value";

    (* Negative and malformed cases *)
    test [] "[label] (file.md)";
    test [ "file.md" ] "[label](file.md";
    test [ "file name.md" ] "[label](<file name.md)";
    test [] "[not a link]";
    test [ "file.md" ] "\\[label](file.md)";
    test [ "Note" ] "\\[[Note]]";
    test [ "file.md" ] "`[label](file.md)`";
    test [ "https://example.com" ] "`https://example.com`";

    (* Unsupported cases, extraction results are incorrect *)
    test [ "file.md (title)" ] "[label](file.md (title))";
    test [] "[label](\"file.md\")";
    test [] "<user@example.com>";
    test [] "user@example.com";
    test [] "www.example.com/path";
    test [ "https://example.com." ] "See https://example.com.";
    test [ "https://example.com," ] "See https://example.com, next";
    ()

  let suite =
    [
      Alcotest.test_case "corpus" `Quick corpus;
    ]
end
