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

let parse_text_file (s : string Seq.t) : t =
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
    (Seq.mapi (fun line_num str ->
         let line_loc : Index.line_loc =
           { page_num = 0; line_num }
         in
         (line_loc, str)) s)

let of_in_channel ic : t =
  parse_text_file (CCIO.read_lines_seq ic)

let of_path ~(env : Eio.Stdenv.t) path : (t, string) result =
  let fs = Eio.Stdenv.fs env in
  try
    Eio.Path.(with_lines (fs / path))
      (fun lines ->
         let document = parse_text_file lines in
         Ok { document with path = Some path }
      )
  with
  | _ -> Error (Printf.sprintf "Failed to read file: %s" path)
