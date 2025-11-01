module Sort_by = struct
  type typ = [
    | `Path_date
    | `Path
    | `Score
    | `Mod_time
  ]

  type t = typ * Document.Compare.order

  let default : t = (`Score, `Desc)

  let default_no_score : t = (`Path, `Asc)

  let pp formatter ((typ, order) : t) =
    Fmt.pf formatter "%s,%s"
      (match typ with
       | `Path_date -> "path-date"
       | `Path -> "path"
       | `Score -> "score"
       | `Mod_time -> "mod-time"
      )
      (match order with
       | `Asc -> "asc"
       | `Desc -> "desc"
      )

  let p ~no_score : t Angstrom.t =
    let open Angstrom in
    let open Parser_components in
    skip_spaces *>
    (choice (List.filter_map
               Fun.id ([
                   Some (string "path" *> return `Path);
                   Some (string "path-date" *> return `Path_date);
                   (if no_score then
                      None
                    else
                      Some (string "score" *> return `Score));
                   Some (string "mod-time" *> return `Mod_time);
                 ]))
     <|>
     (take_while (fun c -> is_not_space c && c <> ',') >>=
      fun s -> fail (Fmt.str "unrecognized sort by type: %s" s))
    )
    >>= fun typ ->
    skip_spaces *>
    char ',' *> skip_spaces *>
    (choice [
        string "asc" *> return `Asc;
        string "desc" *> return `Desc;
      ]
     <|>
     (take_while is_not_space >>=
      fun s -> fail (Fmt.str "unrecognized sort by order: %s" s))
    )
    >>= fun order -> (
      return (typ, order)
    )

  let parse ~no_score s =
    match Angstrom.(parse_string ~consume:Consume.All) (p ~no_score) s with
    | Ok t -> Ok t
    | Error msg -> Error msg
end

type t = [
  | `Mark of string
  | `Mark_listed
  | `Unmark of string
  | `Unmark_listed
  | `Unmark_all
  | `Drop of string
  | `Drop_all_except of string
  | `Drop_marked
  | `Drop_unmarked
  | `Drop_listed
  | `Drop_unlisted
  | `Narrow_level of int
  | `Sort of Sort_by.t * Sort_by.t
  | `Sort_by_fzf of string * int String_map.t option
  | `Search of string
  | `Filter of string
]

let pp fmt (t : t) =
  match t with
  | `Mark s -> Fmt.pf fmt "mark: %s" s
  | `Mark_listed -> Fmt.pf fmt "mark listed"
  | `Unmark s -> Fmt.pf fmt "unmark: %s" s
  | `Unmark_listed -> Fmt.pf fmt "unmark listed"
  | `Unmark_all -> Fmt.pf fmt "unmark all"
  | `Drop s -> Fmt.pf fmt "drop: %s" s
  | `Drop_all_except s -> Fmt.pf fmt "drop all except: %s" s
  | `Drop_marked -> Fmt.pf fmt "drop marked"
  | `Drop_unmarked -> Fmt.pf fmt "drop unmarked"
  | `Drop_listed -> Fmt.pf fmt "drop listed"
  | `Drop_unlisted -> Fmt.pf fmt "drop unlisted"
  | `Narrow_level x -> Fmt.pf fmt "narrow level: %d" x
  | `Sort (x, y) -> (
      Fmt.pf fmt "sort by: %a; %a"
        Sort_by.pp
        x
        Sort_by.pp
        y
    )
  | `Sort_by_fzf (query, _ranking) -> (
      if String.length (String.trim query) = 0 then (
        Fmt.pf fmt "sort by fzf"
      ) else (
        Fmt.pf fmt "sort by fzf: %s" query
      )
    )
  | `Search s -> (
      if String.length s = 0 then (
        Fmt.pf fmt "clear search"
      ) else (
        Fmt.pf fmt "search: %s" s
      )
    )
  | `Filter s -> (
      if String.length s = 0 then (
        Fmt.pf fmt "clear filter"
      ) else (
        Fmt.pf fmt "filter: %s" s
      )
    )

let to_string (t : t) =
  Fmt.str "%a" pp t

module Parsers = struct
  type t' = t

  open Angstrom
  open Parser_components

  let any_string_trimmed =
    any_string >>| String.trim

  let p : t' Angstrom.t =
    skip_spaces *>
    choice [
      string "mark" *> skip_spaces *> (
        choice [
          char ':' *> skip_spaces *>
          any_string_trimmed >>| (fun s -> (`Mark s));
          string "listed" *> skip_spaces *> return `Mark_listed;
        ]
      );
      string "unmark" *> skip_spaces *> (
        choice [
          string "listed" *> skip_spaces *> return `Unmark_listed;
          string "all" *> skip_spaces *> return `Unmark_all;
          char ':' *> skip_spaces *>
          any_string_trimmed >>| (fun s -> (`Unmark s));
        ]
      );
      string "drop" *> skip_spaces *> (
        choice [
          char ':' *> skip_spaces *>
          any_string_trimmed >>| (fun s -> (`Drop s));
          string "all" *> skip_spaces *>
          string "except" *> skip_spaces *> char ':' *> skip_spaces *>
          any_string_trimmed >>| (fun s -> (`Drop_all_except s));
          string "listed" *> skip_spaces *> return `Drop_listed;
          string "unlisted" *> skip_spaces *> return `Drop_unlisted;
          string "marked" *> skip_spaces *> return `Drop_marked;
          string "unmarked" *> skip_spaces *> return `Drop_unmarked;
        ]
      );
      string "narrow" *> skip_spaces *> (
        choice [
          string "level" *> skip_spaces *>
          char ':' *> skip_spaces *>
          satisfy (function '0'..'9' -> true | _ -> false) <* skip_spaces >>|
          (fun c -> `Narrow_level (Char.code c - Char.code '0'));
        ]
      );
      string "clear" *> skip_spaces *> (
        choice [
          string "search" *> skip_spaces *> return (`Search "");
          string "filter" *> skip_spaces *> return (`Filter "");
        ]
      );
      string "sort" *> skip_spaces *>
      string "by" *> skip_spaces *>
      string "fzf" *> skip_spaces *>
      char ':' *> skip_spaces *>
      any_string_trimmed >>| (fun s -> (`Sort_by_fzf (s, None)));
      string "sort" *> skip_spaces *>
      string "by" *> skip_spaces *>
      string "fzf" *> skip_spaces *>
      (return (`Sort_by_fzf ("", None)));
      (string "sort" *> skip_spaces *>
       string "by" *> skip_spaces *>
       char ':' *> skip_spaces *>
       Sort_by.p ~no_score:false >>= fun sort_by ->
       skip_spaces *>
       char ';' *>
       skip_spaces *>
       Sort_by.p ~no_score:true >>| fun sort_by_no_score ->
       `Sort (sort_by, sort_by_no_score));
      string "search" *> skip_spaces *>
      char ':' *> skip_spaces *>
      any_string_trimmed >>| (fun s -> (`Search s));
      string "filter" *> skip_spaces *>
      char ':' *> skip_spaces *>
      any_string_trimmed >>| (fun s -> (`Filter s));
    ]
end

let of_string (s : string) : t option =
  match Angstrom.(parse_string ~consume:Consume.All) Parsers.p s with
  | Ok t -> Some t
  | Error _ -> None
