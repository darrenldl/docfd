open Docfd_lib

module Alco = struct
  let corpus () =
    let test expected_links input =
      let line = Tokenization.tokenize ~drop_spaces:false input
        |> Seq.mapi (fun i x -> (i, x))
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
    test [ "file.md" ] "[](file.md)"

  let suite =
    [
      Alcotest.test_case "corpus" `Quick corpus;
    ]
end
