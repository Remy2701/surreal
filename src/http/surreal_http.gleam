import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import surreal.{type Connection, type SurrealResponse}
import surreal/identifier
import surreal_ql

fn apply_headers(
  req: request.Request(a),
  connection: Connection,
) -> request.Request(a) {
  req
  |> request.set_header("Keep-Alive", "timeout=5, max=1000")
  |> request.set_header("Surreal-DB", connection.database)
  |> request.set_header("Surreal-NS", connection.namespace)
  |> request.set_header("Authorization", connection.authorization)
  |> request.set_header("Accept", "application/json")
}

//-----------------------------------------------------------------------------------------------//
//                                          GET /status                                          //
//-----------------------------------------------------------------------------------------------//

/// The status endpoint returns a simple response indicating the status of the SurrealDB server.
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#status
pub fn status(connection: Connection) -> Result(Nil, Nil) {
  use req <- result.try(
    request.to(connection.endpoint <> "/status")
    |> result.replace_error(Nil),
  )

  use resp <- result.try(
    httpc.send(
      req
      |> request.set_method(http.Get)
      |> apply_headers(connection),
    )
    |> result.replace_error(Nil),
  )

  case resp.status {
    200 -> Ok(Nil)
    _ -> Error(Nil)
  }
}

//-----------------------------------------------------------------------------------------------//
//                                          GET /health                                          //
//-----------------------------------------------------------------------------------------------//

/// The health endpoint returns a simple response indicating the health of the SurrealDB server.
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#health
pub fn health(connection: Connection) -> Result(Nil, Nil) {
  use req <- result.try(
    request.to(connection.endpoint <> "/health")
    |> result.replace_error(Nil),
  )

  use resp <- result.try(
    httpc.send(
      req
      |> request.set_method(http.Get)
      |> apply_headers(connection),
    )
    |> result.replace_error(Nil),
  )

  case resp.status {
    200 -> Ok(Nil)
    _ -> Error(Nil)
  }
}

//-----------------------------------------------------------------------------------------------//
//                                          GET /ready                                           //
//-----------------------------------------------------------------------------------------------//

/// The ready endpoint returns a simple response indicating the readiness of the SurrealDB server.
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#ready
pub fn ready(connection: Connection) -> Result(Nil, Nil) {
  use req <- result.try(
    request.to(connection.endpoint <> "/ready")
    |> result.replace_error(Nil),
  )

  use resp <- result.try(
    httpc.send(
      req
      |> request.set_method(http.Get)
      |> apply_headers(connection),
    )
    |> result.replace_error(Nil),
  )

  case resp.status {
    200 -> Ok(Nil)
    _ -> Error(Nil)
  }
}

//-----------------------------------------------------------------------------------------------//
//                                         GET /version                                          //
//-----------------------------------------------------------------------------------------------//

/// The version endpoint returns the current version of the SurrealDB server.
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#version
pub fn version(connection: Connection) -> Result(String, surreal.SurrealError) {
  use req <- result.try(
    request.to(connection.endpoint <> "/version")
    |> result.replace_error(surreal.InvalidUrl),
  )

  use resp <- result.try(
    httpc.send(
      req
      |> request.set_method(http.Get)
      |> apply_headers(connection),
    )
    |> result.map_error(surreal.HttpError),
  )

  case resp.status {
    200 -> Ok(resp.body)
    _ ->
      Error(surreal.ErrorResponse(
        code: resp.status,
        details: "",
        description: "",
        information: resp.body,
      ))
  }
}

//-----------------------------------------------------------------------------------------------//
//                                         POST /signin                                          //
//-----------------------------------------------------------------------------------------------//

