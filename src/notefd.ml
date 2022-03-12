open Cmdliner

let run (dir : string) =
  let files =
    FileUtil.(find Is_file dir)
      (fun acc x ->
         let words = String.split_on_char '.' (String.lowercase_ascii x) in
         if List.mem "note" words then
           x :: acc
         else
           acc
      ) []
  in
  List.iter (fun x ->
      Printf.printf "file: %s\n" x
    ) files

let dir_arg = Arg.(value & pos 0 dir "." & info [])

let cmd =
  let doc = "Find notes" in
  let version =
    match Build_info.V1.version () with
    | None -> "N/A"
    | Some version -> Build_info.V1.Version.to_string version
  in
  Cmd.v (Cmd.info "notefd" ~version ~doc)
    (Term.(const run $ dir_arg))

let () = exit (Cmd.eval cmd)
