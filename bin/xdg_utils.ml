let all_desktop_files () : string Seq.t =
  match Sys.getenv_opt "XDG_DATA_DIRS" with
  | None -> Seq.empty
  | Some s -> (
      String.split_on_char ':' s
      |> List.to_seq
      |> Seq.flat_map (fun dir ->
          let dir = Filename.concat dir "applications" in
          try
            Sys.readdir dir
            |> Array.to_seq
            |> Seq.map (Filename.concat dir)
          with
          | _ -> Seq.empty
        )
    )

let path_of_desktop_file file =
  let rec aux paths =
    match paths () with
    | Seq.Nil -> None
    | Seq.Cons (path, rest) -> (
        if String.equal file (Filename.basename path) then (
          Some path
        ) else (
          aux rest
        )
      )
  in
  aux (all_desktop_files ())

let default_desktop_file_path (typ : [ `PDF | `ODT | `DOCX ]) =
  let mime_typ =
    match typ with
    | `PDF -> "application/pdf"
    | `ODT -> "application/vnd.oasis.opendocument.text"
    | `DOCX -> "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
  in
  let (stdout, _, ret) = CCUnix.call "xdg-mime query default %s" mime_typ in
  if ret = 0 then (
    path_of_desktop_file (CCString.trim stdout)
  ) else (
    None
  )
