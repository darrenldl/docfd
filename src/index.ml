type t = {
  pos_s_of_word_ci : Int_set.t String_map.t;
  loc_of_pos : (int * int) Int_map.t;
  start_end_inc_pos_of_line_num : (int * int) Int_map.t;
  word_ci_of_pos : int Int_map.t;
  word_of_pos : int Int_map.t;
  line_count : int;
}

type double_indexed_word = int * (int * int) * string

type chunk = double_indexed_word array

let empty : t = {
  pos_s_of_word_ci = String_map.empty;
  loc_of_pos = Int_map.empty;
  start_end_inc_pos_of_line_num = Int_map.empty;
  word_ci_of_pos = Int_map.empty;
  word_of_pos = Int_map.empty;
  line_count = 0;
}

let union (x : t) (y : t) =
  {
    pos_s_of_word_ci =
      String_map.union (fun _k s0 s1 -> Some (Int_set.union s0 s1))
        x.pos_s_of_word_ci
        y.pos_s_of_word_ci;
    loc_of_pos =
      Int_map.union (fun _k x _ -> Some x)
        x.loc_of_pos
        y.loc_of_pos;
    start_end_inc_pos_of_line_num =
      Int_map.union (fun _k (start_x, end_inc_x) (start_y, end_inc_y) ->
          Some (min start_x start_y, max end_inc_x end_inc_y))
        x.start_end_inc_pos_of_line_num
        y.start_end_inc_pos_of_line_num;
    word_ci_of_pos =
      Int_map.union (fun _k x _ -> Some x)
        x.word_ci_of_pos
        y.word_ci_of_pos;
    word_of_pos =
      Int_map.union (fun _k x _ -> Some x)
        x.word_of_pos
        y.word_of_pos;
    line_count = max x.line_count y.line_count;
  }

let words_of_lines (s : (int * string) Seq.t) : double_indexed_word Seq.t =
  s
  |> Seq.flat_map (fun (line_num, s) ->
      Tokenize.f_with_pos ~drop_spaces:false s
      |> Seq.map (fun (i, s) -> ((line_num, i), s))
    )
  |> Seq.mapi (fun i (loc, s) ->
      (i, loc, s))

let of_chunk (arr : chunk) : t =
  Array.fold_left
    (fun
      { pos_s_of_word_ci;
        loc_of_pos;
        start_end_inc_pos_of_line_num;
        word_ci_of_pos;
        word_of_pos;
        line_count;
      }
      (pos, loc, word) ->
      let (line_num, _) = loc in
      let word_ci = String.lowercase_ascii word in
      let index_of_word =
        Word_db.add word
      in
      let index_of_word_ci =
        Word_db.add word_ci
      in
      let pos_s = Option.value ~default:Int_set.empty
          (String_map.find_opt word_ci pos_s_of_word_ci)
                  |> Int_set.add pos
      in
      let start_end_inc_pos =
        match Int_map.find_opt line_num start_end_inc_pos_of_line_num with
        | None -> (pos, pos)
        | Some (x, y) -> (min x pos, max y pos)
      in
      { pos_s_of_word_ci = String_map.add word_ci pos_s pos_s_of_word_ci;
        loc_of_pos = Int_map.add pos loc loc_of_pos;
        start_end_inc_pos_of_line_num =
          Int_map.add line_num start_end_inc_pos start_end_inc_pos_of_line_num;
        word_ci_of_pos = Int_map.add pos index_of_word_ci word_ci_of_pos;
        word_of_pos = Int_map.add pos index_of_word word_of_pos;
        line_count;
      }
    )
    empty
    arr

let chunks_of_words (s : double_indexed_word Seq.t) : chunk Seq.t =
  OSeq.chunks !Params.index_chunk_word_count s

let of_seq (s : (int * string) Seq.t) : t =
  let lines = Array.of_seq s in
  let line_count = Array.length lines in
  let indices =
    lines
    |> Array.to_seq
    |> words_of_lines
    |> chunks_of_words
    |> List.of_seq
    |> Eio.Fiber.List.map (fun chunk ->
        Worker_pool.run (fun () -> of_chunk chunk))
  in
  List.fold_left (fun acc index ->
      union acc index
    )
    { empty with line_count }
    indices

