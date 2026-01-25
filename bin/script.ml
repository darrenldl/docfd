let run pool ~init_state ~path
  : (Session.Snapshot.t Dynarray.t, string) result =
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
      (Session.Snapshot.make
         ~last_command:None
         init_state);
    lines
    |> CCList.foldi (fun state i line ->
        let line_num_in_error_msg = i + 1 in
        if String_utils.line_is_blank_or_system_comment line then (
          state
        ) else (
          match Command.of_string line with
          | None -> (
              raise (Error_with_msg
                       (Fmt.str "failed to parse command on line %d: %s"
                          line_num_in_error_msg line))
            )
          | Some command -> (
              match Session.run_command pool command state with
              | None -> (
                  raise (Error_with_msg
                           (Fmt.str "failed to run command on line %d: %s"
                              line_num_in_error_msg line))
                )
              | Some (command, state) -> (
                  let snapshot =
                    Session.Snapshot.make
                      ~last_command:(Some command)
                      state
                  in
                  Dynarray.add_last snapshots snapshot;
                  state
                )
            )
        )
      ) init_state
    |> ignore;
    Ok snapshots
  with
  | Error_with_msg msg -> Error msg
