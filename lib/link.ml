type typ = [
  | `Markdown
  | `Wiki
  | `URL
]

let string_of_typ (typ : typ) =
  match typ with
  | `Markdown -> "markdown"
  | `Wiki -> "wiki"
  | `URL -> "url"

let typ_of_string (s : string) : typ option =
  match String.lowercase_ascii s with
  | "markdown" -> Some `Markdown
  | "wiki" -> Some `Wiki
  | "url" -> Some `URL
  | _ -> None

type t = {
  start_pos : int;
  end_inc_pos : int;
  typ : typ;
  link : string;
}
