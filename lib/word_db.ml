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

let size t = CCVector.length t.word_of_index

let encode (t : t) (encoder : Pbrt.Encoder.t) (buf : Buffer.t) =
  Pbrt.Encoder.clear encoder;
  Pbrt.Encoder.int_as_bits32 (CCVector.length t.word_of_index) encoder;
  Buffer.add_string buf (Pbrt.Encoder.to_string encoder);
  Pbrt.Encoder.clear encoder;
  CCVector.iter (fun x ->
      Pbrt.Encoder.string x encoder;
    )
    t.word_of_index

let decode (decoder : Pbrt.Decoder.t) : t =
  let length = Pbrt.Decoder.int_as_bits32 decoder in
  let db = make () in
  for _=0 to length-1 do
    let s = Pbrt.Decoder.string decoder in
    add db s |> ignore
  done;
  db
