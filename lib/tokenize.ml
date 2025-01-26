let chunk_tokens (s : (int * string) Seq.t) : (int * string) Seq.t =
  let rec aux offset s =
    match s () with
    | Seq.Nil -> Seq.empty
    | Seq.Cons ((pos, word), rest) -> (
        let word_len = String.length word in
        if word_len <= Params.max_token_size then (
          fun () -> Seq.Cons ((pos + offset, word), aux offset rest)
        ) else (
          let up_to_limit =
            String.sub word 0 Params.max_token_size
          in
          let rest_of_token =
            String.sub word Params.max_token_size (word_len - Params.max_token_size)
          in
          fun () ->
            Seq.Cons
              ((pos + offset, up_to_limit),
               (aux (offset + 1) (Seq.cons (pos, rest_of_token) rest)))
        )
      )
  in
  aux 0 s

type token =
  | Space of string
  | Text of string

let tokenize_with_pos ~drop_spaces (s : string) : (int * string) Seq.t =
  let segmenter = Uuseg.create `Word in
  let s = Misc_utils.sanitize_string s in
  let s_len = String.length s in
  let acc : token Dynarray.t = Dynarray.create () in
  let buf : Uchar.t Dynarray.t = Dynarray.create () in
  let sbuf = Buffer.create 256 in
  let flush_to_acc () =
    if Dynarray.length buf > 0 then (
      Dynarray.iter (Buffer.add_utf_8_uchar sbuf) buf;
      if Uucp.White.is_white_space (Dynarray.get buf 0) then (
        Dynarray.add_last acc (Space (Buffer.contents sbuf))
      ) else (
        Dynarray.add_last acc (Text (Buffer.contents sbuf))
      );
      Dynarray.clear buf;
      Buffer.clear sbuf
    )
  in
  let rec add v =
    match Uuseg.add segmenter v with
    | `Uchar uc -> (
        Dynarray.add_last buf uc;
        add `Await
      )
    | `Boundary -> (
        flush_to_acc ();
        add `Await
      )
    | `Await | `End -> ()
  in
  let rec aux pos =
    if pos >= s_len then (
      add `End;
      flush_to_acc ()
    ) else (
      let decode = String.get_utf_8_uchar s pos in
      if Uchar.utf_decode_is_valid decode then (
        let uchar = Uchar.utf_decode_uchar decode in
        add (`Uchar uchar);
        aux (pos + Uchar.utf_decode_length decode)
      ) else (
        aux (pos + 1)
      )
    )
  in
  aux 0;
  Dynarray.to_seq acc
  |> Seq.mapi (fun i x -> (i, x))
  |> Seq.filter_map (fun ((i, token) : int * token) ->
      match token with
      | Text s -> Some (i, s)
      | Space s ->
        if drop_spaces then
          None
        else
          Some (i, s)
    )
  |> chunk_tokens

let tokenize ~drop_spaces s =
  tokenize_with_pos ~drop_spaces s
  |> Seq.map snd
