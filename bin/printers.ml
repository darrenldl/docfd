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
    match !Params.print_color_mode with
    | `Never -> Cap.dumb
    | `Always -> Cap.ansi
    | `Auto -> (
        if Out_channel.isatty oc then
          Cap.ansi
        else
          Cap.dumb
      )
  in
  Render.to_buffer buf cap (0, 0) (I.width img, I.height img) img;
  Buffer.output_buffer oc buf

let newline_image (out : print_output) =
  Notty_unix.eol (Notty.I.void 0 1)
  |> output_image (out_channel_of_print_output out)

let path_image (out : print_output) path =
  let oc = out_channel_of_print_output out in
  Notty.I.string Notty.A.(fg magenta) path
  |> Notty_unix.eol
  |> output_image oc

let search_results (out : print_output) document (results : Search_result.t Seq.t) =
  let path = Document.path document in
  let oc = out_channel_of_print_output out in
  path_image out path;
  Seq.iteri (fun i search_result ->
      if i > 0 then (
        newline_image out
      );
      let underline =
        match !Params.print_underline_mode with
        | `Never -> false
        | `Always -> true
        | `Auto -> not (Out_channel.isatty oc)
      in
      let img =
        Content_and_search_result_render.search_result
          ~render_mode:(Ui_base.render_mode_of_document document)
          ~width:!Params.search_result_print_text_width
          ~underline
          ~fill_in_context:true
          (Document.index document)
          search_result
      in
      Notty_unix.eol img
      |> output_image oc;
    ) results

module Worker = struct
  type request =
    | Document_and_search_results of Document.t * Search_result.t Seq.t
    | Paths of string Seq.t

  let print_req : (print_output * request) option Eio.Stream.t =
    Eio.Stream.create 10240

  let submit_search_results_print_req out document results =
    Eio.Stream.add
      print_req
      (Some (out, Document_and_search_results (document, results)))

  let submit_paths_print_req out paths =
    Eio.Stream.add
      print_req
      (Some (out, Paths paths))

  let stop () = Eio.Stream.add print_req None

  let fiber () =
    Eio.Cancel.protect (fun () ->
        let first_print = ref true in
        let stop = ref false in
        while not !stop do
          match Eio.Stream.take print_req with
          | None -> stop := true
          | Some (out, req) -> (
              if not !first_print then (
                newline_image out
              );
              (match req with
               | Document_and_search_results (document, results) -> (
                   search_results out document results;
                 )
               | Paths paths -> (
                   Seq.iter (path_image out) paths
                 ));
              first_print := false;
            )
        done
      )
end
