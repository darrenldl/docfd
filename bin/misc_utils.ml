include Docfd_lib.Misc_utils'

let bound_selection ~choice_count (x : int) : int =
  max 0 (min (choice_count - 1) x)

let frequencies_of_words_ci (s : string Seq.t) : int String_map.t =
  Seq.fold_left (fun m word ->
      let word = String.lowercase_ascii word in
      let count = Option.value ~default:0
          (String_map.find_opt word m)
      in
      String_map.add word (count + 1) m
    )
    String_map.empty
    s

let exit_with_error_msg (msg : string) =
  Printf.printf "error: %s\n" msg;
  exit 1

let stdin_is_atty () =
  Unix.isatty Unix.stdin

let stdout_is_atty () =
  Unix.isatty Unix.stdout

let stderr_is_atty () =
  Unix.isatty Unix.stderr

let compute_total_recognized_exts ~exts ~additional_exts =
  let split_on_comma = String.split_on_char ',' in
  (split_on_comma exts)
  :: (List.map split_on_comma additional_exts)
  |> List.to_seq
  |> Seq.flat_map List.to_seq
  |> Seq.map (fun s ->
      s
      |> String_utils.remove_leading_dots
      |> CCString.trim
    )
  |> Seq.filter (fun s -> s <> "")
  |> Seq.map (fun s -> Printf.sprintf ".%s" s)
  |> List.of_seq

let array_sub_seq : 'a. start:int -> end_exc:int -> 'a array -> 'a Seq.t =
  fun ~start ~end_exc arr ->
  let count = Array.length arr in
  let end_exc = min count end_exc in
  let rec aux start =
    if start < end_exc then (
      Seq.cons arr.(start) (aux (start + 1))
    ) else (
      Seq.empty
    )
  in
  aux start

let rotate_list (x : int) (l : 'a list) : 'a list =
  let arr = Array.of_list l in
  let len = Array.length arr in
  Seq.append
    (array_sub_seq ~start:x ~end_exc:len arr)
    (array_sub_seq ~start:0 ~end_exc:x arr)
  |> List.of_seq

let drain_eio_stream (x : 'a Eio.Stream.t) =
  let rec aux () =
    match Eio.Stream.take_nonblocking x with
    | None -> ()
    | Some _ -> aux ()
  in
  aux ()

let mib_of_bytes (x : int) =
  (Int.to_float x) /. (1024.0 *. 1024.0)

let progress_with_reporter ~interactive bar f =
  if interactive then (
    Progress.with_reporter
      ~config:(Progress.Config.v ~ppf:Format.std_formatter ())
      bar
      (fun report_progress ->
         let report_progress =
           let lock = Eio.Mutex.create () in
           fun x ->
             Eio.Mutex.use_rw lock ~protect:false (fun () ->
                 report_progress x
               )
         in
         f report_progress
      )
  ) else (
    f (fun _ -> ())
  )

let normalize_filter_glob_if_not_empty (s : string) =
  if String.length s = 0 then (
    s
  ) else (
    normalize_glob_to_absolute s
  )

let gen_command_to_open_text_file_to_line_num ~editor ~quote_path ~path ~line_num =
  let path =
    if quote_path then
      Filename.quote path
    else
      path
  in
  let fallback = Fmt.str "%s %s" editor path in
  match Filename.basename editor with
  | "nano" ->
    Fmt.str "%s +%d %s" editor line_num path
  | "nvim" | "vim" | "vi" ->
    Fmt.str "%s +%d %s" editor line_num path
  | "kak" ->
    Fmt.str "%s +%d %s" editor line_num path
  | "hx" ->
    Fmt.str "%s %s:%d" editor path line_num
  | "emacs" ->
    Fmt.str "%s +%d %s" editor line_num path
  | "micro" ->
    Fmt.str "%s %s:%d" editor path line_num
  | "jed" | "xjed" ->
    Fmt.str "%s %s -g %d" editor path line_num
  | _ ->
    fallback

let init_db_if_needed db : Sqlite3.Rc.t =
  Sqlite3.exec db {|
CREATE TABLE IF NOT EXISTS line_info (
  doc_hash varchar(500) PRIMARY KEY,
  global_line_num integer,
  start_pos integer,
  end_inc_pos integer,
  page_num integer,
  line_num_in_page integer
);

CREATE INDEX IF NOT EXISTS index_1 ON line_info (global_line_num);

CREATE TABLE IF NOT EXISTS position (
  doc_hash varchar(500),
  flat_position integer,
  word_id integer,
  word_ci_id integer,
  global_line_num integer,
  PRIMARY KEY (doc_hash, flat_position),
  FOREIGN KEY (doc_hash) REFERENCES doc_info (doc_hash),
  FOREIGN KEY (doc_hash) REFERENCES line_info (doc_hash),
  FOREIGN KEY (doc_hash) REFERENCES page_info (doc_hash),
  FOREIGN KEY (word_ci_id) REFERENCES word (id),
  FOREIGN KEY (word_id) REFERENCES word (id)
);

CREATE INDEX IF NOT EXISTS index_2 ON position (word_ci_id);
CREATE INDEX IF NOT EXISTS index_3 ON position (flat_position);

CREATE TABLE IF NOT EXISTS page_info (
  doc_hash varchar(500) PRIMARY KEY,
  page_num integer,
  line_count integer
);

CREATE INDEX IF NOT EXISTS index_1 ON page_info (page_num);

CREATE TABLE IF NOT EXISTS doc_info (
  doc_hash varchar(500) PRIMARY KEY,
  page_count integer,
  global_line_count integer
);

CREATE TABLE IF NOT EXISTS word (
  id integer PRIMARY KEY,
  doc_hash varchar(500),
  word varchar(500)
);

CREATE INDEX IF NOT EXISTS index_1 ON word (word);
CREATE INDEX IF NOT EXISTS index_2 ON word (doc_hash);
  |}
