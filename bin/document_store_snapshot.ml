let counter = ref 0

type t = {
  last_command : Command.t option;
  store : Document_store.t;
  committed : bool;
  id : int;
}

let committed t = t.committed

let last_command t = t.last_command

let store t = t.store

let id t = t.id

let equal_id x y =
  id x = id y

let make ?(committed = true) ~last_command store : t =
  let id = !counter in
  counter := id + 1;
  { last_command; store; id; committed }

let make_empty ?committed () =
  make ?committed ~last_command:None Document_store.empty

let update_store store t =
  { t with store }
