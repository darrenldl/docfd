type t = {
  pos_s_of_word_ci : Int_set.t String_map.t;
  loc_of_pos : (int * int) Int_map.t;
  word_ci_of_pos : string Int_map.t;
  word_of_pos : string Int_map.t;
}

let empty : t = {
  pos_s_of_word_ci = String_map.empty;
  loc_of_pos = Int_map.empty;
  word_ci_of_pos = Int_map.empty;
  word_of_pos = Int_map.empty;
}

let words_of_lines (s : (int * string) Seq.t) : (int * (int * int) * string) Seq.t =
  s
  |> Seq.flat_map (fun (line_num, s) ->
      Tokenize.f_with_pos ~drop_spaces:true s
      |> Seq.map (fun (i, s) -> ((line_num, i), s))
    )
  |> Seq.mapi (fun i (loc, s) ->
      (i, loc, s))

let index (s : (int * string) Seq.t) : t =
  s
  |> words_of_lines
  |> Seq.fold_left (fun
                     { pos_s_of_word_ci;
                       loc_of_pos;
                       word_ci_of_pos;
                       word_of_pos;
                     }
                     (pos, loc, word) ->
                     let word_ci = String.lowercase_ascii word in
                     let pos_s = Option.value ~default:Int_set.empty
                         (String_map.find_opt word pos_s_of_word_ci)
                                 |> Int_set.add pos
                     in
                     { pos_s_of_word_ci = String_map.add word_ci pos_s pos_s_of_word_ci;
                       loc_of_pos = Int_map.add pos loc loc_of_pos;
                       word_ci_of_pos = Int_map.add pos word_ci word_ci_of_pos;
                       word_of_pos = Int_map.add pos word word_of_pos;
                     }
                   )
    empty
