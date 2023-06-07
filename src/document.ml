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
        let index = Index.of_lines s in
        let empty = make_empty () in
        {
          empty with
          title;
          index;
        }
      )
    | Title -> (
        match s () with
        | Seq.Nil -> aux Content title Seq.empty
        | Seq.Cons (x, xs) -> (
            aux Content (Some (Misc_utils.sanitize_string x)) (Seq.cons x xs)
          )
      )
  in
  aux Title None s

let parse_pages (s : string array Seq.t) : t =
  let rec aux (stage : work_stage) title s =
    match stage with
    | Content -> (
        let index = Index.of_pages s in
        let empty = make_empty () in
        {
          empty with
          title;
          index;
        }
      )
    | Title -> (
        match s () with
        | Seq.Nil -> aux Content title Seq.empty
        | Seq.Cons (x, xs) -> (
            let title =
              if Array.length x = 0 then
                None
              else
                Some (Misc_utils.sanitize_string x.(0))
            in
            aux Content title (Seq.cons x xs)
          )
      )
  in
  aux Title None s

let of_in_channel ic : t =
  parse_lines (CCIO.read_lines_seq ic)

let of_text_path ~env path : (t, string) result =
  let fs = Eio.Stdenv.fs env in
  try
    Eio.Path.(with_lines (fs / path))
      (fun lines ->
         let document = parse_lines lines in
         Ok { document with path = Some path }
      )
  with
  | _ -> Error (Printf.sprintf "Failed to read file: %s" path)

let of_pdf_path ~sw ~env path : (t, string) result =
  let proc_mgr = Eio.Stdenv.process_mgr env in
  let rec aux acc page_num =
    let cmd = Fmt.str "pdftotext -f %d -l %d %s -" page_num page_num (Filename.quote path) in
    match Proc_utils.run_return_stdout ~sw ~proc_mgr cmd with
    | None -> (
        Printf.printf "test: cmd: %s\n" cmd;
        Printf.printf "test: page count: %d\n" (List.length acc);
        flush stdout;
        Unix.sleepf 1.0;
        let document = parse_pages (acc |> List.rev |> List.to_seq) in
        { document with path = Some path }
      )
    | Some page -> (
        aux (page :: acc) (page_num + 1)
      )
  in
  Ok (aux [] 1)
(* try
   Ok (aux [] 1)
   with
   | _ -> Error (Printf.sprintf "Failed to read file: %s" path) *)

let of_path ~sw ~(env : Eio_unix.Stdenv.base) path : (t, string) result =
  match Filename.extension path with
  | ".pdf" -> of_pdf_path path
  | _ -> of_text_path ~env path
