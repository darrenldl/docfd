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

  let to_cbor (t : t) : CBOR.Simple.t =
    `Array [ `Int t.page_num; `Int t.line_num_in_page; `Int t.global_line_num ]

  let of_cbor (cbor : CBOR.Simple.t) : t option =
    match cbor with
    | `Array [ `Int page_num; `Int line_num_in_page; `Int global_line_num ] ->
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

  let to_cbor (t : t) : CBOR.Simple.t =
    `Array [ Line_loc.to_cbor t.line_loc; `Int t.pos_in_line ]

  let of_cbor (cbor : CBOR.Simple.t) : t option =
    match cbor with
    | `Array [ line_loc; `Int pos_in_line ] -> (
        match Line_loc.of_cbor line_loc with
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
    OSeq.chunks !Params.index_chunk_size s

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

let load_raw_into_db ~doc_hash (x : Raw.t) : unit =
  Word_db.load_into_db ~doc_hash x.word_db;
  ()

let global_line_count ~doc_hash =
  let open Sqlite3_utils in
  step_stmt
  {|
  SELECT global_line_count FROM doc_info
  WHERE doc_hash = @doc_hash
  |}
  ~names:[("doc_hash", TEXT doc_hash)]
  (fun stmt ->
    column_int stmt 0
  )

let page_count ~doc_hash =
  let open Sqlite3_utils in
  step_stmt
  {|
  SELECT page_count FROM doc_info
  WHERE doc_hash = @doc_hash
  |}
  ~names:[("doc_hash", TEXT doc_hash)]
  (fun stmt ->
  column_int stmt 0
  )

let ccvector_of_int_map
  : 'a . 'a Int_map.t -> 'a CCVector.ro_vector =
  fun m ->
  Int_map.to_seq m
  |> Seq.map snd
  |> CCVector.of_seq
  |> CCVector.freeze

let lines pool ~doc_hash s =
  Raw.of_lines pool s
  |> load_raw_into_db ~doc_hash

let pages pool ~doc_hash s =
  Raw.of_pages pool s
  |> load_raw_into_db ~doc_hash

let word_of_id ~doc_hash id : string =
  let open Sqlite3_utils in
  let stmt = prepare {|
  SELECT word FROM word
  WHERE doc_hash = @doc_hash
  AND id = @id
  |}
  in
  bind_names stmt
  [("doc_hash", TEXT doc_hash); ("id", INT id)];
  let x = column_text stmt 0 in
  finalize stmt;
  x

let word_ci_of_pos ~doc_hash pos : string =
  let open Sqlite3_utils in
  step_stmt
  {|
  SELECT word.word
  FROM position p
  JOIN word on word.id = p.word_ci_id
  WHERE p.doc_hash = @doc_hash
  AND flat_position = @pos
  |}
  ~names:[("doc_hash", TEXT doc_hash); ("pos", INT pos)]
  (fun stmt ->
    column_text stmt 0
  )

let word_of_pos ~doc_hash pos : string =
  let open Sqlite3_utils in
  step_stmt
  {|
  SELECT word.word
  FROM position p
  JOIN word on word.id = p.word_id
  WHERE p.doc_hash = @doc_hash
  AND flat_position = @pos
  |}
  ~names:[("doc_hash", TEXT doc_hash); ("pos", INT pos)]
  (fun stmt ->
  column_text stmt 0
  )

(* let word_ci_and_pos_s ~doc_hash ?range_inc () : (string * Int_set.t) Seq.t =
  let open Sqlite3 in
  match range_inc with
  | None -> (
      Int_map.to_seq t.pos_s_of_word_ci
      |> Seq.map (fun (i, s) -> (word_of_id ~doc_hash i, s))
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
    ) *)

let words_between_start_and_end_inc ~doc_hash (start, end_inc) : string Dynarray.t =
  let open Sqlite3_utils in
let acc = Dynarray.create () in
    iter_stmt
    {|
    SELECT word.word
    FROM position
    JOIN word
      ON word.doc_hash = position.doc_hash
      AND word.id = position.word_id
    WHERE position.doc_hash = @doc_hash
    AND position.flat_position BETWEEN @start AND @end_inc
    ORDER BY position.flat_position
    |}
    ~names:[ ("doc_hash", TEXT doc_hash)
    ; ("start", INT (Int64.of_int start))
    ; ("end_inc", INT (Int64.of_int end_inc))
    ]
    (fun data ->
      Dynarray.add_last acc (Data.to_string_exn data.(0))
    );
    acc

let words_of_global_line_num ~doc_hash x : string Dynarray.t =
  let open Sqlite3_utils in
  if x >= global_line_count ~doc_hash then (
    invalid_arg "Index.words_of_global_line_num: global_line_num out of range"
  ) else (
    let start, end_inc =
    step_stmt
    {|
    SELECT start_pos, end_inc_pos
    FROM line_info
    WHERE doc_hash = @doc_hash
    AND global_line_num = @x
    |}
    ~names:[ ("doc_hash", TEXT doc_hash)
    ; ("x", INT (Int64.of_int x))
    ]
    (fun stmt ->
    (column_int stmt 0, column_int stmt 1)
    )
in
    words_between_start_and_end_inc ~doc_hash (start, end_inc)
  )

let words_of_page_num ~doc_hash x : string Dynarray.t =
  let open Sqlite3_utils in
  if x >= page_count ~doc_hash then (
    invalid_arg "Index.words_of_page_num: page_num out of range"
  ) else (
    let start, end_inc =
    step_stmt
    {|
    SELECT start_pos, end_inc_pos
    FROM page_info
    WHERE doc_hash = @doc_hash
    AND page_num = @x
    |}
    ~names:[ ("doc_hash", TEXT doc_hash)
    ; ("x", INT (Int64.of_int x))
    ]
    (fun stmt ->
    (column_int stmt 0, column_int stmt 1)
    )
in
    words_between_start_and_end_inc ~doc_hash (start, end_inc)
  )

let line_of_global_line_num ~doc_hash x =
  if x >= global_line_count ~doc_hash then (
    invalid_arg "Index.line_of_global_line_num: global_line_num out of range"
  ) else (
    words_of_global_line_num ~doc_hash x
    |> Dynarray.to_list
    |> String.concat ""
  )

let line_loc_of_global_line_num ~doc_hash global_line_num : Line_loc.t =
  let open Sqlite3_utils in
  if global_line_num >= global_line_count ~doc_hash then (
    invalid_arg "Index.line_loc_of_global_line_num: global_line_num out of range"
  ) else (
    let page_num, line_num_in_page =
    step_stmt
    {|
    SELECT page_num, line_num_in_page
    FROM line_info
    WHERE global_line_num = @global_line_num
    |}
    ~names:[ ("doc_hash", TEXT doc_hash)
    ; ("global_line_num", INT (Int64.of_int global_line_num)) ]
    (fun stmt ->
      (column_int stmt 0, column_int stmt 1)
    )
in
    { page_num; line_num_in_page; global_line_num }
  )

let loc_of_pos ~doc_hash pos : Loc.t =
  let open Sqlite3_utils in
  let pos_in_line, global_line_num =
  step_stmt
  {|
  SELECT pos_in_line, global_line_num
  FROM position
  WHERE doc_hash = @doc_hash
  AND pos = @pos
  |}
  ~names:[ ("doc_hash", TEXT doc_hash); ("pos", INT (Int64.of_int pos)) ]
  (fun stmt ->
    (column_int stmt 0, column_int stmt 1)
  )
  in
  let line_loc = line_loc_of_global_line_num ~doc_hash global_line_num in
  { line_loc; pos_in_line }

let max_pos ~doc_hash =
  let open Sqlite3_utils in
  step_stmt
  {|
  SELECT max_pos
  FROM doc_info
  WHERE doc_hash = @doc_hash
  |}
  ~names:[ ("doc_hash", TEXT doc_hash) ]
  (fun stmt ->
    column_int stmt 0
  )

let line_count_of_page_num ~doc_hash page : int =
  let open Sqlite3_utils in
  step_stmt
  {|
  SELECT line_count
  FROM page_info
  WHERE doc_hash = @doc_hash
  AND page = @page
  |}
  ~names:[ ("doc_hash", TEXT doc_hash); ("page", INT (Int64.of_int page)) ]
  (fun stmt ->
    column_int stmt 0
  )

let start_end_inc_pos_of_global_line_num ~doc_hash global_line_num =
  let open Sqlite3_utils in
  if global_line_num >= global_line_count ~doc_hash then (
    invalid_arg "Index.start_end_inc_pos_of_global_line_num: global_line_num out of range"
  ) else (
  step_stmt
  {|
  SELECT start_pos, end_inc_pos
  FROM line_num
  WHERE doc_hash = @doc_hash
  AND global_line_num = @global_line_num
  |}
  ~names:[ ("doc_hash", TEXT doc_hash); ("global_line_num", INT (Int64.of_int global_line_num)) ]
  (fun stmt ->
    (column_int stmt 0, column_int stmt 1)
  )
  )

module Search = struct
  module ET = Search_phrase.Enriched_token

  let usable_positions
      ~doc_hash
      ?within
      ?around_pos
      ~(consider_edit_dist : bool)
      (token : Search_phrase.Enriched_token.t)
    : int Seq.t =
    let open Sqlite3_utils in
    Eio.Fiber.yield ();
    let match_typ = ET.match_typ token in
    let start_end_inc =
      Option.map (fun around_pos ->
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
        match within with
        | None -> (start, end_inc)
        | Some (within_start_pos, within_end_inc_pos) -> (
            (max within_start_pos start, min within_end_inc_pos end_inc)
          )
      )
      around_pos
    in
    let word_candidates : (int * string) list =
        let f acc data =
          let word_id = Data.to_int_exn data.(0) in
          let word = Data.to_string_exn data.(1) in
          (word_id, word) :: acc
        in
        match start_end_inc with
        | None -> (
          fold_stmt
          {|
          SELECT DISTINCT
              word.id AS word_id,
              word.word AS word
          FROM word
          WHERE doc_hash = @doc_hash
          |}
          ~names:[ ("doc_hash", TEXT doc_hash)
          ]
          f
          []
        )
        | Some (start, end_inc) -> (
          fold_stmt
          {|
          SELECT DISTINCT
              word.id AS word_id,
              word.word AS word
          FROM word
          JOIN position
              ON position.doc_hash = word.doc_hash
              AND position.word_id = word.id
          WHERE word_ci.doc_hash = @doc_hash
          AND position.pos BETWEEN @start AND @end_inc
          |}
          ~names:[ ("doc_hash", TEXT doc_hash)
          ; ("start", INT (Int64.of_int start))
          ; ("end_inc", INT (Int64.of_int end_inc))
          ]
          f
          []
        )
    in
    let non_fuzzy_filter
        ~search_word
        ~search_word_ci
        (match_typ : [ `Exact | `Prefix | `Suffix ])
        ~indexed_word
        ~indexed_word_ci
      : bool
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
        if String.equal search_word search_word_ci then (
          f_ci indexed_word_ci
        ) else (
          f indexed_word
        )
    in
    word_candidates
    |> List.to_seq
    |> Seq.filter (fun (_word_id, indexed_word) ->
        Eio.Fiber.yield ();
        String.length indexed_word > 0
      )
    |> Seq.filter (
      match ET.data token with
      | `Explicit_spaces -> (
          fun (_word_id, indexed_word) ->
            Eio.Fiber.yield ();
            Parser_components.is_space indexed_word.[0]
        )
      | `String search_word -> (
        fun (word_id, indexed_word) ->
            Eio.Fiber.yield ();
            let search_word_ci =
              String.lowercase_ascii search_word
            in
          let indexed_word_ci = String.lowercase_ascii indexed_word in
            let indexed_word_len = String.length indexed_word in
            if Parser_components.is_possibly_utf_8 indexed_word.[0] then (
              String.equal search_word indexed_word
            ) else (
              match match_typ with
              | `Fuzzy -> (
                    String.equal search_word_ci indexed_word_ci
                    || CCString.find ~sub:search_word_ci indexed_word_ci >= 0
                    || (indexed_word_len >= 2
                        && CCString.find ~sub:indexed_word_ci search_word_ci >= 0)
                    || (consider_edit_dist
                        && Misc_utils.first_n_chars_of_string_contains ~n:5 indexed_word_ci search_word_ci.[0]
                        && Spelll.match_with (ET.automaton token) indexed_word_ci)
                )
              | `Exact | `Prefix | `Suffix as m -> (
                  non_fuzzy_filter
                    ~search_word
                    ~search_word_ci
                    (m :> [ `Exact | `Prefix | `Suffix ])
                    ~indexed_word
                    ~indexed_word_ci
                )
            )
        )
    )
    |> Seq.flat_map (fun (word_id, indexed_word) ->
        Eio.Fiber.yield ();
        let f acc data =
          Data.to_int_exn data.(0) :: acc
        in
        let l =
        match start_end_inc with
        | None -> (
          fold_stmt
          {|
          SELECT
              position.pos
          FROM position
          WHERE doc_hash = @doc_hash
          AND word_id = @word_id
          |}
          ~names:[ ("doc_hash", TEXT doc_hash)
          ; ("word_id", INT (Int64.of_int word_id))
          ]
          f
          []
        )
        | Some (start, end_inc) -> (
          fold_stmt
          {|
          SELECT
              position.pos
          WHERE doc_hash = @doc_hash
          AND word_id = @word_id
          AND pos BETWEEN @start AND @end_inc
          |}
          ~names:[ ("doc_hash", TEXT doc_hash)
          ; ("word_id", INT (Int64.of_int word_id))
          ; ("start", INT (Int64.of_int start))
          ; ("end_inc", INT (Int64.of_int end_inc))
          ]
          f
          []
        )
        in
        l
        |> List.to_seq
        )

  let search_around_pos
      ~doc_hash
      ~consider_edit_dist
      ~(within : (int * int) option)
      (around_pos : int)
      (l : Search_phrase.Enriched_token.t list)
    : int list Seq.t =
    let rec aux around_pos l =
      Eio.Fiber.yield ();
      match l with
      | [] -> Seq.return []
      | token :: rest -> (
          usable_positions
          ~doc_hash
            ?within
            ~around_pos
            ~consider_edit_dist
            token
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
      ~doc_hash
      ~within_same_line
      ~consider_edit_dist
      (search_scope : Diet.Int.t option)
      (phrase : Search_phrase.t)
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
            usable_positions ~doc_hash ~consider_edit_dist first_word
            |> (fun s ->
                match search_scope with
                | None -> s
                | Some search_scope -> (
                    Seq.filter (fun x ->
                        Diet.Int.mem x search_scope
                      ) s
                  )
              )
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
                             let loc = loc_of_pos ~doc_hash pos in
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
      search_scope
      (exp : Search_exp.t)
      (t : t)
    : Search_result_heap.t =
    Search_exp.flattened exp
    |> List.to_seq
    |> Seq.map (fun phrase -> search_single pool stop_signal ~within_same_line ~consider_edit_dist search_scope phrase t)
    |> Seq.fold_left search_result_heap_merge_with_yield Search_result_heap.empty
end

let search
    pool
    stop_signal
    ~within_same_line
    search_scope
    (exp : Search_exp.t)
    (t : t)
  : Search_result.t array =
  let arr =
    Search.search pool stop_signal ~within_same_line ~consider_edit_dist:true search_scope exp t
    |> Search_result_heap.to_seq
    |> Array.of_seq
  in
  Array.sort Search_result.compare_relevance arr;
  arr
