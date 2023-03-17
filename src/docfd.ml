open Cmdliner

let stdout_is_terminal () =
  Unix.isatty Unix.stdout

let fuzzy_max_edit_distance_arg =
  let doc =
    "Maximum edit distance for fuzzy matches."
  in
  Arg.(value & opt int 3 & info [ "fuzzy-max-edit" ] ~doc ~docv:"N")

let tag_ci_fuzzy_arg =
  let doc =
    Fmt.str "[F]uzzy case-insensitive tag match, up to fuzzy-max-edit edit distance."
  in
  Arg.(value & opt_all string [] & info [ "f" ] ~doc ~docv:"STRING")

let tag_ci_full_arg =
  let doc =
    Fmt.str "Case-[i]nsensitive full tag match."
  in
  Arg.(value & opt_all string [] & info [ "i" ] ~doc ~docv:"STRING")

let tag_ci_sub_arg =
  let doc =
    Fmt.str "Case-insensitive [s]ubstring tag match."
  in
  Arg.(value & opt_all string [] & info [ "s" ] ~doc ~docv:"SUBSTRING")

let tag_exact_arg =
  let doc =
    Fmt.str "[E]exact tag match."
  in
  Arg.(value & opt_all string [] & info [ "e" ] ~doc ~docv:"TAG")

let list_tags_arg =
  let doc =
    Fmt.str "List all tags used."
  in
  Arg.(value & flag & info [ "tags" ] ~doc)

let list_tags_lowercase_arg =
  let doc =
    Fmt.str "List all tags used in lowercase."
  in
  Arg.(value & flag & info [ "ltags" ] ~doc)

let list_files_recursively (dir : string) : string list =
  let rec aux path =
    match Sys.is_directory path with
    | false ->
      let ext = Filename.extension path in
      if Misc_utils.path_is_note path
      || ext = ".txt"
      || ext = ".md"
      then
        [ path ]
      else
        []
    | true -> (
        try
          let l = Array.to_list (Sys.readdir path) in
          List.map (Filename.concat path) l
          |> CCList.flat_map aux
        with
        | _ -> []
      )
    | exception _ -> []
  in
  aux dir

let set_of_tags (tags : string list) : String_set.t =
  List.fold_left (fun s x ->
      String_set.add x s
    )
    String_set.empty
    tags

let lowercase_set_of_tags (tags : string list) : String_set.t =
  List.fold_left (fun s x ->
      String_set.add (String.lowercase_ascii x) s
    )
    String_set.empty
    tags

let print_tag_set (tags : String_set.t) =
  let s = String_set.to_seq tags in
  if stdout_is_terminal () then (
    let table = Array.make 256 [] in
    Seq.iter (fun s ->
        let row = Char.code s.[0] in
        table.(row) <- s :: table.(row)
      ) s;
    Array.iteri (fun i l ->
        table.(i) <- List.rev l
      ) table;
    Array.iteri (fun i l ->
        match l with
        | [] -> ()
        | _ -> (
            let c = Char.chr i in
            Fmt.pr "@[<v>%c | @[<hv>%a@]@,@]" c Fmt.(list ~sep:sp string) l
          )
      ) table;
  ) else (
    Fmt.pr "@[<v>%a@]"
      Fmt.(seq ~sep:cut string)
      s
  )

let render_documents
    (term : Notty_unix.Term.t)
    (documents : Document.t array)
  : Notty.image array * Notty.image array =
  let (_term_width, _term_height) = Notty_unix.Term.size term in
  let images_selected : Notty.image list ref = ref [] in
  let images_unselected : Notty.image list ref = ref [] in
  Array.iter (fun (doc : Document.t) ->
      let open Notty in
      let open Notty.Infix in
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
           (path_image :: preview_images)
        )
      in
      let img_unselected =
        I.string A.(fg blue)
          (Option.value ~default:"" doc.title)
        <->
        (I.string A.empty "  "
         <|>
         I.vcat
           (path_image :: preview_images)
        )
      in
      images_selected := img_selected :: !images_selected;
      images_unselected := img_unselected :: !images_unselected
    ) documents;
  let images_selected = Array.of_list (List.rev !images_selected) in
  let images_unselected = Array.of_list (List.rev !images_unselected) in
  (images_selected, images_unselected)

