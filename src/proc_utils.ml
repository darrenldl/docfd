let command_exists (cmd : string) : bool =
  Sys.command (Fmt.str "command -v %s 2>/dev/null 1>/dev/null" cmd) = 0

let run_return_stdout ~sw ~proc_mgr (cmd : string) : string array option =
  let stdout_read, stdout = Eio.Process.pipe ~sw proc_mgr in
  let p = Eio.Process.spawn ~sw proc_mgr ~stdout ~executable:"sh" [ cmd ] in
  Eio.Buf_read.(parse Int.max_int lines stdout_read
  match Eio.Process.await p with
  | `Exited 0 ->
    let output =
      CCIO.read_lines_seq ic
      |> Array.of_seq
    in
    close_in ic;
    (* Array.iter (fun l ->
       print_endline l
       ) output; *)
    let status = Unix.close_process_in ic in
    match status with
    | Unix.WEXITED n -> (
        Printf.printf "exited n: %d\n" n;
        flush stdout;
        Some output
      )
    | WSIGNALED n -> (
        Printf.printf "signaled n: %d\n" n;
        flush stdout;
        None
      )
    | WSTOPPED n -> (
        Printf.printf "stopped n: %d\n" n;
        flush stdout;
        None
      )
  with
  | End_of_file -> Printf.printf "test\n"; flush stdout; None
