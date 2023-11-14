let path_of_desktop_file file =
  let rec aux dirs =
    match dirs with
    | [] -> None
    | dir :: rest -> (
        let dir = Filename.concat dir "applications" in
        let in_dir =
          try
            Sys.readdir dir
            |> Array.to_list
            |> List.mem file
          with
          | _ -> false
        in
        if in_dir then (
          Some (Filename.concat dir file)
        ) else (
          aux rest
        )
      )
  in
  match Sys.getenv_opt "XDG_DATA_DIRS" with
  | None -> None
  | Some s -> (
      let l = String.split_on_char ':' s in
      aux l
    )

let default_pdf_viewer_desktop_file_path () =
  let (stdout, _, ret) = CCUnix.call "xdg-mime query default application/pdf" in
  if ret = 0 then (
    path_of_desktop_file (CCString.trim stdout)
  ) else (
    None
  )
