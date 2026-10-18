let print_config_path_for_cli_error_msg ~config_path =
  Printf.eprintf "docfd: the invalid arguments might be from config file: %s\n%!" (Filename.quote config_path)

let exit_with_cli_error_msg (msg : string) =
  Printf.eprintf "docfd: %s\n%!" msg;
  Option.iter (fun config_path ->
      print_config_path_for_cli_error_msg ~config_path
    ) !Params.config_path;
  exit Cmdliner.Cmd.Exit.cli_error

let is_non_interactive_mode
    ~filter_exp
    ~sample_search_exp
    ~search_exp
    ~script
    ~print_files_with_match
    ~print_files_without_match
    ~print_links
    ~index_only
    ~list_scripts
  =
  Option.is_some filter_exp
  || Option.is_some sample_search_exp
  || Option.is_some search_exp
  || Option.is_some script
  || print_files_with_match
  || print_files_without_match
  || print_links
  || index_only
  || list_scripts
