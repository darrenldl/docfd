open Misc_utils
open Debug_utils

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

let list_files_recursive_all (path : string) : String_set.t =
  let acc = ref String_set.empty in
  let add x =
    acc := String_set.add x !acc
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
  !acc

let list_files_recursive_filter_by_globs
    (globs : string list)
  : String_set.t =
  let acc = ref String_set.empty in
  let add x =
    acc := String_set.add x !acc
  in
  let path_of_parts parts =
    List.rev parts
    |> String.concat Filename.dir_sep
    |> (fun s -> Printf.sprintf "/%s" s)
  in
  let compile_glob_re s =
    match Misc_utils.compile_glob_re s with
    | None -> (
        failwith (Fmt.str "expected subpath of a valid glob pattern to also be valid: \"%s\"" s)
      )
    | Some x -> x
  in
  let rec aux (path_parts : string list) (glob_parts : string list) =
    match glob_parts with
    | [] -> (
        let path = path_of_parts path_parts in
        match Sys.is_directory path with
        | is_dir -> (
            if not is_dir then (
              add path
            )
          )
        | exception _ -> ()
      )
    | x :: xs -> (
        match x with
        | "" | "." -> aux path_parts xs
        | ".." -> (
            let path_parts =
              match path_parts with
              | [] -> []
              | _ :: xs -> xs
            in
            aux path_parts xs
          )
        | "**" -> (
            let path = path_of_parts path_parts in
            let re_string = String.concat Filename.dir_sep (path :: glob_parts) in
            do_if_debug (fun oc ->
                Printf.fprintf oc "Compiling glob regex using pattern: %s\n" re_string
              );
            let re = compile_glob_re re_string in
            list_files_recursive_all path
            |> String_set.iter (fun path ->
                if Re.execp re path then (
                  do_if_debug (fun oc ->
                      Printf.fprintf oc "Glob regex %s matches path %s\n" re_string path
                    );
                  add path
                )
              )
          )
        | _ -> (
            let re = compile_glob_re x in
            let path = path_of_parts path_parts in
            let next_choices =
              try
                Sys.readdir path
              with
              | _ -> [||]
            in
            Array.iter (fun f ->
                if Re.execp re f then (
                  aux (f :: path_parts) xs
                )
              )
              next_choices;
          )
      )
  in
  List.iter (fun glob ->
      let glob_parts = CCString.split ~by:Filename.dir_sep glob in
      match glob_parts with
      | "" :: rest -> (
          aux [] rest
        )
      | _ -> (
          let path_parts =
            Sys.getcwd ()
            |> CCString.split ~by:Filename.dir_sep
            |> (fun l -> match l with
                | "" :: l -> l
                | _ -> failwith "unexpected case")
            |> List.rev
          in
          aux path_parts glob_parts
        )
    ) globs;
  !acc

let list_files_recursive_filter_by_exts
    ~check_top_level_files
    ~(exts : string list)
    (paths : string list)
  : String_set.t =
  let acc = ref String_set.empty in
  let add x =
    acc := String_set.add x !acc
  in
  let rec aux depth path =
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
          if (not check_top_level_files && depth = 0)
          || List.mem ext exts
          then (
            add path
          )
        )
      )
    | exception _ -> ()
  in
  List.iter (fun x -> aux 0 x) paths;
  !acc

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
            do_if_debug (fun oc ->
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
