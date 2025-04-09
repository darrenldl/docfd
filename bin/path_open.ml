open Docfd_lib
open Debug_utils

module Parsers = struct
  open Angstrom
  open Parser_components

  let inner ~path ~page_num ~line_num ~search_word : string t =
    choice [
      string "path" *> commit *> return path;
      string "page_num" *> commit *> return (Fmt.str "%d" page_num);
      string "line_num" *> commit *> return (Fmt.str "%d" line_num);
      string "search_word" *> commit *> return search_word;
    ]

  let cmd ~path ~page_num ~line_num ~search_word : string t =
    let single =
      choice [
        (string "{{" >>| fun _ -> Fmt.str "{");
        (char '{' *> inner ~path ~page_num ~line_num ~search_word <* char '}');
        (take_while1 (function '{' -> false | _ -> true));
      ]
    in
    many single
    >>| fun l -> String.concat "" l

  let spec : (string * [ `Foreground | `Background ] * string) t =
    take_while1 (function ':' -> false | _ -> true)
    >>= fun ext ->
    char ':' *>
    choice [
      string "fg" *> return `Foreground;
      string "foreground" *> return `Foreground;
      string "bg" *> return `Background;
      string "background" *> return `Background;
    ] >>= fun fb ->
    char '=' *> any_string
    >>= fun cmd ->
    return (ext, fb, cmd)
end

let resolve_cmd ~quote_path ~path ~page_num ~line_num ~search_word (s : string) : string option =
  let open Angstrom in
  let path =
    if quote_path then
      Filename.quote path
    else
      path
  in
  match
    parse_string ~consume:All (Parsers.cmd ~path ~page_num ~line_num ~search_word) s
  with
  | Error _ -> None
  | Ok s -> Some s

let parse_spec (s : string) : (string * [ `Foreground | `Background ] * string) option =
  let open Angstrom in
  match
    parse_string ~consume:All Parsers.spec s
  with
  | Error _ -> None
  | Ok (ext, fb, cmd) -> (
      match
        resolve_cmd ~quote_path:true ~path:"path" ~page_num:1 ~line_num:1 ~search_word:"word" cmd
      with
      | None -> None
      | Some _ -> Some (ext, fb, cmd)
    )

let xdg_open_cmd ~path =
  Fmt.str "xdg-open %s" path

let pandoc_supported_format ~path =
  let path = Filename.quote path in
  let cmd = xdg_open_cmd ~path in
  Proc_utils.run_in_background cmd |> ignore

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

let pdf ~doc_hash ~path ~search_result =
  let path = Filename.quote path in
  let fallback =
    match Params.os_typ with
    | `Linux -> xdg_open_cmd ~path
    | `Darwin -> Fmt.str "open %s" path
  in
  let cmd =
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
                let make_command name args =
                  resolve_cmd
                    ~quote_path:false
                    ~path
                    ~page_num
                    ~line_num:0
                    ~search_word:most_unique_word
                    (if contains "flatpak" then
                       Fmt.str "flatpak run %s %s" flatpak_package_name args
                     else
                       Fmt.str "%s %s" name args)
                  |> Option.get
                in
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
                else if contains "mupdf" then
                  make_command "mupdf" "{path} {page_num}"
                else
                  fallback
              )
          )
        | `Darwin -> fallback
      )
  in
  do_if_debug (fun oc ->
      Printf.fprintf oc "System command: %s\n" cmd
    );
  Proc_utils.run_in_background cmd |> ignore

let gen_command_to_open_text_file_to_line_num ~editor ~quote_path ~path ~line_num =
  let path =
    if quote_path then
      Filename.quote path
    else
      path
  in
  let fallback = Fmt.str "%s {path}" editor in
  resolve_cmd
    ~quote_path:false
    ~path
    ~page_num:0
    ~line_num
    ~search_word:""
    (match Filename.basename editor with
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
       fallback
    )
  |> Option.get

let text ~doc_hash document_src ~editor ~path ~search_result =
  let path = Filename.quote path in
  let fallback = Fmt.str "%s %s" editor path in
  let cmd =
    match search_result with
    | None -> fallback
    | Some search_result -> (
        let first_word = List.hd @@ Search_result.found_phrase search_result in
        let first_word_loc =
          Index.loc_of_pos ~doc_hash first_word.Search_result.found_word_pos
        in
        let line_num = first_word_loc
                       |> Index.Loc.line_loc
                       |> Index.Line_loc.line_num_in_page
                       |> (fun x -> x + 1)
        in
        gen_command_to_open_text_file_to_line_num
          ~editor ~quote_path:false ~path ~line_num
      )
  in
  let cmd =
    match document_src with
    | Document_src.Stdin _ -> Fmt.str "</dev/tty %s" cmd
    | _ -> cmd
  in
  do_if_debug (fun oc ->
      Printf.fprintf oc "System command: %s\n" cmd
    );
  Sys.command cmd |> ignore
