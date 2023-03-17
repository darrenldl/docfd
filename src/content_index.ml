type t = {
  locations_of_word_ci : Int_set.t String_map.t;
  line_of_location_ci : int Int_map.t;
  word_of_location_ci : string Int_map.t;
}

let empty : t = {
  locations_of_word_ci = String_map.empty;
  line_of_location_ci = Int_map.empty;
  word_of_location_ci = Int_map.empty;
}

let union (t1 : t) (t2 : t) : t =
  { 
    locations_of_word_ci =
      String_map.union (fun _ x y -> Some (Int_set.union x y))
        t1.locations_of_word_ci
        t2.locations_of_word_ci;
    line_of_location_ci =
      Int_map.union (fun _ _ _ -> failwith "Unexpected")
        t1.line_of_location_ci
        t2.line_of_location_ci;
    word_of_location_ci =
      Int_map.union (fun _ _ _ -> failwith "Unexpected")
        t1.word_of_location_ci
        t2.word_of_location_ci;
  }

let words_of_lines (s : (int * string) Seq.t) : (int * int * string) Seq.t =
  s
  |> Seq.flat_map (fun (line_num, s) ->
      String.split_on_char ' ' s
      |> List.to_seq
      |> Seq.map (fun s -> (line_num, s)))
  |> Seq.filter (fun (_line_num, s) -> s <> "")
  |> Seq.mapi (fun i (line_num, s) ->
      (i, line_num, s))

let index (s : (int * string) Seq.t) : t =
  s
  |> words_of_lines
  |> Seq.fold_left (fun
                     {locations_of_word_ci; line_of_location_ci; word_of_location_ci }
                     (loc, line, word) ->
                     let word_ci = String.lowercase_ascii word in
                     let locations_ci = Option.value ~default:Int_set.empty
                         (String_map.find_opt word locations_of_word_ci)
                                        |> Int_set.add loc
                     in
                     { locations_of_word_ci = String_map.add word_ci locations_ci locations_of_word_ci;
                       line_of_location_ci = Int_map.add loc line line_of_location_ci;
                       word_of_location_ci = Int_map.add loc word_ci word_of_location_ci;
                     }
                   )
    empty
