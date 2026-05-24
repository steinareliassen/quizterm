import gleam/int
import gleam/json
import lustre/element
import lustre/element/html
import web/components.{terminal_header}
import wisp

pub fn create_json_response(response: #(Int, String, String)) {
  let #(code, message, output) = response
  wisp.log_info("[api][" <> int.to_string(code) <> "][" <> message <> "]")
  json.object([#("response", json.string(output))])
  |> json.to_string
  |> wisp.json_response(200)
}

pub fn status_head(output: String) {
  fn() -> element.Element(a) { html.text(output) |> terminal_header }
}
