module Line_loc = struct
  type t = {
    page_num : int;
    line_num_in_page : int;
    global_line_num : int;
  }

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

module Line_loc_map = Map.Make (Line_loc)

module Loc = struct
  type t = {
    line_loc : Line_loc.t;
    pos_in_line : int;
  }

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
    global_line_num_of_line_loc : int Line_loc_map.t;
    start_end_inc_pos_of_global_line_num : (int * int) Int_map.t;
    word_ci_of_pos : int Int_map.t;
    word_of_pos : int Int_map.t;
    line_count_of_page : int Int_map.t;
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
    global_line_num_of_line_loc = Line_loc_map.empty;
    start_end_inc_pos_of_global_line_num = Int_map.empty;
    word_ci_of_pos = Int_map.empty;
    word_of_pos = Int_map.empty;
    line_count_of_page = Int_map.empty;
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
      global_line_num_of_line_loc =
        Line_loc_map.union (fun _k x _ -> Some x)
          x.global_line_num_of_line_loc
          y.global_line_num_of_line_loc;
      start_end_inc_pos_of_global_line_num =
        Int_map.union (fun _k (start_x, end_inc_x) (start_y, end_inc_y) ->
            Some (min start_x start_y, max end_inc_x end_inc_y))
          x.start_end_inc_pos_of_global_line_num
          y.start_end_inc_pos_of_global_line_num;
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
      global_line_count = max x.global_line_count y.global_line_count;
    }

  let words_of_lines
      (s : (Line_loc.t * string) Seq.t)
    : multi_indexed_word Seq.t =
    s
    |> Seq.flat_map (fun (line_loc, s) ->
        let seq = Tokenize.f_with_pos ~drop_spaces:false s in
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
          global_line_num_of_line_loc;
          start_end_inc_pos_of_global_line_num;
          word_ci_of_pos;
          word_of_pos;
          line_count_of_page;
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
        let pos_s = Option.value ~default:Int_set.empty
            (Int_map.find_opt index_of_word_ci pos_s_of_word_ci)
                    |> Int_set.add pos
        in
        let start_end_inc_pos =
          match Int_map.find_opt global_line_num start_end_inc_pos_of_global_line_num with
          | None -> (pos, pos)
          | Some (x, y) -> (min x pos, max y pos)
        in
        let cur_page_line_count =
          Option.value ~default:0
            (Int_map.find_opt line_loc.page_num line_count_of_page)
        in
        { word_db = dummy_word_db;
          pos_s_of_word_ci = Int_map.add index_of_word_ci pos_s pos_s_of_word_ci;
          loc_of_pos = Int_map.add pos loc loc_of_pos;
          line_loc_of_global_line_num =
            Int_map.add global_line_num line_loc line_loc_of_global_line_num;
          global_line_num_of_line_loc =
            Line_loc_map.add line_loc global_line_num global_line_num_of_line_loc;
          start_end_inc_pos_of_global_line_num =
            Int_map.add global_line_num start_end_inc_pos start_end_inc_pos_of_global_line_num;
          word_ci_of_pos = Int_map.add pos index_of_word_ci word_ci_of_pos;
          word_of_pos = Int_map.add pos index_of_word word_of_pos;
          line_count_of_page =
            Int_map.add line_loc.page_num (max cur_page_line_count (line_loc.line_num_in_page + 1)) line_count_of_page;
          page_count = max page_count (line_loc.page_num + 1);
          global_line_count = max global_line_count (global_line_num + 1);
        }
      )
      (make ())
      arr

  let chunks_of_words (s : multi_indexed_word Seq.t) : chunk Seq.t =
    OSeq.chunks !Params.index_chunk_word_count s

  let of_seq (s : (Line_loc.t * string) Seq.t) : t =
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
      |> Eio.Fiber.List.map (fun chunk ->
          Eio.Fiber.yield ();
          Task_pool.run (fun () -> of_chunk shared_word_db chunk))
    in
    let res =
      List.fold_left (fun acc index ->
          union acc index
        )
        (make ())
        indices
    in
    { res with word_db = shared_word_db.word_db }

  let of_lines (s : string Seq.t) : t =
    s
    |> Seq.mapi (fun global_line_num line ->
        ({ Line_loc.page_num = 0; line_num_in_page = global_line_num; global_line_num }, line)
      )
    |> of_seq

  let of_pages (s : string list Seq.t) : t =
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
    |> of_seq
end

type t = {
  word_db : Word_db.t;
  pos_s_of_word_ci : Int_set.t Int_map.t;
  loc_of_pos : Loc.t CCVector.ro_vector;
  line_loc_of_global_line_num : Line_loc.t CCVector.ro_vector;
  global_line_num_of_line_loc : int Line_loc_map.t;
  start_end_inc_pos_of_global_line_num : (int * int) CCVector.ro_vector;
  word_ci_of_pos : int CCVector.ro_vector;
  word_of_pos : int CCVector.ro_vector;
  line_count_of_page : int CCVector.ro_vector;
  page_count : int;
  global_line_count : int;
}

