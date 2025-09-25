open Misc_utils

let command_exists (cmd : string) : bool =
  Sys.command (Fmt.str "command -v %s 2>/dev/null 1>/dev/null" (Filename.quote cmd)) = 0

let run_in_background (cmd : string) =
  Sys.command (Fmt.str "%s 2>/dev/null 1>/dev/null &" cmd)

let run_return_stdout
    ~proc_mgr
    ~fs
    ~(split_mode : [ `On_line_split | `On_form_feed ])
    (cmd : string list)
  : string list option =
  let form_feed = Char.chr 0x0C in
  Eio.Path.(with_open_out
              ~create:`Never
              (fs / "/dev/null"))
    (fun stderr ->
       let output =
         try
           let lines =
             Eio.Process.parse_out proc_mgr
               (match split_mode with
                | `On_line_split -> Eio.Buf_read.(map List.of_seq lines)
                | `On_form_feed -> (
                    let p =
                      let open Eio.Buf_read in
                      let open Syntax in
                      let* c = peek_char in
                      (match c with
                       | None -> return ()
                       | Some c -> (
                           if c = form_feed then (
                             skip 1
                           ) else (
                             return ()
                           )
                         ))
                      *>
                      (take_while (fun c -> c <> form_feed))
                    in
                    Eio.Buf_read.(map List.of_seq (seq p))
                  )
               )
               ~stderr cmd
           in
           Some lines
         with
         | _ -> None
       in
       output
    )

let pipe_to_command (f : out_channel -> unit) command args =
  if not (command_exists command) then (
    exit_with_error_msg
      (Fmt.str "command %s not found" command)
  );
  let oc =
    Unix.open_process_args_out
      command (Array.append [|command|] args)
  in
  f oc;
  Out_channel.flush oc;
  Out_channel.close oc

let pipe_to_fzf_for_selection ?preview_cmd (lines : string Seq.t)
  : [ `Selection of string list | `Cancelled of int ] =
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
  let args = Dynarray.create () in
  Dynarray.add_last args "fzf";
  Option.iter (fun preview_cmd ->
      Dynarray.add_last args "--preview";
      Dynarray.add_last args preview_cmd;
    ) preview_cmd;
  let pid =
    Unix.create_process "fzf" (Dynarray.to_array args)
      stdin_for_fzf stdout_for_fzf Unix.stderr
  in
  let _, process_status =
    let res = ref None in
    while Option.is_none !res do
      try
        res := Some (Unix.waitpid [] pid)
      with
      | Unix.Unix_error (Unix.EINTR, _, _) -> ()
    done;
    Option.get !res
  in
  Unix.close stdin_for_fzf;
  Unix.close stdout_for_fzf;
  let selection = CCIO.read_lines_l (Unix.in_channel_of_descr read_from_fzf) in
  In_channel.close read_from_fzf_ic;
  match process_status with
  | WEXITED n when n <> 0 -> (
      `Cancelled n
    )
  | WSIGNALED _ | WSTOPPED _ -> (
      `Cancelled 1
    )
  | _ -> (
      `Selection selection
    )
