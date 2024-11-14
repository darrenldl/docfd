let counter = ref 0

type t = {
  last_command : Command.t option;
  store : Document_store.t;
  id : int;
}

let last_command t = t.last_command

let store t = t.store

let id t = t.id

let equal_id x y =
  id x = id y

let make ~last_command store : t =
  let id = !counter in
  counter := id + 1;
  { last_command; store; id }

let make_empty () =
  make ~last_command:None Document_store.empty

let update_store store t =
  { t with store }
