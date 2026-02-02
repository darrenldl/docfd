open Docfd_lib
open Lwd_infix

type input_mode =
  | Navigate
  | Search
  | Filter
  | Clear
  | Sort of [ `Asc | `Desc ]
  | Drop
  | Mark
  | Unmark
  | Narrow
  | Copy
  | Copy_paths
  | Reload
  | Save_script
  | Save_script_overwrite
  | Save_script_no_name
  | Save_script_edit
  | Delete_script_confirm of string * string
  | Links
[@@deriving ord]

module Input_mode_map = Map.Make (struct
    type t = input_mode

    let compare x y =
      match x, y with
      | Delete_script_confirm _, Delete_script_confirm _ -> 0
      | _, _ -> compare_input_mode x y
  end)

type top_level_action =
  | Recompute_document_src
  | Open_file_and_search_result of Document.t * Search_result.t option
  | Open_link of Link.t
  | Edit_command_history
  | Select_and_load_script
  | Delete_script_select
  | Edit_script of string
  | Sort_by_fzf

type search_status = [
  | `Idle
  | `Searching
  | `Parse_error
]

type filter_status = [
  | `Idle
  | `Filtering
  | `Parse_error
]

let empty_text_field = ("", 0)

let render_mode_of_document (doc : Document.t)
  : Content_and_search_result_rendering.render_mode =
  match File_utils.format_of_file (Document.path doc) with
  | `PDF -> `Page_num_only
  | `Pandoc_supported_format -> `None
  | `Text -> `Line_num_only

module Vars = struct
  let quit = Lwd.var false

  let pool : Task_pool.t option Atomic.t = Atomic.make None

  let action : top_level_action option ref = ref None

  let eio_env : Eio_unix.Stdenv.base option ref = ref None

  let hide_document_list : bool Lwd.var = Lwd.var false

  let input_mode : input_mode Lwd.var = Lwd.var Navigate

  let document_src : Document_src.t ref = ref (Document_src.(Files empty_file_collection))

  let term : Notty_unix.Term.t option ref = ref None

  let term_width_height : (int * int) Lwd.var = Lwd.var (0, 0)

  let content_view_offset = Lwd.var 0

  let autocomplete_choices = Lwd.var []

  let filter_field = Lwd.var empty_text_field

  let filter_field_focus_handle = Nottui.Focus.make ()

  let search_field = Lwd.var empty_text_field

  let search_field_focus_handle = Nottui.Focus.make ()

  let search_ui_status : search_status Lwd.var = Lwd.var `Idle

  let filter_ui_status : filter_status Lwd.var = Lwd.var `Idle

  let index_of_document_selected = Lwd.var 0

  let index_of_search_result_selected = Lwd.var 0

  let index_of_link_selected = Lwd.var 0
end

let reset_content_view_offset () =
  Lwd.set Vars.content_view_offset 0

let decr_content_view_offset () =
  let x = Lwd.peek Vars.content_view_offset in
  Lwd.set Vars.content_view_offset (x - 1)

let incr_content_view_offset () =
  let x = Lwd.peek Vars.content_view_offset in
  Lwd.set Vars.content_view_offset (x + 1)

let reset_document_selected () =
  reset_content_view_offset ();
  Lwd.set Vars.index_of_document_selected 0;
  Lwd.set Vars.index_of_search_result_selected 0;
  Lwd.set Vars.index_of_link_selected 0

let set_document_selected ~choice_count n =
  let n = Misc_utils.bound_selection ~choice_count n in
  let old = Lwd.peek Vars.index_of_document_selected in
  if old <> n then (
    reset_content_view_offset ();
    Lwd.set Vars.index_of_document_selected n;
    Lwd.set Vars.index_of_search_result_selected 0;
    Lwd.set Vars.index_of_link_selected 0;
  )

let set_search_result_selected ~choice_count n =
  let old = Lwd.peek Vars.index_of_search_result_selected in
  if old <> n then (
    reset_content_view_offset ();
    let n = Misc_utils.bound_selection ~choice_count n in
    Lwd.set Vars.index_of_search_result_selected n
  )

