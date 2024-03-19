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

let list_files_recursive (dirs : string list) : string list =
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
  List.iter (fun x -> aux 0 x) dirs;
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
