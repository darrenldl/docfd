module Line_loc = struct
  type t = {
    page_num : int;
    line_num_in_page : int;
    global_line_num : int;
  }
  [@@deriving eq]

  let page_num t = t.page_num

  let line_num_in_page t = t.line_num_in_page

  let global_line_num t = t.global_line_num

  let compare (x : t) (y : t) =
    Int.compare x.global_line_num y.global_line_num

  let to_json (t : t) : Yojson.Safe.t =
    `List [ `Int t.page_num; `Int t.line_num_in_page; `Int t.global_line_num ]

  let of_json (json : Yojson.Safe.t) : t option =
    match json with
    | `List [ `Int page_num; `Int line_num_in_page; `Int global_line_num ] ->
      Some { page_num; line_num_in_page; global_line_num }
    | _ -> None
end

module Loc = struct
  type t = {
    line_loc : Line_loc.t;
    pos_in_line : int;
  }
  [@@deriving eq]

  let line_loc t = t.line_loc

  let pos_in_line t =  t.pos_in_line

  let to_json (t : t) : Yojson.Safe.t =
    `List [ Line_loc.to_json t.line_loc; `Int t.pos_in_line ]

  let of_json (json : Yojson.Safe.t) : t option =
    match json with
    | `List [ line_loc; `Int pos_in_line ] -> (
        match Line_loc.of_json line_loc with
        | None -> None
        | Some line_loc -> Some { line_loc; pos_in_line }
      )
    | _ -> None
end

