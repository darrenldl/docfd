let of_images ~width (words : Notty.image list) : Notty.image =
  let open Notty in
  let grid : Notty.image list list =
    List.fold_left
      (fun ((cur_len, acc) : int * Notty.image list list) word ->
         let word_len = I.width word in
         let new_len = cur_len + word_len in
         match acc with
         | [] -> (new_len, [ [ word ] ])
         | line :: rest -> (
             if new_len > width then (
               (* If the (terminal) width is really small,
                  then this new line may still overflow visually.
                  But since we still need to put this one word somewhere eventually,
                  it might as well be here as a line with a single
                  word.

                  Otherwise we just get an infinite loop where we keep trying
                  to find a non-existent sufficiently spacious line to put the word.
               *)
               (word_len, [ word ] :: acc)
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

let of_words ~width words =
  List.map (Notty.I.string Notty.A.empty) words
  |> of_images ~width