type t = {
  last_command : Command.t option;
  store : Document_store.t;
}

let make last_command store : t =
  { last_command; store }

let empty : t =
  {
    last_command = None;
    store = Document_store.empty;
  }
