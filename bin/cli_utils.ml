let print_config_path_for_cli_error_msg ~config_path =
  Printf.eprintf "docfd: the invalid arguments might be loaded from config file: %s\n%!" (Filename.quote config_path)

let exit_with_cli_error_msg (msg : string) =
  Printf.eprintf "docfd: %s\n%!" msg;
  Option.iter (fun config_path ->
      print_config_path_for_cli_error_msg ~config_path
    ) !Params.config_path;
  exit Cmdliner.Cmd.Exit.cli_error
