import gleam/int
import gleam/json
import lustre/attribute.{class}
import lustre/element
import lustre/element/html.{body, div, head, html, link, meta, script, title}
import shared/message.{RoomInfo}
import wisp.{type Response}

pub fn main_html(rooms: List(#(String, message.RoomInfo))) -> Response {
  html([], [
    page_head([
      script(
        [attribute.type_("module"), attribute.src("/lustre/runtime.mjs")],
        "",
      ),
      script([attribute.type_("module"), attribute.src("/client.js")], ""),
      script(
        [
          attribute.id("model"),
          attribute.type_("application/json"),
        ],
        json.array(rooms, fn(room) {
          let #(id, RoomInfo(name, pin_enc)) = room
          json.object([
            #("id", json.string(id)),
            #("name", json.string(name)),
            #("key", json.string(pin_enc)),
          ])
        })
          |> json.to_string,
      ),
    ]),
    page_body([
      div([class("scanlines")], []),
      splash(
        "
╔═══════════════════════════════════════╗
║       Q U I Z T E R M I N A L         ║
╚═══════════════════════════════════════╝
",
      ),
      html.div([attribute.id("app")], []),
    ]),
  ])
  |> element.to_document_string
  |> wisp.html_response(200)
}

pub fn html_404() -> Response {
  html([], [
    page_head([element.none()]),
    page_body([
      div([class("scanlines")], []),
      splash(
        "
╔═══════════════════════════════════════╗
║           4       0       4           ║
╚═════════════════════════════════ohno!═╝
",
      ),
    ]),
  ])
  |> element.to_document_string
  |> wisp.html_response(400)
}

fn splash(splash: String) {
  div([class("terminal-header")], [
    html.pre([class("terminal-title")], [
      html.text(splash),
    ]),
  ])
}

fn page_head(header_elements: List(element.Element(msg))) {
  head([], [
    meta([attribute.charset("utf-8")]),
    meta([
      attribute.name("viewport"),
      attribute.content("width=device-width, initial-scale=1.0"),
    ]),
    title([], "QUIZTERMINAL v1.0"),
    link([
      attribute.rel("stylesheet"),
      attribute.type_("text/css"),
      attribute.href("/static/layout.css"),
    ]),
    ..header_elements
  ])
}

fn page_body(elements: List(element.Element(msg))) {
  body([], [
    div([class("terminal-screen")], [
      div([class("terminal-glow")], elements),
    ]),
  ])
}

pub fn create_json_response(response: #(Int, String, String)) {
  let #(code, message, output) = response
  wisp.log_info("[api][" <> int.to_string(code) <> "][" <> message <> "]")
  json.object([#("response", json.string(output))])
  |> json.to_string
  |> wisp.json_response(200)
}