module Raw = struct
  type t = {
    word_db : Word_db.t;
    pos_s_of_word_ci : Int_set.t Int_map.t;
    loc_of_pos : Loc.t Int_map.t;
    line_loc_of_global_line_num : Line_loc.t Int_map.t;
    start_end_inc_pos_of_global_line_num : (int * int) Int_map.t;
    start_end_inc_pos_of_page_num : (int * int) Int_map.t;
    word_ci_of_pos : int Int_map.t;
    word_of_pos : int Int_map.t;
    line_count_of_page_num : int Int_map.t;
    page_count : int;
    global_line_count : int;
  }

  type multi_indexed_word = {
    pos : int;
    loc : Loc.t;
    word : string;
  }

  type chunk = multi_indexed_word array

  let make () : t = {
    word_db = Word_db.make ();
    pos_s_of_word_ci = Int_map.empty;
    loc_of_pos = Int_map.empty;
    line_loc_of_global_line_num = Int_map.empty;
    start_end_inc_pos_of_global_line_num = Int_map.empty;
    start_end_inc_pos_of_page_num = Int_map.empty;
    word_ci_of_pos = Int_map.empty;
    word_of_pos = Int_map.empty;
    line_count_of_page_num = Int_map.empty;
    page_count = 0;
    global_line_count = 0;
  }

  let union (x : t) (y : t) =
    {
      word_db = Word_db.make ();
      pos_s_of_word_ci =
        Int_map.union (fun _k s0 s1 -> Some (Int_set.union s0 s1))
          x.pos_s_of_word_ci
          y.pos_s_of_word_ci;
      loc_of_pos =
        Int_map.union (fun _k x _ -> Some x)
          x.loc_of_pos
          y.loc_of_pos;
      line_loc_of_global_line_num =
        Int_map.union (fun _k x _ -> Some x)
          x.line_loc_of_global_line_num
          y.line_loc_of_global_line_num;
      start_end_inc_pos_of_global_line_num =
        Int_map.union (fun _k (start_x, end_inc_x) (start_y, end_inc_y) ->
            Some (min start_x start_y, max end_inc_x end_inc_y))
          x.start_end_inc_pos_of_global_line_num
          y.start_end_inc_pos_of_global_line_num;
      start_end_inc_pos_of_page_num =
        Int_map.union (fun _k (start_x, end_inc_x) (start_y, end_inc_y) ->
            Some (min start_x start_y, max end_inc_x end_inc_y))
          x.start_end_inc_pos_of_page_num
          y.start_end_inc_pos_of_page_num;
      word_ci_of_pos =
        Int_map.union (fun _k x _ -> Some x)
          x.word_ci_of_pos
          y.word_ci_of_pos;
      word_of_pos =
        Int_map.union (fun _k x _ -> Some x)
          x.word_of_pos
          y.word_of_pos;
      line_count_of_page_num =
        Int_map.union (fun _k x y -> Some (max x y))
          x.line_count_of_page_num
          y.line_count_of_page_num;
      page_count = max x.page_count y.page_count;
      global_line_count = max x.global_line_count y.global_line_count;
    }

  let words_of_lines
      (s : (Line_loc.t * string) Seq.t)
    : multi_indexed_word Seq.t =
    s
    |> Seq.flat_map (fun (line_loc, s) ->
        let seq = Tokenize.tokenize_with_pos ~drop_spaces:false s in
        if Seq.is_empty seq then (
          let empty_word = ({ Loc.line_loc; pos_in_line = 0 }, "") in
          Seq.return empty_word
        ) else (
          Seq.map (fun (pos_in_line, word) ->
              ({ Loc.line_loc; pos_in_line }, word))
            seq
        )
      )
    |> Seq.mapi (fun pos (loc, word) ->
        { pos; loc; word })

  type shared_word_db = {
    lock : Mutex.t;
    word_db : Word_db.t;
  }

  let of_chunk (shared_word_db : shared_word_db) (arr : chunk) : t =
    Array.fold_left
      (fun
        { word_db = dummy_word_db;
          pos_s_of_word_ci;
          loc_of_pos;
          line_loc_of_global_line_num;
          start_end_inc_pos_of_global_line_num;
          start_end_inc_pos_of_page_num;
          word_ci_of_pos;
          word_of_pos;
          line_count_of_page_num;
          page_count;
          global_line_count;
        }
        { pos; loc; word } ->
        let word_ci = String.lowercase_ascii word in

        Mutex.lock shared_word_db.lock;
        let index_of_word =
          Word_db.add shared_word_db.word_db word
        in
        let index_of_word_ci =
          Word_db.add shared_word_db.word_db word_ci
        in
        Mutex.unlock shared_word_db.lock;

        let line_loc = loc.Loc.line_loc in
        let global_line_num = line_loc.global_line_num in
        let page_num = line_loc.page_num in
        let pos_s =
          Int_map.find_opt index_of_word_ci pos_s_of_word_ci
          |> Option.value ~default:Int_set.empty
          |> Int_set.add pos
        in
        let cur_page_line_count =
          Option.value ~default:0
            (Int_map.find_opt page_num line_count_of_page_num)
        in
        { word_db = dummy_word_db;
          pos_s_of_word_ci = Int_map.add index_of_word_ci pos_s pos_s_of_word_ci;
          loc_of_pos = Int_map.add pos loc loc_of_pos;
          line_loc_of_global_line_num =
            Int_map.add global_line_num line_loc line_loc_of_global_line_num;
          start_end_inc_pos_of_global_line_num =
            Int_map.add
              global_line_num
              (match Int_map.find_opt global_line_num start_end_inc_pos_of_global_line_num with
               | None -> (pos, pos)
               | Some (x, y) -> (min x pos, max y pos))
              start_end_inc_pos_of_global_line_num;
          start_end_inc_pos_of_page_num =
            Int_map.add
              page_num
              (match Int_map.find_opt page_num start_end_inc_pos_of_page_num with
               | None -> (pos, pos)
               | Some (x, y) -> (min x pos, max y pos))
              start_end_inc_pos_of_page_num;
          word_ci_of_pos = Int_map.add pos index_of_word_ci word_ci_of_pos;
          word_of_pos = Int_map.add pos index_of_word word_of_pos;
          line_count_of_page_num =
            Int_map.add line_loc.page_num (max cur_page_line_count (line_loc.line_num_in_page + 1)) line_count_of_page_num;
          page_count = max page_count (line_loc.page_num + 1);
          global_line_count = max global_line_count (global_line_num + 1);
        }
      )
      (make ())
      arr

  let chunks_of_words (s : multi_indexed_word Seq.t) : chunk Seq.t =
    OSeq.chunks !Params.index_chunk_token_count s

  let of_seq pool (s : (Line_loc.t * string) Seq.t) : t =
    let shared_word_db : shared_word_db =
      { lock = Mutex.create ();
        word_db = Word_db.make ();
      }
    in
    let indices =
      s
      |> Seq.map (fun (line_loc, s) -> (line_loc, Misc_utils.sanitize_string s))
      |> words_of_lines
      |> chunks_of_words
      |> List.of_seq
      |> Task_pool.map_list pool (fun chunk ->
          of_chunk shared_word_db chunk)
    in
    let res =
      List.fold_left (fun acc index ->
          union acc index
        )
        (make ())
        indices
    in
    { res with word_db = shared_word_db.word_db }

  let of_lines pool (s : string Seq.t) : t =
    s
    |> Seq.mapi (fun global_line_num line ->
        ({ Line_loc.page_num = 0; line_num_in_page = global_line_num; global_line_num }, line)
      )
    |> of_seq pool

  let of_pages pool (s : string list Seq.t) : t =
    s
    |> Seq.mapi (fun page_num page ->
        (page_num, page)
      )
    |> Seq.flat_map (fun (page_num, page) ->
        match page with
        | [] -> (
            let empty_line = ({ Line_loc.page_num; line_num_in_page = 0; global_line_num = 0 }, "") in
            Seq.return empty_line
          )
        | _ -> (
            List.to_seq page
            |> Seq.mapi (fun line_num_in_page line ->
                ({ Line_loc.page_num; line_num_in_page; global_line_num = 0 }, line)
              )
          )
      )
    |> Seq.mapi (fun global_line_num ((line_loc : Line_loc.t), line) ->
        ({ line_loc with global_line_num }, line)
      )
    |> of_seq pool
