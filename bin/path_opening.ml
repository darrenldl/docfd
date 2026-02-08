open Docfd_lib
open Debug_utils

type launch_mode = [ `Terminal | `Detached ]

type spec = string list * launch_mode * string

let specs : (string, launch_mode * string) Hashtbl.t = Hashtbl.create 128

module Parsers = struct
  open Angstrom
  open Parser_components

  let expected_char c =
    fail (Fmt.str "expected char %c" c)

  let inner ~path ~page_num ~line_num ~search_word : string t =
    choice [
      string "path" *> commit *> return path;
      string "page_num" *> commit
      >>= (fun _ ->
          match page_num with
          | None -> fail "page_num not available"
          | Some n -> return (Fmt.str "%d" n)
        );
      string "line_num" *> commit
      >>= (fun _ ->
          match line_num with
          | None -> fail "line_num not available"
          | Some n -> return (Fmt.str "%d" n)
        );
      string "search_word" *> commit
      >>= (fun _ ->
          match search_word with
          | None -> fail "search_word not available"
          | Some s -> return (Fmt.str "'%s'" s));
    ]
    <|>
    fail "invalid placeholder"

  let cmd ~path ~page_num ~line_num ~search_word : string t =
    let single =
      choice [
        (string "{{" >>| fun _ -> Fmt.str "{");
        (char '{' *> commit *>
         inner ~path ~page_num ~line_num ~search_word <*
         (char '}' <|> expected_char '}'));
        (take_while1 (function '{' -> false | _ -> true));
      ]
    in
    many single
    >>| fun l -> String.concat "" l

  let spec : spec t =
    sep_by (char ',')
      (take_while1 (function ':' | ',' -> false | _ -> true))
    >>= fun exts ->
    (char ':' <|> expected_char ':')*>
    (choice [
        string "terminal" *> return `Terminal;
        string "detached" *> return `Detached;
      ]
     <|>
     fail "invalid launch mode")
    >>= fun launch_mode ->
    (char '=' <|> expected_char '=') *> any_string
    >>= fun cmd ->
    return (exts, launch_mode, cmd)
end

module Config = struct
  type t = {
    quote_path : bool;
    path : string;
    page_num : int option;
    line_num : int option;
    search_word : string option;
    launch_mode : launch_mode;
  }

  let make ?(quote_path = true) ~path ?page_num ?line_num ?search_word ~launch_mode () : t =
    {
      quote_path;
      path;
      page_num;
      line_num;
      search_word;
      launch_mode;
    }
end

let resolve_cmd (config : Config.t) (s : string) : (string, string) result =
  let open Angstrom in
  let { Config.quote_path; path; page_num; line_num; search_word } = config in
  let path =
    if quote_path then
      Filename.quote path
    else
      path
  in
  match
    parse_string ~consume:All (Parsers.cmd ~path ~page_num ~line_num ~search_word) s
  with
  | Error msg -> Error (Misc_utils.trim_angstrom_error_msg msg)
  | Ok s -> Ok s

let parse_spec (s : string) : (spec, string) result =
  let open Angstrom in
  match
    parse_string ~consume:All Parsers.spec s
  with
  | Error msg -> Error (Misc_utils.trim_angstrom_error_msg msg)
  | Ok (exts', launch_mode, cmd) -> (
      let rec aux acc exts =
        match exts with
        | [] -> Ok (List.rev acc, launch_mode, cmd)
        | ext :: rest -> (
            let ext = ext
              |> String.lowercase_ascii
              |> String_utils.remove_leading_dots
              |> Fmt.str ".%s"
            in
            let config =
              if ext = ".pdf" then (
                Config.make
                  ~path:"path"
                  ~page_num:1
                  ~search_word:"word"
                  ~launch_mode:`Detached
                  ()
              ) else (
                Config.make
                  ~path:"path"
                  ~line_num:1
                  ~launch_mode:`Terminal
                  ()
              )
            in
            match
              resolve_cmd config cmd
            with
            | Error msg -> Error msg
            | Ok _ -> aux (ext :: acc) rest
          )
      in
      aux [] exts'
    )

let xdg_open_cmd =
  "xdg-open {path}"

