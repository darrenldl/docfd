let time () =
  Int32.of_float (Unix.gettimeofday ())

let compress_to_path ~(path : string) (s : string) : (unit, string) result =
  try
  let oc = Gzip.open_out path in
  Gzip.output_substring oc s 0 (String.length s);
  Gzip.close_out oc;
  Ok ()
  with
  | _ -> Error (Fmt.str "failed to write to %s" path)

let decompress_from_path ~(path : string) : string option =
  try
    let ic = Gzip.open_in path in
    let buf_final = Buffer.create (1024 * 1024) in
    let read_size = 1024 * 1024 in
    let buf = Bytes.create read_size in
    (try
      let run = ref true in
      while !run do
        let len = Gzip.input ic buf 0 read_size in
        if len = 0 then (
          run := false;
        );
        Buffer.add_subbytes buf_final buf 0 len
      done
    with
    | End_of_file -> ()
    );
    Gzip.close_in ic;
    Some (Buffer.contents buf_final)
  with
  | _ -> None