end

type t = {
  word_db : Word_db.t;
  pos_s_of_word_ci : Int_set.t Int_map.t;
  loc_of_pos : Loc.t CCVector.ro_vector;
  line_loc_of_global_line_num : Line_loc.t CCVector.ro_vector;
  start_end_inc_pos_of_global_line_num : (int * int) CCVector.ro_vector;
  start_end_inc_pos_of_page_num : (int * int) CCVector.ro_vector;
  word_ci_of_pos : int CCVector.ro_vector;
  word_of_pos : int CCVector.ro_vector;
  line_count_of_page_num : int CCVector.ro_vector;
  page_count : int;
  global_line_count : int;
}

let make () : t = {
  word_db = Word_db.make ();
  pos_s_of_word_ci = Int_map.empty;
  loc_of_pos = CCVector.(freeze (create ()));
  line_loc_of_global_line_num = CCVector.(freeze (create ()));
  start_end_inc_pos_of_global_line_num = CCVector.(freeze (create ()));
  start_end_inc_pos_of_page_num = CCVector.(freeze (create ()));
  word_ci_of_pos = CCVector.(freeze (create ()));
  word_of_pos = CCVector.(freeze (create ()));
  line_count_of_page_num = CCVector.(freeze (create ()));
  page_count = 0;
  global_line_count = 0;
}

let equal (x : t) (y : t) =
  let equal_int_int (x0, y0) (x1, y1) =
    x0 = x1 && y0 = y1
  in
  Word_db.equal x.word_db y.word_db
  &&
  Int_map.equal
    Int_set.equal
    x.pos_s_of_word_ci y.pos_s_of_word_ci
  &&
  CCVector.equal Loc.equal x.loc_of_pos y.loc_of_pos
  &&
  CCVector.equal
    Line_loc.equal
    x.line_loc_of_global_line_num
    y.line_loc_of_global_line_num
  &&
  CCVector.equal
    (fun (x0, y0) (x1, y1) -> x0 = x1 && y0 = y1)
    x.start_end_inc_pos_of_global_line_num
    y.start_end_inc_pos_of_global_line_num
  &&
  CCVector.equal
    equal_int_int
    x.start_end_inc_pos_of_page_num
    y.start_end_inc_pos_of_page_num
  &&
  CCVector.equal
    Int.equal
    x.word_ci_of_pos
    y.word_ci_of_pos
  &&
  CCVector.equal
    Int.equal
    x.word_of_pos
    y.word_of_pos
  &&
  CCVector.equal
    Int.equal
    x.line_count_of_page_num
    y.line_count_of_page_num
  &&
  x.page_count = y.page_count
  &&
  x.global_line_count = y.global_line_count

let global_line_count t = t.global_line_count

let page_count t = t.page_count

let ccvector_of_int_map
  : 'a . 'a Int_map.t -> 'a CCVector.ro_vector =
  fun m ->
  Int_map.to_seq m
  |> Seq.map snd
  |> CCVector.of_seq
  |> CCVector.freeze

let of_raw (raw : Raw.t) : t =
  let line_loc_of_global_line_num =
    ccvector_of_int_map raw.Raw.line_loc_of_global_line_num
  in
  let start_end_inc_pos_of_global_line_num =
    ccvector_of_int_map raw.Raw.start_end_inc_pos_of_global_line_num
  in
  let start_end_inc_pos_of_page_num =
    ccvector_of_int_map raw.Raw.start_end_inc_pos_of_page_num
  in
  let page_count = raw.Raw.page_count in
  let global_line_count = raw.Raw.global_line_count in
  assert (global_line_count = CCVector.length line_loc_of_global_line_num);
  assert (global_line_count = CCVector.length start_end_inc_pos_of_global_line_num);
  assert (page_count = CCVector.length start_end_inc_pos_of_page_num);
  {
    word_db = raw.Raw.word_db;
    pos_s_of_word_ci = raw.Raw.pos_s_of_word_ci;
    loc_of_pos =
      ccvector_of_int_map raw.Raw.loc_of_pos;
    line_loc_of_global_line_num;
    start_end_inc_pos_of_global_line_num;
    start_end_inc_pos_of_page_num;
    word_ci_of_pos = ccvector_of_int_map raw.Raw.word_ci_of_pos;
    word_of_pos = ccvector_of_int_map raw.Raw.word_of_pos;
    line_count_of_page_num = ccvector_of_int_map raw.Raw.line_count_of_page_num;
    page_count;
    global_line_count;
  }

