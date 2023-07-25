type t = {
  unique_count : int;
  word_of_index : string Int_map.t;
  index_of_word : int String_map.t;
}

let empty : t = {
  unique_count = 0;
  word_of_index = Int_map.empty;
  index_of_word = String_map.empty;
}

let add (word : string) (t : t) : t * int =
  match String_map.find_opt word t.index_of_word with
  | Some index -> (t, index)
  | None -> (
      let index = t.unique_count in
      ({
        unique_count = t.unique_count + 1;
        word_of_index = Int_map.add index word t.word_of_index;
        index_of_word = String_map.add word index t.index_of_word;
      },
        index
      )
    )

let word_of_index i t : string =
  Int_map.find i t.word_of_index

let index_of_word s t : int =
  String_map.find s t.index_of_word

let to_json (t : t) : Yojson.Safe.t =
  let l =
    Int_map.to_seq t.word_of_index
    |> Seq.map (fun (_, s) -> `String s)
    |> List.of_seq
  in
  `List l

let of_json (json : Yojson.Safe.t) : t option =
  match json with
  | `List l -> (
      let db = ref empty in
      let exception Invalid in
      try
        List.iter (fun x ->
            match x with
            | `String s -> (
                let (db', _) = add s !db in
                db := db'
              )
            | _ -> raise Invalid
          ) l;
        Some !db
      with
      | Invalid -> None
    )
  | _ -> None
