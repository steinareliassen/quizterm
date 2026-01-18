//// This module contains the code to run the sql queries defined in
//// `./src/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/option.{type Option}
import pog

/// A row you get from running the `find_admin` query
/// defined in `./src/sql/find_admin.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type FindAdminRow {
  FindAdminRow(name: Option(String), token: Option(String))
}

/// Runs the `find_admin` query
/// defined in `./src/sql/find_admin.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn find_admin(
  db: pog.Connection,
  arg_1: String,
) -> Result(pog.Returned(FindAdminRow), pog.QueryError) {
  let decoder = {
    use name <- decode.field(0, decode.optional(decode.string))
    use token <- decode.field(1, decode.optional(decode.string))
    decode.success(FindAdminRow(name:, token:))
  }

  "select name, token from admin where name = $1
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `insert_admin` query
/// defined in `./src/sql/insert_admin.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_admin(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "insert into admin(name, token) values ($1, $2)
"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}
