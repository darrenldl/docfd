open Docfd_lib

module I = Notty.I

module A = Notty.A

type word_image_grid = {
  start_global_line_num : int;
  data : Notty.image array array;
}

let start_and_end_inc_global_line_num_of_search_result
    (index : Index.t)
    (search_result : Search_result.t)
  : (int * int) =
  match Search_result.found_phrase search_result with
  | [] -> failwith "Unexpected case"
  | l -> (
      List.fold_left (fun s_e Search_result.{ found_word_pos; _ } ->
          let loc = Index.loc_of_pos found_word_pos index in
          let line_loc = Index.Loc.line_loc loc in
          let global_line_num = Index.Line_loc.global_line_num line_loc in
          match s_e with
          | None -> Some (global_line_num, global_line_num)
          | Some (s, e) ->
            Some (min s global_line_num, max global_line_num e)
        )
        None
        l
      |> Option.get
    )

let word_image_grid_of_index
    ~start_global_line_num
    ~end_inc_global_line_num
    (index : Index.t)
  : word_image_grid =
  let global_line_count = Index.global_line_count index in
  if global_line_count = 0 then
    { start_global_line_num = 0; data = [||] }
  else (
    let end_inc_global_line_num = min (global_line_count - 1) end_inc_global_line_num in
    let data =
      OSeq.(start_global_line_num -- end_inc_global_line_num)
      |> Seq.map (fun global_line_num ->
          let data =
            Index.words_of_global_line_num global_line_num index
            |> Seq.map (fun word -> I.string A.empty word)
            |> Array.of_seq
          in
          data
        )
      |> Array.of_seq
    in
    { start_global_line_num; data }
  )

let color_word_image_grid
    (grid : word_image_grid)
    (index : Index.t)
    (search_result : Search_result.t)
  : unit =
  List.iter (fun Search_result.{ found_word_pos = pos; found_word = word; _ } ->
      let loc = Index.loc_of_pos pos index in
      let line_loc = Index.Loc.line_loc loc in
      let global_line_num = Index.Line_loc.global_line_num line_loc in
      let pos_in_line = Index.Loc.pos_in_line loc in
      grid.data.(global_line_num - grid.start_global_line_num).(pos_in_line) <-
        I.string A.(fg black ++ bg lightyellow) word
    )
    (Search_result.found_phrase search_result)

type render_mode = [
  | `Page_num_only
  | `Line_num_only
  | `Page_and_line_num
  | `None
]

let render_grid ~(render_mode : render_mode) (grid : word_image_grid) (index : Index.t) : Notty.image =
  grid.data
  |> Array.to_list
  |> List.mapi (fun i words ->
      let words =
        match Array.to_list words with
        | [] -> [ I.void 0 1 ]
        | l -> l
      in
      let global_line_num = grid.start_global_line_num + i in
      let line_loc = Index.line_loc_of_global_line_num global_line_num index in
      let display_line_num = Index.Line_loc.line_num_in_page line_loc + 1 in
      let display_page_num = Index.Line_loc.page_num line_loc + 1 in
      let content =
        match render_mode with
        | `Page_num_only ->
          I.strf ~attr:A.(fg lightyellow) "Page %d" display_page_num
          ::
          I.strf ": "
          ::
          words
        | `Line_num_only ->
          I.strf ~attr:A.(fg lightyellow) "%d" display_line_num
          ::
          I.strf ": "
          ::
          words
        | `Page_and_line_num ->
          I.strf ~attr:A.(fg lightyellow) "Page %d, %d"
            display_page_num
            display_line_num
          ::
          I.strf ": "
          ::
          words
        | `None ->
          words
      in
      I.hcat content
    )
  |> I.vcat

let content_snippet
    ?(search_result : Search_result.t option)
    ~(fallback_start_global_line_num : int)
    ~(height : int)
    (index : Index.t)
  : Notty.image =
  let max_line_num =
    match Index.global_line_count index with
    | 0 -> 0
    | n -> n - 1
  in
  match search_result with
  | None ->
    let grid =
      word_image_grid_of_index
        ~start_global_line_num:fallback_start_global_line_num
        ~end_inc_global_line_num:(min max_line_num (fallback_start_global_line_num + height))
        index
    in
    render_grid ~render_mode:`None grid index
  | Some search_result ->
    let (relevant_start_line, relevant_end_inc_line) =
      start_and_end_inc_global_line_num_of_search_result index search_result
    in
    let avg = (relevant_start_line + relevant_end_inc_line) / 2 in
    let start_global_line_num = max 0 (avg - height / 2 + 1) in
    let end_inc_global_line_num = min max_line_num (avg + height) in
    let grid =
      word_image_grid_of_index
        ~start_global_line_num
        ~end_inc_global_line_num
        index
    in
    color_word_image_grid grid index search_result;
    render_grid ~render_mode:`None grid index

let search_results
    ~render_mode
    ~start
    ~end_exc
    (index : Index.t)
    (results : Search_result.t array)
  : Notty.image list =
  let open Notty in
  let open Notty.Infix in
  let results =
    Array.sub results
      start
      (end_exc - start)
  in
  results
  |> Array.to_list
  |> List.map (fun (search_result : Search_result.t) ->
      let (start_global_line_num, end_inc_global_line_num) =
        start_and_end_inc_global_line_num_of_search_result index search_result
      in
      let grid =
        word_image_grid_of_index
          ~start_global_line_num
          ~end_inc_global_line_num
          index
      in
      color_word_image_grid grid index search_result;
      let img = render_grid ~render_mode grid index in
      if !Params.debug then (
        let score = Search_result.score search_result in
        I.strf "(score: %f)" score
        <->
        img
      ) else (
        img
      )
    )
