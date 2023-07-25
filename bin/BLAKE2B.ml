module B = Digestif.Make_BLAKE2B (struct
    let digest_size = 20
  end)

let hash_of_file ~env ~path =
  let fs = Eio.Stdenv.fs env in
  let ctx = ref B.empty in
  try
    Eio.Path.(with_open_in (fs / path))
      (fun flow ->
         match
           Eio.Buf_read.parse ~max_size:Params.hash_chunk_size
             (fun buf ->
                try
                  while true do
                    ctx := B.feed_string !ctx (Eio.Buf_read.take Params.hash_chunk_size buf)
                  done
                with
                | End_of_file ->
                  ctx := B.feed_string !ctx (Eio.Buf_read.take_all buf)
             )
             flow
         with
         | Ok () -> Ok (!ctx |> B.get |> B.to_hex)
         | Error (`Msg msg) -> Error msg
      )
  with
  | _ -> Error (Printf.sprintf "Failed to hash file: %s" path)
