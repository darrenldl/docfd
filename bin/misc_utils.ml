open Docfd_lib
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
      |> CCString.trim
      |> String_utils.remove_leading_dots
      |> String.lowercase_ascii
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

let trim_angstrom_error_msg (s : string) =
  CCString.chop_prefix ~pre:": " s
  |> Option.value ~default:s

let ranking_of_ranked_document_list (l : string list) : int String_map.t =
  CCList.foldi (fun acc i path ->
      String_map.add path i acc
    ) String_map.empty l

let line_based_fuzzy_find
    (lines : string Seq.t)
    (exp : Search_exp.t)
  : string Dynarray.t =
  lines
  |> Seq.fold_left (fun acc line ->
      let parts = Tokenization.tokenize ~drop_spaces:false line
        |> List.of_seq
      in
      let search_results =
        List.filter_map (fun phrase ->
            let words =
              List.map (fun token ->
                  CCList.foldi
                    (fun first_match i part ->
                       match first_match with
                       | Some x -> Some x
                       | None -> (
                           if
                             Search_phrase.Enriched_token.compatible_with_word token part
                           then (
                             Some (i, part, String.lowercase_ascii part)
                           ) else (
                             None
                           )
                         )
                    )
                    None
                    parts
                )
                (Search_phrase.enriched_tokens phrase)
            in
            if List.for_all Option.is_some words then (
              let found_phrase =
                List.map Option.get words
                |> List.map (fun (i, part, part_ci) ->
                    Search_result.{
                      found_word_pos = i;
                      found_word_ci = part_ci;
                      found_word = part;
                    }
                  )
              in
              Some (Search_result.make phrase
                      ~found_phrase
                      ~found_phrase_opening_closing_symbol_match_count:0)
            ) else (
              None
            )
          )
          (Search_exp.flattened exp)
      in
      let best_search_result =
        List.fold_left (fun best x ->
            match best with
            | None -> Some x
            | Some best -> (
                if Search_result.score x > Search_result.score best then (
                  Some x
                ) else (
                  Some best
                )
              )
          )
          None
          search_results
      in
      match best_search_result with
      | None -> acc
      | Some best -> (
          (line, best) :: acc
        )
    )
    []
  |> List.sort (fun (_s0, r0) (_s1, r1) ->
      Search_result.compare_relevance r0 r1
    )
  |> List.map fst
  |> Dynarray.of_list
