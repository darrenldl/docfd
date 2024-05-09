open Docfd_lib

type print_output = [ `Stdout | `Stderr ]

let out_channel_of_print_output (out : print_output) : out_channel =
  match out with
  | `Stdout -> stdout
  | `Stderr -> stderr

let output_image (oc : out_channel) (img : Notty.image) : unit =
  let open Notty in
  let buf = Buffer.create 1024 in
  let cap =
    if Out_channel.isatty oc then
      Cap.ansi
    else
      Cap.dumb
  in
  Render.to_buffer buf cap (0, 0) (I.width img, I.height img) img;
  Buffer.output_buffer oc buf

let newline_image (out : print_output) =
  Notty_unix.eol (Notty.I.void 0 1)
  |> output_image (out_channel_of_print_output out)

let search_results (out : print_output) document (results : Search_result.t Seq.t) =
  let path = Document.path document in
  let oc = out_channel_of_print_output out in
  Notty.I.string Notty.A.(fg magenta) path
  |> Notty_unix.eol
  |> output_image oc;
  Seq.iteri (fun i search_result ->
      if i > 0 then (
        newline_image out
      );
      let img =
        Content_and_search_result_render.search_result
          ~render_mode:(Ui_base.render_mode_of_document document)
          ~width:!Params.search_result_print_text_width
          ~fill_in_context:true
          (Document.index document)
          search_result
      in
      Notty_unix.eol img
      |> output_image oc;
    ) results

module Worker = struct
  let print_req : (print_output * Document.t * Search_result.t Seq.t) Eio.Stream.t = Eio.Stream.create 100

  let submit_search_results_print_req out document results =
    Eio.Stream.add print_req (out, document, results)

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
end
