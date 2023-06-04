type t = {
  path : string option;
  title : string option;
  index : Index.t;
}

let make_empty () : t =
  {
    path = None;
    title = None;
    index = Index.empty;
  }

let copy (t : t) =
  {
    path = t.path;
    title = t.title;
    index = t.index;
  }

module Parsers = struct
  open Angstrom
  open Parser_components

  let word_p ~delim =
    take_while1 (fun c ->
        (not (is_space c))
        &&
        (not (String.contains delim c))
      )

  let words_p ~delim = many (word_p ~delim <* spaces)
end

type work_stage =
  | Title
  | Content

let parse_lines (s : string Seq.t) : t =
  let rec aux (stage : work_stage) title s =
    match stage with
    | Content -> (
        let s = 
          match title with
          | None -> s
          | Some title ->
            Seq.cons title s
        in
        let index = Index.of_seq s in
        let empty = make_empty () in
        {
          empty with
          title = (match title with
              | None -> None
              | Some (_line_loc, title) -> Some title);
          index;
        }
      )
    | Title -> (
        match s () with
        | Seq.Nil -> aux Content title Seq.empty
        | Seq.Cons (x, xs) -> (
            aux Content (Some x) xs
          )
      )
  in
  aux Title None
    (Seq.mapi (fun line_num_in_page str ->
         let line_loc =
           { Index.Line_loc.page_num = 0; line_num_in_page }
         in
         (line_loc, str)) s)

let parse_pages (s : string array Seq.t) : t =
  let rec aux (stage : work_stage) title s =
    match stage with
    | Content -> (
        let s = 
          match title with
          | None -> s
          | Some title ->
            Seq.cons title s
        in
        let index = Index.of_seq s in
        let empty = make_empty () in
        {
          empty with
          title = (match title with
              | None -> None
              | Some (_line_loc, title) -> Some title);
          index;
        }
      )
    | Title -> (
        match s () with
        | Seq.Nil -> aux Content title Seq.empty
        | Seq.Cons (x, xs) -> (
            aux Content (Some x) xs
          )
      )
  in
  s
  |> Seq.mapi (fun page_num page ->
      (page_num, page)
      )
  |> Seq.flat_map (fun (page_num, page) ->
      if Array.length page = 0 then
        let empty_line = ({ Index.Line_loc.page_num; line_num_in_page = 0; }, "") in
        Seq.return empty_line
      else (
        Array.to_seq page
  |> Seq.mapi (fun line_num_in_page line ->
      ({ Index.Line_loc.page_num; line_num_in_page; }, line)
      )
      )
      )
  |> aux Title None

let of_in_channel ic : t =
  parse_lines (CCIO.read_lines_seq ic)

let of_text_path ~(env : Eio.Stdenv.t) path : (t, string) result =
  let fs = Eio.Stdenv.fs env in
  try
    Eio.Path.(with_lines (fs / path))
      (fun lines ->
         let document = parse_lines lines in
         Ok { document with path = Some path }
      )
  with
  | _ -> Error (Printf.sprintf "Failed to read file: %s" path)

(* let of_pdf_path path : (t, string) result =
  let rec aux title acc page_num =
    let cmd = Fmt.str "pdftotext -f %d -l %d" in
    match Proc_utils.run_return_stdout cmd with
    | None -> acc
    | Some lines -> (
      if page_num = 0 then (
        if Array.length lines = 0 then
      ) else (
      )
    )
  in
  aux None [] 0 *)

let of_path ~(env : Eio.Stdenv.t) path : (t, string) result =
  match Filename.extension path with
  (* | ".pdf" -> (
  ) *)
  | _ -> of_text_path ~env path
