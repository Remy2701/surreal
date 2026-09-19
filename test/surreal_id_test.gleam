import gleam/list
import gleam/option
import gleam/string
import surreal/identifier

pub fn surreal_rand_id_test() {
  let id = identifier.generate(option.None)
  assert id.type_ == option.None as "Expected untyped identifier"
  assert string.length(id.id) == 20 as "Expected identifier to be 20 characters"

  let allowed_characters = "abcdefghijklmnopqrstuvwxyz0123456789"
  string.to_graphemes(id.id)
  |> list.each(fn(grapheme) {
    assert string.contains(allowed_characters, grapheme)
      as "Expected identifier to only contain allowed characters"
  })
}
