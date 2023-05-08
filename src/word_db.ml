type t = {
  lock : Mutex.t;
  mutable unique_count : int;
  word_of_index : (int, string) Hashtbl.t;
  index_of_word : (string, int) Hashtbl.t;
}

let t : t = {
  lock = Mutex.create ();
  unique_count = 0;
  word_of_index = Hashtbl.create 40960;
  index_of_word = Hashtbl.create 40960;
}

let add (word : string) : int =
  Mutex.lock t.lock;
  let index =
    match Hashtbl.find_opt t.index_of_word word with
    | Some index -> index
    | None -> (
        let index = t.unique_count in
        t.unique_count <- t.unique_count + 1;
        Hashtbl.replace t.word_of_index index word;
        Hashtbl.replace t.index_of_word word index;
        index
      )
  in
  Mutex.unlock t.lock;
  index

let word_of_index i : string =
  Mutex.lock t.lock;
  let x = Hashtbl.find t.word_of_index i in
  Mutex.unlock t.lock;
  x

let index_of_word s : int =
  Mutex.lock t.lock;
  let x = Hashtbl.find t.index_of_word s in
  Mutex.unlock t.lock;
  x