let of_lines pool s =
  Raw.of_lines pool s
  |> of_raw

let of_pages pool s =
  Raw.of_pages pool s
  |> of_raw

let word_ci_of_pos pos (t : t) : string =
  Word_db.word_of_index t.word_db (CCVector.get t.word_ci_of_pos pos)

let word_of_pos pos (t : t) : string =
  Word_db.word_of_index t.word_db (CCVector.get t.word_of_pos pos)

let word_ci_and_pos_s ?range_inc (t : t) : (string * Int_set.t) Seq.t =
  match range_inc with
  | None -> (
      Int_map.to_seq t.pos_s_of_word_ci
      |> Seq.map (fun (i, s) -> (Word_db.word_of_index t.word_db i, s))
    )
  | Some (start, end_inc) -> (
      assert (start <= end_inc);
      let start = max 0 start in
      let end_inc = min (CCVector.length t.word_ci_of_pos - 1) end_inc in
      let words_to_consider = ref Int_set.empty in
      for pos = start to end_inc do
        let index = CCVector.get t.word_ci_of_pos pos in
        words_to_consider := Int_set.add index !words_to_consider
      done;
      Int_set.to_seq !words_to_consider
      |> Seq.map (fun index ->
          (Word_db.word_of_index t.word_db index, Int_map.find index t.pos_s_of_word_ci)
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

let words_of_global_line_num x t : string Seq.t =
  if x >= global_line_count t then (
    invalid_arg "Index.words_of_global_line_num: global_line_num out of range"
  ) else (
    let (start, end_inc) =
      CCVector.get t.start_end_inc_pos_of_global_line_num x
    in
    OSeq.(start -- end_inc)
    |> Seq.map (fun pos -> word_of_pos pos t)
  )

let words_of_page_num x t : string Seq.t =
  if x >= page_count t then (
    invalid_arg "Index.words_of_page_num: page_num out of range"
  ) else (
    let (start, end_inc) =
      CCVector.get t.start_end_inc_pos_of_page_num x
    in
    OSeq.(start -- end_inc)
    |> Seq.map (fun pos -> word_of_pos pos t)
  )

let line_of_global_line_num x t =
  if x >= global_line_count t then (
    invalid_arg "Index.line_of_global_line_num: global_line_num out of range"
  ) else (
    words_of_global_line_num x t
    |> List.of_seq
    |> String.concat ""
  )

let line_loc_of_global_line_num x t =
  if x >= global_line_count t then (
    invalid_arg "Index.line_loc_of_global_line_num: global_line_num out of range"
  ) else (
    CCVector.get t.line_loc_of_global_line_num x
  )

let loc_of_pos pos t : Loc.t =
  CCVector.get t.loc_of_pos pos

let line_count_of_page_num page t : int =
  CCVector.get t.line_count_of_page_num page

let start_end_inc_pos_of_global_line_num x t =
  if x >= global_line_count t then (
    invalid_arg "Index.start_end_inc_pos_of_global_line_num: global_line_num out of range"
  ) else (
    CCVector.get t.start_end_inc_pos_of_global_line_num x
  )

module Search = struct
  module ET = Search_phrase.Enriched_token

  let usable_positions
      ?within
      ?around_pos
      ~(consider_edit_dist : bool)
      (token : Search_phrase.Enriched_token.t)
      (t : t)
    : int Seq.t =
    Eio.Fiber.yield ();
    let match_typ = ET.match_typ token in
    let word_ci_and_positions_to_consider =
      match around_pos with
      | None -> word_ci_and_pos_s t
      | Some around_pos -> (
          let start, end_inc =
            if ET.is_linked_to_prev token then (
              match match_typ with
              | `Fuzzy ->
                (around_pos - !Params.max_linked_token_search_dist,
                 around_pos + !Params.max_linked_token_search_dist)
              | `Exact | `Prefix | `Suffix ->
                (around_pos + 1,
                 around_pos + 1)
            ) else (
              (around_pos - !Params.max_token_search_dist,
               around_pos + !Params.max_token_search_dist)
            )
          in
          let start, end_inc =
            match within with
            | None -> (start, end_inc)
            | Some (within_start_pos, within_end_inc_pos) -> (
                (max within_start_pos start, min within_end_inc_pos end_inc)
              )
          in
          word_ci_and_pos_s ~range_inc:(start, end_inc) t
        )
    in
    let non_fuzzy_filter_pos_s
        ~search_word
        ~search_word_ci
        ~indexed_word_ci
        (match_typ : [ `Exact | `Prefix | `Suffix ])
        (pos_s : Int_set.t)
      : Int_set.t option
      =
      let f_ci =
        match match_typ with
        | `Exact -> String.equal search_word_ci
        | `Prefix -> CCString.prefix ~pre:search_word_ci
        | `Suffix -> CCString.suffix ~suf:search_word_ci
      in
      let f =
        match match_typ with
        | `Exact -> String.equal search_word
        | `Prefix -> CCString.prefix ~pre:search_word
        | `Suffix -> CCString.suffix ~suf:search_word
      in
      if f_ci indexed_word_ci then (
        if String.equal search_word search_word_ci then (
          Some pos_s
        ) else (
          pos_s
          |> Int_set.filter (fun pos ->
              let indexed_word = word_of_pos pos t in
              f indexed_word
            )
          |> Option.some
        )
      ) else (
        None
      )
    in
    word_ci_and_positions_to_consider
    |> Seq.filter (fun (indexed_word_ci, _pos_s) ->
        Eio.Fiber.yield ();
        String.length indexed_word_ci > 0
      )
    |> Seq.filter_map (
      match ET.data token with
      | `Explicit_spaces -> (
          fun (indexed_word_ci, pos_s) ->
            Eio.Fiber.yield ();
            if Parser_components.is_space indexed_word_ci.[0] then
              Some pos_s
            else
              None
        )
      | `String search_word -> (
          fun (indexed_word_ci, pos_s) ->
            Eio.Fiber.yield ();
            let search_word_ci =
              String.lowercase_ascii search_word
            in
            let indexed_word_ci_len = String.length indexed_word_ci in
            if Parser_components.is_possibly_utf_8 indexed_word_ci.[0] then (
              if String.equal search_word_ci indexed_word_ci then (
                Some pos_s
              ) else (
                None
              )
            ) else (
              match match_typ with
              | `Fuzzy -> (
                  if
                    String.equal search_word_ci indexed_word_ci
                    || CCString.find ~sub:search_word_ci indexed_word_ci >= 0
                    || (indexed_word_ci_len >= 2
                        && CCString.find ~sub:indexed_word_ci search_word_ci >= 0)
                    || (consider_edit_dist
                        && Misc_utils.first_n_chars_of_string_contains ~n:5 indexed_word_ci search_word_ci.[0]
                        && Spelll.match_with (ET.automaton token) indexed_word_ci)
                  then (
                    Some pos_s
                  ) else (
                    None
                  )
                )
              | `Exact | `Prefix | `Suffix as m -> (
                  non_fuzzy_filter_pos_s
                    ~search_word
                    ~search_word_ci
                    ~indexed_word_ci
                    (m :> [ `Exact | `Prefix | `Suffix ])
                    pos_s
                )
            )
        )
    )
    |> Seq.flat_map (fun pos_s ->
        Eio.Fiber.yield ();
        Int_set.to_seq pos_s)

  let search_around_pos
      ~consider_edit_dist
      ~(within : (int * int) option)
      (around_pos : int)
      (l : Search_phrase.Enriched_token.t list)
      (t : t)
    : int list Seq.t =
    let rec aux around_pos l =
      Eio.Fiber.yield ();
      match l with
      | [] -> Seq.return []
      | token :: rest -> (
          usable_positions
            ?within
            ~around_pos
            ~consider_edit_dist
            token
            t
          |> Seq.flat_map (fun pos ->
              aux pos rest
              |> Seq.map (fun l -> pos :: l)
            )
        )
    in
    aux around_pos l

  let search_result_heap_merge_with_yield x y =
    Eio.Fiber.yield ();
    Search_result_heap.merge x y

  let search_single
      pool
      stop_signal
      ~within_same_line
      ~consider_edit_dist
      (phrase : Search_phrase.t)
      (t : t)
    : Search_result_heap.t =
    Eio.Fiber.yield ();
    if Search_phrase.is_empty phrase then (
      Search_result_heap.empty
    ) else (
      match Search_phrase.enriched_tokens phrase with
      | [] -> failwith "unexpected case"
      | first_word :: rest -> (
          Eio.Fiber.yield ();
          let possible_start_count, possible_starts =
            usable_positions ~consider_edit_dist first_word t
            |> Misc_utils.length_and_list_of_seq
          in
          if possible_start_count = 0 then
            Search_result_heap.empty
          else (
            let search_limit_per_start =
              max
                Params.search_result_min_per_start
                (
                  (Params.default_search_result_total_per_document + possible_start_count - 1) / possible_start_count
                )
            in
            let search_chunk_size =
              max 10 (possible_start_count / Task_pool.size)
            in
            possible_starts
            |> CCList.chunks search_chunk_size
            |> Task_pool.map_list pool (fun (pos_list : int list) : Search_result_heap.t ->
                Eio.Fiber.first
                  (fun () ->
                     Stop_signal.await stop_signal;
                     Search_result_heap.empty)
                  (fun () ->
                     Eio.Fiber.yield ();
                     pos_list
                     |> List.map (fun pos ->
                         Eio.Fiber.yield ();
                         let within =
                           if within_same_line then (
                             let loc = loc_of_pos pos t in
                             Some (start_end_inc_pos_of_global_line_num loc.line_loc.global_line_num t)
                           ) else (
                             None
                           )
                         in
                         search_around_pos ~consider_edit_dist ~within pos rest t
                         |> Seq.map (fun l -> pos :: l)
                         |> Seq.map (fun (l : int list) ->
                             Eio.Fiber.yield ();
                             let opening_closing_symbol_pairs = List.map (fun pos -> word_of_pos pos t) l
                                                                |>  Misc_utils.opening_closing_symbol_pairs
                             in
                             let found_phrase_opening_closing_symbol_match_count =
                               let pos_arr : int array = Array.of_list l in
                               List.fold_left (fun total (x, y) ->
                                   let pos_x = pos_arr.(x) in
                                   let pos_y = pos_arr.(y) in
                                   let c_x = String.get (word_of_pos pos_x t) 0 in
                                   let c_y = String.get (word_of_pos pos_y t) 0 in
                                   assert (List.exists (fun (x, y) -> c_x = x && c_y = y)
                                             Params.opening_closing_symbols);
                                   if pos_x < pos_y then (
                                     let outstanding_opening_symbol_count =
                                       OSeq.(pos_x + 1 --^ pos_y)
                                       |> Seq.fold_left (fun count pos ->
                                           match count with
                                           | Some count -> (
                                               let word = word_of_pos pos t in
                                               if String.length word = 1 then (
                                                 if String.get word 0 = c_x then (
                                                   Some (count + 1)
                                                 ) else if String.get word 0 = c_y then (
                                                   if count = 0 then (
                                                     None
                                                   ) else (
                                                     Some (count - 1)
                                                   )
                                                 ) else (
                                                   Some count
                                                 )
                                               ) else (
                                                 Some count
                                               )
                                             )
                                           | None -> None
                                         )
                                         (Some 0)
                                     in
                                     match outstanding_opening_symbol_count with
                                     | Some 0 -> total + 1
                                     | _ -> total
                                   ) else (
                                     total
                                   )
                                 )
                                 0
                                 opening_closing_symbol_pairs
                             in
                             Search_result.make
                               phrase
                               ~found_phrase:(List.map
                                                (fun pos ->
                                                   Search_result.{
                                                     found_word_pos = pos;
                                                     found_word_ci = word_ci_of_pos pos t;
                                                     found_word = word_of_pos pos t;
                                                   }) l)
                               ~found_phrase_opening_closing_symbol_match_count
                           )
                         |> Seq.fold_left (fun best_results r ->
                             Eio.Fiber.yield ();
                             let best_results = Search_result_heap.add best_results r in
                             if Search_result_heap.size best_results <= search_limit_per_start then (
                               best_results
                             ) else (
                               let x = Search_result_heap.find_min_exn best_results in
                               Search_result_heap.delete_one Search_result.equal x best_results
                             )
                           )
                           Search_result_heap.empty
                       )
                     |> List.fold_left search_result_heap_merge_with_yield Search_result_heap.empty
                  )
              )
            |> List.fold_left search_result_heap_merge_with_yield Search_result_heap.empty
          )
        )
    )

  let search
      pool
      stop_signal
      ~within_same_line
      ~consider_edit_dist
      (exp : Search_exp.t)
      (t : t)
    : Search_result_heap.t =
    Search_exp.flattened exp
    |> List.to_seq
    |> Seq.map (fun phrase -> search_single pool stop_signal ~within_same_line ~consider_edit_dist phrase t)
    |> Seq.fold_left search_result_heap_merge_with_yield Search_result_heap.empty
