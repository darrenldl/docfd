let flush_encoder (encoder : Pbrt.Encoder.t) (buf : Buffer.t) =
  Buffer.add_string buf (Pbrt.Encoder.to_string encoder)

let encode_stage
(encoder : Pbrt.Encoder.t)
(buf : Buffer.t)
(f : Pbrt.Encoder.t -> unit)
=
  Pbrt.Encoder.clear encoder;
  f encoder;
  flush_encoder encoder buf
