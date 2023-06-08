type t = {
  lock : Mutex.t;
  mutable unique_count : int;
  word_of_index : (int, string) Kcas_data.Hashtbl.t;
  index_of_word : (string, int) Kcas_data.Hashtbl.t;
}

let t : t = {
  lock = Mutex.create ();
  unique_count = 0;
  word_of_index = Kcas_data.Hashtbl.create ~min_buckets:1000 ();
  index_of_word = Kcas_data.Hashtbl.create ~min_buckets:1000 ();
}

let add (word : string) : int =
  Mutex.lock t.lock;
  let index =
    match Kcas_data.Hashtbl.find_opt t.index_of_word word with
    | Some index -> index
    | None -> (
        let index = t.unique_count in
        t.unique_count <- t.unique_count + 1;
        Kcas_data.Hashtbl.replace t.word_of_index index word;
        Kcas_data.Hashtbl.replace t.index_of_word word index;
        index
      )
  in
  Mutex.unlock t.lock;
  index

let word_of_index i : string =
  Kcas_data.Hashtbl.find t.word_of_index i

let index_of_word s : int =
  Kcas_data.Hashtbl.find t.index_of_word s
