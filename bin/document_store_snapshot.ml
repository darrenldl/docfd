type t = {
  last_action : Action.t option;
  store : Document_store.t;
}

let make last_action store : t =
  { last_action; store }

let empty : t =
  {
    last_action = None;
    store = Document_store.empty;
  }
