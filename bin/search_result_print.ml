open Misc_utils

type print_output = [ `Stdout | `Stderr ]

let out_channel_of_print_output (out : print_output) : out_channel =
  match out with
  | `Stdout -> stdout
  | `Stderr -> stderr

let print_output_is_atty (out : print_output) =
  match out with
  | `Stdout -> stdout_is_atty ()
  | `Stderr -> stderr_is_atty ()

let newline_image ~(out : print_output) =
  Notty_unix.eol (Notty.I.void 0 1)
  |> Notty_unix.output_image ~fd:(out_channel_of_print_output out)

let search_result_images ~(out : print_output) ~document (images : Notty.image list) =
  let path = Document.path document in
  let oc = out_channel_of_print_output out in
  if print_output_is_atty out then (
    let buf = Buffer.create (String.length path) in
    let fmt = Format.formatter_of_buffer buf in
    Ocolor_format.prettify_formatter fmt;
    Fmt.pf fmt "@[<h>@{<magenta>%s@}@]%a" path Format.pp_print_flush ();
    Printf.fprintf oc "%s\n" (Buffer.contents buf);
  ) else (
    Printf.fprintf oc "%s\n" path;
  );
  let images = Array.of_list images in
  Array.iteri (fun i img ->
      if i > 0 then (
        newline_image ~out
      );
      Notty_unix.eol img
      |> Notty_unix.output_image ~fd:oc;
    ) images
