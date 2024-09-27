let ci_string_set_of_list (l : string list) =
  l
  |> List.map String.lowercase_ascii
  |> String_set.of_list

let first_n_chars_of_string_contains ~n s c =
  let s_len = String.length s in
  let s =
    if s_len <= n then
      s
    else
      String.sub s 0 n
  in
  String.contains s c

let char_is_usable c =
  let code = Char.code c in
  (0x20 <= code && code <= 0x7E)

let sanitize_string s =
  let s_len = String.length s in
  let bytes = Bytes.make s_len ' ' in
  let rec aux pos =
    if pos >= s_len then
      String.of_bytes bytes
    else (
      let decode = String.get_utf_8_uchar s pos in
      if Uchar.utf_decode_is_valid decode then (
        let c = String.get_uint8 s pos in
        if c land 0b1000_0000 = 0b0000_0000 then (
          if 0x20 <= c && c <= 0x7E then (
            Bytes.blit_string s pos bytes pos 1
          );
          aux (pos+1)
        ) else (
          let len = Uchar.utf_decode_length decode in
          Bytes.blit_string s pos bytes pos len;
          aux (pos+len)
        )
      ) else (
        aux (pos+1)
      )
    )
  in
  aux 0

let length_and_list_of_seq (s : 'a Seq.t) : int * 'a list =
  let len, acc =
    Seq.fold_left (fun (len, acc) x ->
        (len + 1, x :: acc)
      )
      (0, [])
      s
  in
  (len, List.rev acc)

let div_round_to_closest x y =
  (x + (y / 2)) / y

let div_round_up x y =
  (x + (y - 1)) / y

let opening_closing_symbol_pairs (l : string list) : (int * int) list =
  let _, pairs =
    CCList.foldi
      (fun ((m, pairs) : (int list Char_map.t) * ((int * int) list)) i s ->
         if String.length s = 1 then (
           let c = String.get s 0 in
           match List.assoc_opt c Params.opening_closing_symbols with
           | Some _ -> (
               let stack =
                 match Char_map.find_opt c m with
                 | None -> []
                 | Some l -> l
               in
               (Char_map.add c (i :: stack) m, pairs)
             )
           | None -> (
               match List.assoc_opt c Params.opening_closing_symbols_flipped with
               | Some corresponding_open_symbol -> (
                   let stack =
                     match Char_map.find_opt corresponding_open_symbol m with
                     | None -> []
                     | Some l -> l
                   in
                   match stack with
                   | [] -> (m, pairs)
                   | x :: xs -> (
                       (Char_map.add corresponding_open_symbol xs m, (x, i) :: pairs)
                     )
                 )
               | None -> (m, pairs)
             )
         ) else (
           (m, pairs)
         )
      )
      (Char_map.empty, [])
      l
  in
  pairs

let cwd_path_parts () =
  Sys.getcwd ()
  |> CCString.split ~by:Filename.dir_sep
  |> List.rev

let path_of_parts parts =
  match List.rev parts with
  | [] | [ "" ] -> Filename.dir_sep
  | [ x ] -> x
  | l -> String.concat Filename.dir_sep l

let normalize_glob_to_absolute glob =
  let rec aux acc parts =
    match parts with
    | [] -> path_of_parts acc
    | x :: xs -> (
        match x with
        | "" | "." -> aux acc xs
        | ".." -> (
            let acc =
              match acc with
              | [] -> []
              | _ :: xs -> xs
            in
            aux acc xs
          )
        | "**" -> (
            aux (List.rev parts @ acc) []
          )
        | _ -> (
            aux (x :: acc) xs
          )
      )
  in
  let glob_parts = CCString.split ~by:Filename.dir_sep glob in
  match glob_parts with
  | "" :: l -> (
      (* Absolute path on Unix-like systems *)
      aux [ "" ] l
    )
  | _ -> (
      aux (cwd_path_parts ()) glob_parts
    )

let normalize_path_to_absolute path =
  let rec aux acc path_parts =
    match path_parts with
    | [] -> path_of_parts acc
    | x :: xs -> (
        match x with
        | "" | "." -> aux acc xs
        | ".." -> (
            let acc =
              match acc with
              | [] -> []
              | _ :: xs -> xs
            in
            aux acc xs
          )
        | _ -> (
            aux (x :: acc) xs
          )
      )
  in
  let path_parts = CCString.split ~by:Filename.dir_sep path in
  match path_parts with
  | "" :: l -> (
      (* Absolute path on Unix-like systems *)
      aux [ "" ] l
    )
  | _ -> (
      aux (cwd_path_parts ()) path_parts
    )

let encode_int (buf : Buffer.t) (x : int) =
  Buffer.add_int64_be buf (Int64.of_int x)

let encode_string (buf : Buffer.t) (x : string) =
  let len = String.length x in
  encode_int buf len;
  Buffer.add_string buf x

let decode_int (s : string) (pos : int ref) : int =
  let res = 
    String.get_int64_be s !pos
    |> Int64.to_int
  in
  pos := !pos + 8;
  res

let decode_string (s : string) (pos : int ref) : string =
  let len = decode_int s pos in
  let res =
    String.sub s !pos len
  in
  pos := !pos + len;
  res
