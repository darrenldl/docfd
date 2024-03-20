open Docfd_lib

let lines = [
  "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer placerat lacus non cursus";
  "tincidunt. Suspendisse viverra leo ac quam tincidunt, quis euismod neque tempus. ";
  "Vestibulum rutrum commodo tristique. Curabitur tristique dapibus dolor, vitae porttitor";
  "est tristique quis. Sed urna ex, gravida vitae ipsum vel, fermentum viverra risus. ";
  "Maecenas et nulla iaculis, bibendum libero vitae, varius est. Fusce eros enim, placerat ";
  "quis magna eu, rutrum vulputate ante. Praesent non mi vel ipsum finibus lobortis. ";
  "Duis posuere auctor hendrerit. Nunc sodales egestas vestibulum. Quisque suscipit maximus ";
  "aliquam. Pellentesque tempor mi condimentum bibendum bibendum. Donec vitae accumsan quam, ";
  "nec vulputate lectus. Nulla ligula ipsum, dictum vel augue at, semper vestibulum ex. ";
  "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed arcu ligula, cursus nec ";
  "lacinia ut, lobortis in libero.";
  "";
  "Sed ultricies placerat urna, hendrerit ornare elit semper sit amet. Praesent ";
  "pretium blandit velit, eu imperdiet lectus tincidunt ut. Suspendisse eget eros ";
  "tellus. Nulla tristique vel libero non dapibus. Ut scelerisque sem sit amet ";
  "odio mattis vestibulum. Nam vitae commodo mi. Vestibulum consequat orci at tellus porta ";
  "placerat.";
  "";
  "In vel mi vestibulum felis accumsan congue eget efficitur tortor. Integer ";
  "quam purus, malesuada vel nisl at, posuere vestibulum augue. Curabitur velit ";
  "tortor, vestibulum id placerat eu, convallis at velit. Ut a lectus ";
  "quis erat tincidunt aliquet. Etiam ut erat magna. Maecenas quis commodo leo, ";
  "eleifend elementum ante. Nullam dapibus erat augue, a bibendum quam volutpat id. ";
  "Morbi in ullamcorper arcu. Fusce venenatis lacus purus, vel pellentesque mi ";
  "elementum a. Maecenas at mattis massa. Fusce ut elit tortor. Morbi rhoncus ";
  "molestie orci eu malesuada. Aliquam gravida rutrum sem, vitae condimentum magna ";
  "convallis pulvinar. Duis urna lacus, ultrices a ultrices pharetra, eleifend ";
  "in ante. Fusce id elementum dolor. Nullam ornare nisl ac ultrices lobortis.";
  "";
  "Proin ullamcorper vulputate enim sed facilisis. Praesent vel mi metus. ";
  "Fusce sagittis efficitur odio at condimentum. Nullam mollis lacinia consequat. ";
  "Integer vel ex sit amet nunc aliquam molestie et eu nibh. Nam leo nunc, laoreet ";
  "vitae iaculis sit amet, dapibus sit amet neque. Suspendisse eleifend, leo eget ";
  "tempor molestie, massa enim auctor dui, quis vehicula erat urna id felis. Vivamus ";
  "pharetra, sem non tempus ornare, risus tortor posuere tortor, eu pellentesque eros est ";
  "ac erat. Sed sit amet tellus nisl. Phasellus magna urna, tincidunt in sem ";
  "id, aliquam vulputate leo. Sed eleifend justo eu mauris egestas imperdiet. Fusce sagittis";
  ", turpis ac efficitur pulvinar, purus tellus gravida sem, eget accumsan nisl sapien a ";
  "ante. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac ";
  "turpis egestas. Nunc eget nibh orci. Cras facilisis facilisis sapien, ";
  "a vehicula lorem imperdiet vel. Proin vel nulla nisi.";
  "";
  "Aenean sit amet risus at lectus pellentesque pellentesque at eu quam. ";
  "Duis euismod porttitor ante quis lacinia. Cras sit amet vulputate nunc. ";
  "Integer sollicitudin vitae sapien finibus fermentum. Donec eu tellus ";
  "suscipit, dignissim turpis non, eleifend massa. Nullam quis ex nisi. ";
  "Quisque dignissim quis leo eu finibus.  ";
]

let bench ~name ~cycle (f : unit -> 'a) =
  let start_time = Sys.time () in
  for _=0 to cycle-1 do
    f () |> ignore
  done;
  let end_time = Sys.time () in
  Printf.printf "%s: time per cycle: %6fs\n" name
    ((end_time -. start_time) /. (float_of_int cycle))

let main env =
  Eio.Switch.run @@ fun sw ->
  let pool = Task_pool.make ~sw (Eio.Stdenv.domain_mgr env) in
  let index = Index.of_lines pool (List.to_seq lines) in
  let fuzzy_max_edit_distance = 3 in
  let search_exp = Search_exp.make ~fuzzy_max_edit_distance "vestibul rutru" |> Option.get in
  let s = "PellentesquePellentesque" in
  for len=1 to 20 do
    let limit = 2 in
    bench ~name:(Fmt.str "Spelll.of_string, limit: %d, len %2d:" limit len) ~cycle:10 (fun () ->
        Spelll.of_string ~limit:2 (String.sub s 0 len))
  done;
  for len=1 to 20 do
    let limit = 1 in
    bench ~name:(Fmt.str "Spelll.of_string, limit: %d, len %2d:" limit len) ~cycle:10 (fun () ->
        Spelll.of_string ~limit:1 (String.sub s 0 len))
  done;
  bench ~name:"Index.search" ~cycle:1000 (fun () ->
      Index.search pool (Stop_signal.make ()) search_exp index);
  ()

let () = Eio_main.run main
