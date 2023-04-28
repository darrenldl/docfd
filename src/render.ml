let documents
    (documents : Document.t array)
  : Notty.image array * Notty.image array =
  let images_selected : Notty.image list ref = ref [] in
  let images_unselected : Notty.image list ref = ref [] in
  Array.iter (fun (doc : Document.t) ->
      let open Notty in
      let open Notty.Infix in
      let search_result_score_image =
        if !Params.debug then
          if Array.length doc.search_results = 0 then
            I.empty
          else
            let x = doc.search_results.(0) in
            I.strf "(best content search result score: %f)" (Search_result.score x)
        else
          I.empty
      in
      let preview_line_images =
        let line_count =
          min Params.preview_line_count (Index.line_count doc.index)
        in
        OSeq.(0 --^ line_count)
        |> Seq.map (fun line_num -> Index.line_of_line_num line_num doc.index)
        |> Seq.map (fun line ->
            (I.string A.(bg lightgreen) " ")
            <|>
            (I.strf " %s" (Misc_utils.sanitize_string_for_printing line))
          )
        |> List.of_seq
      in
      let preview_image =
        I.vcat preview_line_images
      in
      let path_image =
        I.string A.(fg lightgreen) "@ "
        <|>
        I.string A.empty
          (Option.value ~default:Params.stdin_doc_path_placeholder doc.path);
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
           [ search_result_score_image;
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
           [ search_result_score_image;
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

let search_results
    ~start
    ~end_exc
    (index : Index.t)
    (results : Search_result.t array)
  : Notty.image array =
  let open Notty in
  let open Notty.Infix in
  try
    let results =
      Array.sub results
        start
        (end_exc - start)
    in
    Array.map (fun (search_result : Search_result.t) ->
        let (relevant_start_line, relevant_end_inc_line) =
          List.fold_left (fun s_e (pos, _, _) ->
              let (line_num, _) = Index.loc_of_pos pos index in
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
          OSeq.(relevant_start_line
                --
                relevant_end_inc_line)
          |> Seq.map (fun line ->
              Index.words_of_line_num line index
              |> Seq.map Misc_utils.sanitize_string_for_printing
              |> Seq.map (fun word -> I.string A.empty word)
              |> Array.of_seq
            )
          |> Array.of_seq
        in
        List.iter (fun (pos, _word_ci, word) ->
            let (line_num, pos_in_line) = Index.loc_of_pos pos index in
            let word = Misc_utils.sanitize_string_for_printing word in
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
          let score = Search_result.score search_result in
          I.strf "(score: %f)" score
          <->
          img
        else
          img
      )
      results
  with
  | _ -> [| I.strf "Failed to render content search results" |]
