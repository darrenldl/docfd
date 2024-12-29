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
end

module Loc = struct
  type t = {
    line_loc : Line_loc.t;
    pos_in_line : int;
  }
  [@@deriving eq]

  let line_loc t = t.line_loc

  let pos_in_line t =  t.pos_in_line
end

module Raw = struct
  type t = {
    word_db : Word_db.t;
    pos_s_of_word : Int_set.t Int_map.t;
    loc_of_pos : Loc.t Int_map.t;
    line_loc_of_global_line_num : Line_loc.t Int_map.t;
    start_end_inc_pos_of_global_line_num : (int * int) Int_map.t;
    start_end_inc_pos_of_page_num : (int * int) Int_map.t;
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
    pos_s_of_word = Int_map.empty;
    loc_of_pos = Int_map.empty;
    line_loc_of_global_line_num = Int_map.empty;
    start_end_inc_pos_of_global_line_num = Int_map.empty;
    start_end_inc_pos_of_page_num = Int_map.empty;
    word_of_pos = Int_map.empty;
    line_count_of_page_num = Int_map.empty;
    page_count = 0;
    global_line_count = 0;
  }

  let union (x : t) (y : t) =
    {
      word_db = Word_db.make ();
      pos_s_of_word =
        Int_map.union (fun _k s0 s1 -> Some (Int_set.union s0 s1))
          x.pos_s_of_word
          y.pos_s_of_word;
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
          pos_s_of_word;
          loc_of_pos;
          line_loc_of_global_line_num;
          start_end_inc_pos_of_global_line_num;
          start_end_inc_pos_of_page_num;
          word_of_pos;
          line_count_of_page_num;
          page_count;
          global_line_count;
        }
        { pos; loc; word } ->

        Mutex.lock shared_word_db.lock;
        let index_of_word =
          Word_db.add shared_word_db.word_db word
        in
        Mutex.unlock shared_word_db.lock;

        let line_loc = loc.Loc.line_loc in
        let global_line_num = line_loc.global_line_num in
        let page_num = line_loc.page_num in
        let pos_s =
          Int_map.find_opt index_of_word pos_s_of_word
          |> Option.value ~default:Int_set.empty
          |> Int_set.add pos
        in
        let cur_page_line_count =
          Option.value ~default:0
            (Int_map.find_opt page_num line_count_of_page_num)
        in
        { word_db = dummy_word_db;
          pos_s_of_word = Int_map.add index_of_word pos_s pos_s_of_word;
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
    let empty_word =
      let line_loc =
        { Line_loc.page_num = 0; line_num_in_page = 0; global_line_num = 0 }
      in
      let loc = { Loc.line_loc; pos_in_line = 0 } in
      { pos = 0; loc; word = "" }
    in
    (if Seq.is_empty s then (
        Seq.return empty_word
      ) else (
       s
     ))
    |> OSeq.chunks !Params.index_chunk_size

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

let doc_id_of_doc_hash : Sqlite3.db -> string -> int64 =
  let cache = CCCache.lru ~eq:String.equal 10240 in
  fun db ->
    let open Sqlite3_utils in
    CCCache.with_cache cache (fun doc_hash ->
        step_stmt db
          {|
    SELECT id
    FROM doc_info
    WHERE hash = @doc_hash
    |}
          ~names:[ ("@doc_hash", TEXT doc_hash) ]
          (fun stmt ->
             column_int64 stmt 0
          )
      )

let load_raw_into_db db ~doc_hash (x : Raw.t) : unit =
  let open Sqlite3_utils in
  step_stmt db
    {|
  INSERT INTO doc_info
  (id, hash, page_count, global_line_count, max_pos)
  VALUES
  (NULL, @doc_hash, @page_count, @global_line_count, @max_pos)
  |}
    ~names:[ ("@doc_hash", TEXT doc_hash)
           ; ("@page_count", INT (Int64.of_int x.page_count))
           ; ("@global_line_count", INT (Int64.of_int x.global_line_count))
           ; ("@max_pos", INT (Int64.of_int (Int_map.max_binding x.word_of_pos |> fst)))
           ]
    ignore;
  let doc_id = doc_id_of_doc_hash db doc_hash in
  step_stmt db "BEGIN IMMEDIATE" ignore;
  with_stmt db
    {|
  INSERT INTO page_info
  (doc_id, page_num, line_count, start_pos, end_inc_pos)
  VALUES
  (@doc_id, @page_num, @line_count, @start_pos, @end_inc_pos)
  |}
    (fun stmt ->
       Int_map.iter (fun page_num line_count ->
           let (start_pos, end_inc_pos) =
             Int_map.find page_num x.start_end_inc_pos_of_page_num
           in
           bind_names stmt [ ("@doc_id", INT doc_id)
                           ; ("@page_num", INT (Int64.of_int page_num))
                           ; ("@line_count", INT (Int64.of_int line_count))
                           ; ("@start_pos", INT (Int64.of_int start_pos))
                           ; ("@end_inc_pos", INT (Int64.of_int end_inc_pos))
                           ];
           step stmt;
           reset stmt;
         )
         x.line_count_of_page_num
    );
  with_stmt db
    {|
  INSERT INTO line_info
  (doc_id, global_line_num, start_pos, end_inc_pos, page_num, line_num_in_page)
  VALUES
  (@doc_id, @global_line_num, @start_pos, @end_inc_pos, @page_num, @line_num_in_page)
  |}
    (fun stmt ->
       Int_map.iter (fun line_num line_loc ->
           let (start_pos, end_inc_pos) =
             Int_map.find line_num x.start_end_inc_pos_of_global_line_num
           in
           let page_num = line_loc.Line_loc.page_num in
           let line_num_in_page = line_loc.Line_loc.line_num_in_page in
           bind_names stmt [ ("@doc_id", INT doc_id)
                           ; ("@global_line_num", INT (Int64.of_int line_num))
                           ; ("@start_pos", INT (Int64.of_int start_pos))
                           ; ("@end_inc_pos", INT (Int64.of_int end_inc_pos))
                           ; ("@page_num", INT (Int64.of_int page_num))
                           ; ("@line_num_in_page", INT (Int64.of_int line_num_in_page))
                           ];
           step stmt;
           reset stmt;
         )
         x.line_loc_of_global_line_num;
    );
  with_stmt db
    {|
  INSERT INTO position
  (doc_id, pos, word_id, global_line_num, pos_in_line)
  VALUES
  (@doc_id, @pos, @word_id, @global_line_num, @pos_in_line)
    |}
    (fun stmt ->
       Int_map.iter (fun word_id pos_s ->
           Int_set.iter (fun pos ->
               let loc = Int_map.find pos x.loc_of_pos in
               let global_line_num = loc.Loc.line_loc.global_line_num in
               let pos_in_line = loc.Loc.pos_in_line in
               bind_names stmt
                 [ ("@doc_id", INT doc_id)
                 ; ("@pos", INT (Int64.of_int pos))
                 ; ("@word_id", INT (Int64.of_int word_id))
                 ; ("@global_line_num", INT (Int64.of_int global_line_num))
                 ; ("@pos_in_line", INT (Int64.of_int pos_in_line))
                 ];
               step stmt;
               reset stmt;
             )
             pos_s
         )
         x.pos_s_of_word
    );
  step_stmt db "COMMIT" ignore;
  Word_db.load_into_db db ~doc_id x.word_db

let global_line_count =
  let cache = CCCache.lru ~eq:String.equal 10240 in
  let open Sqlite3_utils in
  fun db ~doc_hash ->
    CCCache.with_cache cache (fun doc_hash ->
        step_stmt db
          {|
    SELECT global_line_count FROM doc_info
    WHERE hash = @doc_hash
    |}
          ~names:[ ("@doc_hash", TEXT doc_hash) ]
          (fun stmt ->
             column_int stmt 0
          )
      )
      doc_hash

let page_count db ~doc_hash =
  let open Sqlite3_utils in
  step_stmt db
    {|
    SELECT page_count FROM doc_info
    WHERE hash = @doc_hash
    |}
    ~names:[("@doc_hash", TEXT doc_hash)]
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

let is_indexed db ~doc_hash =
  let open Sqlite3_utils in
  step_stmt db
    {|
    SELECT 0
    FROM doc_info
    WHERE hash = @doc_hash
    |}
    ~names:[ ("@doc_hash", TEXT doc_hash) ]
    (fun stmt ->
       data_count stmt > 0
    )

let index_lines pool db ~doc_hash s =
  Raw.of_lines pool s
  |> load_raw_into_db db ~doc_hash

let index_pages pool db ~doc_hash s =
  Raw.of_pages pool s
  |> load_raw_into_db db ~doc_hash

let word_of_id db ~doc_hash id : string =
  let open Sqlite3_utils in
  let doc_id = doc_id_of_doc_hash db doc_hash in
  step_stmt db
    {|
    SELECT word FROM word
    WHERE doc_id = @doc_id
    AND id = @id
    |}
    ~names:[ ("@doc_id", INT doc_id); ("@id", INT id) ]
    (fun stmt ->
       column_text stmt 0
    )

let word_of_pos db ~doc_hash pos : string =
  let open Sqlite3_utils in
  let doc_id = doc_id_of_doc_hash db doc_hash in
  step_stmt db
    {|
    SELECT word.word
    FROM position p
    JOIN word
        ON word.doc_id = p.doc_id
        AND word.id = p.word_id
    WHERE p.doc_id = @doc_id
    AND pos = @pos
    |}
    ~names:[ ("@doc_id", INT doc_id)
           ; ("@pos", INT (Int64.of_int pos)) ]
    (fun stmt ->
       column_text stmt 0
    )

let word_ci_of_pos db ~doc_hash pos : string =
  word_of_pos db ~doc_hash pos
  |> String.lowercase_ascii

let words_between_start_and_end_inc : Sqlite3.db -> doc_hash:string -> int * int -> string Dynarray.t =
  let cache =
    CCCache.lru ~eq:(fun (x0, y0, z0) (x1, y1, z1) ->
        String.equal x0 x1
        && Int.equal y0 y1
        && Int.equal z0 z1
      )
      10240
  in
  fun db ~doc_hash (start, end_inc) ->
    CCCache.with_cache cache (fun (doc_hash, start, end_inc) ->
        let open Sqlite3_utils in
        let doc_id = doc_id_of_doc_hash db doc_hash in
        let acc = Dynarray.create () in
        iter_stmt db
          {|
    SELECT word.word
    FROM position p
    JOIN word
        ON word.doc_id = p.doc_id
        AND word.id = p.word_id
    WHERE p.doc_id = @doc_id
    AND p.pos BETWEEN @start AND @end_inc
    ORDER BY p.pos
    |}
          ~names:[ ("@doc_id", INT doc_id)
                 ; ("@start", INT (Int64.of_int start))
                 ; ("@end_inc", INT (Int64.of_int end_inc))
                 ]
          (fun data ->
             Dynarray.add_last acc (Data.to_string_exn data.(0))
          );
        acc
      )
      (doc_hash, start, end_inc)

let words_of_global_line_num : Sqlite3.db -> doc_hash:string -> int -> string Dynarray.t =
  let cache =
    CCCache.lru ~eq:(fun (x0, y0) (x1, y1) ->
        String.equal x0 x1 && Int.equal y0 y1)
      10240
  in
  fun db ~doc_hash x ->
    CCCache.with_cache cache (fun (doc_hash, x) ->
        let open Sqlite3_utils in
        let doc_id = doc_id_of_doc_hash db doc_hash in
        if x >= global_line_count db ~doc_hash then (
          invalid_arg "Index.words_of_global_line_num: global_line_num out of range"
        ) else (
          let start, end_inc =
            step_stmt db
              {|
        SELECT start_pos, end_inc_pos
        FROM line_info
        WHERE doc_id = @doc_id
        AND global_line_num = @x
        |}
              ~names:[ ("@doc_id", INT doc_id)
                     ; ("@x", INT (Int64.of_int x))
                     ]
              (fun stmt ->
                 (column_int stmt 0, column_int stmt 1)
              )
          in
          words_between_start_and_end_inc db ~doc_hash (start, end_inc)
        )
      )
      (doc_hash, x)

let words_of_page_num db ~doc_hash x : string Dynarray.t =
  let open Sqlite3_utils in
  if x >= page_count db ~doc_hash then (
    invalid_arg "Index.words_of_page_num: page_num out of range"
  ) else (
    let doc_id = doc_id_of_doc_hash db doc_hash in
    let start, end_inc =
      step_stmt db
        {|
        SELECT start_pos, end_inc_pos
        FROM page_info
        WHERE doc_id = @doc_id
        AND page_num = @x
        |}
        ~names:[ ("@doc_id", INT doc_id)
               ; ("@x", INT (Int64.of_int x))
               ]
        (fun stmt ->
           (column_int stmt 0, column_int stmt 1)
        )
    in
    words_between_start_and_end_inc db ~doc_hash (start, end_inc)
  )

let line_of_global_line_num db ~doc_hash x =
  if x >= global_line_count db ~doc_hash then (
    invalid_arg "Index.line_of_global_line_num: global_line_num out of range"
  ) else (
    words_of_global_line_num db ~doc_hash x
    |> Dynarray.to_list
    |> String.concat ""
  )

let line_loc_of_global_line_num db ~doc_hash global_line_num : Line_loc.t =
  let open Sqlite3_utils in
  let doc_id = doc_id_of_doc_hash db doc_hash in
  if global_line_num >= global_line_count db ~doc_hash then (
    invalid_arg "Index.line_loc_of_global_line_num: global_line_num out of range"
  ) else (
    let page_num, line_num_in_page =
      step_stmt db
        {|
        SELECT page_num, line_num_in_page
        FROM line_info
        WHERE doc_id = @doc_id
        AND global_line_num = @global_line_num
        |}
        ~names:[ ("@doc_id", INT doc_id)
               ; ("@global_line_num", INT (Int64.of_int global_line_num)) ]
        (fun stmt ->
           (column_int stmt 0, column_int stmt 1)
        )
    in
    { Line_loc.page_num; line_num_in_page; global_line_num }
  )

let loc_of_pos db ~doc_hash pos : Loc.t =
  let open Sqlite3_utils in
  let doc_id = doc_id_of_doc_hash db doc_hash in
  let pos_in_line, global_line_num =
    step_stmt db
      {|
      SELECT pos_in_line, global_line_num
      FROM position
      WHERE doc_id = @doc_id
      AND pos = @pos
      |}
      ~names:[ ("@doc_id", INT doc_id)
             ; ("@pos", INT (Int64.of_int pos)) ]
      (fun stmt ->
         (column_int stmt 0, column_int stmt 1)
      )
  in
  let line_loc = line_loc_of_global_line_num db ~doc_hash global_line_num in
  { line_loc; pos_in_line }

let max_pos db ~doc_hash =
  let open Sqlite3_utils in
  step_stmt db
    {|
    SELECT max_pos
    FROM doc_info
    WHERE hash = @doc_hash
    |}
    ~names:[ ("@doc_hash", TEXT doc_hash) ]
    (fun stmt ->
       column_int stmt 0
    )

let line_count_of_page_num db ~doc_hash page : int =
  let open Sqlite3_utils in
  let doc_id = doc_id_of_doc_hash db doc_hash in
  step_stmt db
    {|
    SELECT line_count
    FROM page_info
    WHERE doc_id = @doc_id
    AND page = @page
    |}
    ~names:[ ("@doc_id", INT doc_id)
           ; ("@page", INT (Int64.of_int page)) ]
    (fun stmt ->
       column_int stmt 0
    )

let start_end_inc_pos_of_global_line_num db ~doc_hash global_line_num =
  let open Sqlite3_utils in
  let doc_id = doc_id_of_doc_hash db doc_hash in
  if global_line_num >= global_line_count db ~doc_hash then (
    invalid_arg "Index.start_end_inc_pos_of_global_line_num: global_line_num out of range"
  ) else (
    step_stmt db
      {|
      SELECT start_pos, end_inc_pos
      FROM line_info
      WHERE doc_id = @doc_id
      AND global_line_num = @global_line_num
      |}
      ~names:[ ("@doc_id", INT doc_id)
             ; ("@global_line_num", INT (Int64.of_int global_line_num)) ]
      (fun stmt ->
         (column_int stmt 0, column_int stmt 1)
      )
  )

module Search = struct
  module ET = Search_phrase.Enriched_token

  let indexed_word_is_usable
      (match_typ : [ `Fuzzy | `Exact | `Prefix | `Suffix ])
      ~consider_edit_dist
      (token : Search_phrase.Enriched_token.t)
      ~indexed_word
    =
    Eio.Fiber.yield ();
    String.length indexed_word > 0
    &&
    (match ET.data token with
     | `Explicit_spaces -> (
         Parser_components.is_space indexed_word.[0]
       )
     | `String search_word -> (
         let search_word_ci = String.lowercase_ascii search_word in
         let indexed_word_ci = String.lowercase_ascii indexed_word in
         let use_ci_match = String.equal search_word search_word_ci in
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
           | `Exact -> (
               if use_ci_match then (
                 String.equal search_word_ci indexed_word_ci
               ) else (
                 String.equal search_word indexed_word
               )
             )
           | `Prefix -> (
               if use_ci_match then (
                 CCString.prefix ~pre:search_word_ci indexed_word_ci
               ) else (
                 CCString.prefix ~pre:search_word indexed_word
               )
             )
           | `Suffix -> (
               if use_ci_match then (
                 CCString.suffix ~suf:search_word_ci indexed_word_ci
               ) else (
                 CCString.suffix ~suf:search_word indexed_word
               )
             )
         )
       )
    )

  let usable_positions
      db
      ~doc_hash
      ?within
      ?around_pos
      ~(consider_edit_dist : bool)
      (token : Search_phrase.Enriched_token.t)
    : int Seq.t =
    let open Sqlite3_utils in
    Eio.Fiber.yield ();
    let doc_id = doc_id_of_doc_hash db doc_hash in
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
    let word_candidates : int Dynarray.t =
      let acc : int Dynarray.t =
        Dynarray.create ()
      in
      let f data =
        Eio.Fiber.yield ();
        let indexed_word = Data.to_string_exn data.(1) in
        if indexed_word_is_usable
            match_typ
            ~consider_edit_dist
            token
            ~indexed_word
        then (
          let word_id = Data.to_int_exn data.(0) in
          Dynarray.add_last acc word_id
        )
      in
      (
        match start_end_inc with
        | None -> (
            iter_stmt db
              {|
              SELECT
                  word.id AS word_id,
                  word.word AS word
              FROM word
              WHERE doc_id = @doc_id
              |}
              ~names:[ ("@doc_id", INT doc_id)
                     ]
              f
          )
        | Some (start, end_inc) -> (
            iter_stmt db
              {|
              SELECT DISTINCT
                  word.id AS word_id,
                  word.word AS word
              FROM word
              JOIN position p
                  ON p.doc_id = word.doc_id
                  AND p.word_id = word.id
              WHERE word.doc_id = @doc_id
              AND p.pos BETWEEN @start AND @end_inc
              |}
              ~names:[ ("@doc_id", INT doc_id)
                     ; ("@start", INT (Int64.of_int start))
                     ; ("@end_inc", INT (Int64.of_int end_inc))
                     ]
              f
          )
      );
      acc
    in
    let positions : int Dynarray.t = Dynarray.create () in
    let record_position data =
      Eio.Fiber.yield ();
      Dynarray.add_last positions (Data.to_int_exn data.(0))
    in
    word_candidates
    |> Dynarray.iter (fun word_id ->
        Eio.Fiber.yield ();
        match start_end_inc with
        | None -> (
            iter_stmt db
              {|
              SELECT
                  p.pos
              FROM position p
              WHERE doc_id = @doc_id
              AND word_id = @word_id
              ORDER BY p.pos
              |}
              ~names:[ ("@doc_id", INT doc_id)
                     ; ("@word_id", INT (Int64.of_int word_id))
                     ]
              record_position
          )
        | Some (start, end_inc) -> (
            iter_stmt db
              {|
              SELECT
                  p.pos
              FROM position p
              WHERE doc_id = @doc_id
              AND word_id = @word_id
              AND pos BETWEEN @start AND @end_inc
              ORDER BY p.pos
              |}
              ~names:[ ("@doc_id", INT doc_id)
                     ; ("@word_id", INT (Int64.of_int word_id))
                     ; ("@start", INT (Int64.of_int start))
                     ; ("@end_inc", INT (Int64.of_int end_inc))
                     ]
              record_position
          )
      );
    Dynarray.to_seq positions

  let search_around_pos
      db
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
            db
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
      db
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
            Eio.Fiber.first
              (fun () ->
                 Stop_signal.await stop_signal;
                 Seq.empty)
              (fun () ->
                 usable_positions db ~doc_hash ~consider_edit_dist first_word)
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
                             let loc = loc_of_pos db ~doc_hash pos in
                             Some (start_end_inc_pos_of_global_line_num db ~doc_hash loc.line_loc.global_line_num)
                           ) else (
                             None
                           )
                         in
                         search_around_pos db ~doc_hash ~consider_edit_dist ~within pos rest
                         |> Seq.map (fun l -> pos :: l)
                         |> Seq.map (fun (l : int list) ->
                             Eio.Fiber.yield ();
                             let opening_closing_symbol_pairs =
                               List.map (fun pos -> word_of_pos db ~doc_hash pos) l
                               |>  Misc_utils.opening_closing_symbol_pairs
                             in
                             let found_phrase_opening_closing_symbol_match_count =
                               let pos_arr : int array = Array.of_list l in
                               List.fold_left (fun total (x, y) ->
                                   let pos_x = pos_arr.(x) in
                                   let pos_y = pos_arr.(y) in
                                   let c_x = String.get (word_of_pos db ~doc_hash pos_x) 0 in
                                   let c_y = String.get (word_of_pos db ~doc_hash pos_y) 0 in
                                   assert (List.exists (fun (x, y) -> c_x = x && c_y = y)
                                             Params.opening_closing_symbols);
                                   if pos_x < pos_y then (
                                     let outstanding_opening_symbol_count =
                                       OSeq.(pos_x + 1 --^ pos_y)
                                       |> Seq.fold_left (fun count pos ->
                                           match count with
                                           | Some count -> (
                                               let word = word_of_pos db ~doc_hash pos in
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
                                                     found_word_ci = word_ci_of_pos db ~doc_hash pos;
                                                     found_word = word_of_pos db ~doc_hash pos;
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
      db
      ~doc_hash
      ~within_same_line
      ~consider_edit_dist
      search_scope
      (exp : Search_exp.t)
    : Search_result_heap.t =
    Search_exp.flattened exp
    |> List.to_seq
    |> Seq.map (fun phrase -> search_single pool stop_signal db ~doc_hash ~within_same_line ~consider_edit_dist search_scope phrase)
    |> Seq.fold_left search_result_heap_merge_with_yield Search_result_heap.empty
end

let search
    pool
    stop_signal
    db
    ~doc_hash
    ~within_same_line
    search_scope
    (exp : Search_exp.t)
  : Search_result.t array =
  let arr =
    Search.search
      pool
      stop_signal
      db
      ~doc_hash
      ~within_same_line
      ~consider_edit_dist:true
      search_scope
      exp
    |> Search_result_heap.to_seq
    |> Array.of_seq
  in
  Array.sort Search_result.compare_relevance arr;
  arr