let make () : t = {
  word_db = Word_db.make ();
  pos_s_of_word_ci = Int_map.empty;
  loc_of_pos = CCVector.(freeze (create ()));
  line_loc_of_global_line_num = CCVector.(freeze (create ()));
  global_line_num_of_line_loc = Line_loc_map.empty;
  start_end_inc_pos_of_global_line_num = CCVector.(freeze (create ()));
  word_ci_of_pos = CCVector.(freeze (create ()));
  word_of_pos = CCVector.(freeze (create ()));
  line_count_of_page = CCVector.(freeze (create ()));
  page_count = 0;
  global_line_count = 0;
}

let global_line_count t = t.global_line_count

let ccvector_of_int_map
  : 'a . 'a Int_map.t -> 'a CCVector.ro_vector =
  fun m ->
  Int_map.to_seq m
  |> Seq.map snd
  |> CCVector.of_seq
  |> CCVector.freeze

let of_raw (raw : Raw.t) : t =
  {
    word_db = raw.Raw.word_db;
    pos_s_of_word_ci = raw.Raw.pos_s_of_word_ci;
    loc_of_pos =
      ccvector_of_int_map raw.Raw.loc_of_pos;
    line_loc_of_global_line_num =
      ccvector_of_int_map raw.Raw.line_loc_of_global_line_num;
    global_line_num_of_line_loc =
      raw.Raw.global_line_num_of_line_loc;
    start_end_inc_pos_of_global_line_num =
      ccvector_of_int_map raw.Raw.start_end_inc_pos_of_global_line_num;
    word_ci_of_pos = ccvector_of_int_map raw.Raw.word_ci_of_pos;
    word_of_pos = ccvector_of_int_map raw.Raw.word_of_pos;
    line_count_of_page = ccvector_of_int_map raw.Raw.line_count_of_page;
    page_count = raw.Raw.page_count;
    global_line_count = raw.Raw.global_line_count;
  }

let of_lines s =
  Raw.of_lines s
  |> of_raw

