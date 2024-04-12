open Docfd_lib
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

let newline_image (out : print_output) =
  Notty_unix.eol (Notty.I.void 0 1)
  |> Notty_unix.output_image ~fd:(out_channel_of_print_output out)

let search_results (out : print_output) document (results : Search_result.t Seq.t) =
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
  Seq.iteri (fun i search_result ->
      if i > 0 then (
        newline_image out
      );
      let img =
        Content_and_search_result_render.search_result
          ~render_mode:(Ui_base.render_mode_of_document document)
          ~width:!Params.search_result_print_text_width
          (Document.index document)
          search_result
      in
      Notty_unix.eol img
      |> Notty_unix.output_image ~fd:oc;
    ) results

let print_req : (print_output * Document.t * Search_result.t Seq.t) Eio.Stream.t = Eio.Stream.create 100

let submit_print_req out document results = Eio.Stream.add print_req (out, document, results)

let fiber () =
  let first_print = ref true in
  while true do
    let (out, document, results) = Eio.Stream.take print_req in
    if not !first_print then (
      newline_image out
    );
    search_results out document results;
    first_print := false;
  done
