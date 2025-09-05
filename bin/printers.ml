let output_image ~color (oc : out_channel) (img : Notty.image) : unit =
  let open Notty in
  let buf = Buffer.create 1024 in
  let cap =
    if color then
      Cap.ansi
    else
      Cap.dumb
  in
  Render.to_buffer buf cap (0, 0) (I.width img, I.height img) img;
  Buffer.output_buffer oc buf

let newline_image oc =
  Notty_unix.eol (Notty.I.void 0 1)
  |> output_image ~color:false oc

let path_image ~color oc path =
  Notty.I.string Notty.A.(fg magenta) path
  |> Notty_unix.eol
  |> output_image ~color oc

let search_result_group ~color ~underline (oc : out_channel) ((document, results) : Document_store.search_result_group) =
  let path = Document.path document in
  path_image ~color oc path;
  Array.iteri (fun i search_result ->
      if i > 0 then (
        newline_image oc
      );
      let img =
        Content_and_search_result_render.search_result
          ~doc_id:(Document.doc_id document)
          ~render_mode:(UI_base.render_mode_of_document document)
          ~width:!Params.search_result_print_text_width
          ~underline
          ~fill_in_context:true
          search_result
      in
      Notty_unix.eol img
      |> output_image ~color oc;
    ) results

let search_result_groups
    ~color
    ~underline
    (oc : out_channel)
    (s : Document_store.search_result_group Seq.t)
  =
  Seq.iteri (fun i x ->
      if i > 0 then (
        newline_image oc;
      );
      search_result_group ~color ~underline oc x
    ) s
