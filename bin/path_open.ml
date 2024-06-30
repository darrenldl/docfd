open Docfd_lib

let xdg_open_cmd ~path =
  Fmt.str "xdg-open %s" path

let pandoc_supported_format ~path =
  let path = Filename.quote path in
  let cmd = xdg_open_cmd ~path in
  Proc_utils.run_in_background cmd |> ignore

let compute_most_unique_word_and_residing_page_num index found_phrase =
  let page_nums = found_phrase
                  |> List.map (fun word ->
                      word.Search_result.found_word_pos
                      |> (fun pos -> Index.loc_of_pos pos index)
                      |> Index.Loc.line_loc
                      |> Index.Line_loc.page_num
                    )
                  |> List.sort_uniq Int.compare
  in
  let frequency_of_word_of_page_ci : int String_map.t Int_map.t =
    List.fold_left (fun acc page_num ->
        let m = Misc_utils.frequencies_of_words_ci
            (Index.words_of_page_num page_num index)
        in
        Int_map.add page_num m acc
      )
      Int_map.empty
      page_nums
  in
  found_phrase
  |> List.map (fun word ->
      let page_num =
        Index.loc_of_pos word.Search_result.found_word_pos index
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

let pdf index ~path ~search_result =
  let path = Filename.quote path in
  let fallback =
    match Params.os_typ with
    | `Linux -> xdg_open_cmd ~path
    | `Darwin -> Fmt.str "open %s" path
    | `Windows -> Fmt.str {|start "" %s|} path
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
                  compute_most_unique_word_and_residing_page_num index found_phrase
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
                let make_command name args =
                  if contains "flatpak" then
                    Fmt.str "flatpak run %s %s" flatpak_package_name args
                  else
                    Fmt.str "%s %s" name args
                in
                let page_num = most_unique_word_page_num + 1 in
                if contains "okular" then
                  make_command "okular"
                    (Fmt.str "--page %d --find %s %s" page_num most_unique_word path)
                else if contains "evince" then
                  make_command "evince"
                    (Fmt.str "--page-index %d --find %s %s" page_num most_unique_word path)
                else if contains "xreader" then
                  make_command "xreader"
                    (Fmt.str "--page-index %d --find %s %s" page_num most_unique_word path)
                else if contains "atril" then
                  make_command "atril"
                    (Fmt.str "--page-index %d --find %s %s" page_num most_unique_word path)
                else if contains "mupdf" then
                  make_command "mupdf" (Fmt.str "%s %d" path page_num)
                else
                  fallback
              )
          )
        | `Darwin -> fallback
        | `Windows -> fallback
      )
  in
  Proc_utils.run_in_background cmd |> ignore

let text index document_src ~editor ~path ~search_result =
  let path = Filename.quote path in
  let fallback = Fmt.str "%s %s" editor path in
  let cmd =
    match search_result with
    | None -> fallback
    | Some search_result -> (
        let first_word = List.hd @@ Search_result.found_phrase search_result in
        let first_word_loc = Index.loc_of_pos first_word.Search_result.found_word_pos index in
        let line_num = first_word_loc
                       |> Index.Loc.line_loc
                       |> Index.Line_loc.line_num_in_page
                       |> (fun x -> x + 1)
        in
        match Filename.basename editor with
        | "nano" ->
          Fmt.str "%s +%d %s" editor line_num path
        | "nvim" | "vim" | "vi" ->
          Fmt.str "%s +%d %s" editor line_num path
        | "kak" ->
          Fmt.str "%s +%d %s" editor line_num path
        | "hx" ->
          Fmt.str "%s %s:%d" editor path line_num
        | "emacs" ->
          Fmt.str "%s +%d %s" editor line_num path
        | "micro" ->
          Fmt.str "%s %s:%d" editor path line_num
        | "jed" | "xjed" ->
          Fmt.str "%s %s -g %d" editor path line_num
        | _ ->
          fallback
      )
  in
  let cmd =
    match document_src with
    | Document_src.Stdin _ -> Fmt.str "</dev/tty %s" cmd
    | _ -> cmd
  in
  Sys.command cmd |> ignore
