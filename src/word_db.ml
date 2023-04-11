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

let add (word : string) (t : t) : int * t =
  match String_map.find_opt word t.index_of_word with
  | Some index -> index, t
  | None ->
    let index = t.unique_count in
    let unique_count = t.unique_count + 1 in
    (index,
     { unique_count;
       word_of_index = Int_map.add index word t.word_of_index;
       index_of_word = String_map.add word index t.index_of_word;
     })

let word_of_index i t : string =
  Int_map.find i t.word_of_index

let index_of_word s t : int =
  String_map.find s t.index_of_word