(* let render_headers
    (term : Notty_unix.Term.t)
    (constraints : Tag_search_constraints.t)
    (headers : header array) : Notty.image array * Notty.image array =
   let (term_width, _term_height) = Notty_unix.Term.size term in
   let images_selected : Notty.image list ref = ref [] in
   let images_unselected : Notty.image list ref = ref [] in
   Array.iter (fun header ->
      let open Notty in
      let open Notty.Infix in
      let tag_arr = Array.of_list header.tags in
      let tag_matched = Array.of_list header.tag_matched  in
      let max_tag_len =
        Array.fold_left (fun len s ->
            max len (String.length s))
          0 tag_arr
      in
      let image_of_tag i s : image =
        I.string
          (if Search_constraints.is_empty constraints
           || tag_matched.(i)
           then
             A.(fg red)
           else
             A.empty)
          s
        |> I.hpad 0 (max_tag_len - String.length s + 1)
      in
      let tag_images =
        Array.mapi image_of_tag tag_arr
      in
      let col_count = term_width / 2 / (max_tag_len + 2) in
      let row_count =
        (Array.length tag_arr + (col_count-1)) / col_count
      in
      let img_selected =
        I.string A.(fg blue ++ st bold)
          (Option.value ~default:"" header.title)
        <->
        (I.string A.empty "  "
         <|>
         I.vcat
           [
             (
               I.string A.empty "[ "
               <|> I.tabulate col_count row_count (fun x y ->
                   let i = x + col_count * y in
                   if i < Array.length tag_arr then
                     tag_images.(i)
                   else
                     I.empty
                 )
               <|> I.string A.empty "]"
             );
             I.string A.empty header.path;
           ]
        )
      in
      let img_unselected =
        I.string A.(fg blue)
          (Option.value ~default:"" header.title)
        <->
        (I.string A.empty "  "
         <|>
         I.vcat
           [
             (
               I.string A.empty "[ "
               <|> I.tabulate col_count row_count (fun x y ->
                   let i = x + col_count * y in
                   if i < Array.length tag_arr then
                     tag_images.(i)
                   else
                     I.empty
                 )
               <|> I.string A.empty "]"
             );
             I.string A.empty header.path;
           ]
        )
      in
      images_selected := img_selected :: !images_selected;
      images_unselected := img_unselected :: !images_unselected
    ) headers;
   let images_selected = Array.of_list (List.rev !images_selected) in
   let images_unselected = Array.of_list (List.rev !images_unselected) in
   (images_selected, images_unselected) *)

type mode = [
  | `Navigate
  | `Content
  | `Tag_ci_fuzzy
  | `Tag_ci_full
  | `Tag_ci_sub
  | `Tag_exact
]

