open Docfd_lib

module I = Notty.I

module A = Notty.A

type cell_typ = [
  | `Plain
  | `Search_result
]

type cell = {
  word : string;
  typ : cell_typ;
}

module Text_block_render = struct
  let hchunk_rev ~width (img : Notty.image) : Notty.image list =
    let open Notty in
    let rec aux acc img =
      let img_width = I.width img in
      if img_width <= width then (
        img :: acc
      ) else (
        let acc = (I.hcrop 0 (img_width - width) img) :: acc in
        aux acc (I.hcrop width 0 img)
      )
    in
    aux [] img

  let of_cells ?attr ~width ?(underline = false) (cells : cell list) : Notty.image * Int_set.t =
    let open Notty.Infix in
    assert (width > 0);
    let rendered_lines_with_search_result_words = ref Int_set.empty in
    let grid : Notty.image list list =
      List.fold_left
        (fun ((cur_len, acc) : int * Notty.image list list) (cell : cell) ->
           let attr =
             match attr with
             | Some attr -> attr
             | None -> (match cell.typ with
                 | `Plain -> A.empty
                 | `Search_result -> A.(fg black ++ bg lightyellow)
               )
           in
           let word =
             (match I.string attr cell.word with
              | s -> s
              | exception _ -> (
                  I.string A.(fg lightred) (String.make (String.length cell.word) '?')
                ))
           in
           let word_len = I.width word in
           let word =
             match cell.typ with
             | `Plain -> word
             | `Search_result -> (
                 if underline then (
                   word
                   <->
                   (I.string A.empty (String.make word_len '^'))
                 ) else (
                   word
                 )
               )
           in
           let new_len = cur_len + word_len in
           let cur_len, acc =
             if new_len <= width then (
               match acc with
               | [] -> (new_len, [ [ word ] ])
               | line :: rest -> (
                   (new_len, (word :: line) :: rest)
                 )
             ) else (
               if word_len <= width then (
                 (word_len, [ word ] :: acc)
               ) else (
                 let lines =
                   hchunk_rev ~width word
                   |> List.map (fun x -> [ x ])
                 in
                 (0, [] :: (lines @ acc))
               )
             )
           in
           (match cell.typ with
            | `Plain -> ()
            | `Search_result -> (
                rendered_lines_with_search_result_words :=
                  Int_set.add (List.length acc - 1) !rendered_lines_with_search_result_words
              ));
           (cur_len, acc)
        )
        (0, [])
        cells
      |> snd
      |> List.rev_map List.rev
    in
    let img =
      grid
      |> List.map I.hcat
      |> I.vcat
    in
    (img, !rendered_lines_with_search_result_words)

  let of_words ?attr ~width ?underline (words : string list) : Notty.image =
    of_cells ?attr ~width ?underline (List.map (fun word -> { word; typ = `Plain }) words)
    |> fst
end

type word_grid = {
  start_global_line_num : int;
  data : cell array array;
}

let start_and_end_inc_global_line_num_of_search_result
    ~doc_hash
    (search_result : Search_result.t)
  : (int * int) =
  match Search_result.found_phrase search_result with
  | [] -> failwith "unexpected case"
  | l -> (
      List.fold_left (fun s_e Search_result.{ found_word_pos; _ } ->
          let loc = Index.loc_of_pos ~doc_hash found_word_pos in
          let line_loc = Index.Loc.line_loc loc in
          let global_line_num = Index.Line_loc.global_line_num line_loc in
          match s_e with
          | None -> (
              Some (global_line_num, global_line_num)
            )
          | Some (s, e) -> (
              Some (min s global_line_num, max global_line_num e)
            )
        )
        None
        l
      |> Option.get
    )

let word_grid_of_index
    ~doc_hash
    ~start_global_line_num
    ~end_inc_global_line_num
  : word_grid =
  let global_line_count = Index.global_line_count ~doc_hash in
  let check x =
    assert (0 <= x);
    assert (x <= global_line_count - 1);
  in
  check start_global_line_num;
  check end_inc_global_line_num;
  if global_line_count = 0 then (
    { start_global_line_num = 0; data = [||] }
  ) else (
    let data =
      OSeq.(start_global_line_num -- end_inc_global_line_num)
      |> Seq.map (fun global_line_num ->
          let data =
            Index.words_of_global_line_num ~doc_hash global_line_num
            |> Dynarray.to_seq
            |> Seq.map (fun word -> { word; typ = `Plain })
            |> Array.of_seq
          in
          data
        )
      |> Array.of_seq
    in
    { start_global_line_num; data }
  )

