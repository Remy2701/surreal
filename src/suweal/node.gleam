import gleam/float
import gleam/list
import gleam/option.{type Option}
import gleam/string
import omcg/module
import suweal/surreal_ql
import suweal/surreal_type

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

fn surreal_type_to_module(type_: surreal_type.SurrealType) -> module.Module {
  case type_ {
    surreal_type.Int ->
      module.binop.access(
        module.identifier.create("surreal_type"),
        module.identifier.create("Int"),
      )
      |> module.add_import(["suweal", "surreal_type"])
    surreal_type.String ->
      module.binop.access(
        module.identifier.create("surreal_type"),
        module.identifier.create("String"),
      )
      |> module.add_import(["suweal", "surreal_type"])
    surreal_type.Float ->
      module.binop.access(
        module.identifier.create("surreal_type"),
        module.identifier.create("Float"),
      )
      |> module.add_import(["suweal", "surreal_type"])
    surreal_type.Identifier(name) ->
      module.binop.access(
        module.identifier.create("surreal_type"),
        module.identifier.create("Identifier"),
      )
      |> module.function_call.create()
      |> module.function_call.add(module.literal.string(name))
      |> module.add_import(["suweal", "surreal_type"])
    surreal_type.Record(name) ->
      module.binop.access(
        module.identifier.create("surreal_type"),
        module.identifier.create("Record"),
      )
      |> module.function_call.create()
      |> module.function_call.add(module.literal.string(name))
      |> module.add_import(["suweal", "surreal_type"])
    surreal_type.Datetime ->
      module.binop.access(
        module.identifier.create("surreal_type"),
        module.identifier.create("Datetime"),
      )
      |> module.add_import(["suweal", "surreal_type"])
    surreal_type.Bool ->
      module.binop.access(
        module.identifier.create("surreal_type"),
        module.identifier.create("Bool"),
      )
      |> module.add_import(["suweal", "surreal_type"])
    surreal_type.Option(inner) ->
      module.binop.access(
        module.identifier.create("surreal_type"),
        module.identifier.create("Option"),
      )
      |> module.function_call.create()
      |> module.function_call.add(surreal_type_to_module(inner))
      |> module.add_import(["suweal", "surreal_type"])
    surreal_type.Array(inner) ->
      module.binop.access(
        module.identifier.create("surreal_type"),
        module.identifier.create("Array"),
      )
      |> module.function_call.create()
      |> module.function_call.add(surreal_type_to_module(inner))
      |> module.add_import(["suweal", "surreal_type"])
    surreal_type.Point ->
      module.binop.access(
        module.identifier.create("surreal_type"),
        module.identifier.create("Point"),
      )
      |> module.add_import(["suweal", "surreal_type"])
    surreal_type.Object ->
      module.binop.access(
        module.identifier.create("surreal_type"),
        module.identifier.create("Object"),
      )
      |> module.add_import(["suweal", "surreal_type"])
    surreal_type.None ->
      module.binop.access(
        module.identifier.create("surreal_type"),
        module.identifier.create("None"),
      )
      |> module.add_import(["suweal", "surreal_type"])
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

fn surreal_value_to_module(value: surreal_ql.SurrealQL) -> module.Module {
  case value {
    surreal_ql.String(value) ->
      module.binop.access(
        module.identifier.create("surreal_ql"),
        module.identifier.create("String"),
      )
      |> module.function_call.create()
      |> module.function_call.add(module.literal.string(value))
      |> module.add_import(["suweal", "surreal_ql"])
    surreal_ql.Int(value) ->
      module.binop.access(
        module.identifier.create("surreal_ql"),
        module.identifier.create("Int"),
      )
      |> module.function_call.create()
      |> module.function_call.add(module.literal.int(value))
      |> module.add_import(["suweal", "surreal_ql"])
    surreal_ql.Float(value) ->
      module.binop.access(
        module.identifier.create("surreal_ql"),
        module.identifier.create("Float"),
      )
      |> module.function_call.create()
      |> module.function_call.add(module.literal.float(value))
      |> module.add_import(["suweal", "surreal_ql"])
    surreal_ql.Bool(value) ->
      module.binop.access(
        module.identifier.create("surreal_ql"),
        module.identifier.create("Bool"),
      )
      |> module.function_call.create()
      |> module.function_call.add(module.literal.bool(value))
      |> module.add_import(["suweal", "surreal_ql"])
    surreal_ql.Datetime(value) ->
      module.binop.access(
        module.identifier.create("surreal_ql"),
        module.identifier.create("Datetime"),
      )
      |> module.function_call.create()
      |> module.function_call.add(module.literal.string(value))
      |> module.add_import(["suweal", "surreal_ql"])
    surreal_ql.Null ->
      module.binop.access(
        module.identifier.create("surreal_ql"),
        module.identifier.create("Null"),
      )
      |> module.add_import(["suweal", "surreal_ql"])
    surreal_ql.Object(value) ->
      module.binop.access(
        module.identifier.create("surreal_ql"),
        module.identifier.create("Object"),
      )
      |> module.function_call.create()
      |> module.function_call.add(
        module.literal.list(
          list.map(value, fn(value) {
            module.literal.tuple([
              module.literal.string(value.0),
              surreal_value_to_module(value.1),
            ])
          }),
        ),
      )
      |> module.add_import(["suweal", "surreal_ql"])
    surreal_ql.Raw(value) ->
      module.binop.access(
        module.identifier.create("surreal_ql"),
        module.identifier.create("Raw"),
      )
      |> module.function_call.create()
      |> module.function_call.add(module.literal.string(value))
      |> module.add_import(["suweal", "surreal_ql"])
    surreal_ql.Array(values) ->
      module.binop.access(
        module.identifier.create("surreal_ql"),
        module.identifier.create("Array"),
      )
      |> module.function_call.create()
      |> module.function_call.add(
        module.literal.list(list.map(values, surreal_value_to_module)),
      )
      |> module.add_import(["suweal", "surreal_ql"])
  }
}

fn option_of(
  value: option.Option(t),
  to_module: fn(t) -> module.Module,
) -> module.Module {
  case value {
    option.Some(value) ->
      module.binop.access(
        module.identifier.create("option"),
        module.identifier.create("Some"),
      )
      |> module.function_call.create()
      |> module.function_call.add(to_module(value))
      |> module.add_import(["gleam", "option"])
    option.None ->
      module.binop.access(
        module.identifier.create("option"),
        module.identifier.create("None"),
      )
      |> module.add_import(["gleam", "option"])
  }
}

pub fn to_module(node: Node) -> module.Module {
  case node {
    DefineNormalTable(name:, schemafull:, permissions:, as_:) ->
      module.binop.access(
        module.identifier.create("node"),
        module.identifier.create("DefineNormalTable"),
      )
      |> module.function_call.create()
      |> module.function_call.add_with_alias(
        "name",
        module.literal.string(name),
      )
      |> module.function_call.add_with_alias(
        "schemafull",
        module.literal.bool(schemafull),
      )
      |> module.function_call.add_with_alias(
        "permissions",
        to_module(permissions),
      )
      |> module.function_call.add_with_alias("as_", option_of(as_, to_module))
      |> module.add_import(["suweal", "node"])
    DefineRelationTable(name:, schemafull:, permissions:, in:, out:) ->
      module.binop.access(
        module.identifier.create("node"),
        module.identifier.create("DefineRelationTable"),
      )
      |> module.function_call.create()
      |> module.function_call.add_with_alias(
        "name",
        module.literal.string(name),
      )
      |> module.function_call.add_with_alias(
        "schemafull",
        module.literal.bool(schemafull),
      )
      |> module.function_call.add_with_alias(
        "permissions",
        to_module(permissions),
      )
      |> module.function_call.add_with_alias("in", module.literal.string(in))
      |> module.function_call.add_with_alias("out", module.literal.string(out))
      |> module.add_import(["suweal", "node"])
    DefineField(
      name:,
      table:,
      type_:,
      default:,
      assert_:,
      permissions:,
      flexible:,
    ) ->
      module.binop.access(
        module.identifier.create("node"),
        module.identifier.create("DefineField"),
      )
      |> module.function_call.create()
      |> module.function_call.add_with_alias("name", to_module(name))
      |> module.function_call.add_with_alias(
        "table",
        module.literal.string(table),
      )
      |> module.function_call.add_with_alias(
        "type_",
        surreal_type_to_module(type_),
      )
      |> module.function_call.add_with_alias(
        "default",
        option_of(default, to_module),
      )
      |> module.function_call.add_with_alias(
        "assert_",
        option_of(assert_, to_module),
      )
      |> module.function_call.add_with_alias(
        "permissions",
        option_of(permissions, to_module),
      )
      |> module.function_call.add_with_alias(
        "flexible",
        module.literal.bool(flexible),
      )
      |> module.add_import(["suweal", "node"])
    DefineIndex(name:, table:, fields:, unique:) ->
      module.binop.access(
        module.identifier.create("node"),
        module.identifier.create("DefineIndex"),
      )
      |> module.function_call.create()
      |> module.function_call.add_with_alias(
        "name",
        module.literal.string(name),
      )
      |> module.function_call.add_with_alias(
        "table",
        module.literal.string(table),
      )
      |> module.function_call.add_with_alias(
        "fields",
        module.literal.list(list.map(fields, module.literal.string)),
      )
      |> module.function_call.add_with_alias(
        "unique",
        module.literal.bool(unique),
      )
      |> module.add_import(["suweal", "node"])
    FunctionCall(lhs:, rhs:, arguments:) ->
      module.binop.access(
        module.identifier.create("node"),
        module.identifier.create("FunctionCall"),
      )
      |> module.function_call.create()
      |> module.function_call.add_with_alias(
        "lhs",
        option_of(lhs, module.literal.string),
      )
      |> module.function_call.add_with_alias("rhs", module.literal.string(rhs))
      |> module.function_call.add_with_alias(
        "arguments",
        module.literal.list(list.map(arguments, to_module)),
      )
      |> module.add_import(["suweal", "node"])
    Self ->
      module.binop.access(
        module.identifier.create("node"),
        module.identifier.create("Self"),
      )
      |> module.add_import(["suweal", "node"])
    None ->
      module.binop.access(
        module.identifier.create("node"),
        module.identifier.create("None"),
      )
      |> module.add_import(["suweal", "node"])
    Full ->
      module.binop.access(
        module.identifier.create("node"),
        module.identifier.create("Full"),
      )
      |> module.add_import(["suweal", "node"])
    All ->
      module.binop.access(
        module.identifier.create("node"),
        module.identifier.create("All"),
      )
      |> module.add_import(["suweal", "node"])
    Number(value) ->
      module.binop.access(
        module.identifier.create("node"),
        module.identifier.create("Number"),
      )
      |> module.function_call.create()
      |> module.function_call.add(module.literal.float(value))
      |> module.add_import(["suweal", "node"])
    Parameter(value) ->
      module.binop.access(
        module.identifier.create("node"),
        module.identifier.create("Parameter"),
      )
      |> module.function_call.create()
      |> module.function_call.add(module.literal.string(value))
      |> module.add_import(["suweal", "node"])
    Identifier(value) ->
      module.binop.access(
        module.identifier.create("node"),
        module.identifier.create("Identifier"),
      )
      |> module.function_call.create()
      |> module.function_call.add(module.literal.string(value))
      |> module.add_import(["suweal", "node"])
    Value(value) ->
      module.binop.access(
        module.identifier.create("node"),
        module.identifier.create("Value"),
      )
      |> module.function_call.create()
      |> module.function_call.add(surreal_value_to_module(value))
      |> module.add_import(["suweal", "node"])
    Object(fields) ->
      module.binop.access(
        module.identifier.create("node"),
        module.identifier.create("Object"),
      )
      |> module.function_call.create()
      |> module.function_call.add(
        module.literal.list(
          list.map(fields, fn(field) {
            let #(key, value) = field
            module.literal.tuple([module.literal.string(key), to_module(value)])
          }),
        ),
      )
      |> module.add_import(["suweal", "node"])
    Array(fields) ->
      module.binop.access(
        module.identifier.create("node"),
        module.identifier.create("Array"),
      )
      |> module.function_call.create()
      |> module.function_call.add(
        module.literal.list(list.map(fields, to_module)),
      )
      |> module.add_import(["suweal", "node"])
    Select(fields:, only:, table:, where:, order:, limit:, group_all:) ->
      module.binop.access(
        module.identifier.create("node"),
        module.identifier.create("Select"),
      )
      |> module.function_call.create()
      |> module.function_call.add_with_alias(
        "fields",
        module.literal.list(
          list.map(fields, fn(field) {
            module.binop.access(
              module.identifier.create("node"),
              module.identifier.create("SelectField"),
            )
            |> module.function_call.create()
            |> module.function_call.add_with_alias(
              "field",
              to_module(field.field),
            )
            |> module.function_call.add_with_alias(
              "alias",
              option_of(field.alias, module.literal.string),
            )
            |> module.function_call.add_with_alias(
              "value",
              module.literal.bool(field.value),
            )
          }),
        ),
      )
      |> module.function_call.add_with_alias("only", module.literal.bool(only))
      |> module.function_call.add_with_alias(
        "table",
        module.literal.string(table),
      )
      |> module.function_call.add_with_alias(
        "where",
        option_of(where, to_module),
      )
      |> module.function_call.add_with_alias(
        "order",
        option_of(order, fn(order) {
          module.literal.list(
            list.map(order, fn(entry) {
              let #(field, direction) = entry
              module.literal.tuple([
                to_module(field),
                module.binop.access(
                  module.identifier.create("node"),
                  module.identifier.create(case direction {
                    Ascending -> "Ascending"
                    Descending -> "Descending"
                  }),
                ),
              ])
            }),
          )
        }),
      )
      |> module.function_call.add_with_alias(
        "limit",
        option_of(limit, to_module),
      )
      |> module.function_call.add_with_alias(
        "group_all",
        module.literal.bool(group_all),
      )
      |> module.add_import(["suweal", "node"])
    BinaryOperator(lhs:, operator:, rhs:) ->
      module.binop.access(
        module.identifier.create("node"),
        module.identifier.create("BinaryOperator"),
      )
      |> module.function_call.create()
      |> module.function_call.add_with_alias("lhs", to_module(lhs))
      |> module.function_call.add_with_alias(
        "operator",
        module.binop.access(
          module.identifier.create("node"),
          module.identifier.create(case operator {
            Equal -> "Equal"
            NotEqual -> "NotEqual"
            GreaterThan -> "GreaterThan"
            LessThan -> "LessThan"
            GreaterThanOrEqual -> "GreaterThanOrEqual"
            LessThanOrEqual -> "LessThanOrEqual"
            Access -> "Access"
            Inside -> "Inside"
            RelationTo -> "RelationTo"
            RelationFrom -> "RelationFrom"
            RelationToFrom -> "RelationToFrom"
            Indexing -> "Indexing"
            And -> "And"
            Or -> "Or"
          }),
        ),
      )
      |> module.function_call.add_with_alias("rhs", to_module(rhs))
      |> module.add_import(["suweal", "node"])
    If(condition:, then_:, else_:) ->
      module.binop.access(
        module.identifier.create("node"),
        module.identifier.create("If"),
      )
      |> module.function_call.create()
      |> module.function_call.add_with_alias("condition", to_module(condition))
      |> module.function_call.add_with_alias("then_", to_module(then_))
      |> module.function_call.add_with_alias("else_", to_module(else_))
      |> module.add_import(["suweal", "node"])
    WrappedNode(node) ->
      module.binop.access(
        module.identifier.create("node"),
        module.identifier.create("WrappedNode"),
      )
      |> module.function_call.create()
      |> module.function_call.add_with_alias("node", to_module(node))
      |> module.add_import(["suweal", "node"])
    Update(target:, set:, where:) ->
      module.binop.access(
        module.identifier.create("node"),
        module.identifier.create("Update"),
      )
      |> module.function_call.create()
      |> module.function_call.add_with_alias(
        "target",
        module.literal.string(target),
      )
      |> module.function_call.add_with_alias(
        "set",
        module.literal.list(list.map(set, to_module)),
      )
      |> module.function_call.add_with_alias(
        "where",
        option_of(where, to_module),
      )
      |> module.add_import(["suweal", "node"])
    Create(target:, set:) ->
      module.binop.access(
        module.identifier.create("node"),
        module.identifier.create("Create"),
      )
      |> module.function_call.create()
      |> module.function_call.add_with_alias(
        "target",
        module.literal.string(target),
      )
      |> module.function_call.add_with_alias(
        "set",
        module.literal.list(list.map(set, to_module)),
      )
      |> module.add_import(["suweal", "node"])
    Relate(table:, from:, to:, set:) ->
      module.binop.access(
        module.identifier.create("node"),
        module.identifier.create("Relate"),
      )
      |> module.function_call.create()
      |> module.function_call.add_with_alias(
        "table",
        module.literal.string(table),
      )
      |> module.function_call.add_with_alias("from", to_module(from))
      |> module.function_call.add_with_alias("to", to_module(to))
      |> module.function_call.add_with_alias(
        "set",
        module.literal.list(list.map(set, to_module)),
      )
      |> module.add_import(["suweal", "node"])
    Lambda(parameters:, body:) ->
      module.binop.access(
        module.identifier.create("node"),
        module.identifier.create("Lambda"),
      )
      |> module.function_call.create()
      |> module.function_call.add_with_alias(
        "parameters",
        module.literal.list(list.map(parameters, module.literal.string)),
      )
      |> module.function_call.add_with_alias("body", to_module(body))
      |> module.add_import(["suweal", "node"])
    Delete(target:, where:) ->
      module.binop.access(
        module.identifier.create("node"),
        module.identifier.create("Delete"),
      )
      |> module.function_call.create()
      |> module.function_call.add_with_alias("target", to_module(target))
      |> module.function_call.add_with_alias(
        "where",
        option_of(where, to_module),
      )
      |> module.add_import(["suweal", "node"])
  }
}
