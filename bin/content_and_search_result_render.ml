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
  let grid_end_inc_global_line_num = grid.start_global_line_num + Array.length grid.data - 1 in
  List.iter (fun Search_result.{ found_word_pos = pos; found_word = word; _ } ->
      let loc = Index.loc_of_pos pos index in
      let line_loc = Index.Loc.line_loc loc in
      let global_line_num = Index.Line_loc.global_line_num line_loc in
      if grid.start_global_line_num <= global_line_num
      && global_line_num <= grid_end_inc_global_line_num
      then (
        let pos_in_line = Index.Loc.pos_in_line loc in
        grid.data.(global_line_num - grid.start_global_line_num).(pos_in_line) <-
          I.string A.(fg black ++ bg lightyellow) word
      )
    )
    (Search_result.found_phrase search_result)

type render_mode = [
  | `Page_num_only
  | `Line_num_only
  | `Page_and_line_num
  | `None
]

let render_grid
    ~(render_mode : render_mode)
    ~target_row
    ~width
    ?(height : int option)
    (grid : word_image_grid)
    (index : Index.t)
  : Notty.image =
  let images =
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
        let left_column_label =
          match render_mode with
          | `Page_num_only -> (
              I.hcat
                [ I.strf ~attr:A.(fg lightyellow) "Page %d" display_page_num
                ; I.strf ": " ]
            )
          | `Line_num_only -> (
              I.hcat
                [ I.strf ~attr:A.(fg lightyellow) "%d" display_line_num
                ; I.strf ": " ]
            )
          | `Page_and_line_num -> (
              I.hcat
                [ I.strf ~attr:A.(fg lightyellow) "Page %d, %d"
                    display_page_num
                    display_line_num
                ; I.strf ": " ]
            )
          | `None -> (
              I.strf ""
            )
        in
        let content_width = max 1 (width - I.width left_column_label) in
        let content = Word_grid_render.of_images ~width:content_width words in
        I.hcat [ left_column_label; content ]
      )
  in
  let img = I.vcat images in
  match height with
  | None -> img
  | Some height -> (
      let focal_point_offset =
        CCList.foldi (fun focal_point_offset i img ->
            let img_height = I.height img in
            if i < target_row then (
              focal_point_offset + img_height
            ) else if i = target_row then (
              focal_point_offset + (Misc_utils.div_round_to_closest img_height 2)
            ) else (
              focal_point_offset
            )
          )
          0
          images
      in
      let img_height = I.height img in
      let target_region_start =
        max 0 (focal_point_offset - (Misc_utils.div_round_to_closest height 2))
      in
      let target_region_end_exc = target_region_start + height in
      I.vcrop target_region_start (img_height - target_region_end_exc) img
    )

let content_snippet
    ?(search_result : Search_result.t option)
    ~(width : int)
    ~(height : int)
    (index : Index.t)
  : Notty.image =
  let max_line_num = Index.global_line_count index - 1 in
  assert (max_line_num >= 0);
  assert (height > 0);
  match search_result with
  | None -> (
      let grid =
        word_image_grid_of_index
          ~start_global_line_num:0
          ~end_inc_global_line_num:(min max_line_num (height - 1))
          index
      in
      render_grid ~render_mode:`None ~target_row:0 ~width ~height grid index
    )
  | Some search_result -> (
      let (relevant_start_line, relevant_end_inc_line) =
        start_and_end_inc_global_line_num_of_search_result index search_result
      in
      let avg = (relevant_start_line + relevant_end_inc_line) / 2 in
      let start_global_line_num = max 0 (avg - (Misc_utils.div_round_to_closest height 2)) in
      let end_inc_global_line_num = min max_line_num (start_global_line_num + height - 1) in
      let grid =
        word_image_grid_of_index
          ~start_global_line_num
          ~end_inc_global_line_num
          index
      in
      color_word_image_grid grid index search_result;
      render_grid
        ~render_mode:`None
        ~target_row:(relevant_start_line - start_global_line_num)
        ~width
        ~height
        grid
        index
    )

let search_results
    ~render_mode
    ~start
    ~end_exc
    ~width
    (index : Index.t)
    (results : Search_result.t array)
  : Notty.image list =
  let open Notty in
  let open Notty.Infix in
  let result_count = Array.length results in
  let end_exc = min end_exc result_count in
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
      let img = render_grid ~render_mode ~target_row:0 ~width grid index in
      if Option.is_some !Params.debug_output then (
        let score = Search_result.score search_result in
        I.strf "(Score: %f)" score
        <->
        img
      ) else (
        img
      )
    )
