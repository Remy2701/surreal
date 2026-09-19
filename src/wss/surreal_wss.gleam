import collie
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http/request
import gleam/io
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import surreal
import surreal_ql

pub type SurrealWssConnection {
  SurrealWssConnection(
    subject: process.Subject(collie.WebsocketMessage(SurrealWssMessage)),
    connection: surreal.Connection,
  )
}

pub fn with_namespace(
  connection: SurrealWssConnection,
  namespace: String,
) -> SurrealWssConnection {
  SurrealWssConnection(
    ..connection,
    connection: surreal.with_namespace(connection.connection, namespace),
  )
}

pub fn with_database(
  connection: SurrealWssConnection,
  database: String,
) -> SurrealWssConnection {
  SurrealWssConnection(
    ..connection,
    connection: surreal.with_database(connection.connection, database),
  )
}

pub type SurrealWssError {
  InvalidUrl
  FailedToConnect
}

pub type SurrealWssMessage {
  Query(
    query: String,
    receiver: process.Subject(SurrealWssResponse(dynamic.Dynamic)),
  )
  Signup(
    collection: String,
    fields: List(#(String, surreal_ql.SurrealQL)),
    receiver: process.Subject(SurrealWssResponse(dynamic.Dynamic)),
  )
  Signin(
    collection: String,
    fields: List(#(String, surreal_ql.SurrealQL)),
    receiver: process.Subject(SurrealWssResponse(dynamic.Dynamic)),
  )
  Use(
    namespace: String,
    database: String,
    receiver: process.Subject(SurrealWssResponse(dynamic.Dynamic)),
  )
}

type SurrealWssState {
  SurrealWssState(
    connection: surreal.Connection,
    receivers: dict.Dict(
      Int,
      process.Subject(SurrealWssResponse(dynamic.Dynamic)),
    ),
    last_id: Int,
    pending_use: option.Option(#(String, String)),
  )
}

pub type SurrealWssResponse(a) {
  AuthResponse(id: Int, result: String)
  ErrorResponse(id: Int, error: SurrealWssResponseError)
  QueryResponse(id: Int, result: List(surreal.SurrealResponse(a)))
  UseResponse(id: Int)
}

pub type SurrealWssResponseError {
  SurrealWssResponseError(
    cause: option.Option(String),
    code: Int,
    kind: String,
    message: String,
  )
}

fn surreal_wss_response_error_decoder() -> decode.Decoder(
  SurrealWssResponseError,
) {
  use cause <- decode.field("cause", decode.optional(decode.string))
  use code <- decode.field("code", decode.int)
  use kind <- decode.field("kind", decode.string)
  use message <- decode.field("message", decode.string)

  decode.success(SurrealWssResponseError(cause, code, kind, message))
}

fn surreal_wss_response_decoder(
  decoder: decode.Decoder(a),
) -> decode.Decoder(SurrealWssResponse(a)) {
  use id <- decode.field("id", decode.int)

  use result <- decode.optional_field(
    "result",
    option.None,
    decode.one_of(
      decode.list(surreal.surreal_response_decoder(decoder))
        |> decode.map(QueryResponse(id, _))
        |> decode.map(option.Some),
      [
        decode.string
          |> decode.map(AuthResponse(id, _))
          |> decode.map(option.Some),
        decode.success(UseResponse(id)) |> decode.map(option.Some),
      ],
    ),
  )

  use error <- decode.optional_field(
    "error",
    option.None,
    surreal_wss_response_error_decoder()
      |> decode.map(ErrorResponse(id, _))
      |> decode.map(option.Some),
  )

  case result, error {
    option.Some(result), _ -> decode.success(result)
    option.None, option.Some(error) -> decode.success(error)
    option.None, option.None ->
      decode.failure(
        QueryResponse(0, []),
        "Missing both result and error fields",
      )
  }
}

pub fn send(
  connection: SurrealWssConnection,
  message: SurrealWssMessage,
) -> Nil {
  process.send(connection.subject, collie.to_user_message(message))
}

pub fn send_query(
  connection: SurrealWssConnection,
  query: String,
  receiver: process.Subject(SurrealWssResponse(dynamic.Dynamic)),
) -> Nil {
  send(connection, Query(query, receiver))
}

pub fn send_signup(
  connection: SurrealWssConnection,
  collection: String,
  fields: List(#(String, surreal_ql.SurrealQL)),
  receiver: process.Subject(SurrealWssResponse(dynamic.Dynamic)),
) -> Nil {
  send(connection, Signup(collection, fields, receiver))
}

pub fn send_signin(
  connection: SurrealWssConnection,
  collection: String,
  fields: List(#(String, surreal_ql.SurrealQL)),
  receiver: process.Subject(SurrealWssResponse(dynamic.Dynamic)),
) -> Nil {
  send(connection, Signin(collection, fields, receiver))
}

pub type SurrealWssConnectionBuilder {
  SurrealWssConnectionBuilder(
    connection: surreal.Connection,
    name: option.Option(
      process.Name(collie.WebsocketMessage(SurrealWssMessage)),
    ),
    on_close: fn(collie.CloseReason) -> Nil,
  )
}

pub fn new(connection: surreal.Connection) {
  SurrealWssConnectionBuilder(connection, option.None, fn(_) { Nil })
}

pub fn named(
  builder: SurrealWssConnectionBuilder,
  name: process.Name(collie.WebsocketMessage(SurrealWssMessage)),
) -> SurrealWssConnectionBuilder {
  SurrealWssConnectionBuilder(..builder, name: option.Some(name))
}

pub fn on_close(
  builder: SurrealWssConnectionBuilder,
  on_close: fn(collie.CloseReason) -> Nil,
) -> SurrealWssConnectionBuilder {
  SurrealWssConnectionBuilder(..builder, on_close: on_close)
}

pub fn start(
  builder: SurrealWssConnectionBuilder,
) -> Result(SurrealWssConnection, SurrealWssError) {
  use req <- result.try(
    request.to(builder.connection.endpoint <> "/rpc")
    |> result.map_error(fn(_) { InvalidUrl }),
  )
  let req =
    req
    |> request.prepend_header("Authorization", builder.connection.authorization)
    |> request.prepend_header("Surreal-DB", builder.connection.database)
    |> request.prepend_header("Surreal-NS", builder.connection.namespace)
    |> request.prepend_header("Sec-WebSocket-Protocol", "json")

  let collie =
    req
    |> collie.new(SurrealWssState(
      connection: builder.connection,
      receivers: dict.new(),
      pending_use: option.None,
      last_id: 0,
    ))
    |> collie.on_message(handle_message)
    |> collie.on_close(fn(_, reason) { builder.on_close(reason) })

  let collie = case builder.name {
    option.Some(name) -> collie.named(collie, name)
    option.None -> collie
  }

  use client <- result.try(
    collie
    |> collie.start()
    |> result.map_error(fn(_) { FailedToConnect }),
  )

  let credentials = surreal.decode_credentials(builder.connection)
  case credentials {
    Ok(#(username, password)) -> {
      let subject = process.new_subject()
      send_signin(
        SurrealWssConnection(client.data, builder.connection),
        "",
        [
          #("user", surreal_ql.String(username)),
          #("pass", surreal_ql.String(password)),
        ],
        subject,
      )

      let _ = process.receive(subject, 5000)
      Nil
    }
    Error(err) -> {
      io.println(
        "[Warning] Failed to decode credentials: " <> string.inspect(err),
      )
    }
  }

  Ok(SurrealWssConnection(client.data, builder.connection))
}

fn handle_message(
  connection: collie.Connection,
  state: SurrealWssState,
  message: collie.Message(SurrealWssMessage),
) -> collie.Next(SurrealWssState, SurrealWssMessage) {
  case message {
    collie.Text(data) -> {
      case json.parse(data, surreal_wss_response_decoder(decode.dynamic)) {
        Ok(response) -> {
          let receiver = dict.get(state.receivers, response.id)
          case receiver {
            Ok(receiver) -> process.send(receiver, response)
            _ -> Nil
          }
          collie.continue(
            SurrealWssState(
              ..state,
              receivers: dict.drop(state.receivers, [response.id]),
              connection: case state.pending_use {
                option.Some(#(namespace, database)) ->
                  state.connection
                  |> surreal.with_namespace(namespace)
                  |> surreal.with_database(database)
                _ -> state.connection
              },
              pending_use: option.None,
            ),
          )
        }
        Error(_) -> {
          collie.continue(state)
        }
      }
    }
    collie.Binary(_) -> collie.continue(state)
    collie.User(Query(query, receiver)) -> {
      let _ =
        collie.send_text_frame(
          connection,
          json.to_string(
            json.object([
              #("id", json.int(state.last_id + 1)),
              #("method", json.string("query")),
              #("params", json.preprocessed_array([json.string(query)])),
            ]),
          ),
        )

      collie.continue(
        SurrealWssState(
          ..state,
          last_id: state.last_id + 1,
          receivers: dict.insert(state.receivers, state.last_id + 1, receiver),
        ),
      )
    }
    collie.User(Use(namespace:, database:, receiver:)) -> {
      let _ =
        collie.send_text_frame(
          connection,
          json.to_string(
            json.object([
              #("id", json.int(state.last_id + 1)),
              #("method", json.string("use")),
              #(
                "params",
                json.preprocessed_array([
                  json.string(namespace),
                  json.string(database),
                ]),
              ),
            ]),
          ),
        )

      collie.continue(
        SurrealWssState(
          ..state,
          last_id: state.last_id + 1,
          receivers: dict.insert(state.receivers, state.last_id + 1, receiver),
          pending_use: option.Some(#(namespace, database)),
        ),
      )
    }
    collie.User(Signin(collection, fields, receiver)) -> {
      let _ =
        collie.send_text_frame(
          connection,
          json.to_string(
            json.object([
              #("id", json.int(state.last_id + 1)),
              #("method", json.string("signin")),
              #(
                "params",
                json.preprocessed_array([
                  case collection {
                    "" ->
                      json.object(
                        list.map(fields, fn(entry) {
                          let #(key, value) = entry
                          #(key, surreal_ql.to_json(value))
                        }),
                      )
                    _ ->
                      json.object([
                        #("NS", json.string(state.connection.namespace)),
                        #("DB", json.string(state.connection.database)),
                        #("AC", json.string(collection)),
                        ..list.map(fields, fn(entry) {
                          let #(key, value) = entry
                          #(key, surreal_ql.to_json(value))
                        })
                      ])
                  },
                ]),
              ),
            ]),
          ),
        )

      collie.continue(
        SurrealWssState(
          ..state,
          last_id: state.last_id + 1,
          receivers: dict.insert(state.receivers, state.last_id + 1, receiver),
        ),
      )
    }
    collie.User(Signup(collection, fields, receiver)) -> {
      let _ =
        collie.send_text_frame(
          connection,
          json.to_string(
            json.object([
              #("id", json.int(state.last_id + 1)),
              #("method", json.string("signup")),
              #(
                "params",
                json.preprocessed_array([
                  json.object([
                    #("NS", json.string(state.connection.namespace)),
                    #("DB", json.string(state.connection.database)),
                    #("AC", json.string(collection)),
                    ..list.map(fields, fn(entry) {
                      let #(key, value) = entry
                      #(key, surreal_ql.to_json(value))
                    })
                  ]),
                ]),
              ),
            ]),
          ),
        )

      collie.continue(
        SurrealWssState(
          ..state,
          last_id: state.last_id + 1,
          receivers: dict.insert(state.receivers, state.last_id + 1, receiver),
        ),
      )
    }
  }
}
