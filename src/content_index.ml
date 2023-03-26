type t = {
  pos_s_of_word_ci : Int_set.t String_map.t;
  line_pos_of_pos : (int * int) Int_map.t;
  word_of_pos_ci : string Int_map.t;
  word_of_pos : string Int_map.t;
}

let empty : t = {
  pos_s_of_word_ci = String_map.empty;
  line_pos_of_pos = Int_map.empty;
  word_of_pos_ci = Int_map.empty;
  word_of_pos = Int_map.empty;
}

let union (t1 : t) (t2 : t) : t =
  { 
    pos_s_of_word_ci =
      String_map.union (fun _ x y -> Some (Int_set.union x y))
        t1.pos_s_of_word_ci
        t2.pos_s_of_word_ci;
    line_pos_of_pos =
      Int_map.union (fun _ x _ -> Some x)
        t1.line_pos_of_pos
        t2.line_pos_of_pos;
    word_of_pos_ci =
      Int_map.union (fun _ x _ -> Some x)
        t1.word_of_pos_ci
        t2.word_of_pos_ci;
    word_of_pos =
      Int_map.union (fun _ x _ -> Some x)
        t1.word_of_pos
        t2.word_of_pos;
  }

let words_of_lines (s : (int * string) Seq.t) : (int * (int * int) * string) Seq.t =
  s
  |> Seq.flat_map (fun (line_num, s) ->
      Tokenize.f_with_pos ~drop_spaces:true s
      |> Seq.map (fun (i, s) -> ((line_num, i), s))
    )
  |> Seq.mapi (fun i (line_pos, s) ->
      (i, line_pos, s))

let index (s : (int * string) Seq.t) : t =
  s
  |> words_of_lines
  |> Seq.fold_left (fun
                     { pos_s_of_word_ci;
                       line_pos_of_pos;
                       word_of_pos_ci;
                       word_of_pos;
                     }
                     (pos, line_pos, word) ->
                     let word_ci = String.lowercase_ascii word in
                     let pos_s = Option.value ~default:Int_set.empty
                         (String_map.find_opt word pos_s_of_word_ci)
                                 |> Int_set.add pos
                     in
                     { pos_s_of_word_ci = String_map.add word_ci pos_s pos_s_of_word_ci;
                       line_pos_of_pos = Int_map.add pos line_pos line_pos_of_pos;
                       word_of_pos_ci = Int_map.add pos word_ci word_of_pos_ci;
                       word_of_pos = Int_map.add pos word word_of_pos;
                     }
                   )
    empty