let pandoc_supported_format_config_and_cmd ~path =
  (Config.make ~path ~launch_mode:`Detached (),
   xdg_open_cmd)

let fallback_cmd : string =
  match Params.os_typ with
  | `Linux -> xdg_open_cmd
  | `Darwin -> "open {path}"

let compute_most_unique_word_and_residing_page_num ~doc_id found_phrase =
  let page_nums = found_phrase
    |> List.map (fun word ->
        word.Search_result.found_word_pos
        |> (fun pos -> Index.loc_of_pos ~doc_id pos)
        |> Index.Loc.line_loc
        |> Index.Line_loc.page_num
      )
    |> List.sort_uniq Int.compare
  in
  let frequency_of_word_of_page_ci : int String_map.t Int_map.t =
    List.fold_left (fun acc page_num ->
        let m = Misc_utils.frequencies_of_words_ci
            (Index.words_of_page_num ~doc_id page_num
             |> Dynarray.to_seq)
        in
        Int_map.add page_num m acc
      )
      Int_map.empty
      page_nums
  in
  found_phrase
  |> List.map (fun word ->
      let page_num =
        Index.loc_of_pos ~doc_id word.Search_result.found_word_pos
        |> Index.Loc.line_loc
        |> Index.Line_loc.page_num
      in
      let m = Int_map.find page_num frequency_of_word_of_page_ci in
      let freq =
        String_map.fold (fun word_on_page_ci freq acc_freq ->
            if
              CCString.find ~sub:word.Search_result.found_word_ci word_on_page_ci >= 0
            then (
              acc_freq + freq
            ) else (
              acc_freq
            )
          )
          m
          0
      in
      (word, page_num, freq)
    )
  |> List.fold_left (fun best x ->
      let (_x_word, _x_page_num, x_freq) = x in
      match best with
      | None -> Some x
      | Some (_best_word, _best_page_num, best_freq) -> (
          if x_freq < best_freq then
            Some x
          else
            best
        )
    )
    None
  |> Option.get
  |> (fun (word, page_num, _freq) ->
      (word.found_word, page_num))

let pdf_config_and_cmd ~path ~doc_id_and_search_result : Config.t * string =
  let config =
    let page_num, search_word =
      match doc_id_and_search_result with
      | None -> (
          (1, "")
        )
      | Some (doc_id, search_result) -> (
          let found_phrase = Search_result.found_phrase search_result in
          let (most_unique_word, most_unique_word_page_num) =
            compute_most_unique_word_and_residing_page_num ~doc_id found_phrase
          in
          let page_num = most_unique_word_page_num + 1 in
          (page_num, most_unique_word)
        )
    in
    Config.make ~path ~page_num ~search_word ~launch_mode:`Detached ()
  in
  let cmd =
    match Params.os_typ with
    | `Linux -> (
        match Xdg_utils.default_desktop_file_path `PDF with
        | None -> fallback_cmd
        | Some viewer_desktop_file_path -> (
            let flatpak_package_name =
              let s = Filename.basename viewer_desktop_file_path in
              Option.value ~default:s
                (CCString.chop_suffix ~suf:".desktop" s)
            in
            let viewer_desktop_file_path_lowercase_ascii =
              String.lowercase_ascii viewer_desktop_file_path
            in
            let contains sub =
              CCString.find ~sub viewer_desktop_file_path_lowercase_ascii >= 0
            in
            let make_command name args =
              if contains "flatpak" then
                Fmt.str "flatpak run %s %s" flatpak_package_name args
              else
                Fmt.str "%s %s" name args
            in
            match doc_id_and_search_result with
            | None -> fallback_cmd
            | Some _ -> (
                if contains "okular" then
                  make_command "okular"
                    "--page {page_num} --find {search_word} {path}"
                else if contains "evince" then
                  make_command "evince"
                    "--page-index {page_num} --find {search_word} {path}"
                else if contains "xreader" then
                  make_command "xreader"
                    "--page-index {page_num} --find {search_word} {path}"
                else if contains "atril" then
                  make_command "atril"
                    "--page-index {page_num} --find {search_word} {path}"
                else if contains "zathura" then
                  (* Check zathura before mupdf as desktop file for
                     zathura might be `org.pwmt.zathura-pdf-mupdf.desktop`
                  *)
                  make_command "zathura"
                    "--page {page_num} --find {search_word} {path}"
                else if contains "mupdf" then
                  make_command "mupdf" "{path} {page_num}"
                else
                  fallback_cmd
              )
          )
      )
    | `Darwin -> fallback_cmd
  in
  (config, cmd)

let config_and_cmd_to_open_text_file ~path ?(line_num = 1) () : Config.t * string =
  let editor = !Params.text_editor in
  let config =
    Config.make ~path ~line_num ~launch_mode:`Terminal ()
  in
  let cmd =
    match Filename.basename editor with
    | "nano" ->
      Fmt.str "%s +{line_num} {path}" editor
    | "nvim" | "vim" | "vi" ->
      Fmt.str "%s +{line_num} {path}" editor
    | "kak" ->
      Fmt.str "%s +{line_num} {path}" editor
    | "hx" ->
      Fmt.str "%s {path}:{line_num}" editor
    | "emacs" ->
      Fmt.str "%s +{line_num} {path}" editor
    | "micro" ->
      Fmt.str "%s {path}:{line_num}" editor
    | "jed" | "xjed" ->
      Fmt.str "%s {path} -g {line_num}" editor
    | _ ->
      Fmt.str "%s {path}" editor
  in
  (config, cmd)