let word_ci_of_pos pos t =
  Word_db.word_of_index
    (Int_map.find pos t.word_ci_of_pos)

let word_of_pos pos t =
  Word_db.word_of_index
    (Int_map.find pos t.word_of_pos)

let word_ci_and_pos_s ?range_inc t : (string * Int_set.t) Seq.t =
  match range_inc with
  | None -> String_map.to_seq t.pos_s_of_word_ci
  | Some (start, end_inc) -> (
      assert (start <= end_inc);
      let _, _, m =
        Int_map.split (start-1) t.word_ci_of_pos
      in
      let m, _, _ =
        Int_map.split (end_inc+1) m
      in
      let words_to_consider =
        Int_map.fold (fun _ index set ->
            Int_set.add index set
          ) m Int_set.empty
      in
      Int_set.to_seq words_to_consider
      |> Seq.map Word_db.word_of_index
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
  t.line_count

let lines t =
  OSeq.(0 --^ line_count t)
  |> Seq.map (fun line_num -> line_of_line_num line_num t)

module Search = struct
  let usable_positions
      ?around_pos
      ((search_word, dfa) : (string * Spelll.automaton))
      (t : t)
    : int Seq.t =
    let word_ci_and_positions_to_consider =
      match around_pos with
      | None -> word_ci_and_pos_s t
      | Some around_pos ->
        let start = around_pos - (!Params.max_word_search_range+1) in
        let end_inc = around_pos + (!Params.max_word_search_range+1) in
        word_ci_and_pos_s ~range_inc:(start, end_inc) t
    in
    let search_word_ci =
      String.lowercase_ascii search_word
    in
    word_ci_and_positions_to_consider
    |> Seq.filter (fun (indexed_word, _pos_s) ->
        not (String.for_all Parser_components.is_space indexed_word)
      )
    |> Seq.filter (fun (indexed_word, _pos_s) ->
        String.equal search_word_ci indexed_word
        || CCString.find ~sub:search_word_ci indexed_word >= 0
        || (Misc_utils.first_n_chars_of_string_contains ~n:5 indexed_word search_word_ci.[0]
            && Spelll.match_with dfa indexed_word)
      )
    |> Seq.flat_map (fun (_indexed_word, pos_s) -> Int_set.to_seq pos_s)

  let search_around_pos
      (around_pos : int)
      (l : (string * Spelll.automaton) list)
      (t : t)
    : int list Seq.t =
    let rec aux around_pos l =
      match l with
      | [] -> Seq.return []
      | (search_word, dfa) :: rest -> (
          usable_positions ~around_pos (search_word, dfa) t
          |> Seq.flat_map (fun pos ->
              aux pos rest
              |> Seq.map (fun l -> pos :: l)
            )
        )
    in
    aux around_pos l

  let search
      (constraints : Search_constraints.t)
      (t : t)
    : int list Seq.t =
    if Search_constraints.is_empty constraints then
      Seq.empty
    else (
      match List.combine constraints.phrase constraints.fuzzy_index with
      | [] -> failwith "Unexpected case"
      | first_word :: rest -> (
          let possible_start_count, possible_starts =
            usable_positions first_word t
            |> Misc_utils.list_and_length_of_seq
          in
          if possible_start_count = 0 then
            Seq.empty
          else (
            let search_limit_per_start =
              (Params.search_result_limit + possible_start_count - 1) / possible_start_count
            in
            possible_starts
            |> Eio.Fiber.List.map (fun pos ->
                Worker_pool.run
                  (fun () ->
                     search_around_pos pos rest t
                     |> Seq.map (fun l -> pos :: l)
                     |> Seq.take search_limit_per_start
                     |> List.of_seq
                  )
              )
            |> List.fold_left (fun s (l : int list list) ->
                Seq.append s (List.to_seq l)
              )
              Seq.empty
          )
        )
    )
end

let search
    (constraints : Search_constraints.t)
    (t : t)
  : Search_result.t Seq.t =
  Search.search constraints t
  |> Seq.map (fun l ->
      Search_result.make
        ~search_phrase:constraints.phrase
        ~found_phrase:(List.map
                         (fun pos ->
                            (pos,
                             word_ci_of_pos pos t,
                             word_of_pos pos t
                            )
                         ) l)
    )
