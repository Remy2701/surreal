import birl
import gjwt
import gjwt/header
import gjwt/key
import gjwt/payload
import gleam/bool
import gleam/dynamic
import gleam/dynamic/decode
import gleam/order
import gleam/result

pub type Payload {
  Payload(
    issued_at: birl.Time,
    not_valid_before: birl.Time,
    expire_at: birl.Time,
    issuer: String,
    jwt_id: String,
    namespace: String,
    database: String,
    access: String,
    id: String,
  )
}

fn int_time_decoder() -> decode.Decoder(birl.Time) {
  decode.map(decode.int, birl.from_unix)
}

pub fn verify_jwt(jwt: String, key: key.Key) -> Result(Payload, Nil) {
  use <- bool.guard(!gjwt.verify(jwt, key), Error(Nil))

  use data <- result.try(gjwt.from_jwt(jwt, key))
  let #(_header, payload) = data

  use issued_at <- result.try(
    payload.get_claim(payload, "iat", int_time_decoder())
    |> result.map_error(fn(_) { Nil }),
  )
  use not_valid_before <- result.try(
    payload.get_claim(payload, "nbf", int_time_decoder())
    |> result.map_error(fn(_) { Nil }),
  )
  use expire_at <- result.try(
    payload.get_claim(payload, "exp", int_time_decoder())
    |> result.map_error(fn(_) { Nil }),
  )
  use issuer <- result.try(
    payload.get_claim(payload, "iss", decode.string)
    |> result.map_error(fn(_) { Nil }),
  )
  use jwt_id <- result.try(
    payload.get_claim(payload, "jti", decode.string)
    |> result.map_error(fn(_) { Nil }),
  )
  use namespace <- result.try(
    payload.get_claim(payload, "NS", decode.string)
    |> result.map_error(fn(_) { Nil }),
  )
  use database <- result.try(
    payload.get_claim(payload, "DB", decode.string)
    |> result.map_error(fn(_) { Nil }),
  )
  use access <- result.try(
    payload.get_claim(payload, "AC", decode.string)
    |> result.map_error(fn(_) { Nil }),
  )
  use id <- result.try(
    payload.get_claim(payload, "ID", decode.string)
    |> result.map_error(fn(_) { Nil }),
  )

  use <- bool.guard(
    birl.compare(birl.utc_now(), not_valid_before) == order.Lt,
    Error(Nil),
  )

  use <- bool.guard(
    birl.compare(birl.utc_now(), expire_at) == order.Gt,
    Error(Nil),
  )

  Ok(Payload(
    issued_at,
    not_valid_before,
    expire_at,
    issuer,
    jwt_id,
    namespace,
    database,
    access,
    id,
  ))
}

pub fn generate_jwt(payload: Payload, key: key.Key) -> String {
  let gjwt_payload =
    payload.new()
    |> payload.add_claim(#(
      "iat",
      dynamic.int(payload.issued_at |> birl.to_unix),
    ))
    |> payload.add_claim(#(
      "nbf",
      dynamic.int(payload.not_valid_before |> birl.to_unix),
    ))
    |> payload.add_claim(#(
      "exp",
      dynamic.int(payload.expire_at |> birl.to_unix),
    ))
    |> payload.add_claim(#("iss", dynamic.string(payload.issuer)))
    |> payload.add_claim(#("jti", dynamic.string(payload.jwt_id)))
    |> payload.add_claim(#("NS", dynamic.string(payload.namespace)))
    |> payload.add_claim(#("DB", dynamic.string(payload.database)))
    |> payload.add_claim(#("AC", dynamic.string(payload.access)))
    |> payload.add_claim(#("ID", dynamic.string(payload.id)))

  let header =
    header.new()
    |> header.add_entry(#("alg", dynamic.string(key.algorithm)))
    |> header.add_entry(#("typ", dynamic.string("JWT")))

  gjwt.sign_off(#(header, gjwt_payload), key)
}
