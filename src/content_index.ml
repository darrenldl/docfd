type t = {
  pos_s_of_word_ci : Int_set.t String_map.t;
  loc_of_pos : (int * int) Int_map.t;
  start_end_inc_pos_of_line_num : (int * int) Int_map.t;
  word_ci_of_pos : int Int_map.t;
  word_of_pos : int Int_map.t;
  word_db : Word_db.t;
}

let empty : t = {
  pos_s_of_word_ci = String_map.empty;
  loc_of_pos = Int_map.empty;
  start_end_inc_pos_of_line_num = Int_map.empty;
  word_ci_of_pos = Int_map.empty;
  word_of_pos = Int_map.empty;
  word_db = Word_db.empty;
}

let words_of_lines (s : (int * string) Seq.t) : (int * (int * int) * string) Seq.t =
  s
  |> Seq.flat_map (fun (line_num, s) ->
      Tokenize.f_with_pos ~drop_spaces:false s
      |> Seq.map (fun (i, s) -> ((line_num, i), s))
    )
  |> Seq.mapi (fun i (loc, s) ->
      (i, loc, s))

let index (s : (int * string) Seq.t) : t =
  s
  |> words_of_lines
  |> Seq.fold_left
    (fun
      { pos_s_of_word_ci;
        loc_of_pos;
        start_end_inc_pos_of_line_num;
        word_ci_of_pos;
        word_of_pos;
        word_db;
      }
      (pos, loc, word) ->
      let (line_num, _) = loc in
      let word_ci = String.lowercase_ascii word in
      let index_of_word, word_db =
        Word_db.add word word_db
      in
      let index_of_word_ci, word_db =
        Word_db.add word_ci word_db
      in
      let pos_s = Option.value ~default:Int_set.empty
          (String_map.find_opt word pos_s_of_word_ci)
                  |> Int_set.add pos
      in
      let start_end_inc_pos =
        match Int_map.find_opt line_num start_end_inc_pos_of_line_num with
        | None -> (pos, pos)
        | Some (x, _) -> (x, pos)
      in
      { pos_s_of_word_ci = String_map.add word_ci pos_s pos_s_of_word_ci;
        loc_of_pos = Int_map.add pos loc loc_of_pos;
        start_end_inc_pos_of_line_num =
          Int_map.add line_num start_end_inc_pos start_end_inc_pos_of_line_num;
        word_ci_of_pos = Int_map.add pos index_of_word_ci word_ci_of_pos;
        word_of_pos = Int_map.add pos index_of_word word_of_pos;
        word_db;
      }
    )
    empty

let word_ci_of_pos pos t =
  Word_db.word_of_index
    (Int_map.find pos t.word_ci_of_pos)
    t.word_db

let word_of_pos pos t =
  Word_db.word_of_index
    (Int_map.find pos t.word_of_pos)
    t.word_db

let word_ci_and_pos_s ?range_inc t : (string * Int_set.t) Seq.t =
  match range_inc with
  | None -> String_map.to_seq t.pos_s_of_word_ci
  | Some (start, end_inc) -> (
      assert (start <= end_inc);
      let _, _, m =
        Int_map.split (start-1)
          t.word_ci_of_pos
      in
      let m, _, _ =
        Int_map.split (end_inc+1)
          m
      in
      let words_to_consider =
        Int_map.fold (fun _ index set ->
            Int_set.add index set
          ) m Int_set.empty
      in
      Int_set.to_seq words_to_consider
      |> Seq.map (fun index -> Word_db.word_of_index index t.word_db)
      |> Seq.map (fun word ->
          (word, String_map.find word t.pos_s_of_word_ci)
        )
      |> Seq.map (fun (word, pos_s) ->
          let _, _, m =
            Int_set.split (start-1) pos_s
          in
          let m, _, _ =
            Int_set.split (end_inc+1) m
          in
          (word, m)
        )
    )

let words_of_line_num line_num t : string Seq.t =
  match Int_map.find_opt line_num t.start_end_inc_pos_of_line_num with
  | None -> Seq.empty
  | Some (start, end_inc) ->
  OSeq.(start -- end_inc)
  |> Seq.map (fun pos -> word_of_pos pos t)

let line_of_line_num line_num t =
  words_of_line_num line_num t
  |> List.of_seq
  |> String.concat ""

let loc_of_pos pos t : (int * int) =
  Int_map.find pos t.loc_of_pos

let line_count t : int =
  match Int_map.max_binding_opt t.start_end_inc_pos_of_line_num with
  | None -> 0
  | Some (x, _) -> x

let lines t =
  OSeq.(0 --^ line_count t)
  |> Seq.map (fun line_num -> line_of_line_num line_num t)