let make_label_widget ~s ~len (mode : mode) (v : mode Lwd.var) =
  Lwd.map ~f:(fun mode' ->
      (if mode = mode' then
         Notty.(I.string A.(st bold) s)
       else
         Notty.(I.string A.empty s))
      |> Notty.I.hsnap ~align:`Left len
      |> Nottui.Ui.atom
    ) (Lwd.get v)

let run
    (fuzzy_max_edit_distance : int)
    (tag_ci_fuzzy : string list)
    (tag_ci_full : string list)
    (tag_ci_sub : string list)
    (tag_exact : string list)
    (list_tags : bool)
    (list_tags_lowercase : bool)
    (dir : string)
  =
  if list_tags_lowercase && list_tags then (
    Fmt.pr "Error: Please select only --tags or --ltags\n";
    exit 1
  );
  let files =
    list_files_recursively dir
  in
  let files = List.sort_uniq String.compare files in
  let all_documents =
    List.filter_map (fun path ->
        match Document.of_path path with
        | Ok x -> Some x
        | Error _ -> None) files
  in
  if list_tags_lowercase then (
    let tags_used = ref String_set.empty in
    List.iter (fun (doc : Document.t) ->
        tags_used := String_set.(union
                                   (lowercase_set_of_tags doc.tags)
                                   !tags_used)
      ) all_documents;
    print_tag_set !tags_used
  ) else (
    if list_tags then (
      let tags_used = ref String_set.empty in
      List.iter (fun (doc : Document.t) ->
          tags_used := String_set.(union
                                     (set_of_tags doc.tags)
                                     !tags_used)
        ) all_documents;
      print_tag_set !tags_used
    ) else (
      match all_documents with
      | [] -> ()
      | _ -> (
          let term = Notty_unix.Term.create () in
          let renderer = Nottui.Renderer.make () in
          let tag_constraints =
            Lwd.var (Tag_search_constraints.make
                       ~fuzzy_max_edit_distance
                       ~ci_fuzzy:tag_ci_fuzzy
                       ~ci_full:tag_ci_fuzzy
                       ~ci_sub:tag_ci_fuzzy
                       ~exact:tag_exact)
          in
          let content_constraints =
            Lwd.var (Content_search_constraints.make
                       ~fuzzy_max_edit_distance
                       ~phrase:[])
          in
          let quit = Lwd.var false in
          let selected = Lwd.var 0 in
          let file_to_open = ref None in
          let mode : mode Lwd.var = Lwd.var `Navigate in
          let documents = Lwd.map2 ~f:(fun tag_constraints content_constraints ->
              all_documents
              |> List.filter_map (fun doc ->
                  match Document.satisfies_tag_search_constraints tag_constraints doc with
                  | None -> None
                  | Some doc ->
                      if Content_search_constraints.is_empty content_constraints then
                        Some doc
                      else (
                  match Document.content_search_results content_constraints doc () with
                  | Seq.Nil -> None
                  | Seq.Cons _ as s ->
                      let content_search_results = (fun () -> s)
                  |> List.of_seq
                  |> List.sort Content_search_result.compare
                      in
                      Some { doc with content_search_results }
                      )
                )
              |> (fun l ->
                      if Content_search_constraints.is_empty content_constraints then
                        l
                      else
                        List.sort (fun (doc1 : Document.t) (doc2 : Document.t) ->
                          Content_search_result.compare
                          (List.hd doc1.content_search_results)
                          (List.hd doc2.content_search_results)
                        ) l
                  )
              |> Array.of_list
            )
              (Lwd.get tag_constraints)
              (Lwd.get content_constraints)
          in
          let content_focus_handle = Nottui.Focus.make () in
          let tag_ci_fuzzy_focus_handle = Nottui.Focus.make () in
          let tag_ci_full_focus_handle = Nottui.Focus.make () in
          let tag_ci_sub_focus_handle = Nottui.Focus.make () in
          let tag_exact_focus_handle = Nottui.Focus.make () in
          let left_pane =
            Lwd.map2 ~f:(fun documents i ->
                let image_count = Array.length documents in
                let bound_selection (x : int) : int =
                  max 0 (min (image_count - 1) x)
                in
                let pane =
                  if Array.length documents = 0 then (
                    Nottui.Ui.empty
                  ) else (
                    let (images_selected, images_unselected) =
                      render_documents term documents
                    in
                    CCInt.range' i image_count
                    |> CCList.of_iter
                    |> List.map (fun j ->
                        if Int.equal i j then
                          images_selected.(j)
                        else
                          images_unselected.(j)
                      )
                    |> List.map Nottui.Ui.atom
                    |> Nottui.Ui.vcat
                  )
                in
                pane
                |> Nottui.Ui.keyboard_area (fun event ->
                    match Lwd.peek mode with
                    | `Navigate -> (
                        match event with
                        | (`Escape, [])
                        | (`ASCII 'q', [])
                        | (`ASCII 'C', [`Ctrl]) -> Lwd.set quit true; `Handled
                        | (`ASCII 'j', [])
                        | (`Arrow `Down, []) ->
                          Lwd.set selected (bound_selection (i+1)); `Handled
                        | (`ASCII 'k', [])
                        | (`Arrow `Up, []) ->
                          Lwd.set selected (bound_selection (i-1)); `Handled
                        | (`ASCII '/', []) ->
                            Nottui.Focus.request content_focus_handle;
                          Lwd.set mode `Content;
                          `Handled
                        | (`ASCII 'f', [`Ctrl]) ->
                          Nottui.Focus.request tag_ci_fuzzy_focus_handle;
                          Lwd.set mode `Tag_ci_fuzzy;
                          `Handled
                        | (`ASCII 'i', [`Ctrl]) ->
                          Nottui.Focus.request tag_ci_full_focus_handle;
                          Lwd.set mode `Tag_ci_full;
                          `Handled
                        | (`ASCII 's', [`Ctrl]) ->
                          Nottui.Focus.request tag_ci_sub_focus_handle;
                          Lwd.set mode `Tag_ci_sub;
                          `Handled
                        | (`ASCII 'e', [`Ctrl]) ->
                          Nottui.Focus.request tag_exact_focus_handle;
                          Lwd.set mode `Tag_exact;
                          `Handled
                        | (`Enter, []) -> (
                            Lwd.set quit true;
                            file_to_open := Some documents.(i);
                            `Handled
                          )
                        | _ -> `Handled
                      )
                    | _ -> `Unhandled
                  )
              )
              documents
              (Lwd.get selected)
          in
          let right_pane =
            Lwd.map2 ~f:(fun documents i ->
                if Array.length documents = 0 then
                  Nottui.Ui.empty
                else (
                  let path = documents.(i).path in
                  let (_term_width, term_height) = Notty_unix.Term.size term in
                  let content =
                    try
                      CCIO.with_in path (fun ic ->
                          CCIO.read_lines_seq ic
                          |> OSeq.take term_height
                          |> Seq.map (fun s -> Nottui.Ui.atom Notty.(I.string A.empty s))
                          |> List.of_seq
                          |> Nottui.Ui.vcat
                        )
                    with
                    | _ -> Nottui.Ui.atom Notty.(I.strf "Error: Failed to access %s" path)
                  in
                  content
                )
              )
              documents
              (Lwd.get selected)
          in
          let content_label_str = "(/) Content search:" in
          let tag_ci_fuzzy_label_str = "(Ctrl+f) [F]uzzy case-insensitive tags:" in
          let tag_ci_full_label_str = "(Ctrl+i) Case-[i]sensitive full tags:" in
          let tag_ci_sub_label_str = "(Ctrl+s) Case-insensitive [s]ubstring tags:" in
          let tag_exact_label_str = "(Ctrl+e) [E]exact tags:" in
          let max_label_len =
            List.fold_left (fun x s ->
                max x (String.length s))
              0
              [
                content_label_str;
                tag_ci_fuzzy_label_str;
                tag_ci_full_label_str;
                tag_ci_sub_label_str;
                tag_exact_label_str;
              ]
          in
          let label_widget_len = max_label_len + 1 in
          let content_label =
            make_label_widget
            ~s:content_label_str
            ~len:label_widget_len
            `Content
            mode
          in
          let tag_ci_fuzzy_label =
            make_label_widget
            ~s:tag_ci_fuzzy_label_str
            ~len:label_widget_len
            `Tag_ci_fuzzy
            mode
          in
          let tag_ci_full_label =
            make_label_widget
            ~s:tag_ci_full_label_str
            ~len:label_widget_len
            `Tag_ci_full
            mode
          in
          let tag_ci_sub_label =
            make_label_widget
            ~s:tag_ci_sub_label_str
            ~len:label_widget_len
            `Tag_ci_sub
            mode
          in
          let tag_exact_label =
            make_label_widget
            ~s:tag_exact_label_str
            ~len:label_widget_len
            `Tag_exact
            mode
          in
          let content_field =
            Lwd.var ("", 0)
          in
          let tag_ci_fuzzy_field =
            let s = String.concat " " tag_ci_fuzzy in
            Lwd.var (s, String.length s)
          in
          let tag_ci_full_field =
            let s = String.concat " " tag_ci_full in
            Lwd.var (s, String.length s)
          in
          let tag_ci_sub_field =
            let s = String.concat " " tag_ci_sub in
            Lwd.var (s, String.length s)
          in
          let tag_exact_field =
            let s = String.concat " " tag_exact in
            Lwd.var (s, String.length s)
          in
          let update_content_constraints () =
            let constraints' =
              (Content_search_constraints.make
                 ~fuzzy_max_edit_distance
                 ~phrase:(String.split_on_char ' ' (fst @@ Lwd.peek content_field))
              )
            in
            Lwd.set selected 0;
            Lwd.set content_constraints constraints'
          in
          let update_tag_constraints () =
            let constraints' =
              (Tag_search_constraints.make
                 ~fuzzy_max_edit_distance
                 ~ci_fuzzy:(String.split_on_char ' ' (fst @@ Lwd.peek tag_ci_fuzzy_field))
                 ~ci_full:(String.split_on_char ' ' (fst @@ Lwd.peek tag_ci_full_field))
                 ~ci_sub:(String.split_on_char ' ' (fst @@ Lwd.peek tag_ci_sub_field))
                 ~exact:(String.split_on_char ' ' (fst @@ Lwd.peek tag_exact_field))
              )
            in
            Lwd.set selected 0;
            Lwd.set tag_constraints constraints'
          in
          let make_search_field ~edit_field ~focus_handle ~f =
            Nottui_widgets.edit_field (Lwd.get edit_field)
              ~focus:focus_handle
              ~on_change:(fun (text, x) -> Lwd.set edit_field (text, x))
              ~on_submit:(fun _ ->
                  f ();
                  Nottui.Focus.release focus_handle;
                  Lwd.set mode `Navigate
                )
          in
          let screen =
            Nottui_widgets.vbox
              [
                Nottui_widgets.h_pane
                  left_pane
                  right_pane;
                Nottui_widgets.hbox
                  [
                    content_label;
                    make_search_field
                      ~edit_field:content_field
                      ~focus_handle:content_focus_handle
                      ~f:update_content_constraints;
                  ];
                Nottui_widgets.hbox
                  [
                    tag_ci_fuzzy_label;
                    make_search_field
                      ~edit_field:tag_ci_fuzzy_field
                      ~focus_handle:tag_ci_fuzzy_focus_handle
                      ~f:update_tag_constraints;
                  ];
                Nottui_widgets.hbox
                  [
                    tag_ci_full_label;
                    make_search_field
                      ~edit_field:tag_ci_full_field
                      ~focus_handle:tag_ci_full_focus_handle
                      ~f:update_tag_constraints;
                  ];
                Nottui_widgets.hbox
                  [
                    tag_ci_sub_label;
                    make_search_field
                      ~edit_field:tag_ci_sub_field
                      ~focus_handle:tag_ci_sub_focus_handle
                      ~f:update_tag_constraints;
                  ];
                Nottui_widgets.hbox
                  [
                    tag_exact_label;
                    make_search_field
                      ~edit_field:tag_exact_field
                      ~focus_handle:tag_exact_focus_handle
                      ~f:update_tag_constraints;
                  ];
              ]
          in
          let rec loop () =
            file_to_open := None;
            Lwd.set quit false;
            Nottui.Ui_loop.run
              ~term
              ~renderer
              ~quit
              screen;
            match !file_to_open with
            | None -> ()
            | Some header ->
              match Sys.getenv_opt "EDITOR" with
              | None ->
                Printf.printf "Error: Failed to read environment variable EDITOR\n"; exit 1
              | Some editor -> (
                  Sys.command (Fmt.str "%s \'%s\'" editor header.path) |> ignore;
                  loop ()
                )
          in
          loop ()
        )
    )
  )

let dir_arg = Arg.(value & pos 0 dir "." & info [])

let cmd =
  let doc = "Tag your notes with a simple header" in
  let version = Version_string.s in
  Cmd.v (Cmd.info "notefd" ~version ~doc)
    (Term.(const run
           $ fuzzy_max_edit_distance_arg
           $ tag_ci_fuzzy_arg
           $ tag_ci_full_arg
           $ tag_ci_sub_arg
           $ tag_exact_arg$ list_tags_arg
           $ list_tags_lowercase_arg
           $ dir_arg))

let () = exit (Cmd.eval cmd)