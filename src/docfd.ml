open Cmdliner

let stdin_is_atty () =
  Unix.isatty Unix.stdin

let stdout_is_atty () =
  Unix.isatty Unix.stdout

let max_depth_arg =
  let doc =
    "Scan up to N levels in the file tree."
  in
  Arg.(value & opt int Params.default_max_file_tree_depth & info [ "max-depth" ] ~doc ~docv:"N")

let max_fuzzy_edit_distance_arg =
  let doc =
    "Maximum edit distance for fuzzy matches."
  in
  Arg.(value & opt int Params.default_max_fuzzy_edit_distance & info [ "max-fuzzy-edit" ] ~doc ~docv:"N")

let max_word_search_range_arg =
  let doc =
    "Maximum range to look for the next matching word/symbol in content search."
  in
  Arg.(value & opt int Params.default_max_word_search_range
       & info [ "max-word-search-range" ] ~doc ~docv:"N")

let debug_arg =
  let doc =
    Fmt.str "Display debug info."
  in
  Arg.(value & flag & info [ "debug" ] ~doc)

let list_files_recursively (dir : string) : string list =
  let l = ref [] in
  let add x =
    l := x :: !l
  in
  let rec aux depth path =
    if depth >= !Params.max_file_tree_depth then ()
    else (
      if Sys.is_directory path then (
        let next_choices =
          try
            Sys.readdir path
          with
          | _ -> [||]
        in
        Array.iter (fun f ->
            aux (depth + 1) (Filename.concat path f)
          )
          next_choices
      ) else (
        let ext = Filename.extension path in
        if List.mem ext Params.recognized_exts then (
          add path
        )
      )
    )
  in
  (
    try
      aux 0 dir
    with
    | _ -> ()
  );
  !l

let run
    (debug : bool)
    (max_depth : int)
    (max_fuzzy_edit_distance : int)
    (max_word_search_range : int)
    (files : string list)
  =
  Params.debug := debug;
  Params.max_file_tree_depth := max_depth;
  Params.max_fuzzy_edit_distance := max_fuzzy_edit_distance;
  Params.max_word_search_range := max_word_search_range;
  List.iter (fun file ->
      if not (Sys.file_exists file) then (
        Fmt.pr "Error: File \"%s\" does not exist\n" file;
        exit 1
      )
    )
    files;
  if !Params.debug then (
    Printf.printf "Scanning for text files\n"
  );
  let init_ui_mode, document_src =
    if not (stdin_is_atty ()) then
      Ui_base.(Ui_single_file, Stdin)
    else (
      match files with
      | [] -> Fmt.pr "Error: No files provided\n"; exit 1
      | [ f ] -> (
          if Sys.is_directory f then
            Ui_base.(Ui_multi_file, Files (list_files_recursively f))
          else
            Ui_base.(Ui_single_file, Files [ f ])
        )
      | _ -> (
          Ui_base.(Ui_multi_file,
                   Files (
                     files
                     |> List.to_seq
                     |> Seq.flat_map (fun f ->
                         if Sys.is_directory f then
                           List.to_seq (list_files_recursively f)
                         else
                           Seq.return f
                       )
                     |> List.of_seq
                     |> List.sort_uniq String.compare
                   )
                  )
        )
    )
  in
  if !Params.debug then (
    Printf.printf "Scanning completed\n"
  );
  if !Params.debug then (
    match document_src with
    | Stdin -> Printf.printf "Document source: stdin\n"
    | Files files -> (
        Printf.printf "Document source: files\n";
        List.iter (fun file ->
            Printf.printf "File: %s\n" file;
          )
          files
      )
  );
  let all_documents =
    match document_src with
    | Stdin ->
      [ Document.of_in_channel ~path:None stdin ]
    | Files files ->
      List.filter_map (fun path ->
          match Document.of_path path with
          | Ok x -> Some x
          | Error _ -> None) files
  in
  match all_documents with
  | [] -> Printf.printf "No suitable text files found\n"
  | default_selected_document :: _ -> (
      Ui_base.Vars.init_ui_mode := init_ui_mode;
      let tbl = Lwd.peek Ui_base.Vars.all_documents in
      all_documents
      |> List.to_seq
      |> Seq.map (fun (doc : Document.t) -> (doc.path, doc))
      |> Hashtbl.add_seq tbl;
      Lwd.set Ui_base.Vars.all_documents tbl;
      Ui_base.Vars.total_document_count := List.length all_documents;
      (match document_src with
       | Stdin ->
         let input =
           Unix.(openfile "/dev/tty" [ O_RDWR ] 0666)
         in
         Ui_base.Vars.term := Some (Notty_unix.Term.create ~input ())
       | Files _ ->
         Ui_base.Vars.term := Some (Notty_unix.Term.create ())
      );
      let renderer = Nottui.Renderer.make () in
      Lwd.set Ui_base.Vars.ui_mode init_ui_mode;
      Lwd.set Ui_base.Vars.document_selected default_selected_document;
      let root : Nottui.ui Lwd.t =
        Lwd.map ~f:(fun (ui_mode : Ui_base.ui_mode) ->
            match ui_mode with
            | Ui_multi_file -> Multi_file_view.main
            | Ui_single_file -> Single_file_view.main
          )
          (Lwd.get Ui_base.Vars.ui_mode)
        |> Lwd.join
      in
      let rec loop () =
        Ui_base.Vars.file_to_open := None;
        Lwd.set Ui_base.Vars.quit false;
        Nottui.Ui_loop.run
          ~term:Ui_base.(get_term ())
          ~renderer
          ~quit:Ui_base.Vars.quit
          root;
        match !Ui_base.Vars.file_to_open with
        | None -> ()
        | Some doc ->
          match doc.path with
          | None -> ()
          | Some path ->
            match Sys.getenv_opt "VISUAL", Sys.getenv_opt "EDITOR" with
            | None, None ->
              Printf.printf "Error: Both env variables VISUAL and EDITOR are unset\n"; exit 1
            | Some editor, _
            | None, Some editor -> (
                Sys.command (Fmt.str "%s \'%s\'" editor path) |> ignore;
                loop ()
              )
      in
      loop ()
    )

let files_arg = Arg.(value & pos_all string [ "." ] & info [])

let cmd =
  let doc = "TUI fuzzy document finder" in
  let version = Version_string.s in
  Cmd.v (Cmd.info "docfd" ~version ~doc)
    Term.(const run
          $ debug_arg
          $ max_depth_arg
          $ max_fuzzy_edit_distance_arg
          $ max_word_search_range_arg
          $ files_arg)

let () = exit (Cmd.eval cmd)
