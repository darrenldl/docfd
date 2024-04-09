open Misc_utils

let command_exists (cmd : string) : bool =
  Sys.command (Fmt.str "command -v %s 2>/dev/null 1>/dev/null" (Filename.quote cmd)) = 0

let run_in_background (cmd : string) =
  Sys.command (Fmt.str "%s 2>/dev/null 1>/dev/null &" cmd)

let run_return_stdout ~proc_mgr (cmd : string list) : string list option =
  Eio.Switch.run (fun sw ->
      let _, stderr = Eio.Process.pipe ~sw proc_mgr in
      let output =
        try
          let lines =
            Eio.Process.parse_out proc_mgr
              Eio.Buf_read.(map List.of_seq lines)
              ~stderr cmd
          in
          Some lines
        with
        | _ -> None
      in
      Eio.Flow.close stderr;
      output
    )

let pipe_to_fzf_for_selection (lines : string Seq.t) : string list =
  if not (command_exists "fzf") then (
    exit_with_error_msg
      (Fmt.str "command fzf not found")
  );
  let stdin_for_fzf, write_to_fzf = Unix.pipe ~cloexec:true () in
  let read_from_fzf, stdout_for_fzf = Unix.pipe ~cloexec:true () in
  let write_to_fzf_oc = Unix.out_channel_of_descr write_to_fzf in
  let read_from_fzf_ic = Unix.in_channel_of_descr read_from_fzf in
  Seq.iter (fun file ->
      output_string write_to_fzf_oc file;
      output_string write_to_fzf_oc "\n";
    ) lines;
  Out_channel.close write_to_fzf_oc;
  let pid =
    Unix.create_process "fzf" [| "fzf"; "--multi" |]
      stdin_for_fzf stdout_for_fzf Unix.stderr
  in
  let _, process_status = Unix.waitpid [] pid in
  Unix.close stdin_for_fzf;
  Unix.close stdout_for_fzf;
  let selection = CCIO.read_lines_l (Unix.in_channel_of_descr read_from_fzf) in
  In_channel.close read_from_fzf_ic;
  (match process_status with
   | WEXITED n -> (
       if n <> 0 then (
         exit n
       )
     )
   | WSIGNALED _ | WSTOPPED _ -> (
       exit 1
     )
  );
  selection
