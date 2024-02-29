let do_if_debug (f : out_channel -> unit) =
  match !Params.debug_output with
  | None -> ()
  | Some oc -> (
      f oc
    )