let set_link_selected ~choice_count n =
  let old = Lwd.peek Vars.index_of_link_selected in
  if old <> n then (
    reset_content_view_offset ();
    let n = Misc_utils.bound_selection ~choice_count n in
    Lwd.set Vars.index_of_link_selected n
  )

let task_pool () =
  Option.get (Atomic.get Vars.pool)

let eio_env () =
  Option.get !Vars.eio_env

let term () =
  Option.get !Vars.term

let full_term_sized_background =
  let$ (term_width, term_height) = Lwd.get Vars.term_width_height in
  Notty.I.void term_width term_height
  |> Nottui.Ui.atom

let vbar ~height =
  let uc = Uchar.of_int 0x2502 in
  Notty.I.uchar Notty.A.(fg white) uc 1 height
  |> Nottui.Ui.atom

let hbar ~width =
  let uc = Uchar.of_int 0x2015 in
  Notty.I.uchar Notty.A.(fg white) uc width 1
  |> Nottui.Ui.atom

let hpane
    ~l_ratio
    ~width
    ~height
    (x : width:int -> Nottui.ui Lwd.t)
    (y : width:int -> Nottui.ui Lwd.t)
  : Nottui.ui Lwd.t =
  let l_width =
    (* Minus 1 for pane separator bar. *)
    Int.to_float width *. l_ratio
    |> Float.floor
    |> Int.of_float
    |> (fun x ->
        if x = 0 || x = width then (
          x
        ) else (
          x - 1
        ))
  in
  let r_width =
    (* Minus 1 here too just to be conservative. *)
    width - l_width - 1
  in
  let crop w x = Nottui.Ui.resize ~w ~h:height x in
  let x () =
    let$ x = x ~width:l_width in
    crop l_width x
  in
  let y () =
    let$ y = y ~width:r_width in
    crop r_width y
  in
  if l_width = 0 then (
    y ()
  ) else if r_width = 0 then (
    x ()
  ) else (
    let$* x = x () in
    let$ y = y () in
    Nottui.Ui.hcat [
      x;
      vbar ~height;
      y;
    ]
  )

let vpane
    ~width
    ~height
    (x : height:int -> Nottui.ui Lwd.t)
    (y : height:int -> Nottui.ui Lwd.t)
  : Nottui.ui Lwd.t =
  let t_height =
    (Misc_utils.div_round_up height 2)
  in
  let b_height =
    (* Minus 1 for pane separator bar. *)
    (height / 2) - 1
  in
  let$* x = x ~height:t_height in
  let$ y = y ~height:b_height in
  let crop h x = Nottui.Ui.resize ~w:width ~h x in
  Nottui.Ui.vcat [
    crop t_height x;
    hbar ~width;
    crop b_height y;
  ]

