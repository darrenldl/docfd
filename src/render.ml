let documents
    (_term : Notty_unix.Term.t)
    (documents : Document.t array)
  : Notty.image array * Notty.image array =
  let images_selected : Notty.image list ref = ref [] in
  let images_unselected : Notty.image list ref = ref [] in
  Array.iter (fun (doc : Document.t) ->
      let open Notty in
      let open Notty.Infix in
      let content_search_result_score_image =
        if !Params.debug then
          if Array.length doc.content_search_results = 0 then
            I.empty
          else
            let x = doc.content_search_results.(0) in
            I.strf "(best content search result score: %f)" (Content_search_result.score x)
        else
          I.empty
      in
      let preview_line_images =
        List.map (fun line ->
            (I.string A.(bg lightgreen) " ")
            <|>
            (I.strf " %s" (Misc_utils.sanitize_string_for_printing line))
          )
          doc.preview_lines
      in
      let preview_image =
        I.vcat preview_line_images
      in
      let path_image =
        I.string A.(fg lightgreen) "@ " <|> I.string A.empty doc.path;
      in
      let title =
        Option.value ~default:"" doc.title
        |> Misc_utils.sanitize_string_for_printing
      in
      let img_selected =
        (I.string A.(fg lightblue ++ st bold) title)
        <->
        (I.string A.empty "  "
         <|>
         I.vcat
           [ content_search_result_score_image;
             path_image;
             preview_image;
           ]
        )
      in
      let img_unselected =
        (I.string A.(fg lightblue) title)
        <->
        (I.string A.empty "  "
         <|>
         I.vcat
           [ content_search_result_score_image;
             path_image;
             preview_image;
           ]
        )
      in
      images_selected := img_selected :: !images_selected;
      images_unselected := img_unselected :: !images_unselected
    ) documents;
  let images_selected = Array.of_list (List.rev !images_selected) in
  let images_unselected = Array.of_list (List.rev !images_unselected) in
  (images_selected, images_unselected)

let content_search_results
    ~start
    ~end_exc
    (document : Document.t)
  : Notty.image array =
  let open Notty in
  let open Notty.Infix in
  try
    let doc_lines =
      CCIO.with_in document.path (fun ic ->
          Array.of_list (CCIO.read_lines_l ic)
        )
    in
    let results = Array.sub
        document.content_search_results
        start
        (end_exc - start)
    in
    Array.map (fun (search_result : Content_search_result.t) ->
        let (relevant_start_line, relevant_end_inc_line) =
          List.fold_left (fun s_e (_word, pos) ->
              let (line_num, _) = Int_map.find pos document.content_index.line_pos_of_pos in
              match s_e with
              | None -> Some (line_num, line_num)
              | Some (s, e) ->
                Some (min s line_num, max line_num e)
            )
            None
            search_result.found_phrase
          |> Option.get
        in
        let word_image_grid =
          Array.sub doc_lines relevant_start_line (relevant_end_inc_line - relevant_start_line + 1)
          |> Array.map (fun line ->
              Tokenize.f ~drop_spaces:false line
              |> Seq.map Misc_utils.sanitize_string_for_printing
              |> Seq.map (fun word -> I.string A.empty word)
              |> Array.of_seq
            )
        in
        List.iter (fun (_word, pos) ->
            let (line_num, pos_in_line) = Int_map.find pos document.content_index.line_pos_of_pos in
            let word = Int_map.find pos document.content_index.word_of_pos
                       |> Misc_utils.sanitize_string_for_printing
            in
            word_image_grid.(line_num - relevant_start_line).(pos_in_line) <-
              I.string A.(fg black ++ bg lightyellow) word
          )
          search_result.found_phrase;
        let img =
          word_image_grid
          |> Array.to_list
          |> List.mapi (fun i words ->
              let words = Array.to_list words in
              I.hcat
                (
                  let displayed_line_num = relevant_start_line + i + 1 in
                  I.strf ~attr:A.(fg lightyellow) "%d" displayed_line_num
                  :: I.strf ": "
                  :: words
                )
            )
          |> I.vcat
        in
        if !Params.debug then
          let score = Content_search_result.score search_result in
          I.strf "(score: %f)" score
          <->
          img
        else
          img
      )
      results
  with
  | _ -> [| I.strf "Failed to access %s" document.path |]
