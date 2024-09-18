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
  ((split_on_comma exts)
   @
   (split_on_comma additional_exts))
  |> List.map (fun s ->
      s
      |> String_utils.remove_leading_dots
      |> CCString.trim
    )
  |> List.filter (fun s -> s <> "")
  |> List.map (fun s -> Printf.sprintf ".%s" s)

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