let mark_search_result_in_word_grid
    ~doc_hash
    (grid : word_grid)
    (search_result : Search_result.t)
  : unit =
  let grid_end_inc_global_line_num = grid.start_global_line_num + Array.length grid.data - 1 in
  List.iter (fun Search_result.{ found_word_pos = pos; _ } ->
      let loc = Index.loc_of_pos ~doc_hash pos in
      let line_loc = Index.Loc.line_loc loc in
      let global_line_num = Index.Line_loc.global_line_num line_loc in
      if grid.start_global_line_num <= global_line_num
      && global_line_num <= grid_end_inc_global_line_num
      then (
        let pos_in_line = Index.Loc.pos_in_line loc in
        let row = global_line_num - grid.start_global_line_num in
        let cell = grid.data.(row).(pos_in_line) in
        grid.data.(row).(pos_in_line) <- { cell with typ = `Search_result }
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
    ~doc_hash
    ~(view_offset : int Lwd.var option)
    ~(render_mode : render_mode)
    ~width
    ?(height : int option)
    ?underline
    (grid : word_grid)
  : Notty.image =
  let (_rendered_line_count, rendered_lines_with_search_result_words), images =
    grid.data
    |> Array.to_list
    |> CCList.fold_map_i
      (fun (rendered_line_count, rendered_lines_with_search_result_words_acc) i cells ->
         let cells = Array.to_list cells in
         let global_line_num = grid.start_global_line_num + i in
         let line_loc = Index.line_loc_of_global_line_num ~doc_hash global_line_num in
         let displayed_line_num = Index.Line_loc.line_num_in_page line_loc + 1 in
         let displayed_page_num = Index.Line_loc.page_num line_loc + 1 in
         let left_column_label =
           match render_mode with
           | `Page_num_only -> (
               I.hcat
                 [ I.strf ~attr:A.(fg lightyellow) "Page %d" displayed_page_num
                 ; I.strf ": " ]
             )
           | `Line_num_only -> (
               I.hcat
                 [ I.strf ~attr:A.(fg lightyellow) "%d" displayed_line_num
                 ; I.strf ": " ]
             )
           | `Page_and_line_num -> (
               I.hcat
                 [ I.strf ~attr:A.(fg lightyellow) "Page %d, %d"
                     displayed_page_num
                     displayed_line_num
                 ; I.strf ": " ]
             )
           | `None -> (
               I.void 0 1
             )
         in
         let content_width = max 1 (width - I.width left_column_label) in
         let content, rendered_lines_with_search_result_words =
           Text_block_render.of_cells ?underline ~width:content_width cells
         in
         ((rendered_line_count + I.height content,
           rendered_lines_with_search_result_words
           |> Int_set.map (fun x -> x + rendered_line_count)
           |> Int_set.union rendered_lines_with_search_result_words_acc
          ),
          I.hcat [ left_column_label; content ])
      )
      (0, Int_set.empty)
  in
  let img = I.vcat images in
  match height with
  | None -> img
  | Some height -> (
      let focal_point_offset =
        match
          Int_set.min_elt_opt rendered_lines_with_search_result_words,
          Int_set.max_elt_opt rendered_lines_with_search_result_words
        with
        | Some start_rendered_line_num, Some end_inc_rendered_line_num -> (
            Misc_utils.div_round_to_closest
              (start_rendered_line_num + end_inc_rendered_line_num)
              2
          )
        | _, _ -> 0
      in
      let target_region_start =
        max 0 (focal_point_offset - (Misc_utils.div_round_to_closest height 2))
      in
      let img_height = I.height img in
      let target_region_end_exc =
        min
          img_height
          (target_region_start + height)
      in
      let view_offset_old =
        match view_offset with
        | None -> 0
        | Some x -> Lwd.peek x
      in
      let view_offset' =
        if view_offset_old >= 0 then (
          min
            view_offset_old
            (img_height - target_region_end_exc)
        ) else (
          let view_offset_old = Int.abs view_offset_old in
          - (min
               view_offset_old
               (target_region_start - 0))
        )
      in
      Option.iter (fun x ->
          if view_offset_old <> view_offset' then (
            Lwd.set x view_offset'
          )) view_offset;
      let target_region_start, target_region_end_exc =
        (target_region_start + view_offset',
         target_region_end_exc + view_offset')
      in
      I.vcrop target_region_start (img_height - target_region_end_exc) img
    )

let content_snippet
    ~doc_hash
    ~(view_offset : int Lwd.var)
    ?(search_result : Search_result.t option)
    ~(width : int)
    ~(height : int)
    ?underline
    ()
  : Notty.image =
  let max_end_inc_global_line_num = Index.global_line_count ~doc_hash - 1 in
  assert (height > 0);
  let compute_final_line_num_range
      ~(view_offset : int Lwd.var)
      ~start_global_line_num
    : int * int =
    let end_inc_global_line_num =
      min
        max_end_inc_global_line_num
        (start_global_line_num + height - 1)
    in
    (* We grow the area in one direction
       rather than shifting the area, in order
       to not interfere with the focal point offset computation
       in render_grid.

       The number of lines to grow is an overapproximation
       of the actual lines required, as a
       line may wrap into multiple rendered lines
       in the rendered view if it is longer than
       the width of the content pane.
       But we do not know how many lines (or partial segments
       of lines) exactly until we
       actually render the view/word grid.
    *)
    let view_offset' = Lwd.peek view_offset in
    if view_offset' >= 0 then (
      let end_inc_global_line_num =
        min
          max_end_inc_global_line_num
          (end_inc_global_line_num + view_offset')
      in
      (start_global_line_num, end_inc_global_line_num)
    ) else (
      let start_global_line_num =
        max
          0
          (start_global_line_num - Int.abs view_offset')
      in
      (start_global_line_num, end_inc_global_line_num)
    )
  in
  match search_result with
  | None -> (
      let start_global_line_num, end_inc_global_line_num =
        compute_final_line_num_range
          ~view_offset
          ~start_global_line_num:0
      in
      let grid =
        word_grid_of_index
          ~doc_hash
          ~start_global_line_num
          ~end_inc_global_line_num
      in
      render_grid
        ~doc_hash
        ~view_offset:(Some view_offset)
        ~render_mode:`None
        ~width
        ~height
        ?underline
        grid
    )
  | Some search_result -> (
      let (relevant_start_line, relevant_end_inc_line) =
        start_and_end_inc_global_line_num_of_search_result ~doc_hash search_result
      in
      let avg = (relevant_start_line + relevant_end_inc_line) / 2 in
      let start_global_line_num, end_inc_global_line_num =
        compute_final_line_num_range
          ~view_offset
          ~start_global_line_num:(
            max
              0
              (avg - (Misc_utils.div_round_to_closest height 2))
          )
      in
      let grid =
        word_grid_of_index
          ~doc_hash
          ~start_global_line_num
          ~end_inc_global_line_num
      in
      mark_search_result_in_word_grid ~doc_hash grid search_result;
      render_grid
        ~doc_hash
        ~view_offset:(Some view_offset)
        ~render_mode:`None
        ~width
        ~height
        ?underline
        grid
    )

let word_is_not_space s =
  String.length s > 0 && not (Parser_components.is_space s.[0])

let grab_additional_lines
    ~doc_hash
    ~non_space_word_count
    start_global_line_num
    end_inc_global_line_num
  : int * int =
  let max_end_inc_global_line_num = Index.global_line_count ~doc_hash - 1 in
  let non_space_word_count_of_line n =
    Index.words_of_global_line_num ~doc_hash n
    |> Dynarray.to_seq
    |> Seq.filter word_is_not_space
    |> Seq.length
  in
  let rec aux ~non_space_word_count ~i x y =
    if i < !Params.search_result_print_snippet_max_additional_lines_each_direction
    && non_space_word_count < !Params.search_result_print_snippet_min_size
    then (
      let x, top_add_count =
        let n = x - 1 in
        if n >= 0 then (
          (n, non_space_word_count_of_line n)
        ) else (
          (x, 0)
        )
      in
      let y, bottom_add_count =
        let n = y + 1 in
        if n <= max_end_inc_global_line_num then (
          (n, non_space_word_count_of_line n)
        ) else (
          (y, 0)
        )
      in
      let non_space_word_count =
        non_space_word_count
        + top_add_count
        + bottom_add_count
      in
      aux ~non_space_word_count ~i:(i + 1) x y
    ) else (
      (x, y)
    )
  in
  aux ~non_space_word_count ~i:0 start_global_line_num end_inc_global_line_num

let search_result
    ~doc_hash
    ~render_mode
    ~width
    ?underline
    ?(fill_in_context = false)
    (search_result : Search_result.t)
  : Notty.image =
  let open Notty in
  let open Notty.Infix in
  let (start_global_line_num, end_inc_global_line_num) =
    start_and_end_inc_global_line_num_of_search_result ~doc_hash search_result
    |> (fun (x, y) ->
        if fill_in_context then (
          let non_space_word_count =
            Search_result.search_phrase search_result
            |> Search_phrase.enriched_tokens
            |> List.filter_map (fun token ->
                match Search_phrase.Enriched_token.data token with
                | `Explicit_spaces -> None
                | `String s -> (
                    assert (word_is_not_space s);
                    Some s
                  )
              )
            |> List.length
          in
          grab_additional_lines ~doc_hash ~non_space_word_count x y
        ) else (
          (x, y)
        )
      )
  in
  let grid =
    word_grid_of_index
      ~doc_hash
      ~start_global_line_num
      ~end_inc_global_line_num
  in
  mark_search_result_in_word_grid ~doc_hash grid search_result;
  let img =
    render_grid
      ~doc_hash
      ~view_offset:None
      ~render_mode
      ~width
      ?underline
      grid
  in
  if Option.is_some !Params.debug_output then (
    let score = Search_result.score search_result in
    I.strf "(Score: %f)" score
    <->
    img
  ) else (
    img
  )