/// Access an existing account inside the SurrealDB database server.
/// 
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#signin
pub fn signin(
  connection: Connection,
  table: String,
  email: String,
  password: String,
  content: List(#(String, surreal_ql.SurrealQL)),
) -> Result(String, surreal.SurrealError) {
  use req <- result.try(
    request.to(connection.endpoint <> "/signin")
    |> result.replace_error(surreal.InvalidUrl),
  )

  use resp <- result.try(
    httpc.send(
      req
      |> request.set_method(http.Post)
      |> apply_headers(connection)
      |> request.set_body(
        surreal_ql.Object([
          #("db", surreal_ql.String(connection.database)),
          #("ns", surreal_ql.String(connection.namespace)),
          #("ac", surreal_ql.String(table)),
          #("email", surreal_ql.String(email)),
          #("password", surreal_ql.String(password)),
          ..content
        ])
        |> surreal_ql.to_string(),
      ),
    )
    |> result.map_error(surreal.HttpError),
  )

  json.parse(resp.body, surreal.auth_result_decoder())
  |> result.map_error(surreal.FailedToDecode)
  |> result.flatten()
}

//-----------------------------------------------------------------------------------------------//
//                                         POST /signup                                          //
//-----------------------------------------------------------------------------------------------//

/// Create an account inside the SurrealDB database server.
/// 
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#signup
pub fn signup(
  connection: Connection,
  table: String,
  email: String,
  password: String,
  content: List(#(String, surreal_ql.SurrealQL)),
) -> Result(String, surreal.SurrealError) {
  use req <- result.try(
    request.to(connection.endpoint <> "/signup")
    |> result.replace_error(surreal.InvalidUrl),
  )
  use resp <- result.try(
    httpc.send(
      req
      |> request.set_method(http.Post)
      |> apply_headers(connection)
      |> request.set_body(
        surreal_ql.Object([
          #("db", surreal_ql.String(connection.database)),
          #("ns", surreal_ql.String(connection.namespace)),
          #("ac", surreal_ql.String(table)),
          #("email", surreal_ql.String(email)),
          #("password", surreal_ql.String(password)),
          ..content
        ])
        |> surreal_ql.to_string(),
      ),
    )
    |> result.map_error(surreal.HttpError),
  )

  json.parse(resp.body, surreal.auth_result_decoder())
  |> result.map_error(surreal.FailedToDecode)
  |> result.flatten()
}

//-----------------------------------------------------------------------------------------------//
//                                        GET /key/:table                                        //
//-----------------------------------------------------------------------------------------------//

/// The endpoint to select all records in a specific table in the database.
/// 
/// The equivalent query is:
/// ```surrealql
/// SELECT * FROM type::table($table);
/// ```
/// 
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#get-table
pub fn get_records(
  connection: Connection,
  table: String,
  decoder: decode.Decoder(a),
) -> Result(List(SurrealResponse(List(a))), surreal.SurrealError) {
  use req <- result.try(
    request.to(connection.endpoint <> "/key/" <> table)
    |> result.replace_error(surreal.InvalidUrl),
  )
  use resp <- result.try(
    httpc.send(
      req
      |> request.set_method(http.Get)
      |> apply_headers(connection),
    )
    |> result.map_error(surreal.HttpError),
  )

  resp.body
  |> json.parse(surreal.result_decoder(decode.list(decoder)))
  |> result.map_error(surreal.FailedToDecode)
  |> result.flatten()
}

//-----------------------------------------------------------------------------------------------//
//                                       POST /key/:table                                        //
//-----------------------------------------------------------------------------------------------//

/// The endpoint to create a new record in a specific table in the database.
/// 
/// The equivalent query is:
/// ```surrealql
/// CREATE type::table($table) CONTENT $data;
/// ```
/// 
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#post-table
pub fn post_table(
  connection: Connection,
  table: String,
  content: surreal_ql.SurrealQL,
  decoder: decode.Decoder(a),
) -> Result(List(SurrealResponse(List(a))), surreal.SurrealError) {
  use req <- result.try(
    request.to(connection.endpoint <> "/key/" <> table)
    |> result.replace_error(surreal.InvalidUrl),
  )
  use resp <- result.try(
    httpc.send(
      req
      |> request.set_method(http.Post)
      |> request.set_body(surreal_ql.to_json(content) |> json.to_string())
      |> apply_headers(connection),
    )
    |> result.map_error(surreal.HttpError),
  )

  resp.body
  |> json.parse(surreal.result_decoder(decode.list(decoder)))
  |> result.map_error(surreal.FailedToDecode)
  |> result.flatten()
}

//-----------------------------------------------------------------------------------------------//
//                                      GET /key/:table/:id                                      //
//-----------------------------------------------------------------------------------------------//

/// The get record endpoint selects a specific record in a specific table in the database.
/// 
/// The equivalent query is:
/// ```surrealql
/// SELECT * FROM type::record($table, $id);
/// ```
/// 
/// Consider using the `get_record` function instead if you don't need the raw response, as it will 
/// simplify the result handling.
/// 
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#get-record
pub fn get_record_raw(
  connection: Connection,
  table: String,
  id: identifier.Identifier(a),
  decoder: decode.Decoder(a),
) -> Result(List(SurrealResponse(List(a))), surreal.SurrealError) {
  use req <- result.try(
    request.to(
      connection.endpoint <> "/key/" <> table <> "/" <> identifier.to_string(id),
    )
    |> result.replace_error(surreal.InvalidUrl),
  )
  use resp <- result.try(
    httpc.send(
      req
      |> request.set_method(http.Get)
      |> apply_headers(connection),
    )
    |> result.map_error(surreal.HttpError),
  )

  resp.body
  |> json.parse(surreal.result_decoder(decode.list(decoder)))
  |> result.map_error(surreal.FailedToDecode)
  |> result.flatten()
}

/// The get record endpoint selects a specific record in a specific table in the database.
/// 
/// The equivalent query is:
/// ```surrealql
/// SELECT * FROM type::record($table, $id);
/// ```
/// 
/// This is the simplified version of `get_record_raw` which already extracts the result.
///
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#get-record
pub fn get_record(
  connection: Connection,
  table: String,
  id: identifier.Identifier(a),
  decoder: decode.Decoder(a),
) -> Result(a, surreal.SurrealError) {
  use result <- result.try(get_record_raw(connection, table, id, decoder))
  case result {
    [] -> Error(surreal.NoResponse)
    [first, ..] ->
      case first {
        surreal.SurrealResponse(result:, ..) ->
          result
          |> option.to_result(surreal.NoResponse)
          |> result.try(fn(result) {
            case result {
              [] -> Error(surreal.NoResponse)
              [first, ..] -> Ok(first)
            }
          })
        surreal.SurrealErrorResponse(kind:, details:, result:, ..) ->
          Error(surreal.ErrorResponse(
            200,
            string.inspect(details),
            kind,
            result,
          ))
      }
  }
}

//-----------------------------------------------------------------------------------------------//
//                                     POST /key/:table/:id                                      //
//-----------------------------------------------------------------------------------------------//

/// Creates a record in a specific table in the database.
/// 
/// The equivalent query is:
/// ```surrealql
/// CREATE type::table($id, $table) CONTENT $data;
/// ```
/// 
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#post-record
pub fn post_record(
  connection: Connection,
  table: String,
  id: identifier.Identifier(a),
  content: surreal_ql.SurrealQL,
  decoder: decode.Decoder(a),
) -> Result(List(SurrealResponse(List(a))), surreal.SurrealError) {
  use req <- result.try(
    request.to(
      connection.endpoint <> "/key/" <> table <> "/" <> identifier.to_string(id),
    )
    |> result.replace_error(surreal.InvalidUrl),
  )

  use resp <- result.try(
    httpc.send(
      req
      |> request.set_method(http.Post)
      |> apply_headers(connection)
      |> request.set_body(surreal_ql.to_string(content)),
    )
    |> result.map_error(surreal.HttpError),
  )

  resp.body
  |> json.parse(surreal.result_decoder(decode.list(decoder)))
  |> result.map_error(surreal.FailedToDecode)
  |> result.flatten()
}

//-----------------------------------------------------------------------------------------------//
//                                           POST /sql                                           //
//-----------------------------------------------------------------------------------------------//

/// The SQL endpoint enables use of SurrealQL queries.
/// 
/// https://surrealdb.com/docs/reference/rest-api/http-protocol#sql
pub fn run_sql(
  connection: Connection,
  query: String,
  parameters: List(#(String, surreal_ql.SurrealQL)),
  decoder: decode.Decoder(a),
) -> Result(List(SurrealResponse(a)), surreal.SurrealError) {
  use req <- result.try(
    request.to(connection.endpoint <> "/sql")
    |> result.replace_error(surreal.InvalidUrl),
  )

  use resp <- result.try(
    httpc.send(
      req
      |> request.set_method(http.Post)
      |> apply_headers(connection)
      |> request.set_query(
        parameters
        |> list.map(fn(entry) { #(entry.0, surreal_ql.to_string(entry.1)) }),
      )
      |> request.set_body(query),
    )
    |> result.map_error(surreal.HttpError),
  )

  resp.body
  |> json.parse(surreal.result_decoder(decoder))
  |> result.map_error(surreal.FailedToDecode)
  |> result.flatten()
}
