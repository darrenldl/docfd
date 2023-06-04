type loc = {
  page_num : int;
  line_num_in_page : int;
  pos_in_line : int;
}

module Line_loc = struct
type t = {
  page_num : int;
  line_num_in_page : int;
}

let lt (x : t) (y : t) =
  (x.page_num < y.page_num)
  || (x.page_num = y.page_num && x.line_num_in_page < y.line_num_in_page)

let equal (x : t) (y : t) =
  x.page_num = y.page_num
  && x.line_num_in_page = y.line_num_in_page

    let compare (x : t) (y : t) =
      if lt x y then -1
      else (
        if equal x y then 0
        else 1
      )

let min x y =
  if lt x y then x
  else y

let max x y =
  if lt x y then y
  else x

let of_loc (x : loc) : t =
  { page_num = x.page_num;
    line_num_in_page = x.line_num_in_page;
  }
end

module Line_loc_map = Map.Make (Line_loc)

type t = {
  pos_s_of_word_ci : Int_set.t Int_map.t;
  loc_of_pos : loc Int_map.t;
  start_end_inc_pos_of_line_loc : (int * int) Line_loc_map.t;
  word_ci_of_pos : int Int_map.t;
  word_of_pos : int Int_map.t;
  line_count_of_page : int Int_map.t;
  page_count : int;
}

type multi_indexed_word = {
  pos : int;
  loc : loc;
  word : string;
}

type chunk = multi_indexed_word array

let empty : t = {
  pos_s_of_word_ci = Int_map.empty;
  loc_of_pos = Int_map.empty;
  start_end_inc_pos_of_line_loc = Line_loc_map.empty;
  word_ci_of_pos = Int_map.empty;
  word_of_pos = Int_map.empty;
  line_count_of_page = Int_map.empty;
  page_count = 0;
}

let union (x : t) (y : t) =
  {
    pos_s_of_word_ci =
      Int_map.union (fun _k s0 s1 -> Some (Int_set.union s0 s1))
        x.pos_s_of_word_ci
        y.pos_s_of_word_ci;
    loc_of_pos =
      Int_map.union (fun _k x _ -> Some x)
        x.loc_of_pos
        y.loc_of_pos;
    start_end_inc_pos_of_line_loc =
      Line_loc_map.union (fun _k (start_x, end_inc_x) (start_y, end_inc_y) ->
          Some (min start_x start_y, max end_inc_x end_inc_y))
        x.start_end_inc_pos_of_line_loc
        y.start_end_inc_pos_of_line_loc;
    word_ci_of_pos =
      Int_map.union (fun _k x _ -> Some x)
        x.word_ci_of_pos
        y.word_ci_of_pos;
    word_of_pos =
      Int_map.union (fun _k x _ -> Some x)
        x.word_of_pos
        y.word_of_pos;
    line_count_of_page =
      Int_map.union (fun _k x y -> Some (max x y))
      x.line_count_of_page
      y.line_count_of_page;
    page_count = max x.page_count y.page_count;
  }

let words_of_lines
    (s : (Line_loc.t * string) Seq.t)
  : multi_indexed_word Seq.t =
  s
  |> Seq.flat_map (fun ({ Line_loc.page_num; line_num_in_page }, s) ->
      let seq = Tokenize.f_with_pos ~drop_spaces:false s in
      if Seq.is_empty seq then (
        let empty_word = ({ page_num; line_num_in_page; pos_in_line = 0 }, "") in
        Seq.return empty_word
      ) else (
        Seq.map (fun (pos_in_line, word) ->
            ({ page_num; line_num_in_page; pos_in_line }, word))
          seq
      )
    )
  |> Seq.mapi (fun pos (loc, word) ->
      { pos; loc; word })

let of_chunk (arr : chunk) : t =
  Array.fold_left
    (fun
      { pos_s_of_word_ci;
        loc_of_pos;
        start_end_inc_pos_of_line_loc;
        word_ci_of_pos;
        word_of_pos;
        line_count_of_page;
        page_count;
      }
      { pos; loc; word } ->
      let line_loc = Line_loc.of_loc loc in
      let word_ci = String.lowercase_ascii word in
      let index_of_word = Word_db.add word in
      let index_of_word_ci = Word_db.add word_ci in
      let pos_s = Option.value ~default:Int_set.empty
          (Int_map.find_opt index_of_word_ci pos_s_of_word_ci)
                  |> Int_set.add pos
      in
      let start_end_inc_pos =
        match Line_loc_map.find_opt line_loc start_end_inc_pos_of_line_loc with
        | None -> (pos, pos)
        | Some (x, y) -> (min x pos, max y pos)
      in
      let cur_page_line_count =
        Option.value ~default:0
        (Int_map.find_opt loc.page_num line_count_of_page)
      in
      let page_count = max page_count (loc.page_num + 1) in
      { pos_s_of_word_ci = Int_map.add index_of_word_ci pos_s pos_s_of_word_ci;
        loc_of_pos = Int_map.add pos loc loc_of_pos;
        start_end_inc_pos_of_line_loc =
          Line_loc_map.add line_loc start_end_inc_pos start_end_inc_pos_of_line_loc;
        word_ci_of_pos = Int_map.add pos index_of_word_ci word_ci_of_pos;
        word_of_pos = Int_map.add pos index_of_word word_of_pos;
        line_count_of_page =
          Int_map.add loc.page_num (max cur_page_line_count (loc.line_num_in_page + 1)) line_count_of_page;
        page_count;
      }
    )
    empty
    arr