let wrapped_edit_field ~focus ~on_change ~on_submit ~on_tab x =
  let$ field =
    Nottui_widgets.edit_field (Lwd.get x)
      ~focus
      ~on_change
      ~on_submit
  in
  Nottui.Ui.keyboard_area (fun key ->
      match key with
      | (`Tab, []) -> (
          on_tab (Lwd.peek x);
          `Handled
        )
      | _ -> `Unhandled)
    field

let mouse_handler
    ~(f : [ `Up | `Down ] -> unit)
    ~x ~y
    (button : Notty.Unescape.button)
  =
  let _ = x in
  let _ = y in
  match button with
  | `Scroll `Down -> (
      f `Down;
      `Handled
    )
  | `Scroll `Up -> (
      f `Up;
      `Handled
    )
  | _ -> `Unhandled

module Content_view = struct
  let main
      ~(input_mode : input_mode)
      ~height
      ~width
      ~(search_result_group : Document.t * Search_result.t array)
      ~(search_result_selected : int)
      ~(link_selected : int)
    : Nottui.ui Lwd.t =
    let (document, search_results) = search_result_group in
    let links = Document.links document in
    let data =
      let search_result_count = Array.length search_results in
      let link_count = Array.length links in
      match input_mode with
      | Links -> (
          if link_count = 0 then (
            None
          ) else (
            Some (`Link links.(link_selected))
          )
        )
      | _ -> (
          if search_result_count = 0 then (
            None
          ) else (
            Some (`Search_result search_results.(search_result_selected))
          )
        )
    in
    let$* _ = Lwd.get Vars.content_view_offset in
    let content =
      Content_and_search_result_rendering.content_snippet
        ~doc_id:(Document.doc_id document)
        ~view_offset:Vars.content_view_offset
        ?data
        ~height
        ~width
        ()
    in
    let$* background = full_term_sized_background in
    Nottui.Ui.join_z background (Nottui.Ui.atom content)
    |> Nottui.Ui.mouse_area
      (mouse_handler
         ~f:(fun direction ->
             match direction with
             | `Up -> decr_content_view_offset ()
             | `Down -> incr_content_view_offset ()
           )
      )
    |> Lwd.return
end

module Status_bar = struct
  let fg_color = Notty.A.black

  let bg_color = Notty.A.white

  let attr = Notty.A.(bg bg_color ++ fg fg_color)

  let background_bar : Nottui.Ui.t Lwd.t =
    let$ (term_width, _term_height) = Lwd.get Vars.term_width_height in
    Notty.I.char Notty.A.(bg bg_color) ' ' term_width 1
    |> Nottui.Ui.atom

  let element_spacing = 4

  let element_spacer =
    Notty.(I.string
             A.(bg bg_color ++ fg fg_color))
      (String.make element_spacing ' ')

  let input_mode_images =
    let l =
      [ (Navigate, "NAVIGATE")
      ; (Search, "SEARCH")
      ; (Filter, "FILTER")
      ; (Clear, "CLEAR")
      ; (Sort `Asc, "SORT-ASC")
      ; (Sort `Desc, "SORT-DESC")
      ; (Drop, "DROP")
      ; (Mark, "MARK")
      ; (Unmark, "UNMARK")
      ; (Narrow, "NARROW")
      ; (Copy, "COPY")
      ; (Copy_paths, "COPY-PATHS")
      ; (Reload, "RELOAD")
      ; (Save_script, "SAVE-SCRIPT")
      ; (Save_script_overwrite, "SAVE-SCRIPT")
      ; (Save_script_no_name, "SAVE-SCRIPT")
      ; (Save_script_edit, "SAVE-SCRIPT")
      ; (Delete_script_confirm ("", ""), "DELETE-SCRIPT")
      ; (Links, "LINKS")
      ]
    in
    let max_input_mode_string_len =
      List.fold_left (fun acc (_, s) ->
          max acc (String.length s)
        )
        0
        l
    in
    let input_mode_string_background =
      Notty.I.char Notty.A.(bg bg_color) ' ' max_input_mode_string_len 1
    in
    List.fold_left (fun m (mode, s) ->
        let s = Notty.(I.string A.(bg bg_color ++ fg fg_color ++ st bold) s) in
        Input_mode_map.add mode Notty.I.(s </> input_mode_string_background) m
      )
      Input_mode_map.empty
      l
end

module Key_binding_info = struct
  let rotation : int Lwd.var = Lwd.var 0

  let incr_rotation () =
    Lwd.set rotation (Lwd.peek rotation + 1)

  let reset_rotation () =
    Lwd.set rotation 0

  type labelled_msg = {
    label : string;
    msg : string;
  }

  type labelled_msg_line = labelled_msg list

  type grid_contents = (input_mode * (labelled_msg_line list)) list

  type grid_lookup = Nottui.ui Lwd.t Input_mode_map.t

  let grid_lights : (string, Mtime.t ref * bool Lwd.var list) Hashtbl.t = Hashtbl.create 100

  let lock = Eio.Mutex.create ()

  let grid_light_on_req : string Eio.Stream.t = Eio.Stream.create 100

  let grid_light_off_req : (Mtime.t * Mtime.t * string) Eio.Stream.t = Eio.Stream.create 100

  let blink label =
    Eio.Stream.add grid_light_on_req label

  let grid_light_fiber () =
    let clock = Eio.Stdenv.mono_clock (eio_env ()) in
    Eio.Fiber.both
      (fun () ->
         while true do
           let label = Eio.Stream.take grid_light_on_req in
           let ts_now = Eio.Time.Mono.now clock in
           Eio.Mutex.use_rw lock ~protect:false (fun () ->
               match Hashtbl.find_opt grid_lights label with
               | None -> failwith "unexpected case"
               | Some (ts, l) -> (
                   ts := ts_now;
                   List.iter (fun x -> Lwd.set x true) l;
                   Eio.Stream.add
                     grid_light_off_req
                     (ts_now, Option.get (Mtime.(add_span ts_now Params.blink_on_duration)), label);
                 )
             )
         done
      )
      (fun () ->
         while true do
           let ts_req_time, ts_target_time, label = Eio.Stream.take grid_light_off_req in
           Eio.Time.Mono.sleep_until clock ts_target_time;
           Eio.Mutex.use_rw lock ~protect:false (fun () ->
               match Hashtbl.find_opt grid_lights label with
               | None -> failwith "unexpected case"
               | Some (ts_last_update, l) -> (
                   if Mtime.equal !ts_last_update ts_req_time then (
                     List.iter (fun x -> Lwd.set x false) l;
                   )
                 )
             )
         done
      )

  let make_grid_lookup grid_contents : grid_lookup =
    let max_label_msg_len_lookup : (input_mode * (int * int) Int_map.t) list =
      grid_contents
      |> List.map (fun (grid_key, grid) ->
          let lookup =
            List.fold_left
              (fun (acc : (int * int) Int_map.t) (line : labelled_msg_line) ->
                 line
                 |> List.to_seq
                 |> Seq.fold_lefti
                   (fun (acc : (int * int) Int_map.t) col ({ label; msg } : labelled_msg) ->
                      let label_len =
                        Uuseg_string.fold_utf_8 `Grapheme_cluster (fun x _ -> x + 1) 0 label
                      in
                      let msg_len =
                        Uuseg_string.fold_utf_8 `Grapheme_cluster (fun x _ -> x + 1) 0 msg
                      in
                      let (max_label_len, max_msg_len) =
                        match Int_map.find_opt col acc with
                        | None -> (label_len, msg_len)
                        | Some (max_label_len, max_msg_len) -> (
                            (max max_label_len label_len,
                             max max_msg_len msg_len)
                          )
                      in
                      Int_map.add col (max_label_len, max_msg_len) acc
                   )
                   acc
              )
              Int_map.empty
              grid
          in
          (grid_key, lookup)
        )
    in
    let label_msg_pair grid_key col { label; msg } : Nottui.ui Lwd.t =
      let (max_label_len, max_msg_len) =
        List.assoc grid_key max_label_msg_len_lookup
        |> Int_map.find col
      in
      let light_on_var = Lwd.var false in
      Eio.Mutex.use_rw lock ~protect:false (fun () ->
          let x =
            match Hashtbl.find_opt grid_lights label with
            | None -> (ref Mtime.min_stamp, [ light_on_var ])
            | Some (x, l) -> (x, light_on_var :: l)
          in
          Hashtbl.replace grid_lights label x
        );
      let$ light_on = Lwd.get light_on_var in
      let label_attr =
        if light_on then
          Notty.A.(fg black ++ bg lightyellow ++ st bold)
        else
          Notty.A.(fg lightyellow ++ st bold)
      in
      let msg_attr = Notty.A.empty in
      let msg = String.capitalize_ascii msg in
      let content = Notty.(I.hcat
                             [ I.(string label_attr label
                                  </>
                                  (string label_attr (String.make max_label_len ' ')))
                             ; I.string A.empty "  "
                             ; I.string msg_attr msg
                             ]
                          )
      in
      let full_background =
        Notty.I.void (max_label_len + 2 + max_msg_len + 2) 1
      in
      Notty.I.(content </> full_background)
      |> Nottui.Ui.atom
    in
    List.fold_left (fun m (grid_key, grid_contents) ->
        let max_row_size =
          List.fold_left (fun n l ->
              max n (List.length l)
            )
            0
            grid_contents
        in
        let grid_contents =
          grid_contents
          |> List.map (fun l ->
              let padding =
                List.init (max_row_size - List.length l)
                  (fun _ -> { label = ""; msg = "" })
              in
              List.mapi (fun col x ->
                  label_msg_pair grid_key col x
                )
                (l @ padding)
            )
        in
        let grid =
          let$* rotation = Lwd.get rotation in
          grid_contents
          |> List.map (fun l ->
              Misc_utils.rotate_list (rotation mod max_row_size) l
            )
          |> Nottui_widgets.grid
            ~pad:(Nottui.Gravity.make ~h:`Negative ~v:`Negative)
        in
        Input_mode_map.add grid_key grid m
      )
      Input_mode_map.empty
      grid_contents

  let main ~(grid_lookup : grid_lookup) ~(input_mode : input_mode) =
    Input_mode_map.find input_mode grid_lookup
end

let filter_bar_label_string = "Document filter"

let search_bar_label_string = "Content search"

let max_label_length =
  List.fold_left (fun acc s ->
      max acc (String.length s)
    )
    0
    [ filter_bar_label_string
    ; search_bar_label_string
    ]

let pad_label_string s =
  CCString.pad ~side:`Right ~c:' ' max_label_length s

let autocomplete ~choices (text, pos) : string * int =
  let left = String.sub text 0 pos in
  let right = String.sub text pos (String.length text - pos) in
  let grab_input_word (s : string) =
    let rec aux acc i s =
      if i < 0 then (
        CCString.of_list acc
      ) else (
        let c = s.[i] in
        if Parser_components.is_alphanum c
        || c = '-'
        || c = ':'
        then (
          aux (c :: acc) (i - 1) s
        ) else (
          aux acc (-1) s
        )
      )
    in
    aux [] (String.length s - 1) s
  in
  let current_input_word = grab_input_word left in
  let usable_choices =
    List.filter
      (CCString.prefix ~pre:current_input_word)
      choices
  in
  Lwd.set
    Vars.autocomplete_choices usable_choices;
  match usable_choices with
  | [] -> (text, pos)
  | _ -> (
      let best_fit = usable_choices
        |> List.to_seq
        |> String_utils.longest_common_prefix
      in
      let left =
        String.sub
          left
          0
          (String.length left - String.length current_input_word)
      in
      (String.concat "" [ left; best_fit; right ],
       pos + (String.length best_fit - String.length current_input_word))
    )

module Filter_bar = struct
  let label_string = pad_label_string filter_bar_label_string

  let label ~(input_mode : input_mode) =
    let attr =
      match input_mode with
      | Filter -> Notty.A.(st bold)
      | _ -> Notty.A.empty
    in
    Notty.I.string attr label_string
    |> Nottui.Ui.atom
    |> Lwd.return

  let status =
    let$* status = Lwd.get Vars.filter_ui_status in
    (match status with
     | `Idle -> (
         Notty.I.string Notty.A.(fg lightgreen)
           "  OK"
       )
     | `Filtering -> (
         Notty.I.string Notty.A.(fg lightyellow)
           " ..."
       )
     | `Parse_error -> (
         Notty.I.string Notty.A.(fg lightred)
           " ERR"
       )
    )
    |> Nottui.Ui.atom
    |> Lwd.return

  let autocomplete_choices =
    [ "path-date:"
    ; "path-fuzzy:"
    ; "path-glob:"
    ; "ext:"
    ; "content:"
    ; "mod-date:"
    ]

  let main
      ~input_mode
      ~(edit_field : (string * int) Lwd.var)
      ~focus_handle
      ~on_change
      ~on_submit
    : Nottui.ui Lwd.t =
    Nottui_widgets.hbox
      [
        label ~input_mode;
        status;
        Lwd.return (Nottui.Ui.atom (Notty.I.strf ": "));
        wrapped_edit_field edit_field
          ~focus:focus_handle
          ~on_change:(fun (text, x) ->
              Lwd.set edit_field (text, x);
              on_change ();
            )
          ~on_submit:(fun (text, x) ->
              Lwd.set edit_field (text, x);
              on_submit ();
              Lwd.set Vars.autocomplete_choices [];
              Nottui.Focus.release focus_handle;
              Lwd.set Vars.input_mode Navigate
            )
          ~on_tab:(fun (text, pos) ->
              let (text, pos) =
                autocomplete ~choices:autocomplete_choices (text, pos)
              in
              Lwd.set edit_field (text, pos)
            );
      ]
