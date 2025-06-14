open Docfd_lib
open Debug_utils

type launch_mode = [ `Terminal | `Detached ]

type spec = string * launch_mode * string

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
          | Some s -> return s);
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
    take_while1 (function ':' -> false | _ -> true)
    >>= fun ext ->
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
    return (ext, launch_mode, cmd)
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
  | Ok (ext, launch_mode, cmd) -> (
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
      | Ok _ -> Ok (ext, launch_mode, cmd)
    )

let xdg_open_cmd =
  "xdg-open {path}"

let pandoc_supported_format_config_and_cmd ~path =
  (Config.make ~path ~launch_mode:`Detached (),
   xdg_open_cmd)

let compute_most_unique_word_and_residing_page_num ~doc_hash found_phrase =
  let page_nums = found_phrase
                  |> List.map (fun word ->
                      word.Search_result.found_word_pos
                      |> (fun pos -> Index.loc_of_pos ~doc_hash pos)
                      |> Index.Loc.line_loc
                      |> Index.Line_loc.page_num
                    )
                  |> List.sort_uniq Int.compare
  in
  let frequency_of_word_of_page_ci : int String_map.t Int_map.t =
    List.fold_left (fun acc page_num ->
        let m = Misc_utils.frequencies_of_words_ci
            (Index.words_of_page_num ~doc_hash page_num
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
        Index.loc_of_pos ~doc_hash word.Search_result.found_word_pos
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

let pdf_config_and_cmd ~doc_hash ~path ~search_result : Config.t * string =
  let fallback : Config.t * string =
    let config = Config.make ~path ~launch_mode:`Detached () in
    match Params.os_typ with
    | `Linux -> (config, xdg_open_cmd)
    | `Darwin -> (config, "open {path}")
  in
  match search_result with
  | None -> fallback
  | Some search_result -> (
      let found_phrase = Search_result.found_phrase search_result in
      match Params.os_typ with
      | `Linux -> (
          match Xdg_utils.default_desktop_file_path `PDF with
          | None -> fallback
          | Some viewer_desktop_file_path -> (
              let (most_unique_word, most_unique_word_page_num) =
                compute_most_unique_word_and_residing_page_num ~doc_hash found_phrase
              in
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
              let page_num = most_unique_word_page_num + 1 in
              let config =
                Config.make ~path ~page_num ~search_word:most_unique_word ~launch_mode:`Detached ()
              in
              let make_command name args =
                if contains "flatpak" then
                  Fmt.str "flatpak run %s %s" flatpak_package_name args
                else
                  Fmt.str "%s %s" name args
              in
              if contains "okular" then
                (config,
                 make_command "okular"
                   "--page {page_num} --find {search_word} {path}")
              else if contains "evince" then
                (config,
                 make_command "evince"
                   "--page-index {page_num} --find {search_word} {path}")
              else if contains "xreader" then
                (config,
                 make_command "xreader"
                   "--page-index {page_num} --find {search_word} {path}")
              else if contains "atril" then
                (config,
                 make_command "atril"
                   "--page-index {page_num} --find {search_word} {path}")
              else if contains "mupdf" then
                (config, make_command "mupdf" "{path} {page_num}")
              else
                fallback
            )
        )
      | `Darwin -> fallback
    )

let config_and_cmd_to_open_text_file ~path ?(line_num = 1) () : Config.t * string =
  let editor = !Params.text_editor in
  let fallback =
    (Config.make ~path ~launch_mode:`Terminal (), Fmt.str "%s {path}" editor)
  in
  let config =
    Config.make ~path ~line_num ~launch_mode:`Terminal ()
  in
  match Filename.basename editor with
  | "nano" ->
    (config,
     Fmt.str "%s +{line_num} {path}" editor)
  | "nvim" | "vim" | "vi" ->
    (config,
     Fmt.str "%s +{line_num} {path}" editor)
  | "kak" ->
    (config,
     Fmt.str "%s +{line_num} {path}" editor)
  | "hx" ->
    (config,
     Fmt.str "%s {path}:{line_num}" editor)
  | "emacs" ->
    (config,
     Fmt.str "%s +{line_num} {path}" editor)
  | "micro" ->
    (config,
     Fmt.str "%s {path}:{line_num}" editor)
  | "jed" | "xjed" ->
    (config,
     Fmt.str "%s {path} -g {line_num}" editor)
  | _ ->
    fallback

let text_config_and_cmd ~doc_hash ~path ~search_result : Config.t * string =
  let line_num =
    match search_result with
    | None -> None
    | Some search_result -> (
        let first_word = List.hd @@ Search_result.found_phrase search_result in
        let first_word_loc =
          Index.loc_of_pos ~doc_hash first_word.Search_result.found_word_pos
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

let main ~close_term ~doc_hash ~document_src_is_stdin ~path ~search_result =
  let ext = File_utils.extension_of_file path in
  let config, cmd =
    (match File_utils.format_of_file path with
     | `PDF -> (
         pdf_config_and_cmd ~doc_hash ~path ~search_result
       )
     | `Pandoc_supported_format -> (
         pandoc_supported_format_config_and_cmd ~path
       )
     | `Text -> (
         text_config_and_cmd ~doc_hash ~path ~search_result
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
        if document_src_is_stdin then (
          Fmt.str "</dev/tty %s" cmd
        ) else (
          cmd
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
