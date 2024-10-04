type t = {
  desc : string;
  last_action : Action.t option;
  store : Document_store.t;
}

let make desc last_action store : t =
  { desc; last_action; store }

let empty : t =
  {
    desc = "";
    last_action = None;
    store = Document_store.empty;
  }