end

module Search_bar = struct
  let label_string = pad_label_string search_bar_label_string

  let label ~(input_mode : input_mode) =
    let attr =
      match input_mode with
      | Search -> Notty.A.(st bold)
      | _ -> Notty.A.empty
    in
    Notty.I.string attr label_string
    |> Nottui.Ui.atom
    |> Lwd.return

  let status =
    let$* status = Lwd.get Vars.search_ui_status in
    (match status with
     | `Idle -> (
         Notty.I.string Notty.A.(fg lightgreen)
           "  OK"
       )
     | `Searching -> (
         Notty.I.string Notty.A.(fg lightyellow)
           " ..."
       )
     | `Parse_error -> (
         Notty.I.string Notty.A.(fg lightred)
           " ERR"
       )
    )
    |> Nottui.Ui.atom
    |> Lwd.return

  let main
      ~input_mode
      ~(edit_field : (string * int) Lwd.var)
      ~focus_handle
      ~on_change
      ~on_submit
    : Nottui.ui Lwd.t =
    Nottui_widgets.hbox
      [
        label ~input_mode;
        status;
        Lwd.return (Nottui.Ui.atom (Notty.I.strf ": "));
        wrapped_edit_field edit_field
          ~focus:focus_handle
          ~on_change:(fun (text, x) ->
              Lwd.set edit_field (text, x);
              on_change ();
            )
          ~on_submit:(fun (text, x) ->
              Lwd.set edit_field (text, x);
              on_submit ();
              Lwd.set Vars.autocomplete_choices [];
              Nottui.Focus.release focus_handle;
              Lwd.set Vars.input_mode Navigate
            )
          ~on_tab:(fun (_, _) -> ());
      ]
end

let term' : unit -> Notty_unix.Term.t = term

let ui_loop ~quit ~term root =
  let renderer = Nottui.Renderer.make () in
  let root =
    let$ root = root in
    root
    (* |> Nottui.Ui.event_filter (fun x ->
        match x with
        | `Key (`Escape, []) -> (
            Lwd.set quit true;
            `Handled
          )
        | _ -> `Unhandled
       ) *)
  in
  let rec loop () =
    if not (Lwd.peek quit) then (
      let (term_width, term_height) = Notty_unix.Term.size (term' ()) in
      let (prev_term_width, prev_term_height) = Lwd.peek Vars.term_width_height in
      if term_width <> prev_term_width || term_height <> prev_term_height then (
        Lwd.set Vars.term_width_height (term_width, term_height)
      );
      Nottui.Ui_loop.step
        ~process_event:true
        ~timeout:0.05
        ~renderer
        term
        (Lwd.observe @@ root);
      Eio.Fiber.yield ();
      loop ()
    )
  in
  loop ()

let set_input_mode mode =
  Lwd.set Vars.input_mode mode;
  Key_binding_info.reset_rotation ()
