type typ = [
  | `Markdown
  | `Wiki
  | `URL
]

type t = {
  start_pos : int;
  end_inc_pos : int;
  typ : typ;
  link : string;
}
