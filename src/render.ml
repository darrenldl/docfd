let documents
    (term : Notty_unix.Term.t)
    (documents : Document.t array)
  : Notty.image array * Notty.image array =
  let (_term_width, _term_height) = Notty_unix.Term.size term in
  let images_selected : Notty.image list ref = ref [] in
  let images_unselected : Notty.image list ref = ref [] in
  Array.iter (fun (doc : Document.t) ->
      let open Notty in
      let open Notty.Infix in
      let content_search_result_score_image =
        if !Params.debug then
          match doc.content_search_results with
          | [] -> I.empty
          | x :: _ ->
            I.strf "(content search result score: %f)" (Content_search_result.score x)
        else
          I.empty
      in
      let preview_images =
        List.map (fun line ->
            I.strf "|  %s" line
          )
          doc.preview_lines
      in
      let path_image =
        I.string A.empty doc.path;
      in
      let img_selected =
        I.string A.(fg blue ++ st bold)
          (Option.value ~default:"" doc.title)
        <->
        (I.string A.empty "  "
         <|>
         I.vcat
           (content_search_result_score_image :: path_image :: preview_images)
        )
      in
      let img_unselected =
        I.string A.(fg blue)
          (Option.value ~default:"" doc.title)
        <->
        (I.string A.empty "  "
         <|>
         I.vcat
           (content_search_result_score_image :: path_image :: preview_images)
        )
      in
      images_selected := img_selected :: !images_selected;
      images_unselected := img_unselected :: !images_unselected
    ) documents;
  let images_selected = Array.of_list (List.rev !images_selected) in
  let images_unselected = Array.of_list (List.rev !images_unselected) in
  (images_selected, images_unselected)

let content_search_results
    (document : Document.t)
  : Notty.image array =
  let open Notty in
  try
    let doc_lines =
      CCIO.with_in document.path (fun ic ->
          Array.of_list (CCIO.read_lines_l ic)
        )
    in
    let images = ref [] in
    List.iter (fun (search_result : Content_search_result.t) ->
        let (relevant_start_line, relevant_end_inc_line) =
          List.fold_left (fun s_e (_word, loc) ->
              let (line_num, _pos) = Int_map.find loc document.content_index.line_pos_of_location_ci in
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
              Content_index.tokenize line
              |> List.map (fun word -> I.string A.empty word)
              |> Array.of_list
            )
        in
        List.iter (fun (_word, loc) ->
            let (line_num, pos) = Int_map.find loc document.content_index.line_pos_of_location_ci in
            let word = Int_map.find loc document.content_index.word_of_location in
            word_image_grid.(line_num - relevant_start_line).(pos) <-
              I.string A.(fg red ++ st bold) word
          )
          search_result.found_phrase;
        let img =
          word_image_grid
          |> Array.to_list
          |> List.mapi (fun i words ->
              let words = Array.to_list words in
              I.hcat
                (
                  I.strf ~attr:A.(fg yellow) "%d" (relevant_start_line + i)
                  :: I.strf ": "
                  :: words
                )
            )
          |> I.vcat
        in
        images := img :: !images
      )
      document.content_search_results;
    Array.of_list (List.rev !images)
  with
  | _ -> [| I.strf "Failed to access %s" document.path |]
