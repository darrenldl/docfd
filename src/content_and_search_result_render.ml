module I = Notty.I

module A = Notty.A

type word_image_grid = {
  start_line : int;
  data : Notty.image array array;
}

let start_and_end_inc_line_of_search_result
    (index : Index.t)
    (search_result : Search_result.t)
  : (int * int) =
  match Search_result.found_phrase search_result with
  | [] -> failwith "Unexpected case"
  | l -> (
      List.fold_left (fun s_e (pos, _, _) ->
          let (line_num, _) = Index.loc_of_pos pos index in
          match s_e with
          | None -> Some (line_num, line_num)
          | Some (s, e) ->
            Some (min s line_num, max line_num e)
        )
        None
        l
      |> Option.get
    )

let word_image_grid_of_index
    ~start_line
    ~end_inc_line
    (index : Index.t)
  : word_image_grid =
  let data =
    OSeq.(start_line -- end_inc_line)
    |> Seq.map (fun line_num ->
        Index.words_of_line_num line_num index
        |> Seq.map Misc_utils.sanitize_string_for_printing
        |> Seq.map (fun word -> I.string A.empty word)
        |> Array.of_seq
      )
    |> Array.of_seq
  in
  { start_line; data }

let color_word_image_grid
    (grid : word_image_grid)
    (index : Index.t)
    (search_result : Search_result.t)
  : unit =
  List.iter (fun (pos, _word_ci, word) ->
      let (line_num, pos_in_line) = Index.loc_of_pos pos index in
      let word = Misc_utils.sanitize_string_for_printing word in
      grid.data.(line_num - grid.start_line).(pos_in_line) <-
        I.string A.(fg black ++ bg lightyellow) word
    )
    (Search_result.found_phrase search_result)

let render_grid ~display_line_num (grid : word_image_grid) : Notty.image =
  grid.data
  |> Array.to_list
  |> List.mapi (fun i words ->
      let words = Array.to_list words in
      let content =
        if display_line_num then (
          let displayed_line_num = grid.start_line + i + 1 in
          (I.strf ~attr:A.(fg lightyellow) "%d" displayed_line_num
           :: I.strf ": "
           :: words)
        ) else (
          match words with
          | [] -> [ I.void 0 1 ]
          | _ -> words
        )
      in
      I.hcat content
    )
  |> I.vcat

let content_snippet
    ?(search_result : Search_result.t option)
    ~(height : int)
    (index : Index.t)
  : Notty.image =
  let max_line_num =
    match Index.line_count index with
    | 0 -> 0
    | n -> n - 1
  in
  match search_result with
  | None ->
    let grid =
      word_image_grid_of_index
        ~start_line:0
        ~end_inc_line:(min max_line_num height)
        index
    in
    render_grid ~display_line_num:false grid
  | Some search_result ->
    let (relevant_start_line, relevant_end_inc_line) =
      start_and_end_inc_line_of_search_result index search_result
    in
    let avg = (relevant_start_line + relevant_end_inc_line) / 2 in
    let start_line = max 0 (avg - height / 2) in
    let end_inc_line = min max_line_num (avg + height) in
    let grid =
      word_image_grid_of_index
        ~start_line
        ~end_inc_line
        index
    in
    color_word_image_grid grid index search_result;
    render_grid ~display_line_num:false grid

let search_results
    ~start
    ~end_exc
    (index : Index.t)
    (results : Search_result.t array)
  : Notty.image list =
  let open Notty in
  let open Notty.Infix in
  try
    let results =
      Array.sub results
        start
        (end_exc - start)
    in
    results
    |> Array.to_list
    |> List.map (fun (search_result : Search_result.t) ->
        let (start_line, end_inc_line) =
          start_and_end_inc_line_of_search_result index search_result
        in
        let grid =
          word_image_grid_of_index
            ~start_line
            ~end_inc_line
            index
        in
        color_word_image_grid grid index search_result;
        let img = render_grid ~display_line_num:true grid in
        if !Params.debug then
          let score = Search_result.score search_result in
          I.strf "(score: %f)" score
          <->
          img
        else
          img
      )
  with
  | _ -> [ I.strf "Failed to render content search results" ]
