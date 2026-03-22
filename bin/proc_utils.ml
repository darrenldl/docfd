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
