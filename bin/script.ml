let run pool ~init_store ~path
  : (Document_store_snapshot.t Dynarray.t, string) result =
  let exception Error_with_msg of string in
  let snapshots = Dynarray.create () in
  try
    let lines =
      try
        CCIO.with_in path CCIO.read_lines_l
      with
      | Sys_error _ -> (
          raise (Error_with_msg (Fmt.str "failed to read script %s" (Filename.quote path)))
        )
    in
    Dynarray.add_last
      snapshots
      (Document_store_snapshot.make
         ~last_command:None
         init_store);
    lines
    |> CCList.foldi (fun store i line ->
        let line_num_in_error_msg = i + 1 in
        if String_utils.line_is_blank_or_comment line then (
          store
        ) else (
          match Command.of_string line with
          | None -> (
              raise (Error_with_msg
                       (Fmt.str "failed to parse command on line %d: %s"
                          line_num_in_error_msg line))
            )
          | Some command -> (
              match Document_store.run_command pool command store with
              | None -> (
                  raise (Error_with_msg
                           (Fmt.str "failed to run command on line %d: %s"
                              line_num_in_error_msg line))
                )
              | Some store -> (
                  let snapshot =
                    Document_store_snapshot.make
                      ~last_command:(Some command)
                      store
                  in
                  Dynarray.add_last snapshots snapshot;
                  store
                )
            )
        )
      ) init_store
    |> ignore;
    Ok snapshots
  with
  | Error_with_msg msg -> Error msg