end

let search
    pool
    stop_signal
    ~within_same_line
    (exp : Search_exp.t)
    (t : t)
  : Search_result.t array =
  let arr =
    Search.search pool stop_signal ~within_same_line ~consider_edit_dist:true exp t
    |> Search_result_heap.to_seq
    |> Array.of_seq
  in
  Array.sort Search_result.compare_relevance arr;
  arr

module Compressed = struct
  type t' = t

  type t = {
    word_db : Word_db.t;
    pos_s_of_word_ci : Int_set.t Int_map.t;
    loc_of_pos : Loc.t CCVector.ro_vector;
    line_loc_of_global_line_num : Line_loc.t CCVector.ro_vector;
    start_pos_of_global_line_num : int CCVector.ro_vector;
    start_pos_of_page_num : int CCVector.ro_vector;
    word_ci_of_pos : int CCVector.ro_vector;
    word_of_pos : int CCVector.ro_vector;
    line_count_of_page_num : int CCVector.ro_vector;
    page_count : int;
    global_line_count : int;
  }

  let of_uncompressed (t' : t') : t =
    {
      word_db = t'.word_db;
      pos_s_of_word_ci = t'.pos_s_of_word_ci;
      loc_of_pos = t'.loc_of_pos;
      line_loc_of_global_line_num = t'.line_loc_of_global_line_num;
      start_pos_of_global_line_num =
        CCVector.map fst t'.start_end_inc_pos_of_global_line_num;
      start_pos_of_page_num =
        CCVector.map fst t'.start_end_inc_pos_of_page_num;
      word_ci_of_pos = t'.word_ci_of_pos;
      word_of_pos = t'.word_of_pos;
      line_count_of_page_num = t'.line_count_of_page_num;
      page_count = t'.page_count;
      global_line_count = t'.global_line_count;
    }

  let to_uncompressed (t : t) : t' =
    let decompress_contiguous_interval_ccvector
        ~end_inc_of_last
        (vec : int CCVector.ro_vector)
      : (int * int) CCVector.ro_vector =
      let len = CCVector.length vec in
      let last_index = len - 1 in
      CCVector.mapi (fun i x ->
          let y =
            if i < last_index then (
              CCVector.get vec (i + 1)
            ) else (
              end_inc_of_last
            )
          in
          (x, y)
        )
        vec
    in
    let last_pos =
      CCVector.length t.loc_of_pos - 1
    in
    {
      word_db = t.word_db;
      pos_s_of_word_ci = t.pos_s_of_word_ci;
      loc_of_pos = t.loc_of_pos;
      line_loc_of_global_line_num = t.line_loc_of_global_line_num;
      start_end_inc_pos_of_global_line_num =
        (decompress_contiguous_interval_ccvector
           ~end_inc_of_last:last_pos)
          t.start_pos_of_global_line_num;
      start_end_inc_pos_of_page_num =
        (decompress_contiguous_interval_ccvector
           ~end_inc_of_last:last_pos)
          t.start_pos_of_page_num;
      word_ci_of_pos = t.word_ci_of_pos;
      word_of_pos = t.word_of_pos;
      line_count_of_page_num = t.line_count_of_page_num;
      page_count = t.page_count;
      global_line_count = t.global_line_count;
    }

  let to_json (t : t) : Yojson.Safe.t =
    let json_of_int (x : int) = `Int x in
    (* let json_of_int_int ((x, y) : int * int) = `List [ `Int x; `Int y ] in *)
    let json_of_int_map
      : 'a . ('a -> Yojson.Safe.t) -> 'a Int_map.t -> Yojson.Safe.t =
      fun f m ->
        let l =
          Int_map.to_seq m
          |> Seq.map (fun (k, v) -> `List [ `Int k; f v ])
          |> List.of_seq
        in
        `List l
    in
    let json_of_ccvector
      : 'a . ('a -> Yojson.Safe.t) -> ('a, _) CCVector.t -> Yojson.Safe.t =
      fun f vec ->
        let l =
          CCVector.to_seq vec
          |> Seq.map f
          |> List.of_seq
        in
        `List l
    in
    let json_of_int_set (s : Int_set.t) =
      let l =
        Int_set.to_seq s
        |> Seq.map json_of_int
        |> List.of_seq
      in
      `List l
    in
    `Assoc [
      ("word_db",
       Word_db.to_json t.word_db);
      ("pos_s_of_word_ci",
       json_of_int_map json_of_int_set t.pos_s_of_word_ci);
      ("loc_of_pos",
       json_of_ccvector Loc.to_json t.loc_of_pos);
      ("line_loc_of_global_line_num",
       json_of_ccvector Line_loc.to_json t.line_loc_of_global_line_num);
      ("start_pos_of_global_line_num",
       json_of_ccvector json_of_int t.start_pos_of_global_line_num);
      ("start_pos_of_page_num",
       json_of_ccvector json_of_int t.start_pos_of_page_num);
      ("word_ci_of_pos",
       json_of_ccvector json_of_int t.word_ci_of_pos);
      ("word_of_pos",
       json_of_ccvector json_of_int t.word_of_pos);
      ("line_count_of_page_num",
       json_of_ccvector json_of_int t.line_count_of_page_num);
      ("page_count",
       `Int t.page_count);
      ("global_line_count",
       `Int t.global_line_count);
    ]

  let of_json (json : Yojson.Safe.t) : t option =
    let open Option_syntax in
    let int_of_json (json : Yojson.Safe.t) : int option =
      match json with
      | `Int x -> Some x
      | _ -> None
    in
    (*let int_int_of_json (json : Yojson.Safe.t) : (int * int) option =
      match json with
      | `List [ `Int x; `Int y ] -> Some (x, y)
      | _ -> None
      in *)
    let int_set_of_json (json : Yojson.Safe.t) : Int_set.t option =
      match json with
      | `List l -> (
          let exception Invalid in
          let s = ref Int_set.empty in
          try
            List.iter (fun x ->
                match int_of_json x with
                | None -> raise Invalid
                | Some x -> s := Int_set.add x !s
              ) l;
            Some !s
          with
          | Invalid -> None
        )
      | _ -> None
    in
    let ccvector_of_json
      : 'a . (Yojson.Safe.t -> 'a option) -> Yojson.Safe.t -> 'a CCVector.ro_vector option =
      fun f json ->
        match json with
        | `List l -> (
            let exception Invalid in
            let vec : 'a CCVector.vector = CCVector.create () in
            try
              List.iter (fun v ->
                  match f v with
                  | None -> raise Invalid
                  | Some (v : 'a) -> (
                      CCVector.push vec v
                    )
                ) l;
              Some (CCVector.freeze vec)
            with
            | Invalid -> None
          )
        | _ -> None
    in
    let int_map_of_json
      : 'a . (Yojson.Safe.t -> 'a option) -> Yojson.Safe.t -> 'a Int_map.t option =
      fun f json ->
        match json with
        | `List l -> (
            let exception Invalid in
            let m : 'a Int_map.t ref = ref Int_map.empty in
            try
              List.iter (fun v ->
                  match v with
                  | `List [ `Int k; v ] -> (
                      match f v with
                      | None -> raise Invalid
                      | Some (v : 'a) -> (
                          m := Int_map.add k v !m;
                        )
                    )
                  | _ -> raise Invalid
                ) l;
              Some !m
            with
            | Invalid -> None
          )
        | _ -> None
    in
    match json with
    | `Assoc l -> (
        let* word_db =
          let* x = List.assoc_opt "word_db" l in
          Word_db.of_json x
        in
        let* pos_s_of_word_ci =
          let* x = List.assoc_opt "pos_s_of_word_ci" l in
          int_map_of_json int_set_of_json x
        in
        let* loc_of_pos =
          let* x = List.assoc_opt "loc_of_pos" l in
          ccvector_of_json Loc.of_json x
        in
        let* line_loc_of_global_line_num =
          let* x = List.assoc_opt "line_loc_of_global_line_num" l in
          ccvector_of_json Line_loc.of_json x
        in
        let* start_pos_of_global_line_num =
          let* x = List.assoc_opt "start_pos_of_global_line_num" l in
          ccvector_of_json int_of_json x
        in
        let* start_pos_of_page_num =
          let* x = List.assoc_opt "start_pos_of_page_num" l in
          ccvector_of_json int_of_json x
        in
        let* word_ci_of_pos =
          let* x = List.assoc_opt "word_ci_of_pos" l in
          ccvector_of_json int_of_json x
        in
        let* word_of_pos =
          let* x = List.assoc_opt "word_of_pos" l in
          ccvector_of_json int_of_json x
        in
        let* line_count_of_page_num =
          let* x = List.assoc_opt "line_count_of_page_num" l in
          ccvector_of_json int_of_json x
        in
        let* page_count =
          let* x = List.assoc_opt "page_count" l in
          int_of_json x
        in
        let+ global_line_count =
          let* x = List.assoc_opt "global_line_count" l in
          int_of_json x
        in
        {
          word_db;
          pos_s_of_word_ci;
          loc_of_pos;
          line_loc_of_global_line_num;
          start_pos_of_global_line_num;
          start_pos_of_page_num;
          word_ci_of_pos;
          word_of_pos;
          line_count_of_page_num;
          page_count;
          global_line_count;
        }
      )
    | _ -> None
end

let to_compressed_string (t : t) : string =
  t
  |> Compressed.of_uncompressed
  |> Compressed.to_json
  |> Yojson.Safe.to_string
  |> GZIP.compress

let of_compressed_string (s : string) : t option =
  let open Option_syntax in
  let* s = GZIP.decompress s in
  try
    let s = Yojson.Safe.from_string s in
    let+ compressed = Compressed.of_json s in
    Compressed.to_uncompressed compressed
  with
  | _ -> None
