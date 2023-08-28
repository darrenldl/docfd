type t = {
  word_of_index : string CCVector.vector;
  mutable index_of_word : int String_map.t;
}

let make () : t = {
  word_of_index = CCVector.create ();
  index_of_word = String_map.empty;
}

let add (t : t) (word : string) : int =
  match String_map.find_opt word t.index_of_word with
  | Some index -> index
  | None -> (
      let index = CCVector.length t.word_of_index in
      CCVector.push t.word_of_index word;
      t.index_of_word <- String_map.add word index t.index_of_word;
      index
    )

let word_of_index t i : string =
  CCVector.get t.word_of_index i

let index_of_word t s : int =
  String_map.find s t.index_of_word

let to_json (t : t) : Yojson.Safe.t =
  let l =
    CCVector.to_seq t.word_of_index
    |> Seq.map (fun s -> `String s)
    |> List.of_seq
  in
  `List l

let of_json (json : Yojson.Safe.t) : t option =
  match json with
  | `List l -> (
      let db = make () in
      let exception Invalid in
      try
        List.iter (fun x ->
            match x with
            | `String s -> (
                add db s |> ignore
              )
            | _ -> raise Invalid
          ) l;
        Some db
      with
      | Invalid -> None
    )
  | _ -> None
