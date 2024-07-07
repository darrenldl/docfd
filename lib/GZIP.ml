(* Basically fully copied from examples in Decompress manual *)

let time () =
  Int32.of_float (Unix.gettimeofday ())

let compress (s : string) : string =
  let i = De.bigstring_create De.io_buffer_size in
  let o = De.bigstring_create De.io_buffer_size in
  let config = Gz.Higher.configuration Gz.Unix time in
  let w = De.Lz77.make_window ~bits:15 in
  let q = De.Queue.create 1024 in
  let res = Buffer.create 4096 in
  let cur = ref 0 in
  let refill buf =
    let len = min (String.length s - !cur) De.io_buffer_size in
    Bigstringaf.blit_from_string s ~src_off:!cur buf ~dst_off:0 ~len;
    cur := !cur + len;
    len
  in
  let flush buf len =
    let str = Bigstringaf.substring buf ~off:0 ~len in
    Buffer.add_string res str
  in
  Gz.Higher.compress ~w ~q ~level:4 ~refill ~flush () config i o;
  Buffer.contents res

let decompress (s : string) : string option =
  let i = De.bigstring_create De.io_buffer_size in
  let o = De.bigstring_create De.io_buffer_size in
  let r = Buffer.create 0x1000 in
  let cur = ref 0 in
  let refill buf =
    let len = min (String.length s - !cur) De.io_buffer_size in
    Bigstringaf.blit_from_string s ~src_off:!cur buf ~dst_off:0 ~len;
    cur := !cur + len;
    len
  in
  let flush buf len =
    let str = Bigstringaf.substring buf ~off:0 ~len in
    Buffer.add_string r str
  in
  match Gz.Higher.uncompress ~refill ~flush i o with
  | Ok _ -> Some (Buffer.contents r)
  | Error _ -> None
