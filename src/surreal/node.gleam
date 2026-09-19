import gleam/bool
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/string
import surreal_ql
import surreal_type

pub type OrderDirection {
  Ascending
  Descending
}

pub type Operator {
  Equal
  NotEqual
  GreaterThan
  LessThan
  GreaterThanOrEqual
  LessThanOrEqual
  Access
  Inside
  RelationTo
  RelationFrom
  RelationToFrom
  Indexing
  And
  Or
}

pub type SelectField {
  SelectField(field: Node, alias: Option(String), value: Bool)
}

pub type Node {
  DefineNormalTable(
    name: String,
    schemafull: Bool,
    permissions: Node,
    as_: Option(Node),
  )
  DefineRelationTable(
    name: String,
    schemafull: Bool,
    permissions: Node,
    in: String,
    out: String,
  )
  DefineField(
    name: Node,
    table: String,
    type_: surreal_type.SurrealType,
    flexible: Bool,
    default: Option(Node),
    assert_: Option(Node),
    permissions: Option(Node),
  )
  DefineIndex(name: String, table: String, fields: List(String), unique: Bool)
  FunctionCall(lhs: Option(String), rhs: String, arguments: List(Node))
  Self
  None
  Full
  All
  Number(Float)
  Parameter(String)
  Identifier(String)
  Value(surreal_ql.SurrealQL)
  Object(List(#(String, Node)))
  Array(List(Node))
  Select(
    fields: List(SelectField),
    only: Bool,
    table: String,
    where: Option(Node),
    order: Option(List(#(Node, OrderDirection))),
    limit: Option(Node),
    group_all: Bool,
  )
  If(condition: Node, then_: Node, else_: Node)
  BinaryOperator(lhs: Node, operator: Operator, rhs: Node)
  WrappedNode(node: Node)
  Update(target: String, set: List(Node), where: Option(Node))
  Create(target: String, set: List(Node))
  Relate(table: String, from: Node, to: Node, set: List(Node))
  Lambda(parameters: List(String), body: Node)
  Delete(target: Node, where: Option(Node))
}

pub fn to_string(node: Node) -> String {
  case node {
    DefineNormalTable(name:, schemafull:, permissions:, as_:) ->
      "DEFINE TABLE "
      <> name
      <> " TYPE NORMAL "
      <> case schemafull {
        True -> " SCHEMAFULL"
        False -> " SCHEMALESS"
      }
      <> case as_ {
        option.Some(node) -> " AS " <> to_string(node)
        option.None -> ""
      }
      <> " PERMISSIONS "
      <> case permissions {
        None -> "NONE"
        Full -> "FULL"
        All -> "ALL"
        _ -> ""
      }
    DefineRelationTable(name:, schemafull:, permissions:, in:, out:) ->
      "DEFINE TABLE "
      <> name
      <> " TYPE RELATION "
      <> " IN "
      <> in
      <> " OUT "
      <> out
      <> case schemafull {
        True -> " SCHEMAFULL"
        False -> " SCHEMALESS"
      }
      <> " PERMISSIONS "
      <> case permissions {
        None -> "NONE"
        Full -> "FULL"
        All -> "ALL"
        _ -> ""
      }
    DefineField(
      name:,
      table:,
      type_:,
      default:,
      assert_:,
      permissions:,
      flexible:,
    ) ->
      "DEFINE FIELD "
      <> to_string(name)
      <> " ON "
      <> table
      <> case flexible {
        True -> " FLEXIBLE"
        False -> ""
      }
      <> " TYPE "
      <> surreal_type.to_string(type_)
      <> case default {
        option.Some(node) -> " DEFAULT " <> to_string(node)
        option.None -> ""
      }
      <> case assert_ {
        option.Some(node) -> " ASSERT " <> to_string(node)
        option.None -> ""
      }
      <> case permissions {
        option.Some(node) -> " PERMISSIONS " <> to_string(node)
        option.None -> ""
      }
    DefineIndex(name:, table:, fields:, unique:) ->
      "DEFINE INDEX "
      <> name
      <> " ON "
      <> table
      <> " FIELDS "
      <> string.join(fields, ", ")
      <> case unique {
        True -> " UNIQUE"
        False -> ""
      }
    FunctionCall(lhs:, rhs:, arguments:) ->
      case lhs {
        option.Some(lhs) -> lhs <> "::"
        _ -> ""
      }
      <> rhs
      <> "("
      <> string.join(list.map(arguments, to_string), ", ")
      <> ")"
    Self -> "@"
    None -> "NONE"
    Full -> "FULL"
    All -> "*"
    Number(value) -> float.to_string(value)
    Parameter(name) -> "$" <> name
    Identifier(name) -> name
    Value(value) -> surreal_ql.to_string(value)
    Object(fields) -> {
      let field_strings =
        fields
        |> list.map(fn(entry) {
          let #(key, value) = entry
          key <> ": " <> to_string(value)
        })
        |> string.join(", ")
      "{" <> field_strings <> "}"
    }
    Array(fields) -> {
      let field_strings =
        fields
        |> list.map(to_string)
        |> string.join(", ")
      "[" <> field_strings <> "]"
    }
    Select(fields:, only:, table:, where:, order:, limit:, group_all:) ->
      "SELECT "
      <> string.join(
        list.map(fields, fn(field) {
          to_string(field.field)
          <> case field.alias {
            option.Some(alias) -> " AS " <> alias
            option.None -> ""
          }
        }),
        ", ",
      )
      <> " FROM "
      <> case only {
        True -> "ONLY "
        False -> ""
      }
      <> table
      <> case where {
        option.Some(node) -> " WHERE " <> to_string(node)
        option.None -> ""
      }
      <> case order {
        option.Some(order) ->
          " ORDER BY "
          <> string.join(
            list.map(order, fn(entry) {
              let #(field, direction) = entry
              to_string(field)
              <> " "
              <> case direction {
                Ascending -> "ASC"
                Descending -> "DESC"
              }
            }),
            ", ",
          )
        option.None -> ""
      }
      <> case group_all {
        True -> " GROUP ALL"
        False -> ""
      }
      <> case limit {
        option.Some(node) -> " LIMIT " <> to_string(node)
        option.None -> ""
      }
    BinaryOperator(lhs:, operator:, rhs:) ->
      to_string(lhs)
      <> case operator {
        Equal -> " = "
        NotEqual -> " != "
        GreaterThan -> " > "
        LessThan -> " < "
        GreaterThanOrEqual -> " >= "
        LessThanOrEqual -> " <= "
        Access -> "."
        Inside -> " INSIDE "
        RelationTo -> "->"
        RelationFrom -> "<-"
        RelationToFrom -> "<->"
        Indexing -> "["
        And -> " AND "
        Or -> " OR "
      }
      <> to_string(rhs)
      <> case operator {
        Indexing -> "]"
        _ -> ""
      }
    If(condition:, then_:, else_:) ->
      "IF "
      <> to_string(condition)
      <> " THEN "
      <> to_string(then_)
      <> " ELSE "
      <> to_string(else_)
      <> " END"
    WrappedNode(node) -> "(" <> to_string(node) <> ")"
    Update(target:, set:, where:) ->
      "UPDATE "
      <> target
      <> " SET "
      <> string.join(list.map(set, to_string), ", ")
      <> case where {
        option.Some(node) -> " WHERE " <> to_string(node)
        option.None -> ""
      }
    Create(target:, set:) ->
      "CREATE "
      <> target
      <> " SET "
      <> string.join(list.map(set, to_string), ", ")
    Relate(table:, from:, to:, set:) ->
      "RELATE "
      <> to_string(from)
      <> "->"
      <> table
      <> "->"
      <> to_string(to)
      <> case set {
        [] -> ""
        values -> " SET " <> string.join(list.map(values, to_string), ", ")
      }
    Lambda(parameters:, body:) ->
      "|"
      <> list.map(parameters, fn(p) { "$" <> p }) |> string.join(", ")
      <> "| "
      <> to_string(body)
    Delete(target:, where:) ->
      "DELETE "
      <> to_string(target)
      <> case where {
        option.Some(node) -> " WHERE " <> to_string(node)
        option.None -> ""
      }
  }
}

fn surreal_type_to_gleam_code(type_: surreal_type.SurrealType) -> String {
  case type_ {
    surreal_type.Int -> "surreal_type.Int"
    surreal_type.String -> "surreal_type.String"
    surreal_type.Float -> "surreal_type.Float"
    surreal_type.Identifier(name) ->
      "surreal_type.Identifier(\"" <> name <> "\")"
    surreal_type.Record(name) -> "surreal_type.Record(\"" <> name <> "\")"
    surreal_type.Datetime -> "surreal_type.Datetime"
    surreal_type.Bool -> "surreal_type.Bool"
    surreal_type.Option(inner) ->
      "surreal_type.Option(" <> surreal_type_to_gleam_code(inner) <> ")"
    surreal_type.Array(inner) ->
      "surreal_type.Array(" <> surreal_type_to_gleam_code(inner) <> ")"
    surreal_type.Point -> "surreal_type.Point"
    surreal_type.Object -> "surreal_type.Object"
    surreal_type.None -> "surreal_type.None"
  }
}

pub fn replace_variables(
  node: Node,
  values: List(#(String, surreal_ql.SurrealQL)),
) -> Node {
  case node {
    DefineNormalTable(..) -> node
    DefineRelationTable(..) -> node
    DefineField(..) -> node
    DefineIndex(..) -> node
    FunctionCall(lhs:, rhs:, arguments:) ->
      FunctionCall(
        lhs: lhs,
        rhs: rhs,
        arguments: list.map(arguments, replace_variables(_, values)),
      )
    Self -> node
    None -> node
    Full -> node
    All -> node
    Number(_) -> node
    Parameter(parameter) ->
      case list.key_find(values, parameter) {
        Ok(value) -> Value(value)
        Error(_) -> node
      }
    Value(_) -> node
    Object(fields) ->
      Object(
        list.map(fields, fn(entry) {
          let #(key, value) = entry
          #(key, replace_variables(value, values))
        }),
      )
    Array(fields) -> Array(list.map(fields, replace_variables(_, values)))
    Identifier(_) -> node
    Select(fields:, where:, limit:, ..) ->
      Select(
        ..node,
        fields: list.map(fields, fn(field) {
          SelectField(..field, field: replace_variables(field.field, values))
        }),
        where: option.map(where, replace_variables(_, values)),
        limit: option.map(limit, replace_variables(_, values)),
      )
    BinaryOperator(lhs:, operator:, rhs:) ->
      BinaryOperator(
        lhs: replace_variables(lhs, values),
        operator: operator,
        rhs: replace_variables(rhs, values),
      )
    If(condition:, then_:, else_:) ->
      If(
        condition: replace_variables(condition, values),
        then_: replace_variables(then_, values),
        else_: replace_variables(else_, values),
      )
    WrappedNode(node) -> WrappedNode(replace_variables(node, values))
    Update(target:, set:, where:) ->
      Update(
        target: target,
        set: list.map(set, replace_variables(_, values)),
        where: option.map(where, replace_variables(_, values)),
      )
    Create(target:, set:) ->
      Create(target: target, set: list.map(set, replace_variables(_, values)))
    Relate(from:, to:, set:, ..) ->
      Relate(
        ..node,
        from: replace_variables(from, values),
        to: replace_variables(to, values),
        set: list.map(set, replace_variables(_, values)),
      )
    Lambda(parameters:, body:) ->
      Lambda(
        parameters: parameters,
        body: replace_variables(
          body,
          values
            |> list.filter(fn(entry) { !list.contains(parameters, entry.0) }),
        ),
      )
    Delete(target:, where:) ->
      Delete(
        target: replace_variables(target, values),
        where: option.map(where, replace_variables(_, values)),
      )
  }
}

fn surreal_value_to_gleam_code(value: surreal_ql.SurrealQL) -> String {
  case value {
    surreal_ql.String(value) -> "surreal_ql.String(\"" <> value <> "\")"
    surreal_ql.Int(value) -> "surreal_ql.Int(" <> int.to_string(value) <> ")"
    surreal_ql.Float(value) ->
      "surreal_ql.Float(" <> float.to_string(value) <> ")"
    surreal_ql.Bool(True) -> "surreal_ql.Bool(True)"
    surreal_ql.Bool(False) -> "surreal_ql.Bool(False)"
    surreal_ql.Datetime(date) -> "surreal_ql.Datetime(\"" <> date <> "\")"
    surreal_ql.Null -> "surreal_ql.Null"
    surreal_ql.Object(value) ->
      "surreal_ql.Object(["
      <> string.join(
        list.map(value, fn(value) {
          "#(\""
          <> value.0
          <> "\", "
          <> surreal_value_to_gleam_code(value.1)
          <> ")"
        }),
        ",",
      )
      <> "])"
    surreal_ql.Raw(value) -> "surreal_ql.Raw(\"" <> value <> "\")"
    surreal_ql.Array(values) ->
      "surreal_ql.Array(["
      <> string.join(list.map(values, surreal_value_to_gleam_code), ",")
      <> "])"
  }
}

pub fn to_gleam_code(node: Node) -> String {
  case node {
    DefineNormalTable(name:, schemafull:, permissions:, as_:) ->
      "node.DefineNormalTable(name: \""
      <> name
      <> "\", schemafull: "
      <> bool.to_string(schemafull)
      <> ", permissions: "
      <> to_gleam_code(permissions)
      <> ", as_: "
      <> option.map(as_, fn(node) {
        "option.Some(" <> to_gleam_code(node) <> ")"
      })
      |> option.unwrap("option.None")
      <> ")"
    DefineRelationTable(name:, schemafull:, permissions:, in:, out:) ->
      "node.DefineRelationTable(name: \""
      <> name
      <> "\", schemafull: "
      <> bool.to_string(schemafull)
      <> ", permissions: "
      <> to_gleam_code(permissions)
      <> ", in: \""
      <> in
      <> "\", out: \""
      <> out
      <> "\")"
    DefineField(
      name:,
      table:,
      type_:,
      default:,
      assert_:,
      permissions:,
      flexible:,
    ) ->
      "node.DefineField(name: "
      <> to_gleam_code(name)
      <> ", table: \""
      <> table
      <> "\", type_: "
      <> surreal_type_to_gleam_code(type_)
      <> ", default: "
      <> option.map(default, fn(node) {
        "option.Some(" <> to_gleam_code(node) <> ")"
      })
      |> option.unwrap("option.None")
      <> ", assert_: "
      <> option.map(assert_, fn(node) {
        "option.Some(" <> to_gleam_code(node) <> ")"
      })
      |> option.unwrap("option.None")
      <> ", permissions: "
      <> option.map(permissions, fn(node) {
        "option.Some(" <> to_gleam_code(node) <> ")"
      })
      |> option.unwrap("option.None")
      <> ", flexible: "
      <> bool.to_string(flexible)
      <> ")"
    DefineIndex(name:, table:, fields:, unique:) ->
      "node.DefineIndex(name: \""
      <> name
      <> "\", table: \""
      <> table
      <> "\", fields: ["
      <> string.join(
        list.map(fields, fn(field) { "\"" <> field <> "\"" }),
        ", ",
      )
      <> "], unique: "
      <> bool.to_string(unique)
      <> ")"
    FunctionCall(lhs:, rhs:, arguments:) ->
      "node.FunctionCall(lhs: "
      <> case lhs {
        option.Some(lhs) -> "option.Some(\"" <> lhs <> "\")"
        option.None -> "option.None"
      }
      <> ", rhs: \""
      <> rhs
      <> "\", arguments: ["
      <> string.join(list.map(arguments, to_gleam_code), ", ")
      <> "])"
    Self -> "node.Self"
    None -> "node.None"
    Full -> "node.Full"
    All -> "node.All"
    Number(value) -> "node.Number(" <> float.to_string(value) <> ")"
    Parameter(value) -> "node.Parameter(\"" <> value <> "\")"
    Identifier(value) -> "node.Identifier(\"" <> value <> "\")"
    Value(value) -> "node.Value(" <> surreal_value_to_gleam_code(value) <> ")"
    Object(fields) ->
      "node.Object(["
      <> string.join(
        list.map(fields, fn(value) {
          let #(key, value) = value
          "#(\"" <> key <> "\", " <> to_gleam_code(value) <> ")"
        }),
        ", ",
      )
      <> "])"
    Array(fields) ->
      "node.Array(["
      <> string.join(list.map(fields, to_gleam_code), ", ")
      <> "])"
    Select(fields:, only:, table:, where:, order:, limit:, group_all:) ->
      "node.Select(fields: ["
      <> string.join(
        list.map(fields, fn(field) {
          "node.SelectField(field: "
          <> to_gleam_code(field.field)
          <> ", alias: "
          <> option.map(field.alias, fn(alias) {
            "option.Some(\"" <> alias <> "\")"
          })
          |> option.unwrap("option.None")
          <> ", value: "
          <> bool.to_string(field.value)
          <> ")"
        }),
        ", ",
      )
      <> "], only: "
      <> bool.to_string(only)
      <> ", table: \""
      <> table
      <> "\", where: "
      <> option.map(where, fn(node) {
        "option.Some(" <> to_gleam_code(node) <> ")"
      })
      |> option.unwrap("option.None")
      <> ", order: "
      <> option.map(order, fn(order) {
        "option.Some(["
        <> list.map(order, fn(entry) {
          let #(field, direction) = entry
          "#("
          <> to_gleam_code(field)
          <> ", "
          <> case direction {
            Ascending -> "node.Ascending"
            Descending -> "node.Descending"
          }
          <> ")"
        })
        |> string.join(", ")
        <> "])"
      })
      |> option.unwrap("option.None")
      <> ", limit: "
      <> option.map(limit, fn(node) {
        "option.Some(" <> to_gleam_code(node) <> ")"
      })
      |> option.unwrap("option.None")
      <> ", group_all: "
      <> bool.to_string(group_all)
      <> ")"
    BinaryOperator(lhs:, operator:, rhs:) ->
      "node.BinaryOperator(lhs: "
      <> to_gleam_code(lhs)
      <> ", operator: "
      <> case operator {
        Equal -> "node.Equal"
        NotEqual -> "node.NotEqual"
        GreaterThan -> "node.GreaterThan"
        LessThan -> "node.LessThan"
        GreaterThanOrEqual -> "node.GreaterThanOrEqual"
        LessThanOrEqual -> "node.LessThanOrEqual"
        Access -> "node.Access"
        Inside -> "node.Inside"
        RelationTo -> "node.RelationTo"
        RelationFrom -> "node.RelationFrom"
        RelationToFrom -> "node.RelationToFrom"
        Indexing -> "node.Indexing"
        And -> "node.And"
        Or -> "node.Or"
      }
      <> ", rhs: "
      <> to_gleam_code(rhs)
      <> ")"
    If(condition:, then_:, else_:) ->
      "node.If(condition: "
      <> to_gleam_code(condition)
      <> ", then_: "
      <> to_gleam_code(then_)
      <> ", else_: "
      <> to_gleam_code(else_)
      <> ")"
    WrappedNode(node) -> "node.WrappedNode(node: " <> to_gleam_code(node) <> ")"
    Update(target:, set:, where:) ->
      "node.Update(target: \""
      <> target
      <> "\", set: ["
      <> string.join(list.map(set, to_gleam_code), ", ")
      <> "], where: "
      <> option.map(where, fn(node) {
        "option.Some(" <> to_gleam_code(node) <> ")"
      })
      |> option.unwrap("option.None")
      <> ")"
    Create(target:, set:) ->
      "node.Create(target: \""
      <> target
      <> "\", set: ["
      <> string.join(list.map(set, to_gleam_code), ", ")
      <> "])"
    Relate(table:, from:, to:, set:) ->
      "node.Relate(table: \""
      <> table
      <> "\", from: "
      <> to_gleam_code(from)
      <> ", to: "
      <> to_gleam_code(to)
      <> ", set: ["
      <> string.join(list.map(set, to_gleam_code), ", ")
      <> "])"
    Lambda(parameters:, body:) ->
      "node.Lambda(parameters: ["
      <> string.join(list.map(parameters, fn(p) { "\"" <> p <> "\"" }), ", ")
      <> "], body: "
      <> to_gleam_code(body)
      <> ")"
    Delete(target:, where:) ->
      "node.Delete(target: "
      <> to_gleam_code(target)
      <> ", where: "
      <> option.map(where, fn(node) {
        "option.Some(" <> to_gleam_code(node) <> ")"
      })
      |> option.unwrap("option.None")
      <> ")"
  }
}
