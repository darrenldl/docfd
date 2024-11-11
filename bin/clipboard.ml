let pipe_to_clipboard (f : out_channel -> unit) : unit =
  match Params.clipboard_copy_cmd_and_args with
  | None -> ()
  | Some (cmd, args) -> (
      Proc_utils.pipe_to_command f
        cmd args
    )