let chunks_of_words (s : multi_indexed_word Seq.t) : chunk Seq.t =
  OSeq.chunks !Params.index_chunk_word_count s

let of_seq (s : (Line_loc.t * string) Seq.t) : t =
  let indices =
    s
    |> words_of_lines
    |> chunks_of_words
    |> List.of_seq
    |> Eio.Fiber.List.map (fun chunk ->
        Task_pool.run (fun () -> of_chunk chunk))
  in
  List.fold_left (fun acc index ->
      union acc index
    )
    empty
    indices

let word_ci_of_pos pos t =
  Word_db.word_of_index
    (Int_map.find pos t.word_ci_of_pos)

let word_of_pos pos t =
  Word_db.word_of_index
    (Int_map.find pos t.word_of_pos)

let word_ci_and_pos_s ?range_inc t : (string * Int_set.t) Seq.t =
  match range_inc with
  | None -> (
      Int_map.to_seq t.pos_s_of_word_ci
      |> Seq.map (fun (i, s) -> (Word_db.word_of_index i, s))
    )
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
      |> Seq.map (fun index ->
          (Word_db.word_of_index index, Int_map.find index t.pos_s_of_word_ci)
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

let words_of_line_loc line_loc t : string Seq.t =
  let (start, end_inc) =
    Line_loc_map.find line_loc t.start_end_inc_pos_of_line_loc
  in
  OSeq.(start -- end_inc)
  |> Seq.map (fun pos -> word_of_pos pos t)

let line_of_line_loc line_loc t =
  words_of_line_loc line_loc t
  |> List.of_seq
  |> String.concat ""

let loc_of_pos pos t : loc =
  Int_map.find pos t.loc_of_pos

let line_count_of_page page t : int =
  Int_map.find page t.line_count_of_page

let line_loc_seq ~(start : Line_loc.t) ~(end_inc : Line_loc.t) (t : t) =
  let start_page = start.page_num in
  let end_inc_page = end_inc.page_num in
  let rec aux cur_page end_inc_page =
    if cur_page > end_inc_page then
      Seq.Nil
    else (
    let line_count = line_count_of_page cur_page t in
    let start_line_num =
      if cur_page = start_page then
        start.line_num_in_page
      else
        0
    in
    let end_inc_line_num =
      if cur_page = end_inc_page then
        end_inc.line_num_in_page
      else
        line_count - 1
    in
    let s =
    OSeq.(start_line_num -- end_inc_line_num)
  |> Seq.map (fun line_num_in_page ->
      { Line_loc.page_num = cur_page; line_num_in_page }
      )
    in
    Seq.append s (fun () -> aux (cur_page + 1) end_inc_page) ()
    )
  in
  fun () -> aux start_page end_inc_page

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
        (not (String.equal indexed_word ""))
        &&
        (not (String.for_all Parser_components.is_space indexed_word))
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
      (phrase : Search_phrase.t)
      (t : t)
    : int list Seq.t =
    if Search_phrase.is_empty phrase then
      Seq.empty
    else (
      match List.combine phrase.phrase phrase.fuzzy_index with
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
              max
                1
                (
                  (Params.search_result_limit + possible_start_count - 1) / possible_start_count
                )
            in
            possible_starts
            |> Eio.Fiber.List.map (fun pos ->
                Task_pool.run
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
    (phrase : Search_phrase.t)
    (t : t)
  : Search_result.t array =
  let arr =
    Search.search phrase t
    |> Seq.map (fun l ->
        Search_result.make
          ~search_phrase:phrase.phrase
          ~found_phrase:(List.map
                           (fun pos ->
                              (pos,
                               word_ci_of_pos pos t,
                               word_of_pos pos t
                              )
                           ) l)
      )
    |> Array.of_seq
  in
  Array.sort Search_result.compare arr;
  arr
