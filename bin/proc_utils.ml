let command_exists (cmd : string) : bool =
  Sys.command (Fmt.str "command -v %s 2>/dev/null 1>/dev/null" cmd) = 0

let run_return_stdout ~proc_mgr (cmd : string list) : string list option =
  Eio.Switch.run (fun sw ->
      let _, stderr = Eio.Process.pipe ~sw proc_mgr in
      let output =
        try
          let s = Eio.Process.parse_out proc_mgr Eio.Buf_read.take_all ~stderr cmd in
          Some (String.split_on_char '\n' s)
        with
        | _ -> None
      in
      Eio.Flow.close stderr;
      output
    )
