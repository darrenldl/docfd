open Misc_utils

let read_in_channel_to_tmp_file (ic : in_channel) : (string, string) result =
  let file = Filename.temp_file "docfd-" ".txt" in
  try
    CCIO.with_out file (fun oc ->
        CCIO.copy_into ic oc
      );
    Ok file
  with
  | _ -> (
      Error (Fmt.str "failed to write stdin to %s" (Filename.quote file))
    )

let list_files_recursive_all (path : string) : string list =
  let l = ref [] in
  let add x =
    l := x :: !l
  in
  let rec aux path =
    match Sys.is_directory path with
    | is_dir -> (
        if is_dir then (
          let next_choices =
            try
              Sys.readdir path
            with
            | _ -> [||]
          in
          Array.iter (fun f ->
              aux (Filename.concat path f)
            )
            next_choices
        ) else (
          add path
        )
      )
    | exception _ -> ()
  in
  aux path;
  List.sort_uniq String.compare !l

let list_files_recursive_filter_by_glob
    (globs : (string * Re.re) list)
  : string list =
  let l = ref [] in
  let add x =
    l := x :: !l
  in
  let rec aux path (glob_parts : string list) full_path_re =
    match glob_parts with
    | [] -> add path
    | x :: xs -> (
        match x with
        | "" -> aux cwd xs path
        | "**" -> (
            list_files_recursive_all path
            |> List.filter (fun path ->
                Re.execp full_path_re path
              )
          )
        | _ -> -> (
          let re = Misc_utils.compile_glob_re x in
          let next_choices =
            try
              Sys.readdir path
            with
            | _ -> [||]
          in
          Array.iter (fun f ->
              if Re.execp re f then (
                aux (Filename.concat path f) xs full_path_re
              )
            )
            next_choices;
        )
      )
  in
  List.iter (fun (glob, full_path_re) ->
      let glob_parts = CCString.split ~by:Filename.dir_sep glob in
      match glob_parts with
      | "" :: rest -> (
          aux "/" rest full_path_re
        )
      | _ -> (
          aux (Sys.getcwd ()) glob_parts full_path_re
        )
    ) globs

let list_files_recursive_filter_by_exts (paths : string list) : string list =
  let l = ref [] in
  let add x =
    l := x :: !l
  in
  let rec aux depth path =
    if depth <= !Params.max_file_tree_depth then (
      match Sys.is_directory path with
      | is_dir -> (
          if is_dir then (
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
            let ext = extension_of_file path in
            (* We skip file extension checks for top-level user specified files. *)
            if depth = 0 || List.mem ext !Params.recognized_exts then (
              add path
            )
          )
        )
      | exception _ -> ()
    ) else ()
  in
  List.iter (fun x -> aux 0 x) paths;
  List.sort_uniq String.compare !l

let mkdir_recursive (dir : string) : unit =
  let rec aux acc parts =
    match parts with
    | [] -> ()
    | "" :: xs -> (
        aux Filename.dir_sep xs
      )
    | x :: xs -> (
        let acc = Filename.concat acc x in
        match Sys.is_directory acc with
        | true -> aux acc xs
        | false -> (
            exit_with_error_msg
              (Fmt.str "%s is not a directory" (Filename.quote acc))
          )
        | exception (Sys_error _) -> (
            Debug_utils.do_if_debug (fun oc ->
                Printf.fprintf oc "Creating directory: %s\n" (Filename.quote acc)
              );
            (try
               Sys.mkdir acc 0o755
             with
             | _ -> (
                 exit_with_error_msg
                   (Fmt.str "failed to create directory: %s" (Filename.quote acc))
               )
            );
            aux acc xs
          )
      )
  in
  aux "" (CCString.split ~by:Filename.dir_sep dir)