let text_config_and_cmd ~path ~doc_id_and_search_result : Config.t * string =
  let line_num =
    match doc_id_and_search_result with
    | None -> None
    | Some (doc_id, search_result) -> (
        let first_word = List.hd @@ Search_result.found_phrase search_result in
        let first_word_loc =
          Index.loc_of_pos ~doc_id first_word.Search_result.found_word_pos
        in
        first_word_loc
        |> Index.Loc.line_loc
        |> Index.Line_loc.line_num_in_page
        |> (fun x -> x + 1)
        |> Option.some
      )
  in
  config_and_cmd_to_open_text_file
    ~path
    ?line_num
    ()

let main ~close_term ~path ~doc_id_and_search_result =
  let ext = File_utils.extension_of_file path in
  let config, cmd =
    (match File_utils.format_of_file path with
     | `PDF -> (
         pdf_config_and_cmd ~path ~doc_id_and_search_result
       )
     | `Pandoc_supported_format -> (
         pandoc_supported_format_config_and_cmd ~path
       )
     | `Text -> (
         text_config_and_cmd ~path ~doc_id_and_search_result
       )
     | `Other -> (
         (Config.make ~path ~launch_mode:`Detached (), fallback_cmd)
       )
    )
    |> (fun (config, cmd) ->
        match Hashtbl.find_opt specs ext with
        | None -> (
            (config, cmd)
          )
        | Some (launch_mode, cmd) -> (
            ({ config with launch_mode }, cmd)
          )
      )
    |> (fun (config, cmd) ->
        (config, Result.get_ok (resolve_cmd config cmd)))
  in
  match config.launch_mode with
  | `Terminal -> (
      let cmd =
        if Misc_utils.stdin_is_atty () then (
          cmd
        ) else (
          Fmt.str "</dev/tty %s" cmd
        )
      in
      close_term ();
      do_if_debug (fun oc ->
          Printf.fprintf oc "System command: %s\n" cmd
        );
      Sys.command cmd |> ignore
    )
  | `Detached -> (
      do_if_debug (fun oc ->
          Printf.fprintf oc "System command: %s\n" cmd
        );
      Proc_utils.run_in_background cmd |> ignore
    )

let find_project_root path =
  let rec aux arr =
    let cur = CCString.concat_seq ~sep:Filename.dir_sep (Dynarray.to_seq arr) in
    if Dynarray.length arr = 0 then (
      None
    ) else if Dynarray.length arr = 3
           && Dynarray.get arr 0 = "home"
    then (
      Some cur
    ) else (
      let candidates =
        try
          Some (Sys.readdir cur)
        with
        | _ -> None
      in
      match candidates with
      | None -> (
          None
        )
      | Some candidates -> (
          let root_indicator_exists =
            Array.exists (fun name ->
                List.mem name
                  [ ".git"
                  ; ".hg"
                  ; ".svn"
                  ; ".obsidian"
                  ; ".logseq"
                  ; ".tangent"
                  ]
              )
              candidates
          in
          if root_indicator_exists then (
            Some cur
          ) else (
            Dynarray.pop_last arr |> ignore;
            aux arr
          )
        )
    )
  in
  let arr = Dynarray.of_list (CCString.split ~by:Filename.dir_sep path) in
  aux arr

let open_link ~close_term ~doc link =
  let { Link.typ; link; _ } = link in
  let doc_path = Document.path doc in
  let doc_dir = Filename.dirname doc_path in
  let doc_ext = Filename.extension doc_path in
  let resolve_wiki_link link =
    let link =
      Option.value ~default:link
        (CCString.chop_prefix ~pre:"/" link)
    in
    let link_with_ext = link ^ doc_ext in
    if link.[0] = '.' then (
      Filename.concat doc_dir link_with_ext
    ) else (
      let wiki_root =
        Option.value ~default:doc_dir (find_project_root doc_dir)
      in
      let candidates = File_utils.list_files_recursive
          ~report_progress:(fun () -> ())
          ~filter:(fun _depth path ->
              let path_no_ext =
                try
                  Filename.chop_extension path
                with
                | _ -> path
              in
              CCString.suffix ~suf:link path_no_ext
            )
          wiki_root
      in
      match
        String_set.find_first_opt (fun path ->
            CCString.suffix ~suf:link_with_ext path
          ) candidates
      with
      | Some x -> x
      | None -> (
          match String_set.min_elt_opt candidates with
          | Some x -> x
          | None -> Filename.concat wiki_root link_with_ext
        )
    )
  in
  if String.length link > 0 then (
    match typ with
    | `Markdown -> (
        let path =
          if Filename.is_relative link then (
            Filename.concat doc_dir link
          ) else (
            let project_root =
              Option.value ~default:doc_dir (find_project_root doc_dir)
            in
            Filename.concat project_root link
          )
        in
        main ~close_term ~path ~doc_id_and_search_result:None
      )
    | `Wiki -> (
        let path = resolve_wiki_link link in
        main ~close_term ~path ~doc_id_and_search_result:None
      )
    | `URL -> (
        let config = Config.make ~path:link ~launch_mode:`Detached () in
        resolve_cmd config fallback_cmd
        |> Result.get_ok
        |> Proc_utils.run_in_background
        |> ignore
      )
  )
