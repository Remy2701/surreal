import gleam/dict
import gleam/dynamic/decode

//-----------------------------------------------------------------------------------------------//
//                                             INFO                                              //
//-----------------------------------------------------------------------------------------------//

/// The response type for the INFO TABLE command. The TABLE command returns information regarding 
/// the events, fields, tables, and live statement configurations on a specific table.
/// 
/// ```surql
/// INFO FOR TABLE $table_name;
/// ```
///
/// https://surrealdb.com/docs/reference/query-language/statements/info#table-information
pub type InfoTableResponse {
  InfoTableResponse(
    events: List(#(String, String)),
    fields: List(#(String, String)),
    indexes: List(#(String, String)),
    lives: List(#(String, String)),
    tables: List(#(String, String)),
  )
}

pub fn info_table_response_decoder() -> decode.Decoder(InfoTableResponse) {
  use events <- decode.field(
    "events",
    decode.dict(decode.string, decode.string),
  )
  use fields <- decode.field(
    "fields",
    decode.dict(decode.string, decode.string),
  )
  use indexes <- decode.field(
    "indexes",
    decode.dict(decode.string, decode.string),
  )
  use lives <- decode.field("lives", decode.dict(decode.string, decode.string))
  use tables <- decode.field(
    "tables",
    decode.dict(decode.string, decode.string),
  )

  decode.success(InfoTableResponse(
    dict.to_list(events),
    dict.to_list(fields),
    dict.to_list(indexes),
    dict.to_list(lives),
    dict.to_list(tables),
  ))
}
