type t = {
  word_of_index : string CCVector.vector;
  mutable index_of_word : int String_map.t;
}

let equal (x : t) (y : t) =
  CCVector.equal String.equal x.word_of_index y.word_of_index
  &&
  String_map.equal Int.equal x.index_of_word y.index_of_word

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

let encode (buf : Buffer.t) (t : t) : unit =
  Misc_utils.encode_int buf (CCVector.length t.word_of_index);
  CCVector.iter (Misc_utils.encode_string buf) t.word_of_index

let decode (s : string) (pos : int ref) : t =
  let len = Misc_utils.decode_int s pos in
  let decode_string () = Misc_utils.decode_string s pos in
  let db = make () in
  for _=0 to len-1 do
    let s = decode_string () in
    add db s |> ignore
  done;
  db