let of_pages s =
  Raw.of_pages s
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
  if x >= global_line_count t then
    invalid_arg "Index.words_of_global_line_num: global_line_num out of range"
  else (
    let (start, end_inc) =
      CCVector.get t.start_end_inc_pos_of_global_line_num x
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

let line_count_of_page page t : int =
  CCVector.get t.line_count_of_page page

module Search = struct
  let usable_positions
      ?around_pos
      ~eio_yield
      ~(consider_edit_dist : bool)
      ((search_word, dfa) : (string * Spelll.automaton))
      (t : t)
    : int Seq.t =
    let word_ci_and_positions_to_consider =
      match around_pos with
      | None -> word_ci_and_pos_s t
      | Some around_pos ->
        let start = around_pos - !Params.max_word_search_distance in
        let end_inc = around_pos + !Params.max_word_search_distance in
        word_ci_and_pos_s ~range_inc:(start, end_inc) t
    in
    let search_word_ci =
      String.lowercase_ascii search_word
    in
    word_ci_and_positions_to_consider
    |> Seq.filter (fun (indexed_word, _pos_s) ->
        if eio_yield then (
          Eio.Fiber.yield ();
        );
        (String.length indexed_word > 0)
        && (not (Parser_components.is_space indexed_word.[0]))
      )
    |> Seq.filter (fun (indexed_word, _pos_s) ->
        let indexed_word_len = String.length indexed_word in
        if Parser_components.is_possibly_utf_8 indexed_word.[0] then
          String.equal search_word_ci indexed_word
        else (
          String.equal search_word_ci indexed_word
          || CCString.find ~sub:search_word_ci indexed_word >= 0
          || (CCString.find ~sub:indexed_word search_word_ci >= 0
              && indexed_word_len >= 3)
          || (consider_edit_dist
              && Misc_utils.first_n_chars_of_string_contains ~n:5 indexed_word search_word_ci.[0]
              && Spelll.match_with dfa indexed_word)
        )
      )
    |> Seq.flat_map (fun (_indexed_word, pos_s) -> Int_set.to_seq pos_s)

  let search_around_pos
      ~consider_edit_dist
      (around_pos : int)
      (l : (string * Spelll.automaton) list)
      (t : t)
    : int list Seq.t =
    let rec aux around_pos l =
      match l with
      | [] -> Seq.return []
      | (search_word, dfa) :: rest -> (
          usable_positions
            ~around_pos
            ~eio_yield:false
            ~consider_edit_dist
            (search_word, dfa)
            t
          |> Seq.flat_map (fun pos ->
              aux pos rest
              |> Seq.map (fun l -> pos :: l)
            )
        )
    in
    aux around_pos l

  let search
      ~consider_edit_dist
      (phrase : Search_phrase.t)
      (t : t)
    : Search_result.t Seq.t =
    if Search_phrase.is_empty phrase then (
      Seq.empty
    ) else (
      match List.combine phrase.phrase phrase.fuzzy_index with
      | [] -> failwith "Unexpected case"
      | first_word :: rest -> (
          Eio.Fiber.yield ();
          let possible_start_count, possible_starts =
            usable_positions ~eio_yield:true ~consider_edit_dist first_word t
            |> Misc_utils.list_and_length_of_seq
          in
          if possible_start_count = 0 then
            Seq.empty
          else (
            let search_limit_per_start =
              max
                Params.search_result_min_per_start
                (
                  (Params.search_result_max_total + possible_start_count - 1) / possible_start_count
                )
            in
            possible_starts
            |> List.to_seq
            |> Seq.map (fun pos ->
                search_around_pos ~consider_edit_dist pos rest t
                |> Seq.map (fun l -> pos :: l)
                |> Seq.map (fun l ->
                    Search_result.make
                      ~search_phrase:phrase.phrase
                      ~found_phrase:(List.map
                                       (fun pos ->
                                          Search_result.{
                                            found_word_pos = pos;
                                            found_word_ci = word_ci_of_pos pos t;
                                            found_word = word_of_pos pos t;
                                          }) l)
                  )
                |> Seq.fold_left (fun best_results r ->
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
            |> Seq.flat_map Search_result_heap.to_seq
          )
        )
    )
end

let fulfills_content_reqs
    (e : Content_req_exp.t)
    (t : t)
  : bool =
  let rec aux (e : Content_req_exp.t) =
    let open Content_req_exp in
    match e with
    | Phrase phrase ->
      not (Seq.is_empty (Search.search ~consider_edit_dist:false phrase t))
    | Binary_op (op, e1, e2) -> (
        match op with
        | And -> aux e1 && aux e2
        | Or -> aux e1 || aux e2
      )
  in
  Content_req_exp.is_empty e || aux e

let search
    (phrase : Search_phrase.t)
    (t : t)
  : Search_result.t array =
  let arr =
    Search.search ~consider_edit_dist:true phrase t
    |> Array.of_seq
  in
  Array.sort Search_result.compare_rev arr;
  arr

let to_json (t : t) : Yojson.Safe.t =
  let json_of_int (x : int) = `Int x in
  let json_of_int_int ((x, y) : int * int) = `List [ `Int x; `Int y ] in
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
  let json_of_line_loc_map
    : 'a . ('a -> Yojson.Safe.t) -> 'a Line_loc_map.t -> Yojson.Safe.t =
    fun f m ->
      let l =
        Line_loc_map.to_seq m
        |> Seq.map (fun (k, v) ->
            `List [ Line_loc.to_json k; f v ])
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
    ("global_line_num_of_line_loc",
     json_of_line_loc_map json_of_int t.global_line_num_of_line_loc);
    ("start_end_inc_pos_of_global_line_num",
     json_of_ccvector json_of_int_int t.start_end_inc_pos_of_global_line_num);
    ("word_ci_of_pos",
     json_of_ccvector json_of_int t.word_ci_of_pos);
    ("word_of_pos",
     json_of_ccvector json_of_int t.word_of_pos);
    ("line_count_of_page",
     json_of_ccvector json_of_int t.line_count_of_page);
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
  let int_int_of_json (json : Yojson.Safe.t) : (int * int) option =
    match json with
    | `List [ `Int x; `Int y ] -> Some (x, y)
    | _ -> None
  in
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
  let line_loc_map_of_json
    : 'a . (Yojson.Safe.t -> 'a option) -> Yojson.Safe.t -> 'a Line_loc_map.t option =
    fun f json ->
      match json with
      | `List l -> (
          let exception Invalid in
          let m : 'a Line_loc_map.t ref = ref Line_loc_map.empty in
          try
            List.iter (fun v ->
                match v with
                | `List [ line_loc; v ] -> (
                    match Line_loc.of_json line_loc with
                    | None -> raise Invalid
                    | Some line_loc -> (
                        match f v with
                        | None -> raise Invalid
                        | Some v -> (
                            m := Line_loc_map.add line_loc v !m
                          )
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
      let* global_line_num_of_line_loc =
        let* x = List.assoc_opt "global_line_num_of_line_loc" l in
        line_loc_map_of_json int_of_json x
      in
      let* start_end_inc_pos_of_global_line_num =
        let* x = List.assoc_opt "start_end_inc_pos_of_global_line_num" l in
        ccvector_of_json int_int_of_json x
      in
      let* word_ci_of_pos =
        let* x = List.assoc_opt "word_ci_of_pos" l in
        ccvector_of_json int_of_json x
      in
      let* word_of_pos =
        let* x = List.assoc_opt "word_of_pos" l in
        ccvector_of_json int_of_json x
      in
      let* line_count_of_page =
        let* x = List.assoc_opt "line_count_of_page" l in
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
        global_line_num_of_line_loc;
        start_end_inc_pos_of_global_line_num;
        word_ci_of_pos;
        word_of_pos;
        line_count_of_page;
        page_count;
        global_line_count;
      }
    )
  | _ -> None
