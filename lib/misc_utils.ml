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
  let rec check_n_bytes_start_with_0b10 ~n pos =
    if pos >= s_len || n = 0 then
      n = 0
    else (
      let c = String.get_uint8 s pos in
      (c land 0b1100_0000 = 0b1000_0000)
      &&
      (check_n_bytes_start_with_0b10 ~n:(n - 1) (pos + 1))
    )
  in
  let check_and_blit ~n pos =
    if check_n_bytes_start_with_0b10 ~n:(n-1) (pos+1) then (
      BytesLabels.blit_string ~src:s ~src_pos:pos ~dst:bytes ~dst_pos:pos ~len:n
    )
  in
  let rec aux pos =
    if pos >= s_len then
      String.of_bytes bytes
    else (
      let c = String.get_uint8 s pos in
      if c land 0b1000_0000 = 0b0000_0000 then (
        if 0x20 <= c && c <= 0x7E then (
          BytesLabels.blit_string ~src:s ~src_pos:pos ~dst:bytes ~dst_pos:pos ~len:1
        );
        aux (pos+1)
      ) else if c land 0b1110_0000 = 0b1100_0000 then (
        let n = 2 in
        check_and_blit ~n pos;
        aux (pos+n)
      ) else if c land 0b1111_0000 = 0b1110_0000 then (
        let n = 3 in
        check_and_blit ~n pos;
        aux (pos+n)
      ) else if c land 0b1111_1000 = 0b1111_0000 then (
        let n = 4 in
        check_and_blit ~n pos;
        aux (pos+n)
      ) else (
        aux (pos+1)
      )
    )
  in
  aux 0

let bound_selection ~choice_count (x : int) : int =
  max 0 (min (choice_count - 1) x)

let list_and_length_of_seq (s : 'a Seq.t) : int * 'a list =
  let len, acc =
    Seq.fold_left (fun (len, acc) x ->
        (len + 1, x :: acc)
      )
      (0, [])
      s
  in
  (len, List.rev acc)

let path_is_pdf (s : string) =
  Filename.extension s = ".pdf"
