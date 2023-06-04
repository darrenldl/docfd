let command_exists (cmd : string) : bool =
  Sys.command (Fmt.str "%s 2>/dev/null 1>/dev/null" cmd) = 0

let run_return_stdout (cmd : string) : string array option =
  try
  let stdout, stdin, stderr = Unix.open_process_full cmd in
  let output =
    CCIO.read_lines_seq stdout
  |> Array.of_seq
  in
  let status = Unix.close_process_full (stdout, stdin, stderr) in
  match status with
  | Unix.WEXITED 0 -> Some output
  | _ -> None
  with
  | _ -> None
