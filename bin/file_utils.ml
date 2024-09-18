open Misc_utils
open Debug_utils

let extension_of_file (s : string) =
  Filename.extension s
  |> String.lowercase_ascii

type file_format = [ `PDF | `Pandoc_supported_format | `Text ] [@@deriving ord]

module File_format_set = CCSet.Make (struct
    type t = file_format

    let compare = compare_file_format
  end)

let format_of_file (s : string) : file_format =
  let ext = extension_of_file s in
  if ext = ".pdf" then (
    `PDF
  ) else if List.mem ext Params.pandoc_supported_exts then (
    `Pandoc_supported_format
  ) else (
    `Text
  )

type typ = [
  | `File
  | `Dir
]

type is_link = [
  | `Is_link
  | `Not_link
]

let typ_of_path (path : string) : (typ * is_link) option =
  try
    let stat = Unix.lstat path in
    match stat.st_kind with
    | S_REG -> Some (`File, `Not_link)
    | S_DIR -> Some (`Dir, `Not_link)
    | S_LNK -> (
        let stat = Unix.stat path in
        match stat.st_kind with
        | S_REG -> Some (`File, `Is_link)
        | S_DIR -> Some (`Dir, `Is_link)
        | _ -> None
      )
    | _ -> None
  with
  | _ -> None

let cwd_with_trailing_sep () = Sys.getcwd () ^ Filename.dir_sep

let remove_cwd_from_path (s : string) =
  let pre = cwd_with_trailing_sep () in
  match CCString.chop_prefix ~pre s with
  | None -> s
  | Some s -> s

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

let next_choices path : string Seq.t =
  try
    Sys.readdir path
    |> Array.to_seq
  with
  | _ -> Seq.empty

let list_files_recursive
    ~(filter : int -> string -> bool)
    (path : string)
  : String_set.t =
  let acc = ref String_set.empty in
  let add x =
    acc := String_set.add x !acc
  in
  let rec aux depth path =
    if depth <= !Params.max_file_tree_scan_depth then (
      match typ_of_path path with
      | Some (`Dir, _) -> (
          next_choices path
          |> Seq.iter (fun f ->
              aux (depth + 1) (Filename.concat path f)
            )
        )
      | Some (`File, _) -> (
          if filter depth path then (
            add path
          )
        )
      | _ -> ()
    )
  in
  aux 0 (normalize_path_to_absolute path);
  !acc

let list_files_recursive_filter_by_globs
    (globs : string Seq.t)
  : String_set.t =
  let acc = ref String_set.empty in
  let add x =
    acc := String_set.add x !acc
  in
  let make_glob ~case_sensitive s =
    match Glob.make ~case_sensitive s with
    | None -> (
        failwith (Fmt.str "expected subpath of a valid glob pattern to also be valid: \"%s\"" s)
      )
    | Some x -> x
  in
  let rec aux ~case_sensitive (path_parts : string list) (glob_parts : string list) =
    let path = path_of_parts path_parts in
    match typ_of_path path, glob_parts with
    | Some (`File, _), [] -> add path
    | Some (`File, _), _ -> ()
    | Some (`Dir, _), [] -> ()
    | Some (`Dir, _), x :: xs -> (
        match x with
        | "" | "." -> aux ~case_sensitive path_parts xs
        | ".." -> (
            let path_parts =
              match path_parts with
              | [] -> []
              | _ :: xs -> xs
            in
            aux ~case_sensitive path_parts xs
          )
        | "**" -> (
            let re_string = String.concat Filename.dir_sep (path :: glob_parts) in
            do_if_debug (fun oc ->
                Printf.fprintf oc "Compiling glob regex using pattern: %s\n" re_string
              );
            let glob = make_glob ~case_sensitive re_string in
            path
            |> list_files_recursive ~filter:(fun _depth path ->
                Glob.match_ glob path
              )
            |> String_set.iter (fun path ->
                do_if_debug (fun oc ->
                    Printf.fprintf oc "Glob regex %s matches path %s\n" re_string path
                  );
                add path
              )
          )
        | _ -> (
            let glob = make_glob ~case_sensitive x in
            next_choices path
            |> Seq.iter (fun f ->
                if Glob.match_ glob f then (
                  aux ~case_sensitive (f :: path_parts) xs
                )
              )
          )
      )
    | None, _ -> ()
    | exception _ -> ()
  in
  Seq.iter (fun glob ->
      let case_sensitive =
        Glob.make glob
        |> Option.get
        |> Glob.case_sensitive
      in
      let glob_parts = CCString.split ~by:Filename.dir_sep glob in
      match glob_parts with
      | "" :: l -> (
          (* Absolute path on Unix-like systems *)
          aux ~case_sensitive [ "" ] l
        )
      | _ -> (
          aux ~case_sensitive (cwd_path_parts ()) glob_parts
        )
    ) globs;
  !acc

let list_files_recursive_filter_by_exts
    ~(exts : string list)
    (paths : string Seq.t)
  : String_set.t =
  let filter depth path =
    let ext = extension_of_file path in
    depth = 0 || List.mem ext exts
  in
  paths
  |> Seq.map normalize_path_to_absolute
  |> Seq.map (list_files_recursive ~filter)
  |> Seq.fold_left String_set.union String_set.empty

let mkdir_recursive (dir : string) : unit =
  let rec aux first acc parts =
    match parts with
    | [] -> ()
    | "" :: xs -> (
        if first then
          aux false Filename.dir_sep xs
        else
          aux false "" xs
      )
    | x :: xs -> (
        let acc = Filename.concat acc x in
        match Sys.is_directory acc with
        | true -> aux false acc xs
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
            aux false acc xs
          )
      )
  in
  aux true "" (CCString.split ~by:Filename.dir_sep dir)

let file_size (path : string) : int option =
  try
    let st = Unix.stat path in
    Some st.st_size
  with
  | _ -> None
