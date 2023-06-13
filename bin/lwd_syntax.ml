let ( let+ ) : 'a Lwd.t -> ('a -> 'b) -> 'b Lwd.t =
  (fun v f -> Lwd.map ~f v)

let ( let* ) : 'a Lwd.t -> ('a -> 'b Lwd.t) -> 'b Lwd.t =
  (fun v f -> Lwd.join (Lwd.map ~f v))
