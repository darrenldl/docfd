let hchunk_rev ~width (img : Notty.image) : Notty.image list =
  let open Notty in
  let rec aux acc img =
    let img_width = I.width img in
    if img_width <= width then (
      img :: acc
    ) else (
      let acc = (I.hcrop 0 (img_width - width) img) :: acc in
      aux acc (I.hcrop width 0 img)
    )
  in
  aux [] img

let of_images ~width (words : Notty.image list) : Notty.image =
  let open Notty in
  if width = 0 then (
    invalid_arg "width must be > 0"
  );
  let grid : Notty.image list list =
    List.fold_left
      (fun ((cur_len, acc) : int * Notty.image list list) word ->
         let word_len = I.width word in
         let new_len = cur_len + word_len in
         match acc with
         | [] -> (new_len, [ [ word ] ])
         | line :: rest -> (
             if new_len > width then (
               if word_len > width then (
                 let lines =
                   hchunk_rev ~width word
                   |> List.map (fun x -> [ x ])
                 in
                 (0, [] :: (lines @ acc))
               ) else (
                 (word_len, [ word ] :: acc)
               )
             ) else (
               (new_len, (word :: line) :: rest)
             )
           )
      )
      (0, [])
      words
    |> snd
    |> List.rev_map List.rev
  in
  grid
  |> List.map I.hcat
  |> I.vcat

let of_words ?(attr = Notty.A.empty) ~width words =
  List.map (Notty.I.string attr) words
  |> of_images ~width
